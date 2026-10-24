--!strict
-- Строит трек из списка сегментов. «Черепаха» (cf) стоит на верхней поверхности трека
-- в его центре и смотрит по ходу движения; каждый сегмент двигает ее дальше.

local TrackLayout = require(script.Parent.TrackLayout)

export type Checkpoint = {
	index: number,
	zone: Part,
	spawn: CFrame,
}

export type BuiltTrack = {
	model: Model,
	checkpoints: { Checkpoint },
	grid: { CFrame },
	killHeight: number,
}

local WIDTH = 28
local THICKNESS = 2
local RAIL_HEIGHT = 3
local RAIL_THICKNESS = 1
local MAX_STEP_DEGREES = 6
local ZONE_SIZE = Vector3.new(WIDTH + 8, 30, 12)
local GRID_ROWS = 6
local GRID_COLUMN_OFFSET = 7
local GRID_ROW_SPACING = 14

local TRACK_COLOR = Color3.fromRGB(45, 48, 56)
local RAIL_COLORS = { Color3.fromRGB(235, 64, 52), Color3.fromRGB(240, 240, 240) }
local BOOST_COLOR = Color3.fromRGB(60, 255, 120)
local GATE_COLOR = Color3.fromRGB(255, 200, 40)
local FINISH_COLOR = Color3.fromRGB(255, 255, 255)

local TrackBuilder = {}

local function makePart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

type Builder = {
	cf: CFrame,
	pieces: Folder,
	gates: Folder,
	pieceCount: number,
	minY: number,
	checkpoints: { Checkpoint },
	grid: { CFrame },
}

