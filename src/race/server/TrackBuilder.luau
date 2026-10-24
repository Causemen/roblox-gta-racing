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

local WIDTH = 36
local THICKNESS = 2
local RAIL_HEIGHT = 3
local RAIL_THICKNESS = 1
local MAX_STEP_DEGREES = 6
local LOOP_SHIFT = WIDTH + 10 -- на сколько выезд из петли смещен вбок от въезда
local ZONE_SIZE = Vector3.new(WIDTH + 8, 30, 12)
local GRID_ROWS = 6
local GRID_COLUMN_OFFSET = 7
local GRID_ROW_SPACING = 14

-- Ограждения без трения: машина скользит вдоль них, а не залипает и не разворачивается.
local RAIL_PHYSICS = PhysicalProperties.new(1, 0, 0, 100, 100)

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

type PathPoint = {
	cframe: CFrame,
	segment: number,
	kind: string,
}

type Builder = {
	cf: CFrame,
	pieces: Folder,
	gates: Folder,
	pieceCount: number,
	minY: number,
	checkpoints: { Checkpoint },
	grid: { CFrame },
	path: { PathPoint },
	segmentIndex: number,
	segmentKind: string,
}

-- Кусок трека длиной length от текущей точки вперед. extra удлиняет его симметрично,
-- чтобы закрыть щели на внешней стороне поворота.
local function placePiece(builder: Builder, length: number, extra: number, boost: boolean?, guide: boolean?)
	builder.pieceCount += 1
	table.insert(builder.path, {
		cframe = builder.cf * CFrame.new(0, 0, -length / 2),
		segment = builder.segmentIndex,
		kind = builder.segmentKind,
	})
	local center = builder.cf * CFrame.new(0, -THICKNESS / 2, -length / 2)
	local fullLength = length + extra

	local road = makePart(builder.pieces, "Road", Vector3.new(WIDTH, THICKNESS, fullLength), center, TRACK_COLOR)
	if guide then
		road:SetAttribute("Guide", true) -- машина сама доворачивается вдоль этого куска (client/VehicleController)
	end

	local railColor = RAIL_COLORS[builder.pieceCount % #RAIL_COLORS + 1]
	local railY = THICKNESS / 2 + RAIL_HEIGHT / 2
	local railX = WIDTH / 2 + RAIL_THICKNESS / 2
	local railSize = Vector3.new(RAIL_THICKNESS, RAIL_HEIGHT, fullLength)
	for _, side in { -1, 1 } do
		local rail = makePart(builder.pieces, "Rail", railSize, center * CFrame.new(side * railX, railY, 0), railColor)
		rail.CustomPhysicalProperties = RAIL_PHYSICS
	end

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
	widthGap: boolean
)
	local steps = math.max(2, math.ceil(math.abs(angleDegrees) / MAX_STEP_DEGREES))
	local step = math.rad(angleDegrees) / steps
	local chord = 2 * radius * math.sin(math.abs(step) / 2)
	local extra = if widthGap then WIDTH * math.tan(math.abs(step) / 2) else 0.2

	for _ = 1, steps do
		builder.cf *= rotate(step / 2)
		placePiece(builder, chord, extra)
		builder.cf *= rotate(step / 2)
	end
end

local function yaw(angle: number): CFrame
	-- Положительный угол в раскладке значит вправо, а в CFrame поворот вправо отрицательный.
	return CFrame.Angles(0, -angle, 0)
end

local function pitch(angle: number): CFrame
	return CFrame.Angles(angle, 0, 0)
end

-- Петля это винтовая линия с осью поперек трека: выезд смещается вбок на LOOP_SHIFT, а куски стоят вдоль
-- линии и стыкуются без ступенек (боковые сдвиги между кусками давали зубчатые ограждения).
local function placeLoop(builder: Builder, radius: number)
	local steps = math.ceil(360 / MAX_STEP_DEGREES)
	local step = math.rad(360) / steps
	local drift = LOOP_SHIFT / steps
	local flat = 2 * radius * math.sin(step / 2)
	local chord = math.sqrt(flat * flat + drift * drift)
	local tilt = math.atan2(drift, flat)
	local skew = yaw(tilt)
	local half = skew:Inverse() * pitch(step / 2) * skew
	local seam = WIDTH * math.tan(tilt) -- закрывает клин на стыке с прямой

	builder.cf *= skew
	for index = 1, steps do
		builder.cf *= half
		placePiece(builder, chord, if index == 1 or index == steps then seam else 0.2, nil, true)
		builder.cf *= half
	end
	builder.cf *= skew:Inverse()
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

-- Центральная линия трека невидимыми деталями: по ней едет автопилот (client/AutoPilot).
local function placePath(builder: Builder, model: Model)
	local folder = Instance.new("Folder")
	folder.Name = "Path"
	for index, point in builder.path do
		local marker = Instance.new("Part")
		marker.Name = `P{index}`
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.CanTouch = false
		marker.Transparency = 1
		marker.Size = Vector3.one
		marker.CFrame = point.cframe
		marker:SetAttribute("Index", index)
		marker:SetAttribute("Segment", point.segment)
		marker:SetAttribute("Kind", point.kind)
		marker.Parent = folder
	end
	folder.Parent = model
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
		path = {},
		segmentIndex = 0,
		segmentKind = "",
	}

	for index, segment in spec.segments do
		builder.segmentIndex = index
		builder.segmentKind = segment.kind
		if segment.kind == "straight" then
			placePiece(builder, segment.length, 0.2, segment.boost)
		elseif segment.kind == "turn" then
			placeArc(builder, segment.angle, segment.radius, yaw, true)
		elseif segment.kind == "vcurve" then
			placeArc(builder, segment.angle, segment.radius, pitch, false)
		elseif segment.kind == "loop" then
			placeLoop(builder, segment.radius)
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

	placePath(builder, model)

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
