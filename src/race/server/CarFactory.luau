--!strict
-- Собирает модель машины. Физику (подвеску, мотор, руль) считает клиент владельца,
-- сервер только создает детали и отдает сетевое владение.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VehicleTuning = require(ReplicatedStorage.Shared.VehicleTuning)

local CHASSIS_SIZE = Vector3.new(5, 1.6, 9)
local BODY_COLORS = {
	Color3.fromRGB(230, 57, 70),
	Color3.fromRGB(29, 120, 255),
	Color3.fromRGB(255, 183, 3),
	Color3.fromRGB(46, 196, 182),
	Color3.fromRGB(155, 93, 229),
	Color3.fromRGB(255, 120, 30),
}

local CarFactory = {}

local function weldedPart(
	model: Model,
	chassis: BasePart,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = chassis.CFrame * offset
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = chassis
	weld.Part1 = part
	weld.Parent = part
	return part
end

function CarFactory.create(player: Player, spawn: CFrame, parent: Instance, colorIndex: number): Model
	local color = BODY_COLORS[(colorIndex - 1) % #BODY_COLORS + 1]

	local model = Instance.new("Model")
	model.Name = `Car_{player.Name}`
	model:SetAttribute("OwnerUserId", player.UserId)
	model:SetAttribute("StartCFrame", spawn)

	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = CHASSIS_SIZE
	chassis.CFrame = spawn
	chassis.Color = color
	chassis.Material = Enum.Material.SmoothPlastic
	chassis.TopSurface = Enum.SurfaceType.Smooth
	chassis.BottomSurface = Enum.SurfaceType.Smooth
	-- Без трения: если машина ляжет на брюхо, она скользит, а не прилипает.
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 100)
	chassis.Anchored = true
	chassis.Parent = model
	model.PrimaryPart = chassis

	weldedPart(model, chassis, "Cabin", Vector3.new(4.2, 1.4, 4), CFrame.new(0, 1.5, 0.8), Color3.fromRGB(30, 30, 40))
	weldedPart(model, chassis, "Spoiler", Vector3.new(5, 0.3, 1.2), CFrame.new(0, 1.6, 4), color)
	for _, side in { -1, 1 } do
		local light = weldedPart(
			model,
			chassis,
			"Headlight",
			Vector3.new(1, 0.4, 0.2),
			CFrame.new(side * 1.6, 0.2, -4.55),
			Color3.new(1, 1, 0.8)
		)
		light.Material = Enum.Material.Neon
	end

	-- Колеса чисто визуальные, на высоте, где они касаются земли в покое.
	local inset = VehicleTuning.WheelInset
	local wheelY = -(VehicleTuning.RestLength * (1 - VehicleTuning.CompressionAtRest))
	local wheelSize = Vector3.new(1, VehicleTuning.WheelRadius * 2, VehicleTuning.WheelRadius * 2)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local wheel = weldedPart(
				model,
				chassis,
				"Wheel",
				wheelSize,
				CFrame.new(x * (inset.X + 0.3), wheelY, z * inset.Z),
				Color3.fromRGB(20, 20, 20)
			)
			-- Ось цилиндра Roblox идет по X, то есть вбок от машины, как у настоящего колеса.
			wheel.Shape = Enum.PartType.Cylinder
		end
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 30)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.MaxDistance = 250
	billboard.Parent = chassis
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = player.DisplayName
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard

	model.Parent = parent
	return model
end

return CarFactory
