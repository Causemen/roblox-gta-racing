--!strict
-- Готовые наборы значений VehicleTuning для сравнения в TuningPanel. Не меняют игру сами по себе.

export type Preset = {
	name: string,
	values: { [string]: number },
}

local presets: { Preset } = {
	{
		-- Отправная точка под ощущение стант-гонок GTA Online: выше скорость и разгон, сильное сцепление и
		-- прилипание к трассе, мощный длинный буст, мягче подвеска, активнее управление в воздухе.
		name = "GTA-стант",
		values = {
			MaxSpeed = 170,
			MaxReverseSpeed = 45,
			Acceleration = 110,
			BrakeDeceleration = 170,
			RollingDrag = 0.2,
			OverSpeedDecay = 1.2,
			BoostSpeed = 260,
			BoostAcceleration = 260,
			BoostDuration = 2,
			TurnRate = 2.2,
			FullSteerSpeed = 30,
			YawResponse = 10,
			LateralGrip = 14,
			DampingRatio = 0.5,
			GravityBlend = 8,
			AirPitchRate = 2.2,
			AirRollRate = 3,
			AirResponse = 5,
			AirLeveling = 0.6,
		},
	},
}

return table.freeze(presets)
