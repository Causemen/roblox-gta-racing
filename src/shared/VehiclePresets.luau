--!strict
-- Готовые наборы значений VehicleTuning для сравнения в TuningPanel. Не меняют игру сами по себе:
-- значения по умолчанию лежат в VehicleTuning, а набор поверх них только подменяет перечисленные поля.

export type Preset = {
	name: string,
	values: { [string]: number },
}

local presets: { Preset } = {
	{
		-- Машина до перехода на ощущение GTA: ниже скорость, мягче сцепление, без замедления времени в полете.
		name = "Старый",
		values = {
			MaxSpeed = 130,
			MaxReverseSpeed = 40,
			Acceleration = 75,
			BrakeDeceleration = 150,
			RollingDrag = 0.25,
			OverSpeedDecay = 1.5,
			BoostSpeed = 195,
			BoostAcceleration = 170,
			BoostDuration = 1.5,
			TurnRate = 2.4,
			FullSteerSpeed = 25,
			YawResponse = 8,
			LateralGrip = 10,
			DriftGrip = 1,
			DriftMaxSlip = 0.7,
			DriftTurnBoost = 0,
			DriftAssist = 0,
			DriftDrag = 0,
			DriftBrakeFactor = 1,
			HandbrakeDeceleration = 0,
			DriftBoostMaxDuration = 0,
			DriftBoostMinDuration = 0,
			RoadGuide = 0,
			DampingRatio = 0.35,
			GravityBlend = 6,
			AirPitchRate = 2.5,
			AirRollRate = 2.5,
			AirResponse = 4,
			AirLeveling = 1.2,
			AirTimeScale = 1,
		},
	},
}

return table.freeze(presets)
