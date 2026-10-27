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

return VehicleMath
