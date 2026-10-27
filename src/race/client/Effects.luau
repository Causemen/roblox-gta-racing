--!strict
-- «Сок» езды: линии скорости, следы, искры при посадке, надпись AIR TIME, звук мотора и буста.
-- Следит за телеметрией машины игрока и ничего не меняет в физике.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local CameraController = require(script.Parent.CameraController)
local Input = require(script.Parent.Input)
local VehicleController = require(script.Parent.VehicleController)

-- Звуки: сюда вставить rbxassetid://... из Toolbox. Пока id пуст, звука нет, остальное работает.
local SOUND_IDS = {
	engine = "", -- петля мотора, высота тона следует за скоростью
	boost = "", -- разовый звук включения буста
	land = "rbxassetid://77458829204986", -- удар об землю после прыжка
	crash = "rbxassetid://99755220376998", -- удар машины об стену
	enter = "rbxassetid://132523351027438", -- посадка в машину при появлении
	horn = "rbxassetid://132205340213071", -- гудок (H или кнопка на экране)
	beep = "", -- короткий сигнал отсчета 3-2-1
	go = "", -- сигнал старта
	checkpoint = "", -- проезд чекпоинта
	drift = "", -- визг шин в заносе (петля)
}

-- Фоновая музыка заезда: список rbxassetid://..., играют по кругу. Пусто = музыки нет.
local MUSIC_IDS: { string } = {
	"rbxassetid://129127997655557", -- Phonk Nightmare Race
	"rbxassetid://120477473525627", -- NEON BAILOUT RAGE
	"rbxassetid://105100211445392", -- Psycho Phonk Slay
	"rbxassetid://123636731441495", -- Mad Phonk Energy
	"rbxassetid://137691412494086", -- Drift Storm Car Bass Boosted
	"rbxassetid://140580823167015", -- Voltstorm Overload Phonk Energy
	"rbxassetid://85735197482652", -- DRIFT NIGHT PHONK Car Motion Edit
	"rbxassetid://124698937788234", -- Drum And Bass Jungle Dimensional Drift
}
local MUSIC_VOLUME = 0.35

local SPEED_LINES_FROM = 120 -- с этой скорости появляются линии
local SPEED_LINES_FULL = 260
local MOBILE = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local LINE_COUNT = if MOBILE then 14 else 24 -- на телефонах линий меньше ради производительности
local LINE_LIFE = 0.28
local BOOST_FOV_KICK = 14
local START_FOV_KICK = 12 -- «пинок» камеры в момент GO
local START_KICK_SECONDS = 0.7
local SHAKE_SPEED_MAX = 0.12 -- тряска камеры на полной скорости
local SHAKE_BOOST = 0.3
local AIR_LABEL_MIN = 0.6 -- короче этого прыжок не показываем, чтобы кочки не мигали
local AIR_LABEL_HOLD = 1.4 -- сколько после посадки висит итог
local LAND_BIG = 0.5 -- с такого времени полета посадка дает искры

local BOOST_COLOR = Color3.fromRGB(60, 255, 120)
local NORMAL_COLOR = Color3.fromRGB(150, 210, 255)
local DRIFT_COLOR = Color3.fromRGB(255, 150, 60)

local Effects = {}

type Line = { frame: Frame, born: number, angle: number, radius: number, active: boolean }

local lines: { Line } = {}
local airLabel: TextLabel
local boostLabel: TextLabel
local gui: ScreenGui
local lineBudget = 0

local attachedCar: Model? = nil
local trails: { Trail } = {}
local emitter: ParticleEmitter? = nil
local smoke: ParticleEmitter? = nil
local driftSparks: ParticleEmitter? = nil
local driftSound: Sound? = nil
local beepSound: Sound? = nil
local goSound: Sound? = nil
local checkpointSound: Sound? = nil
local flash: Frame
local startKickUntil = 0
local engine: Sound? = nil
local boostSound: Sound? = nil
local landSound: Sound? = nil
local crashSound: Sound? = nil
local enterSound: Sound? = nil
local hornSound: Sound? = nil
local peakSpeed = 0
local lastCrashAt = 0

local wasGrounded = true
local wasBoosting = false
local airStarted = 0
local holdUntil = 0

local function makeSound(parent: Instance, id: string, looped: boolean): Sound?
	if id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Looped = looped
	sound.Volume = 0.6
	sound.RollOffMaxDistance = 250
	sound.Parent = parent
	return sound
