--!strict
-- Автопилот для тестов в Studio: ведет машину по центральной линии трека и пишет в Output итог заезда
-- (время, вылеты, удары, места проблем). Нужные строки в логе Studio начинаются с [AutoTest].
-- Включается кнопкой справа сверху или автоматически, если у Workspace есть атрибут AutoTest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Input = require(script.Parent.Input)
local RaceRules = require(ReplicatedStorage.Shared.RaceRules)
local VehicleController = require(script.Parent.VehicleController)
local VehicleTuning = require(ReplicatedStorage.Shared.VehicleTuning)

type PathPoint = {
	position: Vector3,
	segment: number,
	kind: string,
}

local LOOKAHEAD_MIN = 30
local LOOKAHEAD_MAX = 90
local LOOKAHEAD_SECONDS = 0.45
local STEER_GAIN = 2.2
local PROBE_STEP = 40 -- шаг, которым смотрим вперед в поисках поворотов, studs
local PROBE_COUNT = 7
local MAX_SLIP = 9 -- как в TrackAnalysis: боковой снос в повороте v²/(R*сцепление), больше нельзя
local STEER_MARGIN = 0.85 -- какую долю максимального поворота руля считаем безопасной
local BRAKE_MARGIN = 0.6 -- какую долю тормозов закладываем в расчет
local BRAKE_SLACK = 8 -- превышение скорости, после которого жмем тормоз
local CRASH_DROP = 0.45 -- доля скорости, потерянная за CRASH_WINDOW, считается ударом
local CRASH_WINDOW = 0.3
local CRASH_MIN_SPEED = 40
local EVENT_COOLDOWN = 1
local MIN_PLANAR = 0.5 -- направление считаем «по плоскости», пока оно не почти вертикально

local AutoPilot = {}

local input: Input.Input
local path: { PathPoint } = {}
local enabled = false
local nearest = 1 -- индекс начала отрезка траектории, на котором сейчас машина
local along = 0 -- где на этом отрезке, от 0 до 1
local button: TextButton
local connectedCar: Model? = nil
local touchConnection: RBXScriptConnection? = nil

local startedAt = 0
local reported = false
local crashes = 0
local railHits = 0
local respawns = 0
local lastGround = { at = 0, speed = 0, where = "" } -- где и на какой скорости машина последний раз стояла на дороге
local maxSpeed = 0
local lastCrashAt = 0
local lastRailAt = 0
local history: { { at: number, speed: number } } = {}

local function describe(index: number): string
	local point = path[index]
	return `{point.kind}#{point.segment}`
end

local function elapsed(): string
	return RaceRules.formatTime(os.clock() - startedAt)
end

-- Ближайший к position отрезок траектории среди индексов from..to: индекс начала и положение на нем (0..1).
local function project(position: Vector3, from: number, to: number): (number, number)
	local bestIndex, bestAlong, bestDistance = from, 0, math.huge
	for index = from, to do
		local start, finish = path[index].position, path[index + 1].position
		local segment = finish - start
		local fraction = math.clamp((position - start):Dot(segment) / math.max(segment:Dot(segment), 1e-3), 0, 1)
		local distance = (start + segment * fraction - position).Magnitude
		if distance < bestDistance then
			bestIndex, bestAlong, bestDistance = index, fraction, distance
		end
	end
	return bestIndex, bestAlong
end

