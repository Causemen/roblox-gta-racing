--!strict
-- Второй трек «Canyon Rush»: быстрее и техничнее первого. Без петли, зато слалом, два прыжка,
-- широкий разворот, холм и большой финальный прыжок. Участки читают и TrackBuilder, и расчетная проверка.
-- Углы в градусах: turn > 0 вправо, vcurve > 0 вверх. Длины и радиусы в studs.

export type Segment =
	{ kind: "grid" }
	| { kind: "straight", length: number, boost: boolean? }
	| { kind: "taper", length: number, width: number }
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
	{ kind = "taper", length = 100, width = 44 },

	-- Слалом на скорости: плавные дуги, без торможения
	{ kind = "straight", length = 80 },
	{ kind = "turn", angle = -50, radius = 300 },
	{ kind = "turn", angle = 100, radius = 300 },
	{ kind = "turn", angle = -50, radius = 300 },
	{ kind = "straight", length = 60 },
	{ kind = "checkpoint" },

	-- Длинный прыжок с бустом через каньон
	{ kind = "straight", length = 50, boost = true },
	{ kind = "vcurve", angle = 15, radius = 150 },
	{ kind = "straight", length = 25 },
	{ kind = "gap", length = 150, drop = 20 },
	{ kind = "straight", length = 330 },
	{ kind = "checkpoint" },

	-- Широкий разворот почти на 180 градусов
	{ kind = "turn", angle = 160, radius = 320 },
	{ kind = "straight", length = 120 },
	{ kind = "checkpoint" },

	-- Второй прыжок, уже без буста: короткий разгон и трамплин
	{ kind = "straight", length = 150 },
	{ kind = "vcurve", angle = 15, radius = 150 },
	{ kind = "straight", length = 25 },
	{ kind = "gap", length = 70, drop = 10 },
	{ kind = "straight", length = 220 },
	{ kind = "checkpoint" },

	-- Холм: подъем, гребень, спуск
	{ kind = "vcurve", angle = 14, radius = 250 },
	{ kind = "straight", length = 120 },
	{ kind = "vcurve", angle = -28, radius = 250 },
	{ kind = "straight", length = 100 },
	{ kind = "vcurve", angle = 14, radius = 250 },
	{ kind = "straight", length = 60 },
	{ kind = "checkpoint" },

	-- Шикана и финальный прыжок
	{ kind = "turn", angle = 60, radius = 260 },
	{ kind = "turn", angle = -60, radius = 260 },
	{ kind = "straight", length = 60, boost = true },
	{ kind = "vcurve", angle = 12, radius = 150 },
	{ kind = "straight", length = 20 },
	{ kind = "gap", length = 55, drop = 15 },
	{ kind = "straight", length = 260 },
	{ kind = "finish" },
	{ kind = "straight", length = 120 },
}

return segments
