--!strict
-- Ввод для машины: клавиатура, геймпад и кнопки на экране телефона через ContextActionService.

local ContextActionService = game:GetService("ContextActionService")

export type Input = {
	throttle: number, -- -1..1, назад/вперед (в воздухе: наклон носа)
	steer: number, -- -1..1, влево/вправо (в воздухе: крен)
	onRespawn: BindableEvent,
}

local Input = {}

local held = { gas = false, brake = false, left = false, right = false }
local stickX = 0
local triggerGas = 0
local triggerBrake = 0

local state: Input = {
	throttle = 0,
	steer = 0,
	onRespawn = Instance.new("BindableEvent"),
}

local function refresh()
	local throttle = (if held.gas then 1 else 0) - (if held.brake then 1 else 0)
	throttle += triggerGas - triggerBrake
	local steer = (if held.right then 1 else 0) - (if held.left then 1 else 0)
	if math.abs(stickX) > 0.15 then
		steer += stickX
	end
	state.throttle = math.clamp(throttle, -1, 1)
	state.steer = math.clamp(steer, -1, 1)
end

local function bindHold(
	name: string,
	key: "gas" | "brake" | "left" | "right",
	title: string,
	position: UDim2,
	...: Enum.KeyCode
)
	ContextActionService:BindAction(name, function(_, inputState: Enum.UserInputState)
		held[key] = inputState == Enum.UserInputState.Begin or inputState == Enum.UserInputState.Change
		refresh()
		return Enum.ContextActionResult.Sink
	end, true, ...)
	ContextActionService:SetTitle(name, title)
	ContextActionService:SetPosition(name, position)
end

function Input.start(): Input
	bindHold("CarGas", "gas", "Газ", UDim2.new(1, -95, 1, -95), Enum.KeyCode.W, Enum.KeyCode.Up)
	bindHold("CarBrake", "brake", "Тормоз", UDim2.new(1, -170, 1, -75), Enum.KeyCode.S, Enum.KeyCode.Down)
	bindHold("CarLeft", "left", "◀", UDim2.new(0, 20, 1, -95), Enum.KeyCode.A, Enum.KeyCode.Left)
	bindHold("CarRight", "right", "▶", UDim2.new(0, 95, 1, -95), Enum.KeyCode.D, Enum.KeyCode.Right)

	ContextActionService:BindAction("CarRespawn", function(_, inputState: Enum.UserInputState)
		if inputState == Enum.UserInputState.Begin then
			state.onRespawn:Fire()
		end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.R, Enum.KeyCode.ButtonY)
	ContextActionService:SetTitle("CarRespawn", "Респаун")
	ContextActionService:SetPosition("CarRespawn", UDim2.new(1, -95, 1, -170))

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