local function globalNearest(position: Vector3)
	nearest, along = project(position, 1, #path - 1)
end

local function updateNearest(position: Vector3)
	nearest, along = project(position, math.max(1, nearest - 3), math.min(#path - 1, nearest + 15))
end

-- Точка траектории на расстоянии distance вперед от места, где сейчас машина (по длине линии).
local function pointAhead(distance: number): Vector3
	local index = nearest
	local from = path[index].position:Lerp(path[index + 1].position, along)
	local remaining = distance
	while index < #path do
		local to = path[index + 1].position
		local length = (to - from).Magnitude
		if remaining <= length then
			return from:Lerp(to, remaining / math.max(length, 1e-3))
		end
		remaining -= length
		from = to
		index += 1
	end
	return path[#path].position
end

-- Максимальная скорость сейчас, чтобы успеть вписаться во все повороты в ближайших PROBE_COUNT * PROBE_STEP.
local function allowedSpeed(): number
	local allowed = math.huge
	for k = 1, PROBE_COUNT do
		local a = pointAhead((k - 1) * PROBE_STEP)
		local b = pointAhead(k * PROBE_STEP)
		local c = pointAhead((k + 1) * PROBE_STEP)
		local first, second = b - a, c - b
		if
			first.Magnitude > 1
			and second.Magnitude > 1
			and math.abs(first.Unit.Y) < MIN_PLANAR
			and math.abs(second.Unit.Y) < MIN_PLANAR
		then
			local flatFirst = Vector3.new(first.X, 0, first.Z).Unit
			local flatSecond = Vector3.new(second.X, 0, second.Z).Unit
			local angle = math.acos(math.clamp(flatFirst:Dot(flatSecond), -1, 1))
			if angle > 0.02 then
				local radius = PROBE_STEP / angle
				local limit = math.min(
					STEER_MARGIN * VehicleTuning.TurnRate * radius,
					math.sqrt(MAX_SLIP * radius * VehicleTuning.LateralGrip)
				)
				local reachable =
					math.sqrt(limit * limit + 2 * VehicleTuning.BrakeDeceleration * BRAKE_MARGIN * (k - 1) * PROBE_STEP)
				allowed = math.min(allowed, reachable)
			end
		end
	end
	return allowed
end

local function onRailTouched(other: BasePart)
	if other.Name ~= "Rail" or os.clock() - lastRailAt < EVENT_COOLDOWN then
		return
	end
	lastRailAt = os.clock()
	railHits += 1
	local speed = VehicleController.getTelemetry().speed
	print(
		`[AutoTest] {elapsed()} удар об ограждение: {describe(nearest)}, скорость {math.floor(
			speed
		)}`
	)
end

local function attachToCar()
	local car = VehicleController.getCar()
	if car == connectedCar then
		return
	end
	if touchConnection then
		touchConnection:Disconnect()
		touchConnection = nil
	end
	connectedCar = car
	if car and car.PrimaryPart then
		touchConnection = car.PrimaryPart.Touched:Connect(onRailTouched)
	end
end

local function detectCrash(speed: number, grounded: boolean)
	local now = os.clock()
	table.insert(history, { at = now, speed = speed })
	while #history > 0 and now - history[1].at > CRASH_WINDOW do
		table.remove(history, 1)
	end
	local peak = 0
	for _, sample in history do
		peak = math.max(peak, sample.speed)
	end
	if
		grounded
		and peak > CRASH_MIN_SPEED
		and speed < peak * (1 - CRASH_DROP)
		and now - lastCrashAt > EVENT_COOLDOWN
	then
		lastCrashAt = now
		crashes += 1
		print(
			`[AutoTest] {elapsed()} жесткий удар: {describe(nearest)}, скорость {math.floor(peak)} -> {math.floor(
				speed
			)}`
		)
	end
end

local function drive()
	attachToCar()
	local car = VehicleController.getCar()
	local chassis = if car then car.PrimaryPart else nil
	if not enabled or not chassis or #path == 0 then
		return
	end

	updateNearest(chassis.Position)
	local telemetry = VehicleController.getTelemetry()
	maxSpeed = math.max(maxSpeed, telemetry.speed)
	detectCrash(telemetry.speed, telemetry.grounded)

	if telemetry.grounded then
		lastGround = { at = os.clock(), speed = telemetry.speed, where = describe(nearest) }
	else
		-- В воздухе руль дает крен, а не поворот: ничего не нажимаем, машина сама выравнивается.
		input.throttle = 0
		input.steer = 0
		return
	end

	local lookahead = math.clamp(telemetry.speed * LOOKAHEAD_SECONDS, LOOKAHEAD_MIN, LOOKAHEAD_MAX)
	local target = chassis.CFrame:PointToObjectSpace(pointAhead(lookahead))
	local headingError = math.atan2(target.X, -target.Z)
	input.steer = math.clamp(headingError * STEER_GAIN, -1, 1)

	local allowed = allowedSpeed()
	if telemetry.speed > allowed + BRAKE_SLACK then
		input.throttle = -1
	elseif telemetry.speed > allowed then
		input.throttle = 0
	else
		input.throttle = 1
	end
end

local function refreshButton()
	button.Text = if enabled then "Автопилот: вкл" else "Автопилот: выкл"
	button.BackgroundColor3 = if enabled then Color3.fromRGB(40, 140, 70) else Color3.fromRGB(45, 52, 74)
end

function AutoPilot.setEnabled(value: boolean)
	enabled = value
	if not enabled then
		input.throttle = 0
		input.steer = 0
	end
	refreshButton()
end

function AutoPilot.onRaceStart()
	startedAt = os.clock()
	reported = false
	crashes, railHits, respawns, maxSpeed = 0, 0, 0, 0
	table.clear(history)
	nearest, along = 1, 0
	if enabled then
		print("[AutoTest] старт заезда")
	end
end

function AutoPilot.onCheckpoint(index: number, total: number)
	if enabled then
		local speed = math.floor(VehicleController.getTelemetry().speed)
		print(`[AutoTest] {elapsed()} чекпоинт {index}/{total}, скорость {speed}`)
	end
end

local function report(finished: boolean, place: number?)
	if not enabled or reported then
		return
	end
	reported = true
	print(
		`[AutoTest] RESULT finished={finished} time={elapsed()} place={place or 0} crashes={crashes} `
			.. `railHits={railHits} respawns={respawns} maxSpeed={math.floor(maxSpeed)} lastSegment={describe(nearest)}`
	)
end

function AutoPilot.onFinished(place: number)
	report(true, place)
end

function AutoPilot.onResults()
	report(false, nil)
end

function AutoPilot.start(playerInput: Input.Input, track: Model)
	input = playerInput
	local folder = track:WaitForChild("Path")
	local parts = folder:GetChildren()
	table.sort(parts, function(a: Instance, b: Instance): boolean
		return (a:GetAttribute("Index") :: number) < (b:GetAttribute("Index") :: number)
	end)
	for _, part in parts do
		table.insert(path, {
			position = (part :: BasePart).Position,
			segment = part:GetAttribute("Segment") :: number,
			kind = part:GetAttribute("Kind") :: string,
		})
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AutoPilot"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")
	button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(150, 32)
	button.Position = UDim2.new(1, -160, 0, 10)
	button.AnchorPoint = Vector2.new(1, 0)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Parent = gui
	button.Activated:Connect(function()
		AutoPilot.setEnabled(not enabled)
	end)

	VehicleController.respawned.Event:Connect(function(reason: string)
		respawns += 1
		local car = VehicleController.getCar()
		if car and car.PrimaryPart then
			globalNearest(car.PrimaryPart.Position)
		end
		table.clear(history)
		if enabled then
			print(
				`[AutoTest] {elapsed()} респаун ({reason}): {describe(nearest)}; последняя опора {lastGround.where}, `
					.. `скорость {math.floor(lastGround.speed)}, без опоры {string.format(
						"%.1f",
						os.clock() - lastGround.at
					)} с`
			)
		end
	end)
	RunService.PreSimulation:Connect(drive)

	AutoPilot.setEnabled(Workspace:GetAttribute("AutoTest") == true)
end

return AutoPilot