end

local function makeLabel(name: string, position: UDim2, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = UDim2.fromOffset(420, 60)
	text.Position = position
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.GothamBlack
	text.TextSize = size
	text.Text = ""
	text.Parent = gui
	return text
end

local function buildGui()
	gui = Instance.new("ScreenGui")
	gui.Name = "RaceEffects"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	for _ = 1, LINE_COUNT do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.Visible = false
		frame.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.5, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		table.insert(lines, { frame = frame, born = 0, angle = 0, radius = 0, active = false })
	end

	flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui

	airLabel = makeLabel("AirTime", UDim2.fromScale(0.5, 0.22), 44)
	boostLabel = makeLabel("Boost", UDim2.fromScale(0.5, 0.3), 30)
	boostLabel.TextColor3 = BOOST_COLOR
end

local function spawnLine(now: number, intensity: number, color: Color3)
	for _, line in lines do
		if not line.active then
			line.active = true
			line.born = now
			line.angle = math.random() * math.pi * 2
			line.radius = 0.35 + math.random() * 0.2
			line.frame.BackgroundColor3 = color
			line.frame.Size = UDim2.fromOffset(60 + 90 * intensity, 2)
			line.frame.Visible = true
			return
		end
	end
end

local function updateLines(now: number, dt: number, intensity: number, color: Color3)
	lineBudget += intensity * 70 * dt
	while lineBudget >= 1 do
		lineBudget -= 1
		spawnLine(now, intensity, color)
	end
	local viewport = gui.AbsoluteSize
	local half = viewport.Magnitude / 2
	for _, line in lines do
		if line.active then
			local age = (now - line.born) / LINE_LIFE
			if age >= 1 then
				line.active = false
				line.frame.Visible = false
			else
				local radius = (line.radius + age * 0.55) * half
				local x = viewport.X / 2 + math.cos(line.angle) * radius
				local y = viewport.Y / 2 + math.sin(line.angle) * radius
				line.frame.Position = UDim2.fromOffset(x, y)
				line.frame.Rotation = math.deg(line.angle)
				line.frame.BackgroundTransparency = 0.1 + age * 0.9
			end
		end
	end
end

local function clearCar()
	for _, trail in trails do
		trail:Destroy()
	end
	table.clear(trails)
	if emitter then
		emitter:Destroy()
		emitter = nil
	end
	for _, extra in { smoke, driftSparks, driftSound, beepSound, goSound, checkpointSound } :: { Instance? } do
		if extra then
			extra:Destroy()
		end
	end
	smoke, driftSparks, driftSound, beepSound, goSound, checkpointSound = nil, nil, nil, nil, nil, nil
	if engine then
		engine:Destroy()
	end
	if boostSound then
		boostSound:Destroy()
	end
	if landSound then
		landSound:Destroy()
	end
	if crashSound then
		crashSound:Destroy()
	end
	if enterSound then
		enterSound:Destroy()
	end
	if hornSound then
		hornSound:Destroy()
	end
	engine, boostSound, landSound, crashSound, enterSound, hornSound = nil, nil, nil, nil, nil, nil
	attachedCar = nil
end

local function attachCar(car: Model, chassis: BasePart)
	clearCar()
	attachedCar = car

	-- Следы от задних колес.
	local size = chassis.Size
	for _, side in { -1, 1 } do
		local top = Instance.new("Attachment")
		top.Position = Vector3.new(side * size.X * 0.4, 0.4, size.Z * 0.45)
		top.Parent = chassis
		local bottom = Instance.new("Attachment")
		bottom.Position = Vector3.new(side * size.X * 0.4, -0.4, size.Z * 0.45)
		bottom.Parent = chassis
		local trail = Instance.new("Trail")
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Lifetime = 0.45
		trail.MinLength = 0.2
		trail.LightEmission = 0.8
		trail.FaceCamera = true
		trail.Color = ColorSequence.new(NORMAL_COLOR)
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.WidthScale = NumberSequence.new(1, 0.2)
		trail.Enabled = false
		trail.Parent = chassis
		table.insert(trails, trail)
	end

	-- Искры: на посадке и при включении буста.
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.Speed = NumberRange.new(25, 55)
	sparks.SpreadAngle = Vector2.new(70, 70)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(1.6, 0)
	sparks.Transparency = NumberSequence.new(0, 1)
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
	sparks.Parent = chassis
	emitter = sparks

	-- Дым и искры заноса: включаются через Enabled, вне заноса не тратят ресурсов.
	local rear = Instance.new("Attachment")
	rear.Position = Vector3.new(0, -0.6, size.Z * 0.45)
	rear.Parent = chassis
	local puff = Instance.new("ParticleEmitter")
	puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
	puff.Rate = if MOBILE then 14 else 28
	puff.Lifetime = NumberRange.new(0.5, 0.9)
	puff.Speed = NumberRange.new(4, 10)
	puff.SpreadAngle = Vector2.new(25, 25)
	puff.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 5) })
	puff.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	puff.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
	puff.Enabled = false
	puff.Parent = rear
	smoke = puff
	local fire = Instance.new("ParticleEmitter")
	fire.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	fire.Rate = if MOBILE then 15 else 35
	fire.Lifetime = NumberRange.new(0.2, 0.4)
	fire.Speed = NumberRange.new(15, 30)
	fire.SpreadAngle = Vector2.new(40, 40)
	fire.LightEmission = 1
	fire.Size = NumberSequence.new(0.9, 0)
	fire.Color = ColorSequence.new(DRIFT_COLOR)
	fire.Enabled = false
	fire.Parent = rear
	driftSparks = fire

	driftSound = makeSound(chassis, SOUND_IDS.drift, true)
	beepSound = makeSound(chassis, SOUND_IDS.beep, false)
	goSound = makeSound(chassis, SOUND_IDS.go, false)
	checkpointSound = makeSound(chassis, SOUND_IDS.checkpoint, false)
	engine = makeSound(chassis, SOUND_IDS.engine, true)
	boostSound = makeSound(chassis, SOUND_IDS.boost, false)
	landSound = makeSound(chassis, SOUND_IDS.land, false)
	crashSound = makeSound(chassis, SOUND_IDS.crash, false)
	enterSound = makeSound(chassis, SOUND_IDS.enter, false)
	hornSound = makeSound(chassis, SOUND_IDS.horn, false)
	peakSpeed = 0
	if enterSound then
		enterSound:Play()
	end
	if engine then
		engine:Play()
	end