-- Кусок трека длиной length от текущей точки вперед. extra удлиняет его симметрично,
-- чтобы закрыть щели на внешней стороне поворота.
local function placePiece(builder: Builder, length: number, extra: number, boost: boolean?)
	builder.pieceCount += 1
	local center = builder.cf * CFrame.new(0, -THICKNESS / 2, -length / 2)
	local fullLength = length + extra

	makePart(builder.pieces, "Road", Vector3.new(WIDTH, THICKNESS, fullLength), center, TRACK_COLOR)

	local railColor = RAIL_COLORS[builder.pieceCount % #RAIL_COLORS + 1]
	local railY = THICKNESS / 2 + RAIL_HEIGHT / 2
	local railX = WIDTH / 2 + RAIL_THICKNESS / 2
	local railSize = Vector3.new(RAIL_THICKNESS, RAIL_HEIGHT, fullLength)
	makePart(builder.pieces, "Rail", railSize, center * CFrame.new(-railX, railY, 0), railColor)
	makePart(builder.pieces, "Rail", railSize, center * CFrame.new(railX, railY, 0), railColor)

	if boost then
		local pad = makePart(
			builder.pieces,
			"BoostPad",
			Vector3.new(WIDTH * 0.6, 0.1, math.min(12, length * 0.5)),
			center * CFrame.new(0, THICKNESS / 2 + 0.05, 0),
			BOOST_COLOR
		)
		pad.Material = Enum.Material.Neon
		pad:SetAttribute("Boost", true)
	end

	builder.minY = math.min(builder.minY, center.Position.Y)
	builder.cf *= CFrame.new(0, 0, -length)
end

-- Дуга из коротких хорд. rotate(angle) дает поворот черепахи на угол.
local function placeArc(
	builder: Builder,
	angleDegrees: number,
	radius: number,
	rotate: (number) -> CFrame,
	widthGap: boolean,
	shift: number?
)
	local steps = math.max(2, math.ceil(math.abs(angleDegrees) / MAX_STEP_DEGREES))
	local step = math.rad(angleDegrees) / steps
	local chord = 2 * radius * math.sin(math.abs(step) / 2)
	local extra = if widthGap then WIDTH * math.tan(math.abs(step) / 2) else 0.2
	local shiftPerStep = (shift or 0) / steps

	for _ = 1, steps do
		builder.cf *= rotate(step / 2)
		placePiece(builder, chord, extra)
		builder.cf *= rotate(step / 2) * CFrame.new(shiftPerStep, 0, 0)
	end
end

local function yaw(angle: number): CFrame
	-- Положительный угол в раскладке значит вправо, а в CFrame поворот вправо отрицательный.
	return CFrame.Angles(0, -angle, 0)
end

local function pitch(angle: number): CFrame
	return CFrame.Angles(angle, 0, 0)
end

local function placeGate(builder: Builder, isFinish: boolean)
	local index = #builder.checkpoints + 1
	local gate = Instance.new("Model")
	gate.Name = `Checkpoint{index}`
	gate.Parent = builder.gates

	local cf = builder.cf
	local color = if isFinish then FINISH_COLOR else GATE_COLOR
	local pillarX = WIDTH / 2 + 3
	for _, side in { -1, 1 } do
		local pillar = makePart(gate, "Pillar", Vector3.new(2, 18, 2), cf * CFrame.new(side * pillarX, 9, 0), color)
		pillar.Material = Enum.Material.Neon
	end
	local bar = makePart(gate, "Bar", Vector3.new(pillarX * 2 + 2, 2, 2), cf * CFrame.new(0, 18, 0), color)
	bar.Material = Enum.Material.Neon
	if isFinish then
		local line = makePart(gate, "FinishLine", Vector3.new(WIDTH, 0.1, 4), cf * CFrame.new(0, 0.05, 0), FINISH_COLOR)
		line.CanCollide = false
	end

	local zone = makePart(gate, "Zone", ZONE_SIZE, cf * CFrame.new(0, ZONE_SIZE.Y / 2 - 2, 0), color)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false

	local spawn = cf * CFrame.new(0, 4, -8)
	zone:SetAttribute("Index", index)
	zone:SetAttribute("SpawnCFrame", spawn)

	table.insert(builder.checkpoints, { index = index, zone = zone, spawn = spawn })
end

local function placeGrid(builder: Builder)
	-- Стартовая решетка позади текущей точки: два ряда машин, лицом по ходу.
	for row = 0, GRID_ROWS - 1 do
		for _, side in { -1, 1 } do
			local offset = CFrame.new(side * GRID_COLUMN_OFFSET, 4, 10 + row * GRID_ROW_SPACING + (side + 1) * 3)
			table.insert(builder.grid, builder.cf * offset)
		end
	end
	local line = makePart(
		builder.pieces,
		"StartLine",
		Vector3.new(WIDTH, 0.1, 2),
		builder.cf * CFrame.new(0, 0.05, 0),
		FINISH_COLOR
	)
	line.CanCollide = false
end

function TrackBuilder.build(parent: Instance, layout: TrackLayout.Layout?): BuiltTrack
	local spec = layout or TrackLayout
	local model = Instance.new("Model")
	model.Name = "Track"

	local pieces = Instance.new("Folder")
	pieces.Name = "Pieces"
	pieces.Parent = model
	local gates = Instance.new("Folder")
	gates.Name = "Checkpoints"
	gates.Parent = model

	local builder: Builder = {
		cf = spec.origin,
		pieces = pieces,
		gates = gates,
		pieceCount = 0,
		minY = spec.origin.Position.Y,
		checkpoints = {},
		grid = {},
	}

	for _, segment in spec.segments do
		if segment.kind == "straight" then
			placePiece(builder, segment.length, 0.2, segment.boost)
		elseif segment.kind == "turn" then
			placeArc(builder, segment.angle, segment.radius, yaw, true)
		elseif segment.kind == "vcurve" then
			placeArc(builder, segment.angle, segment.radius, pitch, false)
		elseif segment.kind == "loop" then
			-- Смещаем петлю вбок на ширину трека, чтобы выезд не врезался во въезд.
			placeArc(builder, 360, segment.radius, pitch, false, WIDTH + 10)
		elseif segment.kind == "gap" then
			-- Убираем наклон, переносим черепаху через яму и вниз.
			local position = builder.cf.Position
			local look = builder.cf.LookVector
			local flatLook = Vector3.new(look.X, 0, look.Z).Unit
			builder.cf = CFrame.lookAt(position, position + flatLook) * CFrame.new(0, -segment.drop, -segment.length)
		elseif segment.kind == "checkpoint" then
			placeGate(builder, false)
		elseif segment.kind == "finish" then
			placeGate(builder, true)
		elseif segment.kind == "grid" then
			placeGrid(builder)
		end
	end

	local gridStart = builder.grid[1] or spec.origin
	model:SetAttribute("CameraCFrame", CFrame.lookAt((gridStart * CFrame.new(30, 40, 60)).Position, gridStart.Position))
	model:SetAttribute("KillHeight", builder.minY - 60)
	model.Parent = parent

	return {
		model = model,
		checkpoints = builder.checkpoints,
		grid = builder.grid,
		killHeight = builder.minY - 60,
	}
end

return TrackBuilder
