-- Запуск: lune run tests/TrackAnalysis.spec.luau
-- Проверяет раскладку трека расчетом на машине по умолчанию и на каждом пресете.

-- VehicleTuning берет Vector3 из Roblox, в Lune его нет.
Vector3 = {
	new = function(x: number, y: number, z: number)
		return { X = x, Y = y, Z = z }
	end,
}

local TrackAnalysis = require("../src/shared/TrackAnalysis")
local TrackCanyon = require("../src/shared/TrackCanyon")
local TrackSegments = require("../src/shared/TrackSegments")
local VehicleMath = require("../src/shared/VehicleMath")
local VehiclePresets = require("../src/shared/VehiclePresets")
local VehicleTuning = require("../src/shared/VehicleTuning")

local TrackList = {
	{ name = "Sky Loop", segments = TrackSegments },
	{ name = "Canyon Rush", segments = TrackCanyon },
}

local function tuningWith(values: { [string]: number }?)
	local tuning = table.clone(VehicleTuning) :: any
	for key, value in values or {} do
		tuning[key] = value
	end
	return tuning
end

local function analyze(segments: { TrackAnalysis.Segment }, tuning: any): TrackAnalysis.Report
	return TrackAnalysis.analyze(segments, tuning, function(speed: number, boosting: boolean): number
		return VehicleMath.driveAcceleration(speed, 1, boosting, tuning)
	end)
end

-- Трек должен проходиться на настройках по умолчанию. Пресеты только выводят замечания: старый пресет
-- медленнее и не доезжает до петли без буста, а трек теперь без буста перед ней.
local setups = { { "по умолчанию", tuningWith(nil) } }
for _, preset in VehiclePresets do
	table.insert(setups, { preset.name, tuningWith(preset.values) })
end
for _, track in TrackList do
	for _, setup in setups do
		local report = analyze(track.segments, setup[2])
		for _, problem in report.problems do
			print(`[{track.name} / {setup[1]}] проблема: {problem}`)
		end
		if setup[2] == setups[1][2] then
			for _, note in report.notes do
				print(`[{track.name}] {note}`)
			end
			assert(
				#report.problems == 0,
				`{track.name} не проходится на «{setup[1]}»: {report.problems[1]}`
			)
		end
	end
end

-- Сам анализатор должен находить ошибки: буст перед поворотом, короткий разбег и недолет прыжка.
local fast = tuningWith(nil)
local boostIntoTurn: { TrackAnalysis.Segment } = {
	{ kind = "grid" },
	{ kind = "straight", length = 140 },
	{ kind = "straight", length = 50, boost = true },
	{ kind = "straight", length = 40 },
	{ kind = "turn", angle = 90, radius = 60 },
}
assert(
	#analyze(boostIntoTurn, fast).problems == 1,
	"буст перед тесным поворотом должен ловиться"
)

local shortJump: { TrackAnalysis.Segment } = {
	{ kind = "grid" },
	{ kind = "straight", length = 30 },
	{ kind = "gap", length = 200, drop = 5 },
}
assert(#analyze(shortJump, fast).problems == 1, "недолет прыжка должен ловиться")

local slowLoop: { TrackAnalysis.Segment } = {
	{ kind = "grid" },
	{ kind = "straight", length = 10 },
	{ kind = "loop", radius = 45 },
}
assert(#analyze(slowLoop, fast).problems == 1, "петля без разгона должна ловиться")

print("TrackAnalysis: ok")
