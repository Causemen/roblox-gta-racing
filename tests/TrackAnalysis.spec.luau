-- Запуск: lune run tests/TrackAnalysis.spec.luau
-- Проверяет раскладку трека расчетом на обычной машине и на пресете «GTA-стант».

-- VehicleTuning берет Vector3 из Roblox, в Lune его нет.
Vector3 = {
	new = function(x: number, y: number, z: number)
		return { X = x, Y = y, Z = z }
	end,
}

local TrackAnalysis = require("../src/shared/TrackAnalysis")
local TrackSegments = require("../src/shared/TrackSegments")
local VehicleMath = require("../src/shared/VehicleMath")
local VehiclePresets = require("../src/shared/VehiclePresets")
local VehicleTuning = require("../src/shared/VehicleTuning")

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

-- Основной трек проходим на всех наборах настроек.
local setups = { { "исходная машина", tuningWith(nil) } }
for _, preset in VehiclePresets do
	table.insert(setups, { preset.name, tuningWith(preset.values) })
end
for _, setup in setups do
	local report = analyze(TrackSegments, setup[2])
	for _, problem in report.problems do
		print(`[{setup[1]}] проблема: {problem}`)
	end
	assert(#report.problems == 0, `Sky Loop не проходится на «{setup[1]}»: {report.problems[1]}`)
end

-- Сам анализатор должен находить ошибки: буст перед поворотом, короткий разбег и недолет прыжка.
local gta = tuningWith(VehiclePresets[1].values)
local boostIntoTurn: { TrackAnalysis.Segment } = {
	{ kind = "grid" },
	{ kind = "straight", length = 140 },
	{ kind = "straight", length = 50, boost = true },
	{ kind = "straight", length = 40 },
	{ kind = "turn", angle = 90, radius = 90 },
}
assert(
	#analyze(boostIntoTurn, gta).problems == 1,
	"буст перед тесным поворотом должен ловиться"
)

local shortJump: { TrackAnalysis.Segment } = {
	{ kind = "grid" },
	{ kind = "straight", length = 30 },
	{ kind = "gap", length = 200, drop = 5 },
}
assert(#analyze(shortJump, gta).problems == 1, "недолет прыжка должен ловиться")

local slowLoop: { TrackAnalysis.Segment } = {
	{ kind = "grid" },
	{ kind = "straight", length = 10 },
	{ kind = "loop", radius = 45 },
}
assert(#analyze(slowLoop, gta).problems == 1, "петля без разгона должна ловиться")

print("TrackAnalysis: ok")
