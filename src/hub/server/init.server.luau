--!strict
-- Точка входа сервера хаба: гараж, магазин, матчмейкинг.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

print(`[Hub] сервер запущен, до {Config.MaxPlayersPerRace} игроков в заезде`)
