--!strict
-- Общие константы игры, доступны и серверу, и клиенту.

local Config = {
	MaxPlayersPerRace = 12,
	MinPlayersBeforeBots = 4,
	QueueWaitSeconds = 20,
	RespawnDelaySeconds = 0.5,
	TrackVoteSeconds = 15,

	-- Заезд
	LobbySeconds = 10,
	CountdownSeconds = 3,
	RaceTimeLimitSeconds = 300,
	FinishGraceSeconds = 30, -- сколько ждем остальных после первого финишера
	ResultsSeconds = 8,
	MinCheckpointSplitSeconds = 1, -- быстрее этого между чекпоинтами проехать нельзя
}

return table.freeze(Config)
