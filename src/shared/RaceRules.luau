--!strict
-- Правила заезда без Roblox API: порядок мест, проверка чекпоинтов, формат времени.

export type Standing = {
	id: number,
	checkpoints: number, -- сколько чекпоинтов пройдено
	distanceToNext: number,
	finishTime: number?,
}

local RaceRules = {}

-- Финишировавшие идут первыми по времени, остальные по пройденным чекпоинтам и расстоянию до следующего.
function RaceRules.standings(racers: { Standing }): { Standing }
	local sorted = table.clone(racers)
	table.sort(sorted, function(a: Standing, b: Standing): boolean
		local aTime, bTime = a.finishTime, b.finishTime
		if aTime and bTime then
			return aTime < bTime
		elseif aTime or bTime then
			return aTime ~= nil
		end
		if a.checkpoints ~= b.checkpoints then
			return a.checkpoints > b.checkpoints
		end
		if a.distanceToNext ~= b.distanceToNext then
			return a.distanceToNext < b.distanceToNext
		end
		return a.id < b.id
	end)
	return sorted
end

-- Между чекпоинтами нельзя проехать быстрее minSeconds: отсекает телепорты читеров.
function RaceRules.isPlausibleSplit(previousAt: number, now: number, minSeconds: number): boolean
	return now - previousAt >= minSeconds
end

-- 83.4567 -> "1:23.457"
function RaceRules.formatTime(seconds: number): string
	local totalMs = math.floor(seconds * 1000 + 0.5)
	local minutes = totalMs // 60000
	local secs = (totalMs // 1000) % 60
	local ms = totalMs % 1000
	return string.format("%d:%02d.%03d", minutes, secs, ms)
end

return RaceRules