end

local function update(dt: number)
	local now = os.clock()
	local car = VehicleController.getCar()
	local chassis = if car then car.PrimaryPart else nil
	if not car or not chassis then
		if attachedCar then
			clearCar()
		end
		airLabel.Text = ""
		boostLabel.Text = ""
		updateLines(now, dt, 0, NORMAL_COLOR)
		CameraController.setFovKick(0)
		CameraController.setShakeBase(0)
		return
	end
	if car ~= attachedCar then
		attachCar(car, chassis)
	end

	local telemetry = VehicleController.getTelemetry()
	local speed = telemetry.speed
	local boosting = telemetry.boosting
	local drifting = telemetry.drift > 0.3
	local color = if boosting then BOOST_COLOR elseif drifting then DRIFT_COLOR else NORMAL_COLOR

	-- Линии скорости и растяжка FOV на бусте.
	local intensity = math.clamp((speed - SPEED_LINES_FROM) / (SPEED_LINES_FULL - SPEED_LINES_FROM), 0, 1)
	if boosting then
		intensity = math.max(intensity, 0.7)
	end
	updateLines(now, dt, intensity, color)
	local kick = if boosting then BOOST_FOV_KICK else 0
	if now < startKickUntil then
		kick = math.max(kick, START_FOV_KICK * (startKickUntil - now) / START_KICK_SECONDS)
	end
	CameraController.setFovKick(kick)
	local shakeBase = SHAKE_SPEED_MAX * intensity
	if boosting then
		shakeBase = math.max(shakeBase, SHAKE_BOOST)
	end
	CameraController.setShakeBase(shakeBase)

	-- Занос: дым и искры, пока машина на земле и скользит; визг шин громче с силой заноса.
	local sliding = drifting and telemetry.grounded
	if smoke then
		smoke.Enabled = sliding
	end
	if driftSparks then
		driftSparks.Enabled = sliding and telemetry.drift > 0.6
	end
	if driftSound then
		driftSound.Volume = if sliding then math.clamp(telemetry.drift, 0, 1) * 0.6 else 0
		if sliding and not driftSound.IsPlaying then
			driftSound:Play()
		elseif not sliding and driftSound.IsPlaying then
			driftSound:Stop()
		end
	end

	-- Следы: видны на скорости, на бусте зеленые.
	for _, trail in trails do
		trail.Enabled = speed > 90 or boosting or drifting
		trail.Color = ColorSequence.new(color)
	end

	-- Удар о стену: скорость резко упала, пока машина на земле.
	peakSpeed = math.max(speed, peakSpeed - dt * 80)
	if telemetry.grounded and peakSpeed > 70 and speed < peakSpeed * 0.6 and now - lastCrashAt > 1 then
		lastCrashAt = now
		if crashSound then
			crashSound:Play()
		end
	end
	if speed < peakSpeed * 0.6 then
		peakSpeed = speed
	end

	-- Включение буста.
	if boosting and not wasBoosting then
		if emitter then
			emitter.Color = ColorSequence.new(BOOST_COLOR)
			emitter:Emit(24)
			emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120))
		end
		if boostSound then
			boostSound:Play()
		end
		CameraController.addShake(0.5)
		boostLabel.Text = "ТУРБО!"
		task.delay(0.8, function()
			boostLabel.Text = ""
		end)
	end
	wasBoosting = boosting

	-- AIR TIME: считаем полет, показываем после порога и держим итог после посадки.
	if telemetry.grounded then
		if not wasGrounded then
			local flight = now - airStarted
			if flight >= AIR_LABEL_MIN then
				airLabel.Text = string.format("AIR TIME %.1f с", flight)
				airLabel.TextColor3 = BOOST_COLOR
				holdUntil = now + AIR_LABEL_HOLD
			end
			if flight >= LAND_BIG then
				CameraController.addShake(math.clamp(flight * 0.5, 0.3, 1))
				if emitter then
					emitter:Emit(math.clamp(math.floor(flight * 30), 12, 60))
				end
				if landSound then
					landSound:Play()
				end
			end
		end
		if now >= holdUntil then
			airLabel.Text = ""
		end
	else
		if wasGrounded then
			airStarted = now
		end
		local flight = now - airStarted
		if flight >= AIR_LABEL_MIN then
			airLabel.Text = string.format("AIR TIME %.1f с", flight)
			airLabel.TextColor3 = Color3.new(1, 1, 1)
			holdUntil = 0
		end
	end
	wasGrounded = telemetry.grounded

	if engine then
		engine.PlaybackSpeed = 0.7 + math.clamp(speed / 200, 0, 1.3)
	end
