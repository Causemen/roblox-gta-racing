--!strict
-- Тестовый стант-трек «Sky Loop», от старта до финиша (point-to-point, как многие стант-гонки GTA).
-- Углы в градусах: turn > 0 вправо, vcurve > 0 вверх. Длины и радиусы в studs.

export type Segment =
	{ kind: "grid" }
	| { kind: "straight", length: number, boost: boolean? }
	| { kind: "turn", angle: number, radius: number }
	| { kind: "vcurve", angle: number, radius: number }
	| { kind: "loop", radius: number }
	| { kind: "gap", length: number, drop: number }
	| { kind: "checkpoint" }
	| { kind: "finish" }

export type Layout = {
	name: string,
	origin: CFrame,
	segments: { Segment },
}

local layout: Layout = {
	name = "Sky Loop",
	origin = CFrame.new(0, 500, 0),
	segments = {
		{ kind = "straight", length = 110 },
		{ kind = "grid" },
		{ kind = "straight", length = 60 },
		{ kind = "straight", length = 50, boost = true },
		{ kind = "straight", length = 40 },
		{ kind = "turn", angle = 90, radius = 90 },
		{ kind = "straight", length = 40 },
		{ kind = "checkpoint" },

		-- Первый прыжок: буст, трамплин, яма, длинная посадка
		{ kind = "straight", length = 40, boost = true },
		{ kind = "vcurve", angle = 15, radius = 120 },
		{ kind = "straight", length = 25 },
		{ kind = "gap", length = 40, drop = 12 },
		{ kind = "straight", length = 110 },
		{ kind = "checkpoint" },

		-- Разворот и петля
		{ kind = "turn", angle = -120, radius = 80 },
		{ kind = "straight", length = 30 },
		{ kind = "straight", length = 40, boost = true },
		{ kind = "loop", radius = 40 },
		{ kind = "straight", length = 60 },
		{ kind = "checkpoint" },

		-- Подъем, вираж и спуск с бустом
		{ kind = "vcurve", angle = 12, radius = 200 },
		{ kind = "straight", length = 60 },
		{ kind = "vcurve", angle = -12, radius = 200 },
		{ kind = "turn", angle = 90, radius = 70 },
		{ kind = "vcurve", angle = -15, radius = 200 },
		{ kind = "straight", length = 60, boost = true },
		{ kind = "vcurve", angle = 15, radius = 200 },
		{ kind = "checkpoint" },

		-- Змейка
		{ kind = "turn", angle = -45, radius = 90 },
		{ kind = "turn", angle = 45, radius = 90 },
		{ kind = "straight", length = 40 },
		{ kind = "checkpoint" },

		-- Финальный прыжок на финишную прямую
		{ kind = "straight", length = 40, boost = true },
		{ kind = "vcurve", angle = 12, radius = 150 },
		{ kind = "straight", length = 20 },
		{ kind = "gap", length = 45, drop = 15 },
		{ kind = "straight", length = 100 },
		{ kind = "finish" },
		{ kind = "straight", length = 80 },
	},
}

return layout
