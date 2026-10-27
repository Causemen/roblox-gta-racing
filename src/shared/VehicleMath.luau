--!strict
-- Чистые формулы физики машины без Roblox API, чтобы их можно было тестировать в Lune.

export type DriveTuning = {
	MaxSpeed: number,
	MaxReverseSpeed: number,
	Acceleration: number,
	BrakeDeceleration: number,
	OverSpeedDecay: number,
	BoostSpeed: number,
	BoostAcceleration: number,
}

export type DriftTuning = {
	DriftGrip: number,
	DriftSteerStart: number,
	DriftMinSpeed: number,
	DriftMaxSlip: number,
	DriftTurnBoost: number,
	DriftAssist: number,
	DriftBrakeFactor: number,
	DriftEnter: number,
	DriftExit: number,
	DriftBoostMinTime: number,
	DriftBoostFullTime: number,
	DriftBoostMinDuration: number,
	DriftBoostMaxDuration: number,
}

local VehicleMath = {}

-- Сила пружины колеса: растет со сжатием, гасится скоростью сжатия; тянуть колесо вниз не может.
function VehicleMath.springForce(
	compression: number,
	compressionSpeed: number,
	stiffness: number,
	damping: number
): number
	if compression <= 0 then
		return 0
	end
	return math.max(0, compression * stiffness + compressionSpeed * damping)
end

-- Жесткость и демпфер на одно колесо из массы, гравитации и желаемой просадки.
function VehicleMath.suspension(
	mass: number,
	gravity: number,
	restLength: number,
	compressionAtRest: number,
	dampingRatio: number
): (number, number)
	local wheelMass = mass / 4
	local stiffness = wheelMass * gravity / (restLength * compressionAtRest)
	local damping = dampingRatio * 2 * math.sqrt(stiffness * wheelMass)
	return stiffness, damping
end

-- Продольное ускорение от газа и тормоза. throttle от -1 до 1, speed со знаком (вперед > 0).
function VehicleMath.driveAcceleration(speed: number, throttle: number, boosting: boolean, tuning: DriveTuning): number
	if boosting then
		if speed < tuning.BoostSpeed then
			return tuning.BoostAcceleration
		end
		return -(speed - tuning.BoostSpeed) * tuning.OverSpeedDecay -- перелет через предел буста гасится, а не держится
	end

	if speed > tuning.MaxSpeed then
		local decay = -(speed - tuning.MaxSpeed) * tuning.OverSpeedDecay
		if throttle < 0 then
			return decay + throttle * tuning.BrakeDeceleration
		end
		return decay
	end

	if throttle > 0 then
		return throttle * tuning.Acceleration
	elseif throttle < 0 then
		if speed > 1 then
			return throttle * tuning.BrakeDeceleration
		elseif speed > -tuning.MaxReverseSpeed then
			return throttle * tuning.Acceleration * 0.6
		end
	end
	return 0
end

-- Желаемая скорость поворота (рад/с вокруг оси «вверх»). steer > 0 значит вправо.
function VehicleMath.desiredYawRate(speed: number, steer: number, turnRate: number, fullSteerSpeed: number): number
	local speedFactor = math.clamp(math.abs(speed) / fullSteerSpeed, 0, 1)
	local direction = if speed >= 0 then 1 else -1
	-- Поворот вправо это отрицательное вращение вокруг оси Y.
	return -steer * turnRate * speedFactor * direction
end

-- Угол заноса в радианах: насколько скорость повернута относительно носа. > 0 значит машину сносит вправо.
-- Задним ходом заноса нет.
function VehicleMath.slipAngle(forwardSpeed: number, lateralSpeed: number): number
	if forwardSpeed <= 0 then
		return 0
	end
	return math.atan2(lateralSpeed, math.max(forwardSpeed, 1))
end

-- Насколько хочет начаться дрифт, 0..1. Нужна скорость от DriftMinSpeed и одно из двух:
-- руль сильнее DriftSteerStart или тормоз/ручник вместе с рулем (так новичок на телефоне входит в занос одним пальцем).
function VehicleMath.driftTrigger(
	speed: number,
	steer: number,
	braking: boolean,
	handbrake: boolean,
	tuning: DriftTuning
): number
	local speedGate = math.clamp((speed - tuning.DriftMinSpeed) / (tuning.DriftMinSpeed * 0.5), 0, 1)
	local amount = math.abs(steer)
	local steerPart = math.clamp((amount - tuning.DriftSteerStart) / math.max(1 - tuning.DriftSteerStart, 0.01), 0, 1)
	local initiate = if (braking or handbrake) and amount >= 0.25 then 1 else 0
	return speedGate * math.max(steerPart, initiate)
end

-- Плавное нарастание дрифта (быстро) и затухание (медленнее, чтобы занос не обрывался от одного касания руля).
function VehicleMath.smoothDrift(current: number, target: number, dt: number, tuning: DriftTuning): number
	local rate = if target > current then tuning.DriftEnter else tuning.DriftExit
	return current + (target - current) * math.min(1, dt * rate)
end

-- Доля бокового сцепления. Дрифт снижает ее до DriftGrip, но чем ближе угол заноса к DriftMaxSlip,
-- тем сильнее сцепление возвращается: занос ограничен и не превращается в вертушку.
function VehicleMath.driftGrip(drift: number, slip: number, tuning: DriftTuning): number
	local base = 1 - (1 - tuning.DriftGrip) * drift
	local limit = math.clamp(math.abs(slip) / math.max(tuning.DriftMaxSlip, 0.01), 0, 1)
	return base + (1 - base) * limit * limit
end

-- Скорость поворота с учетом дрифта: в дрифте нос довернут сильнее (DriftTurnBoost), а без руля нос сам
-- возвращается вдоль скорости (DriftAssist), так что отпустить руль значит выйти из заноса.
function VehicleMath.driftYawRate(
	baseYaw: number,
	slip: number,
	steer: number,
	drift: number,
	tuning: DriftTuning
): number
	local turn = baseYaw * (1 + tuning.DriftTurnBoost * drift)
	local assist = -slip * tuning.DriftAssist * (1 - math.abs(steer))
	return turn + assist
end

-- Тормоз в дрифте слабее: иначе вход в занос тормозом просто остановил бы машину.
function VehicleMath.driftThrottle(throttle: number, drift: number, tuning: DriftTuning): number
	if throttle >= 0 then
		return throttle
	end
	return throttle * (1 - drift * (1 - tuning.DriftBrakeFactor))
end

-- Награда за дрифт: сколько секунд буста дать на выходе из заноса, если дрифтовали chargeSeconds.
-- Короче DriftBoostMinTime награды нет, от DriftBoostFullTime она максимальная, между ними растет линейно.
function VehicleMath.driftBoostDuration(chargeSeconds: number, tuning: DriftTuning): number
	if tuning.DriftBoostMaxDuration <= 0 or chargeSeconds < tuning.DriftBoostMinTime then
		return 0
	end
	local span = math.max(tuning.DriftBoostFullTime - tuning.DriftBoostMinTime, 0.01)
	local t = math.clamp((chargeSeconds - tuning.DriftBoostMinTime) / span, 0, 1)
	return tuning.DriftBoostMinDuration + (tuning.DriftBoostMaxDuration - tuning.DriftBoostMinDuration) * t
end

return VehicleMath
