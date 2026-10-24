--!strict
-- Панель настройки машины для Studio: ползунки меняют VehicleTuning на лету, найденные значения можно скопировать.
-- Открывается кнопкой справа сверху или клавишей F2. В опубликованной игре не создается.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local VehiclePresets = require(ReplicatedStorage.Shared.VehiclePresets)
local VehicleTuning = require(ReplicatedStorage.Shared.VehicleTuning)

-- Геометрию подвески (RestLength, WheelRadius и т.п.) не трогаем: сервер строит по ней модель машины один раз.
local PARAMS: { { key: string, label: string, min: number?, max: number? } } = {
	{ key = "MaxSpeed", label = "Максимальная скорость" },
	{ key = "MaxReverseSpeed", label = "Скорость назад" },
	{ key = "Acceleration", label = "Разгон" },
	{ key = "BrakeDeceleration", label = "Торможение" },
	{ key = "RollingDrag", label = "Сопротивление без газа" },
	{ key = "OverSpeedDecay", label = "Спад скорости выше максимума" },
	{ key = "BoostSpeed", label = "Скорость буста" },
	{ key = "BoostAcceleration", label = "Разгон буста" },
	{ key = "BoostDuration", label = "Длительность буста" },
	{ key = "TurnRate", label = "Поворот руля" },
	{ key = "FullSteerSpeed", label = "Скорость полного руля" },
	{ key = "YawResponse", label = "Отклик поворота" },
	{ key = "LateralGrip", label = "Боковое сцепление" },
	{ key = "RoadGuide", label = "Доворот вдоль дороги в петле" },
	{ key = "DampingRatio", label = "Демпфирование подвески" },
	{ key = "GravityBlend", label = "Прилипание к трассе" },
	{ key = "AirPitchRate", label = "Наклон в воздухе" },
	{ key = "AirRollRate", label = "Крен в воздухе" },
	{ key = "AirResponse", label = "Отклик в воздухе" },
	{ key = "AirLeveling", label = "Выравнивание в воздухе" },
	{
		key = "AirTimeScale",
		label = "Замедление времени в полёте (меньше = медленнее)",
		min = 0.2,
		max = 1,
	},
}

local MIN_FACTOR = 0.25 -- ползунок идет от 25% до 250% исходного значения
local MAX_FACTOR = 2.5
local PANEL_COLOR = Color3.fromRGB(15, 18, 28)
local ACCENT_COLOR = Color3.fromRGB(255, 170, 40)

local TuningPanel = {}

local function formatValue(value: number): string
	return string.format("%.3g", value)
end

local function makeButton(parent: Instance, text: string, size: UDim2, position: UDim2?): TextButton
	local button = Instance.new("TextButton")
	button.Size = size
	if position then
		button.Position = position
	end
	button.BackgroundColor3 = Color3.fromRGB(45, 52, 74)
	button.TextColor3 = Color3.new(1, 1, 1)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = text
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	return button
end

local function makeLabel(parent: Instance, text: string, size: UDim2, alignment: Enum.TextXAlignment): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = size
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 14
	label.TextXAlignment = alignment
	label.Text = text
	label.Parent = parent
	return label
end

