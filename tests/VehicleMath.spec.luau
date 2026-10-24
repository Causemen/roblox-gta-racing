-- Запуск: lune run tests/VehicleMath.spec.luau

local VehicleMath = require("../src/shared/VehicleMath")

local tuning = {
	MaxSpeed = 130,
	MaxReverseSpeed = 40,
	Acceleration = 75,
	BrakeDeceleration = 150,
	OverSpeedDecay = 1.5,
	BoostSpeed = 195,
	BoostAcceleration = 170,
}

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

-- Пружина: в покое четыре колеса держат вес машины.
local mass, gravity, rest, sag = 50, 196.2, 2.2, 0.4
local stiffness, damping = VehicleMath.suspension(mass, gravity, rest, sag, 0.35)
local restForce = VehicleMath.springForce(rest * sag, 0, stiffness, damping)
assert(near(restForce * 4, mass * gravity), `4 колеса держат вес: {restForce * 4} vs {mass * gravity}`)
assert(VehicleMath.springForce(0, 10, stiffness, damping) == 0, "колесо в воздухе не дает силы")
assert(VehicleMath.springForce(0.5, -1000, stiffness, damping) == 0, "пружина не тянет вниз")

-- Мотор
assert(VehicleMath.driveAcceleration(50, 1, false, tuning) == 75, "газ разгоняет")
assert(VehicleMath.driveAcceleration(50, -1, false, tuning) == -150, "тормоз на ходу")
assert(VehicleMath.driveAcceleration(0, -1, false, tuning) == -45, "задний ход с места")
assert(VehicleMath.driveAcceleration(-40, -1, false, tuning) == 0, "задний ход ограничен")
assert(
	VehicleMath.driveAcceleration(150, 1, false, tuning) < 0,
	"выше максимума скорость падает"
)
assert(
	VehicleMath.driveAcceleration(150, 0, true, tuning) == 170,
	"буст разгоняет выше максимума"
)
assert(VehicleMath.driveAcceleration(200, 1, true, tuning) == 0, "буст тоже ограничен")

-- Руль: вправо значит отрицательная угловая скорость, на месте руль не крутит машину.
assert(VehicleMath.desiredYawRate(100, 1, 2.4, 25) < 0, "вправо на ходу")
assert(VehicleMath.desiredYawRate(0, 1, 2.4, 25) == 0, "на месте не поворачивает")
assert(VehicleMath.desiredYawRate(-20, 1, 2.4, 25) > 0, "задним ходом руль инвертирован")

print("VehicleMath: ok")
