--!strict
-- Интерфейс заезда: таймер, место, чекпоинты, скорость, крупные надписи и таблица результатов.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Hud = {}

local gui: ScreenGui
local timerLabel: TextLabel
local placeLabel: TextLabel
local checkpointLabel: TextLabel
local speedLabel: TextLabel
local bannerLabel: TextLabel
local resultsLabel: TextLabel
local hintLabel: TextLabel

local function label(name: string, size: UDim2, position: UDim2, anchor: Vector2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Size = size
	text.Position = position
	text.AnchorPoint = anchor
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.4
	text.Font = Enum.Font.GothamBlack
	text.TextSize = textSize
	text.Text = ""
	text.Parent = gui
	return text
end

function Hud.create()
	gui = Instance.new("ScreenGui")
	gui.Name = "RaceHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	timerLabel = label("Timer", UDim2.fromOffset(300, 50), UDim2.new(0.5, 0, 0, 20), Vector2.new(0.5, 0), 36)
	placeLabel = label("Place", UDim2.fromOffset(240, 50), UDim2.fromOffset(20, 20), Vector2.zero, 32)
	placeLabel.TextXAlignment = Enum.TextXAlignment.Left
	checkpointLabel = label("Checkpoint", UDim2.fromOffset(240, 30), UDim2.fromOffset(20, 70), Vector2.zero, 20)
	checkpointLabel.TextXAlignment = Enum.TextXAlignment.Left
	speedLabel = label("Speed", UDim2.fromOffset(220, 60), UDim2.new(0.5, 0, 1, -30), Vector2.new(0.5, 1), 40)
	bannerLabel = label("Banner", UDim2.fromOffset(700, 120), UDim2.fromScale(0.5, 0.35), Vector2.new(0.5, 0.5), 72)
	hintLabel = label("Hint", UDim2.fromOffset(500, 24), UDim2.new(0.5, 0, 1, -90), Vector2.new(0.5, 1), 16)
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.Text =
		"WASD или стрелки: газ и руль · в воздухе: наклон и крен · R: респаун"
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		hintLabel.Text =
			"◀ ▶ руль · Тормоз · в воздухе: Газ и Тормоз наклоняют нос"
	end

	resultsLabel = label("Results", UDim2.fromOffset(420, 360), UDim2.fromScale(0.5, 0.55), Vector2.new(0.5, 0.5), 24)
	resultsLabel.BackgroundTransparency = 0.35
	resultsLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	resultsLabel.TextYAlignment = Enum.TextYAlignment.Top
	resultsLabel.Font = Enum.Font.GothamBold
	resultsLabel.Visible = false
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.Parent = resultsLabel
end

function Hud.setTimer(text: string)
	timerLabel.Text = text
end

function Hud.setPlace(place: number?, total: number)
	placeLabel.Text = if place then `{place} / {total}` else ""
end

function Hud.setCheckpoint(passed: number, total: number)
	checkpointLabel.Text = if total > 0 then `Чекпоинт {passed} / {total}` else ""
end

function Hud.setSpeed(speed: number?, boosting: boolean)
	if not speed then
		speedLabel.Text = ""
		return
	end
	speedLabel.Text = `{math.floor(speed)} км/ч`
	speedLabel.TextColor3 = if boosting then Color3.fromRGB(60, 255, 120) else Color3.new(1, 1, 1)
end

function Hud.setBanner(text: string)
	bannerLabel.Text = text
end

function Hud.showResults(lines: { string }?)
	if lines then
		resultsLabel.Text = "Результаты\n\n" .. table.concat(lines, "\n")
		resultsLabel.Visible = true
	else
		resultsLabel.Visible = false
	end
end

return Hud
