--!strict
-- Точка входа клиента заезда: подключает машину, камеру, HUD и реагирует на события сервера.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AutoPilot = require(script.AutoPilot)
local CameraController = require(script.CameraController)
local Effects = require(script.Effects)
local Hud = require(script.Hud)
local Input = require(script.Input)
local RaceRules = require(ReplicatedStorage.Shared.RaceRules)
local TouchControls = require(script.TouchControls)
local TuningPanel = require(script.TuningPanel)
local VehicleController = require(script.VehicleController)

local localPlayer = Players.LocalPlayer :: Player
local raceEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RaceEvent") :: RemoteEvent
local track = Workspace:WaitForChild("Track") :: Model
local carsFolder = Workspace:WaitForChild("Cars")

local input = Input.start()
TouchControls.start()
Hud.create()
CameraController.start()
Effects.start()
CameraController.setOverview(track:GetAttribute("CameraCFrame") :: CFrame?)
VehicleController.setKillHeight((track:GetAttribute("KillHeight") :: number?) or -math.huge)
input.onRespawn.Event:Connect(VehicleController.respawn)
if RunService:IsStudio() then
	TuningPanel.start()
	AutoPilot.start(input, track)
end

local state = "Lobby"
local raceStartedAt = 0
local passed = 0
local finishTime: number? = nil
local bannerUntil = 0

local function totalCheckpoints(): number
	return (raceEvent:GetAttribute("Checkpoints") :: number?) or 0
end

local function flash(text: string, seconds: number)
	Hud.setBanner(text)
	bannerUntil = os.clock() + seconds
end

local function onStateChanged()
	local newState = (raceEvent:GetAttribute("State") :: string?) or "Lobby"
	if newState == state then
		return
	end
	state = newState

	if state == "Lobby" or state == "Countdown" then
		passed = 0
		finishTime = nil
		Hud.showResults(nil)
		Hud.setPlace(nil, 0)
	end
	if state == "Racing" then
		raceStartedAt = Workspace:GetServerTimeNow()
		AutoPilot.onRaceStart()
		flash("GO!", 1)
	end
	VehicleController.setEnabled(state == "Racing" and finishTime == nil)
	Hud.setCheckpoint(passed, totalCheckpoints())
end

local function isMine(car: Instance): boolean
	return car:IsA("Model") and car:GetAttribute("OwnerUserId") == localPlayer.UserId
end

local function onCarAdded(car: Instance)
	if not isMine(car) then
		return
	end
	local model = car :: Model
	local chassis = model.PrimaryPart or model:WaitForChild("Chassis") :: BasePart
	if not model.PrimaryPart then
		model.PrimaryPart = chassis
	end
	VehicleController.attach(model, input, carsFolder)
	VehicleController.setEnabled(state == "Racing" and finishTime == nil)
	CameraController.follow(chassis)
end

local function onCarRemoved(car: Instance)
	if car == VehicleController.getCar() then
		VehicleController.detach()
		CameraController.follow(nil)
	end
end

raceEvent:GetAttributeChangedSignal("State"):Connect(onStateChanged)
carsFolder.ChildAdded:Connect(onCarAdded)
carsFolder.ChildRemoved:Connect(onCarRemoved)
for _, car in carsFolder:GetChildren() do
	onCarAdded(car)
end
onStateChanged()

raceEvent.OnClientEvent:Connect(function(message: { [string]: any })
	if message.kind == "Checkpoint" then
		passed = message.index
		Hud.setCheckpoint(passed, message.total)
		local gates = track:FindFirstChild("Checkpoints")
		local gate = gates and gates:FindFirstChild(`Checkpoint{passed}`)
		local zone = gate and gate:FindFirstChild("Zone")
		local spawn = zone and zone:GetAttribute("SpawnCFrame")
		if typeof(spawn) == "CFrame" then
			VehicleController.setRespawn(spawn)
		end
		AutoPilot.onCheckpoint(passed, message.total)
		if passed < message.total then
			flash(`Чекпоинт {passed}`, 0.8)
		end
	elseif message.kind == "Finished" then
		finishTime = message.time
		AutoPilot.onFinished(message.place)
		VehicleController.setEnabled(false)
		flash(`Финиш! {message.place} место · {RaceRules.formatTime(message.time)}`, 6)
	elseif message.kind == "Standings" then
		local order = message.order :: { number }
		Hud.setPlace(table.find(order, localPlayer.UserId), #order)
	elseif message.kind == "Results" then
		local lines = {}
		for _, row in message.rows do
			local time = if row.time then RaceRules.formatTime(row.time) else "не финишировал"
			table.insert(lines, `{row.place}. {row.name}   {time}`)
		end
		Hud.showResults(lines)
		AutoPilot.onResults()
	end
end)

RunService.Heartbeat:Connect(function()
	local now = Workspace:GetServerTimeNow()
	local endsAt = (raceEvent:GetAttribute("EndsAt") :: number?) or now
	local left = math.max(0, math.ceil(endsAt - now))

	if state == "Racing" then
		Hud.setTimer(RaceRules.formatTime(finishTime or (now - raceStartedAt)))
	elseif state == "Lobby" then
		Hud.setTimer(`Новый заезд через {left}`)
	else
		Hud.setTimer("")
	end

	if os.clock() >= bannerUntil then
		Hud.setBanner(if state == "Countdown" then tostring(math.max(1, left)) else "")
	end

	local car = VehicleController.getCar()
	if car then
		local telemetry = VehicleController.getTelemetry()
		Hud.setSpeed(telemetry.speed, telemetry.boosting)
	else
		Hud.setSpeed(nil, false)
	end
end)
