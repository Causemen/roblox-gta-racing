--!strict
-- Тестовый стант-трек «Sky Loop», от старта до финиша (point-to-point, как многие стант-гонки GTA).
-- Сами участки лежат в shared/TrackSegments, чтобы их можно было проверять расчетом в Lune.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackSegments = require(ReplicatedStorage.Shared.TrackSegments)

export type Segment = TrackSegments.Segment

export type Layout = {
	name: string,
	origin: CFrame,
	segments: { Segment },
}

local layout: Layout = {
	name = "Sky Loop",
	origin = CFrame.new(0, 500, 0),
	segments = TrackSegments,
}

return layout
