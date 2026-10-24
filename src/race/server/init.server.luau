--!strict
-- Точка входа гоночного сервера: строит трек и запускает цикл заездов.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local RaceManager = require(script.RaceManager)
local TrackBuilder = require(script.TrackBuilder)

-- Персонажи в гонке не нужны: игрок управляет машиной, камера следует за ней.
Players.CharacterAutoLoads = false

local track = TrackBuilder.build(Workspace)
print(`[Race] трек готов: {#track.checkpoints} чекпоинтов, {#track.grid} мест на старте`)

RaceManager.start(track)