end

local function startMusic()
	if #MUSIC_IDS == 0 then
		return
	end
	local music = Instance.new("Sound")
	music.Name = "RaceMusic"
	music.Volume = MUSIC_VOLUME
	music.Parent = game:GetService("SoundService")
	local index = 0
	local function playNext()
		index = index % #MUSIC_IDS + 1
		music.SoundId = MUSIC_IDS[index]
		music:Play()
	end
	music.Ended:Connect(playNext)
	playNext()
end

-- Отсчет 3-2-1: короткий сигнал на каждую цифру.
function Effects.onCountdownTick()
	if beepSound then
		beepSound:Play()
	end
end

function Effects.flash(color: Color3, startTransparency: number, seconds: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = startTransparency
	TweenService:Create(flash, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

-- GO: звук, вспышка, толчок камеры и пинок FOV на первых секундах разгона.
function Effects.onGo()
	startKickUntil = os.clock() + START_KICK_SECONDS
	CameraController.addShake(0.6)
	if goSound then
		goSound:Play()
	end
	Effects.flash(Color3.new(1, 1, 1), 0.7, 0.35)
end

-- Чекпоинт: звук, мягкая цветная вспышка и крошечный толчок камеры.
function Effects.onCheckpoint()
	if checkpointSound then
		checkpointSound:Play()
	end
	CameraController.addShake(0.15)
	Effects.flash(BOOST_COLOR, 0.82, 0.3)
end

function Effects.start(input: Input.Input)
	buildGui()
	startMusic()
	input.onHorn.Event:Connect(function()
		if hornSound then
			hornSound:Play()
		end
	end)
	VehicleController.respawned.Event:Connect(function()
		peakSpeed = 0
	end)
	RunService.RenderStepped:Connect(update)
end

return Effects
