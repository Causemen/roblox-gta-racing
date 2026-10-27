--!strict
-- Ввод для машины: клавиатура и геймпад через ContextActionService; экранные кнопки телефона рисует TouchControls.

local ContextActionService = game:GetService("ContextActionService")

export type Input = {
	throttle: number, -- -1..1, назад/вперед на трассе (с автогазом это 1, пока не нажат тормоз)
	pitch: number, -- -1..1, кнопки газ/тормоз как есть: в воздухе наклон носа, автогаз его не трогает
	steer: number, -- -1..1, влево/вправо (в воздухе: крен)
	handbrake: boolean, -- ручник (Пробел, кнопка «ДРИФТ»): занос на скорости вместе с рулем
	autoGas: boolean, -- газ жмется сам: новичку на телефоне остается только руль и тормоз
	onRespawn: BindableEvent,
	onHorn: BindableEvent,
}

local Input = {}

export type Key = "gas" | "brake" | "left" | "right" | "noseDown" | "noseUp" | "handbrake"

local held =
	{ gas = false, brake = false, left = false, right = false, noseDown = false, noseUp = false, handbrake = false }
local stickX = 0
local triggerGas = 0
local triggerBrake = 0

local state: Input = {
	throttle = 0,
	pitch = 0,
	steer = 0,
	handbrake = false,
	autoGas = false,
	onRespawn = Instance.new("BindableEvent"),
	onHorn = Instance.new("BindableEvent"),
}

local function refresh()
	local throttle = (if held.gas then 1 else 0) - (if held.brake then 1 else 0)
	throttle += triggerGas - triggerBrake
	state.pitch = math.clamp(throttle + (if held.noseDown then 1 else 0) - (if held.noseUp then 1 else 0), -1, 1)
	if state.autoGas and throttle >= 0 then
		throttle = 1
	end
	local steer = (if held.right then 1 else 0) - (if held.left then 1 else 0)
	if math.abs(stickX) > 0.15 then
		steer += stickX
	end
	state.handbrake = held.handbrake
	state.throttle = math.clamp(throttle, -1, 1)
	state.steer = math.clamp(steer, -1, 1)
end

local function bindHold(name: string, key: Key, ...: Enum.KeyCode)
	ContextActionService:BindAction(name, function(_, inputState: Enum.UserInputState)
		held[key] = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
		refresh()
		return Enum.ContextActionResult.Sink
	end, false, ...)
end

-- Экранные кнопки (client/TouchControls) вызывают это для нажатия и отпускания.
function Input.setHeld(key: Key, down: boolean)
	held[key] = down
	refresh()
end

function Input.setAutoGas(enabled: boolean)
	state.autoGas = enabled
	refresh()
end

function Input.respawn()
	state.onRespawn:Fire()
end

function Input.horn()
	state.onHorn:Fire()
end

function Input.start(): Input
	bindHold("CarGas", "gas", Enum.KeyCode.W, Enum.KeyCode.Up)
	bindHold("CarBrake", "brake", Enum.KeyCode.S, Enum.KeyCode.Down)
	bindHold("CarLeft", "left", Enum.KeyCode.A, Enum.KeyCode.Left)
	bindHold("CarRight", "right", Enum.KeyCode.D, Enum.KeyCode.Right)
	bindHold("CarHandbrake", "handbrake", Enum.KeyCode.Space, Enum.KeyCode.ButtonB)

	ContextActionService:BindAction("CarRespawn", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			state.onRespawn:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.R, Enum.KeyCode.ButtonY)

	ContextActionService:BindAction("CarHorn", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			state.onHorn:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.H, Enum.KeyCode.ButtonL3)

	ContextActionService:BindAction("CarGamepad", function(_, inputState: Enum.UserInputState, input: InputObject)
		local released = inputState == Enum.UserInputState.End or inputState == Enum.UserInputState.Cancel
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			stickX = if released then 0 else input.Position.X
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerGas = if released then 0 else input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			triggerBrake = if released then 0 else input.Position.Z
		end
		refresh()
		return Enum.ContextActionResult.Sink
	end, false, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonR2, Enum.KeyCode.ButtonL2)

	return state
end

return Input
