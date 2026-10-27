--!strict
-- Экранные кнопки для телефона: руль слева, газ и тормоз справа, плюс автогаз и респаун.
-- Кнопки ловят касания сами (InputBegan/InputEnded), поэтому несколько пальцев работают вместе.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Input = require(script.Parent.Input)

local BUTTON = 78 -- размер большой кнопки, px
local MARGIN = 18
local GLASS = Color3.fromRGB(18, 22, 34) -- темное «стекло» кнопки
local GLASS_TOP = Color3.fromRGB(44, 52, 76)
local RIM = Color3.fromRGB(190, 205, 255) -- тонкая светлая обводка
local ACCENT = Color3.fromRGB(0, 224, 255) -- подсветка нажатой кнопки
local ACCENT_BRAKE = Color3.fromRGB(255, 82, 96)
local ACCENT_ON = Color3.fromRGB(70, 230, 140)
local PRESS_TWEEN = TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local TouchControls = {}

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

type Look = {
	button: TextButton,
	body: Frame,
	scale: UIScale,
	stroke: UIStroke,
	icon: TextLabel,
	accent: Color3,
}

-- Кнопка-«стекло»: полупрозрачная заливка с градиентом, тонкая обводка, иконка и маленькая подпись.
local function makeButton(
	parent: Instance,
	icon: string,
	caption: string,
	size: Vector2,
	position: UDim2,
	anchor: Vector2,
	accent: Color3
): Look
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(size.X, size.Y)
	button.Position = position
	button.AnchorPoint = anchor
	button.BackgroundTransparency = 1
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = parent

	local body = Instance.new("Frame")
	body.Size = UDim2.fromScale(1, 1)
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.BackgroundColor3 = Color3.new(1, 1, 1)
	body.BackgroundTransparency = 0.25
	body.Active = false
	body.Parent = button

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = body

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(GLASS_TOP, GLASS)
	gradient.Rotation = 90
	gradient.Parent = body

	local stroke = Instance.new("UIStroke")
	stroke.Color = RIM
	stroke.Transparency = 0.55
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = body

	local scale = Instance.new("UIScale")
	scale.Parent = body

	local big = size.Y >= 70
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.fromScale(1, if caption == "" then 1 else 0.62)
	iconLabel.Position = UDim2.fromScale(0, if caption == "" then 0 else 0.08)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = Color3.new(1, 1, 1)
	iconLabel.TextTransparency = 0.05
	iconLabel.Font = Enum.Font.GothamBold
	iconLabel.TextSize = if big then 28 elseif (utf8.len(icon) or 1) > 2 then 11 else 17
	iconLabel.Parent = body

	if caption ~= "" then
		local captionLabel = Instance.new("TextLabel")
		captionLabel.Size = UDim2.fromScale(1, 0.26)
		captionLabel.Position = UDim2.fromScale(0, 0.68)
		captionLabel.BackgroundTransparency = 1
		captionLabel.Text = caption
		captionLabel.TextColor3 = RIM
		captionLabel.TextTransparency = 0.15
		captionLabel.Font = Enum.Font.GothamMedium
		captionLabel.TextSize = if big then 11 else 9
		captionLabel.Parent = body
	end

	return { button = button, body = body, scale = scale, stroke = stroke, icon = iconLabel, accent = accent }
end

local function setPressed(look: Look, pressed: boolean)
	TweenService:Create(look.scale, PRESS_TWEEN, { Scale = if pressed then 0.92 else 1 }):Play()
	TweenService
		:Create(look.body, PRESS_TWEEN, { BackgroundColor3 = if pressed then look.accent else Color3.new(1, 1, 1) })
		:Play()
	TweenService:Create(look.body, PRESS_TWEEN, { BackgroundTransparency = if pressed then 0.35 else 0.25 }):Play()
	TweenService:Create(look.stroke, PRESS_TWEEN, { Transparency = if pressed then 0 else 0.55 }):Play()
end

local function bindHold(look: Look, onChange: (boolean) -> ())
	local active: InputObject? = nil
	look.button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) and not active then
			active = input
			setPressed(look, true)
			onChange(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == active then
			active = nil
			setPressed(look, false)
			onChange(false)
		end
	end)
end

-- Стандартная раскладка Roblox со стиком и прыжком здесь не нужна: убираем ее, чтобы не мешала кнопкам.
local function hideDefaultControls()
	local player = Players.LocalPlayer :: Player
	local scripts = player:WaitForChild("PlayerScripts", 10)
	local module = scripts and scripts:WaitForChild("PlayerModule", 10)
	if module then
		local ok, controls = pcall(function()
			return (require(module :: ModuleScript) :: any):GetControls()
		end)
		if ok and controls then
			controls:Disable()
		end
	end
