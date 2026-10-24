--!strict
-- Расчетная проверка трека без Roblox API: по числам машины проходит участки и ищет места, где игрок
-- врежется (поворот на слишком большой скорости, короткая прямая для торможения, недолет прыжка, слабая
-- скорость на петле). Это модель в одном измерении, а не физика Roblox: она ловит грубые ошибки раскладки.

export type Segment =
	{ kind: "grid" }
	| { kind: "straight", length: number, boost: boolean? }
	| { kind: "taper", length: number, width: number }
	| { kind: "turn", angle: number, radius: number }
	| { kind: "vcurve", angle: number, radius: number }
	| { kind: "loop", radius: number }
	| { kind: "gap", length: number, drop: number }
	| { kind: "checkpoint" }
	| { kind: "finish" }

export type Tuning = {
	TurnRate: number,
	BrakeDeceleration: number,
	BoostDuration: number,
}

export type Report = {
	problems: { string },
	notes: { string }, -- скорость входа в каждый поворот, петлю и прыжок
}

local GRAVITY = 196.2 -- Workspace.Gravity по умолчанию
local STEP = 0.02 -- шаг интеграции, с
local PAD_LENGTH = 12 -- длина буст-пластины, как в TrackBuilder
local STEER_MARGIN = 0.85 -- какую долю максимальной скорости рулевого берем за предел поворота
local REACTION_SECONDS = 0.7 -- пока игрок заметит поворот и начнет тормозить
local LOOP_FACTOR = 1.3 -- запас над скоростью, при которой гравитация прижимает машину в верхней точке петли
local JUMP_MARGIN = 1.1 -- долет прыжка должен быть длиннее ямы минимум на столько

local TrackAnalysis = {}

local function shortName(segment: Segment): string
	if segment.kind == "turn" then
		return `поворот {segment.angle}° радиусом {segment.radius}`
	elseif segment.kind == "loop" then
		return `петля радиусом {segment.radius}`
	elseif segment.kind == "gap" then
		return `прыжок через яму {segment.length}`
	end
	return segment.kind
end

-- accel(speed, boosting) - продольное ускорение при полном газе, обычно VehicleMath.driveAcceleration.
function TrackAnalysis.analyze(segments: { Segment }, tuning: Tuning, accel: (number, boolean) -> number): Report
	local problems: { string } = {}
	local notes: { string } = {}

	local started = false
	local speed = 0
	local boostLeft = 0
	local pitchDegrees = 0
	local runway = 0 -- сколько прямой подряд перед текущим участком, где можно тормозить

	local function drive(length: number, boostAt: number?)
		local traveled = 0
		while traveled < length do
			if boostAt and traveled >= boostAt then
				boostLeft = tuning.BoostDuration
				boostAt = nil
			end
			speed = math.max(0, speed + accel(speed, boostLeft > 0) * STEP)
			boostLeft = math.max(0, boostLeft - STEP)
			traveled += math.max(speed, 1) * STEP
		end
	end

	for _, segment in segments do
		if segment.kind == "grid" then
			started = true
			speed, boostLeft, runway = 0, 0, 0
		elseif not started then
			continue
		elseif segment.kind == "straight" then
			local boostAt = if segment.boost
				then (segment.length - math.min(PAD_LENGTH, segment.length * 0.5)) / 2
				else nil
			drive(segment.length, boostAt)
			runway += segment.length
		elseif segment.kind == "taper" then
			drive(segment.length)
			runway += segment.length
		elseif segment.kind == "vcurve" then
			drive(math.rad(math.abs(segment.angle)) * segment.radius)
			pitchDegrees += segment.angle
			runway += math.rad(math.abs(segment.angle)) * segment.radius
		elseif segment.kind == "turn" then
			local limit = segment.radius * tuning.TurnRate * STEER_MARGIN
			table.insert(notes, `{shortName(segment)}: вход {math.floor(speed)}, предел {math.floor(limit)}`)
			if speed > limit then
				local stopping = (speed * speed - limit * limit) / (2 * tuning.BrakeDeceleration)
					+ speed * REACTION_SECONDS
				if stopping > runway then
					table.insert(
						problems,
						`{shortName(segment)}: скорость входа {math.floor(speed)} выше предела {math.floor(
							limit
						)}, `
							.. `на торможение нужно {math.ceil(stopping)}, прямой перед поворотом {math.floor(
								runway
							)}`
					)
				end
			end
			speed = math.min(speed, limit)
			drive(math.rad(math.abs(segment.angle)) * segment.radius)
			runway = 0
		elseif segment.kind == "loop" then
			local minimum = math.sqrt(GRAVITY * segment.radius) * LOOP_FACTOR
			table.insert(
				notes,
				`{shortName(segment)}: вход {math.floor(speed)}, нужно от {math.ceil(minimum)}`
			)
			if speed < minimum then
				table.insert(
					problems,
					`{shortName(segment)}: скорость входа {math.floor(speed)} меньше {math.ceil(
						minimum
					)}, не доедет`
				)
			end
			drive(2 * math.pi * segment.radius)
			runway = 0
		elseif segment.kind == "gap" then
			local angle = math.rad(pitchDegrees)
			local vertical = speed * math.sin(angle)
			local airtime = (vertical + math.sqrt(vertical * vertical + 2 * GRAVITY * segment.drop)) / GRAVITY
			local reach = speed * math.cos(angle) * airtime
			table.insert(
				notes,
				`{shortName(segment)}: вход {math.floor(speed)}, долет {math.floor(reach)}, яма {segment.length}`
			)
			if reach < segment.length * JUMP_MARGIN then
				table.insert(
					problems,
					`{shortName(segment)}: долет {math.floor(reach)} при скорости {math.floor(speed)} и подъеме `
						.. `{math.floor(pitchDegrees)}°, нужно хотя бы {math.ceil(
							segment.length * JUMP_MARGIN
						)}`
				)
			end
			drive(segment.length)
			pitchDegrees = 0
			runway = 0
		end
	end

	return { problems = problems, notes = notes }
end

return TrackAnalysis
