--!strict
-- Треки игры по порядку, от старта до финиша (point-to-point, как многие стант-гонки GTA).
-- Сами участки лежат в shared, чтобы их можно было проверять расчетом в Lune. Сервер ездит по списку по кругу.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackCanyon = require(ReplicatedStorage.Shared.TrackCanyon)
local TrackSegments = require(ReplicatedStorage.Shared.TrackSegments)

export type Segment = TrackSegments.Segment

export type Layout = {
	name: string,
	origin: CFrame,
	segments: { Segment },
}

local layouts: { Layout } = {
	{
		name = "Sky Loop",
		origin = CFrame.new(0, 500, 0),
		segments = TrackSegments,
	},
	{
		name = "Canyon Rush",
		origin = CFrame.new(0, 500, 0),
		segments = TrackCanyon,
	},
}

return layouts
