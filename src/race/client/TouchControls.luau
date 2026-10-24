--!strict
-- Экранные кнопки для телефона: руль слева, газ и тормоз справа, плюс автогаз и респаун.
-- Кнопки ловят касания сами (InputBegan/InputEnded), поэтому несколько пальцев работают вместе.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Input = require(script.Parent.Input)

local BUTTON = 104 -- размер большой кнопки, px
local MARGIN = 22
local IDLE = Color3.fromRGB(25, 30, 44)
local PRESSED = Color3.fromRGB(255, 200, 40)
local ON = Color3.fromRGB(60, 200, 110)

local TouchControls = {}

local function isTouchOnly(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
end

local function makeButton(parent: Instance, text: string, size: number, position: UDim2, anchor: Vector2): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(size, size)
	button.Position = position
	button.AnchorPoint = anchor
	button.BackgroundColor3 = IDLE
	button.BackgroundTransparency = 0.35
	button.AutoButtonColor = false
	button.Text = text
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextSize = if size >= BUTTON then 30 else 18
	button.Font = Enum.Font.GothamBold
	button.Parent = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = button
	return button
end

local function bindHold(button: TextButton, onChange: (boolean) -> ())
	local active: InputObject? = nil
	button.InputBegan:Connect(function(input: InputObject)
		if isPress(input) and not active then
			active = input
			button.BackgroundColor3 = PRESSED
			button.BackgroundTransparency = 0.1
			onChange(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input == active then
			active = nil
			button.BackgroundColor3 = IDLE
			button.BackgroundTransparency = 0.35
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

	local left = makeButton(gui, "◀", BUTTON, UDim2.new(0, MARGIN, 1, -MARGIN), Vector2.new(0, 1))
	local right = makeButton(gui, "▶", BUTTON, UDim2.new(0, MARGIN * 2 + BUTTON, 1, -MARGIN), Vector2.new(0, 1))
	local brake =
		makeButton(gui, "Тормоз", BUTTON, UDim2.new(1, -MARGIN * 2 - BUTTON, 1, -MARGIN), Vector2.new(1, 1))
	local gas = makeButton(gui, "Газ", BUTTON, UDim2.new(1, -MARGIN, 1, -MARGIN), Vector2.new(1, 1))
	gas.Size = UDim2.fromOffset(BUTTON, BUTTON * 1.6)
	local respawn = makeButton(gui, "R", 56, UDim2.new(1, -MARGIN, 0, 20), Vector2.new(1, 0))
	local autoGas = makeButton(gui, "", 56, UDim2.new(1, -MARGIN * 2 - 56, 0, 20), Vector2.new(1, 0))

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

	respawn.Text = "Респ."
	respawn.Activated:Connect(Input.respawn)

	-- На телефоне без клавиатуры газ жмется сам: новичку надо только рулить и тормозить.
	local enabled = isTouchOnly()
	local function showAutoGas()
		autoGas.Text = if enabled then "Авто\nгаз ✓" else "Авто\nгаз"
		autoGas.BackgroundColor3 = if enabled then ON else IDLE
		Input.setAutoGas(enabled)
	end
	showAutoGas()
	autoGas.Activated:Connect(function()
		enabled = not enabled
		showAutoGas()
	end)

	task.spawn(hideDefaultControls)
end

return TouchControls
