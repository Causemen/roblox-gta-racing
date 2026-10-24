--!strict
-- Настройки аркадной машины. Скорости в studs/s (1 stud/s примерно 1 км/ч), ускорения в studs/s².

local VehicleTuning = {
	-- Подвеска (raycast, по лучу на каждое колесо)
	RestLength = 2.2,
	WheelRadius = 1.2,
	CompressionAtRest = 0.4, -- доля RestLength, на которую машина проседает стоя
	DampingRatio = 0.35, -- 1 = критическое демпфирование пружины
	WheelInset = Vector3.new(2.2, 0, 3.4), -- смещение лучей от центра шасси по X и Z

	-- Двигатель и тормоза
	MaxSpeed = 130,
	MaxReverseSpeed = 40,
	Acceleration = 75,
	BrakeDeceleration = 150,
	RollingDrag = 0.25, -- доля скорости, теряемая за секунду без газа
	OverSpeedDecay = 1.5, -- как быстро скорость выше максимума возвращается к нему

	-- Буст-пластины
	BoostSpeed = 195,
	BoostAcceleration = 170,
	BoostDuration = 1.5,

	-- Управление на земле
	TurnRate = 2.4, -- рад/с на полном руле
	FullSteerSpeed = 25, -- ниже этой скорости руль слабее
	YawResponse = 8,
	LateralGrip = 10,

	-- Управление в воздухе
	AirPitchRate = 2.5,
	AirRollRate = 2.5,
	AirResponse = 4,
	AirLeveling = 1.2, -- машина сама выравнивается, если игрок не жмет кнопки

	-- Прилипание к трассе: на земле гравитация направлена в поверхность (петли, трубы)
	GravityBlend = 6,

	-- Автореспаун, если машина стоит на месте
	StuckSeconds = 3,
	StuckSpeed = 4,
}

return table.freeze(VehicleTuning)
