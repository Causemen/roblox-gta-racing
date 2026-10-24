-- Запуск: lune run tests/RaceRules.spec.luau

local RaceRules = require("../src/shared/RaceRules")

local order = RaceRules.standings({
	{ id = 1, checkpoints = 2, distanceToNext = 50 },
	{ id = 2, checkpoints = 3, distanceToNext = 80 },
	{ id = 3, checkpoints = 5, distanceToNext = 0, finishTime = 95.2 },
	{ id = 4, checkpoints = 2, distanceToNext = 20 },
	{ id = 5, checkpoints = 5, distanceToNext = 0, finishTime = 91.0 },
})
local ids = {}
for _, standing in order do
	table.insert(ids, standing.id)
end
assert(table.concat(ids, ",") == "5,3,2,4,1", `порядок мест: {table.concat(ids, ",")}`)

assert(RaceRules.isPlausibleSplit(10, 11.5, 1), "1.5 с между чекпоинтами допустимо")
assert(not RaceRules.isPlausibleSplit(10, 10.3, 1), "0.3 с между чекпоинтами это телепорт")

assert(RaceRules.formatTime(83.4567) == "1:23.457", RaceRules.formatTime(83.4567))
assert(RaceRules.formatTime(5) == "0:05.000", RaceRules.formatTime(5))

print("RaceRules: ok")
