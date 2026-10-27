-- Запуск: lune run tests/TrackGeometry.spec.luau
-- Проверяет, что трек не пересекает сам себя: ведет «черепаху» по участкам, как TrackBuilder, и ищет точки пути,
-- которые лежат рядом в плане и на одной высоте, хотя идут далеко друг от друга по трассе.

local TrackCanyon = require("../src/shared/TrackCanyon")
local TrackSegments = require("../src/shared/TrackSegments")

local SAMPLE = 8 -- шаг точек пути, studs
local START_WIDTH = 56 -- как в TrackBuilder
local LOOP_SHIFT_MARGIN = 10
local APART = 150 -- точки ближе этого по трассе считаются соседними
local LOOP_APART = 800 -- вокруг петли соседними считаются куски ближе этого
local CLEARANCE = 25 -- ниже этой разницы высот два куска трека мешают друг другу
local MARGIN = 8 -- запас между краями дорог в плане

type Point = { x: number, y: number, z: number, along: number, width: number, loop: number? }

local function walk(segments: { any }): { Point }
	local points: { Point } = {}
	local x, y, z = 0, 0, 0
	local heading = 0 -- рад, 0 = вдоль -Z, положительный = вправо
	local pitch = 0
	local width = START_WIDTH
	local along = 0

	local loopId: number? = nil
	local function record()
		table.insert(points, { x = x, y = y, z = z, along = along, width = width, loop = loopId })
	end
	local function forward(length: number)
		local steps = math.max(1, math.ceil(length / SAMPLE))
		local step = length / steps
		for _ = 1, steps do
			x += math.sin(heading) * math.cos(pitch) * step
			z -= math.cos(heading) * math.cos(pitch) * step
			y += math.sin(pitch) * step
			along += step
			record()
		end
	end
	local function arc(angle: number, radius: number, vertical: boolean)
		local total = math.rad(angle)
		local steps = math.max(1, math.ceil(math.abs(total) * radius / SAMPLE))
		for _ = 1, steps do
			local half = total / steps / 2
			if vertical then
				pitch += half
			else
				heading += half
			end
			x += math.sin(heading) * math.cos(pitch) * math.abs(total) * radius / steps
			z -= math.cos(heading) * math.cos(pitch) * math.abs(total) * radius / steps
			y += math.sin(pitch) * math.abs(total) * radius / steps
			along += math.abs(total) * radius / steps
			if vertical then
				pitch += half
			else
				heading += half
			end
			record()
		end
	end

	record()
	for _, segment in segments do
		if segment.kind == "straight" then
			forward(segment.length)
		elseif segment.kind == "taper" then
			forward(segment.length)
			width = segment.width
		elseif segment.kind == "turn" then
			arc(segment.angle, segment.radius, false)
		elseif segment.kind == "vcurve" then
			arc(segment.angle, segment.radius, true)
		elseif segment.kind == "loop" then
			-- Кольцо в вертикальной плоскости со сдвигом вбок на выезде
			local right = width + LOOP_SHIFT_MARGIN
			local steps = 36
			local startX, startY, startZ = x, y, z
			loopId = (loopId or 0) + 1
			for index = 1, steps do
				local t = index / steps * 2 * math.pi
				local ahead = segment.radius * math.sin(t)
				local up = segment.radius * (1 - math.cos(t))
				local side = right * index / steps
				x = startX + math.sin(heading) * ahead + math.cos(heading) * side
				z = startZ - math.cos(heading) * ahead + math.sin(heading) * side
				y = startY + up
				along += 2 * math.pi * segment.radius / steps
				record()
			end
			x, y, z = startX + math.cos(heading) * right, startY, startZ + math.sin(heading) * right
			pitch = 0
			loopId = nil
		elseif segment.kind == "gap" then
			pitch = 0
			x += math.sin(heading) * segment.length
			z -= math.cos(heading) * segment.length
			y -= segment.drop
			along += segment.length
			record()
		end
	end
	return points
end

local function check(name: string, segments: { any })
	local points = walk(segments)
	for i = 1, #points do
		for j = i + 1, #points do
			local a, b = points[i], points[j]
			-- Петля стоит над собственным выездом по замыслу, поэтому рядом с ней проверяем только дальние куски.
			local near = if a.loop or b.loop then LOOP_APART else APART
			if b.along - a.along < near then
				continue
			end
			local planar = math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
			if planar < (a.width + b.width) / 2 + MARGIN and math.abs(a.y - b.y) < CLEARANCE then
				error(
					`{name}: трек пересекает сам себя около ({math.floor(a.x)}, {math.floor(
						a.y
					)}, {math.floor(a.z)}) `
						.. `и ({math.floor(b.x)}, {math.floor(b.y)}, {math.floor(b.z)})`
				)
			end
		end
	end
	local last = points[#points]
	print(
		`{name}: {#points} точек, длина {math.floor(last.along)}, финиш на высоте {math.floor(
			last.y
		)}`
	)
end

check("Sky Loop", TrackSegments)
check("Canyon Rush", TrackCanyon)

-- Проверка самой проверки: трек, который возвращается в начало, должен ловиться.
local ok = pcall(check, "кольцо", {
	{ kind = "straight", length = 300 },
	{ kind = "turn", angle = 90, radius = 100 },
	{ kind = "turn", angle = 90, radius = 100 },
	{ kind = "turn", angle = 90, radius = 100 },
	{ kind = "turn", angle = 90, radius = 100 },
})
assert(not ok, "пересечение трека должно ловиться")

print("TrackGeometry: ok")
