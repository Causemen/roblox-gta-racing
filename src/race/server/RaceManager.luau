--!strict
-- Ведет заезд по кругу: Lobby -> Countdown -> Racing -> Finished -> Lobby.
-- Проверяет прохождение чекпоинтов на сервере по позиции машины и считает места.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CarFactory = require(script.Parent.CarFactory)
local Config = require(ReplicatedStorage.Shared.Config)
local RaceRules = require(ReplicatedStorage.Shared.RaceRules)
local RaceState = require(ReplicatedStorage.Shared.RaceState)
local TrackBuilder = require(script.Parent.TrackBuilder)
local TrackLayout = require(script.Parent.TrackLayout)

type Racer = {
	player: Player,
	car: Model,
	passed: number, -- сколько чекпоинтов пройдено
	lastSplitAt: number,
	finishTime: number?,
}

local STANDINGS_INTERVAL = 0.5

local RaceManager = {}

local layouts: { TrackLayout.Layout } = {}
local trackIndex = 0
local track: TrackBuilder.BuiltTrack
local raceEvent: RemoteEvent
local carsFolder: Folder
local racers: { [Player]: Racer } = {}
local state: RaceState.RaceState = "Lobby"
local stateEndsAt = 0
local raceStartedAt = 0

local function broadcastState(newState: RaceState.RaceState, duration: number)
	-- Состояние лежит в атрибутах, чтобы игрок, зашедший посреди заезда, сразу его увидел.
	state = newState
	stateEndsAt = Workspace:GetServerTimeNow() + duration
	raceEvent:SetAttribute("EndsAt", stateEndsAt)
	raceEvent:SetAttribute("State", state)
end

