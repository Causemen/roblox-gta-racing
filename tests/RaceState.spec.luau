-- Запуск: lune run tests/RaceState.spec.luau

local RaceState = require("../src/shared/RaceState")

assert(RaceState.next("Lobby") == "Countdown", "Lobby -> Countdown")
assert(RaceState.next("Voting") == "Lobby", "Voting -> Lobby")

print("RaceState: ok")
