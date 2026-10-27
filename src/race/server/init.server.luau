--!strict
-- Точка входа гоночного сервера: строит трек и запускает цикл заездов.

local Players = game:GetService("Players")

local RaceManager = require(script.RaceManager)
local TrackLayout = require(script.TrackLayout)

-- Персонажи в гонке не нужны: игрок управляет машиной, камера следует за ней.
Players.CharacterAutoLoads = false

RaceManager.start(TrackLayout)