end

function TouchControls.start()
	if not UserInputService.TouchEnabled then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TouchControls"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = (Players.LocalPlayer :: Player):WaitForChild("PlayerGui")

	local square = Vector2.new(BUTTON, BUTTON)
	local bottomLeft, bottomRight = Vector2.new(0, 1), Vector2.new(1, 1)
	local left = makeButton(gui, "◀", "", square, UDim2.new(0, MARGIN, 1, -MARGIN), bottomLeft, ACCENT)
	local right = makeButton(gui, "▶", "", square, UDim2.new(0, MARGIN * 2 + BUTTON, 1, -MARGIN), bottomLeft, ACCENT)
	local brake = makeButton(
		gui,
		"■",
		"ТОРМОЗ",
		square,
		UDim2.new(1, -MARGIN * 2 - BUTTON, 1, -MARGIN),
		bottomRight,
		ACCENT_BRAKE
	)
	local gas = makeButton(
		gui,
		"▲",
		"ГАЗ",
		Vector2.new(BUTTON, BUTTON * 1.6),
		UDim2.new(1, -MARGIN, 1, -MARGIN),
		bottomRight,
		ACCENT
	)
	-- Вместо газа при автогазе: наклон носа в воздухе вперед и назад.
	local noseDown =
		makeButton(gui, "↓", "ВПЕРЁД", square, UDim2.new(1, -MARGIN, 1, -MARGIN), bottomRight, ACCENT)
	local noseUp = makeButton(
		gui,
		"↑",
		"НАЗАД",
		square,
		UDim2.new(1, -MARGIN, 1, -MARGIN * 2 - BUTTON),
		bottomRight,
		ACCENT
	)
	local respawn =
		makeButton(gui, "⟲", "", Vector2.new(42, 42), UDim2.new(1, -MARGIN, 0, 20), Vector2.new(1, 0), ACCENT)
	local autoGas = makeButton(
		gui,
		"АВТО-ГАЗ",
		"",
		Vector2.new(78, 42),
		UDim2.new(1, -MARGIN * 2 - 42, 0, 20),
		Vector2.new(1, 0),
		ACCENT_ON
	)

	bindHold(left, function(down)
		Input.setHeld("left", down)
	end)
	bindHold(right, function(down)
		Input.setHeld("right", down)
	end)
	bindHold(brake, function(down)
		Input.setHeld("brake", down)
	end)
	bindHold(gas, function(down)
		Input.setHeld("gas", down)
	end)
	bindHold(noseDown, function(down)
		Input.setHeld("noseDown", down)
	end)
	bindHold(noseUp, function(down)
		Input.setHeld("noseUp", down)
	end)

	bindHold(respawn, function(down)
		if down then
			Input.respawn()
		end
	end)

	local horn = makeButton(
		gui,
		"♪",
		"",
		Vector2.new(42, 42),
		UDim2.new(1, -MARGIN * 3 - 42 - 78, 0, 20),
		Vector2.new(1, 0),
		ACCENT
	)
	bindHold(horn, function(down)
		if down then
			Input.horn()
		end
	end)

	-- На телефоне без клавиатуры газ жмется сам: новичку надо только рулить и тормозить.
	local enabled = isTouchOnly()
	local function place(look: Look, anchor: Vector2, position: UDim2)
		look.button.AnchorPoint = anchor
		look.button.Position = position
	end
	local function showAutoGas()
		-- Включенный автогаз подсвечен зеленой обводкой и зеленым текстом.
		autoGas.stroke.Color = if enabled then ACCENT_ON else RIM
		autoGas.stroke.Transparency = if enabled then 0.05 else 0.55
		autoGas.icon.TextColor3 = if enabled then ACCENT_ON else Color3.new(1, 1, 1)
		Input.setAutoGas(enabled)
		gas.button.Visible = not enabled
		-- Автогаз: ↑↓ стоят вместо газа справа. Ручной газ: они над ◀ ▶ слева.
		if enabled then
			place(noseDown, bottomRight, UDim2.new(1, -MARGIN, 1, -MARGIN))
			place(noseUp, bottomRight, UDim2.new(1, -MARGIN, 1, -MARGIN * 2 - BUTTON))
		else
			place(noseUp, bottomLeft, UDim2.new(0, MARGIN, 1, -MARGIN * 2 - BUTTON))
			place(noseDown, bottomLeft, UDim2.new(0, MARGIN * 2 + BUTTON, 1, -MARGIN * 2 - BUTTON))
		end
	end
	showAutoGas()
	autoGas.button.Activated:Connect(function()
		enabled = not enabled
		showAutoGas()
	end)

	task.spawn(hideDefaultControls)
end

return TouchControls
