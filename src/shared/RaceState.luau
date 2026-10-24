--!strict
-- Состояния заезда, которые ведет RaceManager на гоночном сервере.

export type RaceState = "Lobby" | "Countdown" | "Racing" | "Finished" | "Rewards" | "Voting"

local RaceState = {
	Order = { "Lobby", "Countdown", "Racing", "Finished", "Rewards", "Voting" } :: { RaceState },
}

function RaceState.next(state: RaceState): RaceState
	local order = RaceState.Order
	local index = table.find(order, state) or 0
	return order[index % #order + 1]
end

return RaceState
