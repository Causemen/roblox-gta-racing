--!strict
-- Аркадная физика машины на клиенте владельца (у него сетевое владение шасси).
-- Четыре луча вниз работают как подвеска, остальное (мотор, руль, сцепление, гравитация)
-- задается силами. На земле гравитация тянет в трассу, поэтому машина проходит петли.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Input = require(script.Parent.Input)
local VehicleMath = require(ReplicatedStorage.Shared.VehicleMath)
local VehicleTuning = require(ReplicatedStorage.Shared.VehicleTuning)

export type Telemetry = {
	speed: number,
	grounded: boolean,
	boosting: boolean,
	drift: number, -- 0..1, насколько машина в дрифте
}

local VehicleController = {}

-- Срабатывает после респауна, аргумент: причина ("manual", "fall", "stuck").
VehicleController.respawned = Instance.new("BindableEvent")

local WORLD_UP = Vector3.yAxis

local active: {
	car: Model,
	chassis: BasePart,
	center: VectorForce,
	torque: Torque,
	wheelOffsets: { Vector3 },
	wheelForces: { VectorForce },
	instances: { Instance },
	connection: RBXScriptConnection,
}? =
	nil

local AIR_TIME_DELAY = 0.15 -- сколько секунд в воздухе до замедления времени, чтобы кочки не включали его

local enabled = false
local airTime = 0
local timeScale: number? = nil -- во сколько раз замедлено время, пока машина в полете
local respawnCFrame: CFrame? = nil
local killHeight = -math.huge
local telemetry: Telemetry = { speed = 0, grounded = false, boosting = false, drift = 0 }

local function makeForce(chassis: BasePart, offset: Vector3, instances: { Instance }): VectorForce
	local attachment = Instance.new("Attachment")
	attachment.Name = "CarForce"
	attachment.Position = offset
	attachment.Parent = chassis
	local force = Instance.new("VectorForce")
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = false
	force.Force = Vector3.zero
	force.Parent = chassis
	table.insert(instances, attachment)
	table.insert(instances, force)
	return force
end

function VehicleController.setEnabled(value: boolean)
	enabled = value
end

function VehicleController.setRespawn(cframe: CFrame)
	respawnCFrame = cframe
end

function VehicleController.setKillHeight(height: number)
	killHeight = height
end

function VehicleController.getTelemetry(): Telemetry
	return telemetry
end

function VehicleController.getCar(): Model?
	return if active then active.car else nil
end

function VehicleController.respawn(reason: string?)
	local current = active
	if not current or not respawnCFrame or current.chassis.Anchored then
		return
	end
	-- Как в GTA: машина ставится на последний чекпоинт и сразу едет с небольшой скоростью.
	current.car:PivotTo(respawnCFrame)
	current.chassis.AssemblyLinearVelocity = respawnCFrame.LookVector * 40
	current.chassis.AssemblyAngularVelocity = Vector3.zero
	airTime, timeScale = 0, nil
	VehicleController.respawned:Fire(reason or "manual")
end

function VehicleController.detach()
	local current = active
	if not current then
		return
	end
	current.connection:Disconnect()
	for _, instance in current.instances do
		instance:Destroy()
	end
	active = nil
	airTime, timeScale = 0, nil
	telemetry = { speed = 0, grounded = false, boosting = false, drift = 0 }
end

