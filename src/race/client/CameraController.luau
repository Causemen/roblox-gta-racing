--!strict
-- Камера позади машины. Ось «вверх» камеры плавно следует за машиной, поэтому в петле
-- мир переворачивается вместе с игроком, как в стант-гонках GTA.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CameraController = {}

local OFFSET = Vector3.new(0, 6, 16)
local LOOK_AHEAD = 6
local FOLLOW_SPEED = 10
local BASE_FOV = 70
local MAX_FOV = 95
local SHAKE_STUDS = 0.9 -- смещение камеры при полной тряске
local FOV_SPEED = 200 -- на этой скорости FOV максимальный

local target: BasePart? = nil
local overview: CFrame? = nil
local smoothedUp = Vector3.yAxis
local position: Vector3? = nil
local fovKick = 0 -- добавка к FOV, например на бусте
local smoothedKick = 0
local shake = 0 -- 0..1, затухает сам
local shakeBase = 0 -- постоянная тряска от скорости/буста

function CameraController.follow(part: BasePart?)
	target = part
	position = nil
end

-- Добавка к FOV в градусах (0 = нет), меняется плавно.
function CameraController.setFovKick(degrees: number)
	fovKick = degrees
end

-- Тряска камеры: impulse (0..1) разовый удар, затухает; base держится, пока выставлен.
function CameraController.addShake(impulse: number)
	shake = math.min(1, shake + impulse)
end

function CameraController.setShakeBase(amount: number)
	shakeBase = amount
end

function CameraController.setOverview(cframe: CFrame?)
	overview = cframe
end

function CameraController.start()
	local camera = Workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable

	RunService:BindToRenderStep("CarCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local part = target
		if not part or not part.Parent then
			if overview then
				camera.CFrame = overview
				camera.FieldOfView = BASE_FOV
			end
			return
		end

		local cf = part.CFrame
		local alpha = math.min(1, dt * FOLLOW_SPEED)
		smoothedUp = smoothedUp:Lerp(cf.UpVector, alpha).Unit

		-- Позиция сзади-сверху по направлению машины, но без резких рывков.
		local flatLook = (cf.LookVector - smoothedUp * cf.LookVector:Dot(smoothedUp))
		if flatLook.Magnitude < 0.01 then
			flatLook = cf.LookVector
		end
		flatLook = flatLook.Unit
		local desired = cf.Position - flatLook * OFFSET.Z + smoothedUp * OFFSET.Y
		position = if position then position:Lerp(desired, alpha) else desired
		local focus = cf.Position + flatLook * LOOK_AHEAD + smoothedUp * 2

		local look = CFrame.lookAt(position :: Vector3, focus, smoothedUp)
		shake = math.max(0, shake - dt * 2.5)
		local power = math.min(1, shake + shakeBase)
		if power > 0.01 then
			local t = os.clock() * 45
			local offset = Vector3.new(math.noise(t, 0, 1), math.noise(0, t, 2), 0) * power * SHAKE_STUDS
			look = look * CFrame.new(offset)
		end
		camera.CFrame = look

		local speed = part.AssemblyLinearVelocity.Magnitude
		smoothedKick += (fovKick - smoothedKick) * math.min(1, dt * 6)
		local goalFov = BASE_FOV + (MAX_FOV - BASE_FOV) * math.clamp(speed / FOV_SPEED, 0, 1) + smoothedKick
		camera.FieldOfView += (goalFov - camera.FieldOfView) * alpha
	end)
end

return CameraController