function TuningPanel.start()
	local tuning = VehicleTuning :: any
	local defaults: { [string]: number } = {}
	for _, param in PARAMS do
		defaults[param.key] = tuning[param.key]
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TuningPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local toggle = makeButton(gui, "Настройка (F2)", UDim2.fromOffset(140, 32), UDim2.new(1, -10, 0, 10))
	toggle.AnchorPoint = Vector2.new(1, 0)

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(340, 460)
	panel.Position = UDim2.new(1, -10, 0, 50)
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.BackgroundColor3 = PANEL_COLOR
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -96)
	list.Position = UDim2.fromOffset(8, 48)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.Parent = list

	local refreshers: { () -> () } = {}
	local draggingKey: string? = nil

	for _, param in PARAMS do
		local key = param.key
		local min = param.min or defaults[key] * MIN_FACTOR
		local max = param.max or defaults[key] * MAX_FACTOR

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 44)
		row.BackgroundTransparency = 1
		row.Parent = list

		makeLabel(row, param.label, UDim2.new(0.7, 0, 0, 20), Enum.TextXAlignment.Left)
		local valueLabel = makeLabel(row, "", UDim2.new(0.3, 0, 0, 20), Enum.TextXAlignment.Right)
		valueLabel.Position = UDim2.fromScale(0.7, 0)

		local track = Instance.new("Frame")
		track.Size = UDim2.new(1, 0, 0, 14)
		track.Position = UDim2.fromOffset(0, 24)
		track.BackgroundColor3 = Color3.fromRGB(45, 52, 74)
		track.Active = true
		track.Parent = row
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = ACCENT_COLOR
		fill.BorderSizePixel = 0
		fill.Parent = track

		local function refresh()
			local value: number = tuning[key]
			fill.Size = UDim2.fromScale(math.clamp((value - min) / (max - min), 0, 1), 1)
			valueLabel.Text = formatValue(value)
			valueLabel.TextColor3 = if value == defaults[key] then Color3.new(1, 1, 1) else ACCENT_COLOR
		end
		table.insert(refreshers, refresh)

		local function setFromX(x: number)
			local alpha = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			tuning[key] = min + (max - min) * alpha
			refresh()
		end

		track.InputBegan:Connect(function(input: InputObject)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				draggingKey = key
				list.ScrollingEnabled = false
				setFromX(input.Position.X)
			end
		end)
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if
				draggingKey == key
				and (
					input.UserInputType == Enum.UserInputType.MouseMovement
					or input.UserInputType == Enum.UserInputType.Touch
				)
			then
				setFromX(input.Position.X)
			end
		end)
		refresh()
	end

	UserInputService.InputEnded:Connect(function(input: InputObject)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			draggingKey = nil
			list.ScrollingEnabled = true
		end
	end)

	-- Пресеты: первая кнопка возвращает исходные значения, остальные берутся из VehiclePresets.
	local function applyValues(values: { [string]: number })
		for key, value in defaults do
			tuning[key] = values[key] or value
		end
		for _, refresh in refreshers do
			refresh()
		end
	end

	local presetCount = #VehiclePresets + 1
	local function addPresetButton(index: number, name: string, values: { [string]: number })
		local button = makeButton(
			panel,
			name,
			UDim2.new(1 / presetCount, -6, 0, 30),
			UDim2.new((index - 1) / presetCount, 3, 0, 8)
		)
		button.Activated:Connect(function()
			applyValues(values)
		end)
	end
	addPresetButton(1, "Исходный", {})
	for index, preset in VehiclePresets do
		addPresetButton(index + 1, preset.name, preset.values)
	end

	-- Поле для копирования: только измененные значения, готовые вставить в VehicleTuning.luau.
	local exportBox = Instance.new("TextBox")
	exportBox.Size = UDim2.new(1, -10, 0, 150)
	exportBox.BackgroundColor3 = Color3.fromRGB(30, 35, 52)
	exportBox.TextColor3 = Color3.new(1, 1, 1)
	exportBox.Font = Enum.Font.Code
	exportBox.TextSize = 14
	exportBox.TextXAlignment = Enum.TextXAlignment.Left
	exportBox.TextYAlignment = Enum.TextYAlignment.Top
	exportBox.MultiLine = true
	exportBox.TextEditable = false
	exportBox.ClearTextOnFocus = false
	exportBox.Visible = false
	exportBox.Parent = list

	local showButton =
		makeButton(panel, "Показать значения", UDim2.new(0.5, -12, 0, 32), UDim2.new(0, 8, 1, -40))
	local resetButton = makeButton(panel, "Сбросить", UDim2.new(0.5, -12, 0, 32), UDim2.new(0.5, 4, 1, -40))

	showButton.Activated:Connect(function()
		local lines = {}
		for _, param in PARAMS do
			local value: number = tuning[param.key]
			if value ~= defaults[param.key] then
				table.insert(lines, `{param.key} = {formatValue(value)},`)
			end
		end
		local text = if #lines > 0 then table.concat(lines, "\n") else "-- без изменений"
		exportBox.Text = text
		exportBox.Visible = true
		print(`[Tuning] измененные значения:\n{text}`)
	end)

	resetButton.Activated:Connect(function()
		applyValues({})
		exportBox.Visible = false
	end)

	local function setOpen(open: boolean)
		panel.Visible = open
	end
	toggle.Activated:Connect(function()
		setOpen(not panel.Visible)
	end)
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if not processed and input.KeyCode == Enum.KeyCode.F2 then
			setOpen(not panel.Visible)
		end
	end)
end

return TuningPanel