-- Строит трек с номером index вместо прежнего. Зовем только между заездами, когда машин на трассе нет.
local function loadTrack(index: number)
	local old = Workspace:FindFirstChild("Track")
	if old then
		old:Destroy()
	end
	trackIndex = index
	local layout = layouts[index]
	track = TrackBuilder.build(Workspace, layout)
	raceEvent:SetAttribute("Checkpoints", #track.checkpoints)
	raceEvent:SetAttribute("TrackName", layout.name)
	print(
		`[Race] трек «{layout.name}» готов: {#track.checkpoints} чекпоинтов, {#track.grid} мест на старте`
	)
end

local function destroyCar(racer: Racer)
	racer.car:Destroy()
end

local function clearRacers()
	for _, racer in racers do
		destroyCar(racer)
	end
	table.clear(racers)
end

local function spawnRacers()
	local index = 0
	for _, player in Players:GetPlayers() do
		index += 1
		local slot = track.grid[index]
		if not slot then
			break -- мест на решетке больше нет, игрок ждет следующего заезда
		end
		local car = CarFactory.create(player, slot, carsFolder, index)
		racers[player] = { player = player, car = car, passed = 0, lastSplitAt = 0 }
	end
end

local function releaseCars()
	for player, racer in racers do
		local chassis = racer.car.PrimaryPart
		if chassis then
			chassis.Anchored = false
			chassis:SetNetworkOwner(player)
		end
		racer.lastSplitAt = os.clock()
	end
end

local function finishedCount(): number
	local count = 0
	for _, racer in racers do
		if racer.finishTime then
			count += 1
		end
	end
	return count
end

local function checkCheckpoints()
	local now = os.clock()
	for player, racer in racers do
		if racer.finishTime then
			continue
		end
		local checkpoint = track.checkpoints[racer.passed + 1]
		local chassis = racer.car.PrimaryPart
		if not checkpoint or not chassis then
			continue
		end

		local localPos = checkpoint.zone.CFrame:PointToObjectSpace(chassis.Position)
		local half = checkpoint.zone.Size / 2
		local inside = math.abs(localPos.X) <= half.X
			and math.abs(localPos.Y) <= half.Y
			and math.abs(localPos.Z) <= half.Z
		if not inside then
			continue
		end
		if not RaceRules.isPlausibleSplit(racer.lastSplitAt, now, Config.MinCheckpointSplitSeconds) then
			warn(
				`[Race] {player.Name}: слишком быстрый чекпоинт {checkpoint.index}, пропускаем`
			)
			continue
		end

		racer.passed = checkpoint.index
		racer.lastSplitAt = now
		raceEvent:FireClient(player, { kind = "Checkpoint", index = checkpoint.index, total = #track.checkpoints })

		if checkpoint.index == #track.checkpoints then
			local time = now - raceStartedAt
			racer.finishTime = time
			raceEvent:FireClient(player, { kind = "Finished", place = finishedCount(), time = time })
		end
	end
end

local function currentStandings(): { RaceRules.Standing }
	local list = {}
	for _, racer in racers do
		local chassis = racer.car.PrimaryPart
		local nextCheckpoint = track.checkpoints[racer.passed + 1]
		local distance = if chassis and nextCheckpoint
			then (chassis.Position - nextCheckpoint.zone.Position).Magnitude
			else 0
		table.insert(list, {
			id = racer.player.UserId,
			checkpoints = racer.passed,
			distanceToNext = distance,
			finishTime = racer.finishTime,
		})
	end
	return RaceRules.standings(list)
end

local function broadcastStandings()
	local order = {}
	for _, standing in currentStandings() do
		table.insert(order, standing.id)
	end
	raceEvent:FireAllClients({ kind = "Standings", order = order })
end

local function broadcastResults()
	local rows = {}
	for place, standing in currentStandings() do
		local player = Players:GetPlayerByUserId(standing.id)
		table.insert(rows, {
			place = place,
			name = if player then player.DisplayName else "?",
			time = standing.finishTime,
		})
	end
	raceEvent:FireAllClients({ kind = "Results", rows = rows })
end

local function runRace()
	raceStartedAt = os.clock()
	local firstFinishAt: number? = nil
	local lastStandingsAt = 0

	while true do
		RunService.Heartbeat:Wait()
		checkCheckpoints()

		local now = os.clock()
		if now - lastStandingsAt >= STANDINGS_INTERVAL then
			lastStandingsAt = now
			broadcastStandings()
		end

		local total = 0
		for _ in racers do
			total += 1
		end
		local finished = finishedCount()
		if finished > 0 and not firstFinishAt then
			firstFinishAt = now
			broadcastState("Racing", Config.FinishGraceSeconds)
		end

		if total == 0 or finished == total then
			break
		elseif firstFinishAt and now - firstFinishAt >= Config.FinishGraceSeconds then
			break
		elseif now - raceStartedAt >= Config.RaceTimeLimitSeconds then
			break
		end
	end
end

local function loop()
	while true do
		broadcastState("Lobby", Config.LobbySeconds)
		while #Players:GetPlayers() == 0 do
			task.wait(1)
		end
		task.wait(Config.LobbySeconds)

		spawnRacers()
		broadcastState("Countdown", Config.CountdownSeconds)
		task.wait(Config.CountdownSeconds)

		releaseCars()
		broadcastState("Racing", Config.RaceTimeLimitSeconds)
		runRace()

		broadcastState("Finished", Config.ResultsSeconds)
		broadcastResults()
		task.wait(Config.ResultsSeconds)
		clearRacers()
		loadTrack(trackIndex % #layouts + 1)
	end
end

function RaceManager.start(trackLayouts: { TrackLayout.Layout })
	layouts = trackLayouts

	local remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	raceEvent = Instance.new("RemoteEvent")
	raceEvent.Name = "RaceEvent"
	raceEvent.Parent = remotes
	remotes.Parent = ReplicatedStorage

	carsFolder = Instance.new("Folder")
	carsFolder.Name = "Cars"
	carsFolder.Parent = Workspace

	loadTrack(1)

	Players.PlayerRemoving:Connect(function(player)
		local racer = racers[player]
		if racer then
			destroyCar(racer)
			racers[player] = nil
		end
	end)

	task.spawn(loop)
end

return RaceManager
