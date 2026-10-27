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
assert(VehicleMath.driveAcceleration(200, 1, true, tuning) < 0, "буст тоже ограничен")

-- Руль: вправо значит отрицательная угловая скорость, на месте руль не крутит машину.
assert(VehicleMath.desiredYawRate(100, 1, 2.4, 25) < 0, "вправо на ходу")
assert(VehicleMath.desiredYawRate(0, 1, 2.4, 25) == 0, "на месте не поворачивает")
assert(VehicleMath.desiredYawRate(-20, 1, 2.4, 25) > 0, "задним ходом руль инвертирован")

-- Дрифт
local drift = {
	DriftGrip = 0.35,
	DriftSteerStart = 0.7,
	DriftMinSpeed = 70,
	DriftMaxSlip = 0.7,
	DriftTurnBoost = 0.5,
	DriftAssist = 2.5,
	DriftBrakeFactor = 0.35,
	DriftEnter = 10,
	DriftExit = 3.5,
}

assert(VehicleMath.slipAngle(100, 0) == 0, "едет прямо, заноса нет")
assert(VehicleMath.slipAngle(100, 50) > 0, "сносит вправо")
assert(VehicleMath.slipAngle(100, -50) < 0, "сносит влево")
assert(near(VehicleMath.slipAngle(100, 100), math.pi / 4), "45 градусов при равных скоростях")
assert(VehicleMath.slipAngle(-20, 30) == 0, "задним ходом заноса нет")

assert(
	VehicleMath.driftTrigger(50, 1, false, false, drift) == 0,
	"ниже минимальной скорости дрифта нет"
)
assert(
	VehicleMath.driftTrigger(120, 0.3, false, false, drift) == 0,
	"слабый руль без тормоза не дрифтует"
)
assert(VehicleMath.driftTrigger(120, 1, false, false, drift) == 1, "полный руль на скорости")
assert(
	VehicleMath.driftTrigger(120, 0.5, true, false, drift) == 1,
	"тормоз с рулем входит в занос"
)
assert(VehicleMath.driftTrigger(120, -0.5, false, true, drift) == 1, "ручник с рулем влево")
assert(
	VehicleMath.driftTrigger(120, 0, true, true, drift) == 0,
	"тормоз и ручник без руля не дрифт"
)
assert(
	VehicleMath.driftTrigger(80, 1, false, false, drift) < VehicleMath.driftTrigger(120, 1, false, false, drift),
	"на малой скорости дрифт слабее"
)

assert(VehicleMath.driftGrip(0, 0, drift) == 1, "без дрифта сцепление полное")
assert(
	near(VehicleMath.driftGrip(1, 0, drift), 0.35),
	"в дрифте без заноса сцепление минимально"
)
assert(
	near(VehicleMath.driftGrip(1, 0.7, drift), 1),
	"на пределе заноса сцепление полное"
)
assert(near(VehicleMath.driftGrip(1, -0.7, drift), 1), "предел одинаков в обе стороны")
assert(
	VehicleMath.driftGrip(1, 0.3, drift) < VehicleMath.driftGrip(1, 0.5, drift),
	"чем больше занос, тем больше сцепление"
)

local current = VehicleMath.smoothDrift(0, 1, 0.05, drift)
assert(current > 0 and current < 1, "дрифт нарастает плавно")
assert(
	1 - VehicleMath.smoothDrift(1, 0, 0.05, drift) < VehicleMath.smoothDrift(0, 1, 0.05, drift),
	"затухает медленнее, чем нарастает"
)
assert(VehicleMath.smoothDrift(0, 1, 10, drift) == 1, "большой шаг не перелетает цель")

-- Руль в дрифте: нос доворачивается сильнее, без руля возвращается вдоль скорости.
local base = VehicleMath.desiredYawRate(120, 1, 2.4, 25)
assert(
	VehicleMath.driftYawRate(base, 0, 1, 1, drift) < base,
	"в дрифте вправо вращение сильнее (более отрицательное)"
)
assert(VehicleMath.driftYawRate(base, 0, 1, 0, drift) == base, "вне дрифта вращение прежнее")
assert(
	VehicleMath.driftYawRate(0, 0.3, 0, 1, drift) < 0,
	"снос вправо без руля: нос возвращается вправо"
)
assert(
	VehicleMath.driftYawRate(0, -0.3, 0, 1, drift) > 0,
	"снос влево без руля: нос возвращается влево"
)
assert(
	VehicleMath.driftYawRate(0, 0.3, 1, 1, drift) == 0,
	"на полном руле помощник не мешает"
)

assert(VehicleMath.driftThrottle(1, 1, drift) == 1, "газ в дрифте не меняется")
assert(near(VehicleMath.driftThrottle(-1, 1, drift), -0.35), "тормоз в дрифте слабее")
assert(VehicleMath.driftThrottle(-1, 0, drift) == -1, "вне дрифта тормоз полный")

print("VehicleMath: ok")
