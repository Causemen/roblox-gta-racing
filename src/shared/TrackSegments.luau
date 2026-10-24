--!strict
-- Участки тестового трека «Sky Loop» без Roblox API: их читают и TrackBuilder, и расчетная проверка трека.
-- Углы в градусах: turn > 0 вправо, vcurve > 0 вверх. Длины и радиусы в studs.

export type Segment =
	{ kind: "grid" }
	| { kind: "straight", length: number, boost: boolean? }
	| { kind: "taper", length: number, width: number } -- плавно меняет ширину трека до width
	| { kind: "turn", angle: number, radius: number }
	| { kind: "vcurve", angle: number, radius: number }
	| { kind: "loop", radius: number }
	| { kind: "gap", length: number, drop: number }
	| { kind: "checkpoint" }
	| { kind: "finish" }

local segments: { Segment } = {
	{ kind = "straight", length = 110 },
	{ kind = "grid" },
	{ kind = "straight", length = 40 },
	{ kind = "taper", length = 100, width = 40 }, -- старт шириной на четыре машины, дальше трек уже
	{ kind = "turn", angle = 90, radius = 180 },
	{ kind = "straight", length = 60 },
	{ kind = "checkpoint" },

	-- Первый прыжок: буст, трамплин, яма, длинная посадка с запасом на торможение
	{ kind = "straight", length = 50, boost = true },
	{ kind = "vcurve", angle = 15, radius = 150 },
	{ kind = "straight", length = 25 },
	{ kind = "gap", length = 45, drop = 12 },
	{ kind = "straight", length = 200 },
	{ kind = "checkpoint" },

	-- Широкий разворот и петля
	{ kind = "turn", angle = -120, radius = 190 },
	{ kind = "straight", length = 100 },
	{ kind = "straight", length = 40, boost = true },
	{ kind = "loop", radius = 70 },
	{ kind = "straight", length = 120 },
	{ kind = "checkpoint" },

	-- Подъем, вираж и спуск
	{ kind = "vcurve", angle = 12, radius = 250 },
	{ kind = "straight", length = 80 },
	{ kind = "vcurve", angle = -12, radius = 250 },
	{ kind = "turn", angle = 90, radius = 190 },
	{ kind = "vcurve", angle = -15, radius = 250 },
	{ kind = "straight", length = 60 },
	{ kind = "vcurve", angle = 15, radius = 250 },
	{ kind = "checkpoint" },

	-- Змейка
	{ kind = "turn", angle = -45, radius = 160 },
	{ kind = "turn", angle = 45, radius = 160 },
	{ kind = "straight", length = 80 },
	{ kind = "checkpoint" },

	-- Финальный прыжок на финишную прямую
	{ kind = "straight", length = 60, boost = true },
	{ kind = "vcurve", angle = 12, radius = 150 },
	{ kind = "straight", length = 20 },
	{ kind = "gap", length = 45, drop = 15 },
	{ kind = "straight", length = 140 },
	{ kind = "finish" },
	{ kind = "straight", length = 120 },
}

return segments
