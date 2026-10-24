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
local FOV_SPEED = 200 -- на этой скорости FOV максимальный

local target: BasePart? = nil
local overview: CFrame? = nil
local smoothedUp = Vector3.yAxis
local position: Vector3? = nil

function CameraController.follow(part: BasePart?)
	target = part
	position = nil
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

		camera.CFrame = CFrame.lookAt(position :: Vector3, focus, smoothedUp)

		local speed = part.AssemblyLinearVelocity.Magnitude
		local goalFov = BASE_FOV + (MAX_FOV - BASE_FOV) * math.clamp(speed / FOV_SPEED, 0, 1)
		camera.FieldOfView += (goalFov - camera.FieldOfView) * alpha
	end)
end

return CameraController