function VehicleController.attach(car: Model, input: Input.Input, carsFolder: Instance)
	VehicleController.detach()
	local chassis = car.PrimaryPart :: BasePart
	respawnCFrame = car:GetAttribute("StartCFrame") :: CFrame?

	local instances: { Instance } = {}
	local centerAttachment = Instance.new("Attachment")
	centerAttachment.Name = "CarCenter"
	centerAttachment.Parent = chassis
	table.insert(instances, centerAttachment)

	local center = Instance.new("VectorForce")
	center.Attachment0 = centerAttachment
	center.RelativeTo = Enum.ActuatorRelativeTo.World
	center.ApplyAtCenterOfMass = true
	center.Force = Vector3.zero
	center.Parent = chassis
	table.insert(instances, center)

	local torque = Instance.new("Torque")
	torque.Attachment0 = centerAttachment
	torque.RelativeTo = Enum.ActuatorRelativeTo.World
	torque.Torque = Vector3.zero
	torque.Parent = chassis
	table.insert(instances, torque)

	local inset = VehicleTuning.WheelInset
	local wheelOffsets = {
		Vector3.new(-inset.X, 0, -inset.Z),
		Vector3.new(inset.X, 0, -inset.Z),
		Vector3.new(-inset.X, 0, inset.Z),
		Vector3.new(inset.X, 0, inset.Z),
	}
	local wheelForces = {}
	for _, offset in wheelOffsets do
		table.insert(wheelForces, makeForce(chassis, offset, instances))
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = { carsFolder }

	local gravityDir = -WORLD_UP
	local boostUntil = 0
	local stuckFor = 0
	local driftCharge = 0 -- сколько секунд подряд машина в дрифте: от этого зависит буст на выходе
	local driftAmount = 0 -- 0..1, плавно нарастает от тормоза/ручника с рулем или от полного руля на скорости
	local size = chassis.Size
	local rayLength = VehicleTuning.RestLength + VehicleTuning.WheelRadius

	local function step(dt: number)
		if chassis.Anchored then
			return
		end
		local mass = chassis.AssemblyMass
		local gravity = Workspace.Gravity
		local stiffness, damping = VehicleMath.suspension(
			mass,
			gravity,
			VehicleTuning.RestLength,
			VehicleTuning.CompressionAtRest,
			VehicleTuning.DampingRatio
		)
		local cf = chassis.CFrame
		local up, right, look = cf.UpVector, cf.RightVector, cf.LookVector
		local velocity = chassis.AssemblyLinearVelocity
		local forwardSpeed = velocity:Dot(look)
		local now = os.clock()

		local throttle = if enabled then input.throttle else 0
		local steer = if enabled then input.steer else 0
		local pitchInput = if enabled then input.pitch else 0
		local handbrake = enabled and input.handbrake

		-- Дрифт: тормоз или ручник вместе с рулем (или полный руль) на скорости. Сцепление падает,
		-- но чем больше угол заноса, тем сильнее оно возвращается, поэтому занос управляем.
		local slip = VehicleMath.slipAngle(forwardSpeed, velocity:Dot(right))
		local driftTarget = if telemetry.grounded
			then VehicleMath.driftTrigger(forwardSpeed, steer, throttle < 0, handbrake, VehicleTuning)
			else 0
		driftAmount = VehicleMath.smoothDrift(driftAmount, driftTarget, dt, VehicleTuning)
		if driftAmount > 0.5 and forwardSpeed > VehicleTuning.DriftMinSpeed * 0.8 then
			driftCharge += dt
		elseif driftAmount < 0.3 then
			-- Вышли из заноса на скорости: награда буст-ускорением. Потеряли скорость (удар): без награды.
			local reward = VehicleMath.driftBoostDuration(driftCharge, VehicleTuning)
			if reward > 0 and forwardSpeed > VehicleTuning.DriftMinSpeed then
				boostUntil = math.max(boostUntil, now + reward)
			end
			driftCharge = 0
		end
		local gripScale = VehicleMath.driftGrip(driftAmount, slip, VehicleTuning)

		-- Подвеска и боковое сцепление на каждом колесе.
		local grounded = 0
		local guideRoad: Instance? = nil
		local normalSum = Vector3.zero
		for i, offset in wheelOffsets do
			local origin = cf:PointToWorldSpace(offset)
			local hit = Workspace:Raycast(origin, -up * rayLength, rayParams)
			if hit then
				grounded += 1
				normalSum += hit.Normal
				if hit.Instance:GetAttribute("Boost") then
					boostUntil = now + VehicleTuning.BoostDuration
				end
				if not guideRoad and hit.Instance:GetAttribute("Guide") then
					guideRoad = hit.Instance
				end
				local compression = rayLength - hit.Distance
				local pointVelocity = chassis:GetVelocityAtPosition(origin)
				local spring = VehicleMath.springForce(compression, -pointVelocity:Dot(up), stiffness, damping)
				local grip = -right * pointVelocity:Dot(right) * (mass / 4) * VehicleTuning.LateralGrip * gripScale
				wheelForces[i].Force = up * spring + grip
			else
				wheelForces[i].Force = Vector3.zero
			end
		end
		local onGround = grounded >= 2

		-- Замедление времени в полете: скорость умножаем на k, гравитацию на k², траектория остается той же,
		-- но проходится дольше. На посадке скорость возвращаем.
		local slowdown = math.clamp(VehicleTuning.AirTimeScale, 0.2, 1)
		if onGround then
			airTime = 0
			if timeScale then
				chassis.AssemblyLinearVelocity = velocity / timeScale
				timeScale = nil
			end
		else
			airTime += dt
			if not timeScale and airTime >= AIR_TIME_DELAY and slowdown < 1 then
				timeScale = slowdown
				chassis.AssemblyLinearVelocity = velocity * slowdown
			end
		end
		local flightScale = timeScale or 1

		-- Своя гравитация: на трассе тянет в поверхность, в воздухе плавно возвращается вниз.
		local targetGravity = if onGround then -normalSum.Unit else -WORLD_UP
		gravityDir = gravityDir:Lerp(targetGravity, math.min(1, dt * VehicleTuning.GravityBlend)).Unit
		local force = (gravityDir * flightScale * flightScale + WORLD_UP) * mass * gravity -- + WORLD_UP гасит гравитацию мира

		local boosting = now < boostUntil
		local angular = chassis.AssemblyAngularVelocity
		local inertia = mass * (size.X * size.X + size.Z * size.Z) / 12

		if onGround then
			local driveThrottle = VehicleMath.driftThrottle(throttle, driftAmount, VehicleTuning)
			local accel = VehicleMath.driveAcceleration(forwardSpeed, driveThrottle, boosting, VehicleTuning)
			if throttle == 0 and not boosting then
				accel -= forwardSpeed * VehicleTuning.RollingDrag
			end
			accel -= forwardSpeed * VehicleTuning.DriftDrag * driftAmount
			if handbrake and forwardSpeed > 1 and not boosting then
				accel -= VehicleTuning.HandbrakeDeceleration
			end
			force += look * accel * mass

			local baseYaw =
				VehicleMath.desiredYawRate(forwardSpeed, steer, VehicleTuning.TurnRate, VehicleTuning.FullSteerSpeed)
			local desiredYaw = VehicleMath.driftYawRate(baseYaw, slip, steer, driftAmount, VehicleTuning)
			if guideRoad and VehicleTuning.RoadGuide > 0 then
				-- Петля идет винтом и уводит дорогу вбок: без доворота машина ехала бы в забор.
				local roadForward = -(guideRoad :: BasePart).CFrame.ZVector
				local flat = roadForward - up * roadForward:Dot(up)
				if flat.Magnitude > 0.1 then
					flat = flat.Unit
					local misalignment = math.atan2(up:Dot(look:Cross(flat)), look:Dot(flat))
					desiredYaw += misalignment * VehicleTuning.RoadGuide
				end
			end
			local yawRate = angular:Dot(up)
			torque.Torque = up * (desiredYaw - yawRate) * VehicleTuning.YawResponse * inertia
		else
			if boosting and forwardSpeed < VehicleTuning.BoostSpeed * flightScale then
				-- Предел буста действует и в воздухе: без него прыжок разгонял машину до 350 и перелетал трассу.
				force += look * VehicleTuning.BoostAcceleration * 0.5 * mass * flightScale * flightScale
			end
			-- В воздухе: газ/тормоз наклоняют нос, руль дает крен. Без кнопок машина выравнивается.
			local desired = right * (-pitchInput * VehicleTuning.AirPitchRate)
				+ look * (steer * VehicleTuning.AirRollRate)
			if pitchInput == 0 and steer == 0 then
				desired += up:Cross(WORLD_UP) * VehicleTuning.AirLeveling
			end
			-- Вращение вокруг «вверх» в воздухе не трогаем, гасим только наклон и крен.
			local current = angular - up * angular:Dot(up)
			torque.Torque = (desired - current) * VehicleTuning.AirResponse * inertia
		end
		center.Force = force

		telemetry = { speed = velocity.Magnitude, grounded = onGround, boosting = boosting, drift = driftAmount }

		-- Упал с трассы или застрял: возвращаем на последний чекпоинт.
		if chassis.Position.Y < killHeight then
			VehicleController.respawn("fall")
			return
		end
		if enabled and velocity.Magnitude < VehicleTuning.StuckSpeed then
			stuckFor += dt
			if stuckFor >= VehicleTuning.StuckSeconds then
				stuckFor = 0
				VehicleController.respawn("stuck")
			end
		else
			stuckFor = 0
		end
	end

	active = {
		car = car,
		chassis = chassis,
		center = center,
		torque = torque,
		wheelOffsets = wheelOffsets,
		wheelForces = wheelForces,
		instances = instances,
		connection = RunService.Heartbeat:Connect(step),
	}
end

return VehicleController
