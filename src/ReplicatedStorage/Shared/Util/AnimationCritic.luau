--!strict
--[[
	Crítico de animaciones, en código y sin IA: revisa una secuencia de fotogramas y busca
	tres problemas del "Animation Critic Method":
	  - pose:       una articulación sale de sus límites (pose rara o imposible).
	  - stiff:      una articulación queda quieta mucho tiempo mientras el resto del cuerpo se mueve.
	  - transition: cambio brusco de velocidad (aceleración alta) en una articulación.

	Entrada: fotogramas ordenados por tiempo, con ángulos en grados por nombre de articulación.
	Salida: puntuación de 0 a 10 y lista de incidencias agrupadas por (articulación, tipo).

	Es el sustituto determinista de la revisión fotograma a fotograma de un agente:
	no entiende estilo, solo detecta fallos medibles.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Util.Result)

export type Frame = {
	t: number, -- segundos desde el inicio
	angles: { [string]: number }, -- grados por articulación
}

export type Limits = { [string]: { min: number, max: number } }

export type Options = {
	stillDeg: number?, -- movimiento por debajo de esto cuenta como quieto (defecto 0.5)
	stillFrames: number?, -- cuántos fotogramas quieto hacen falta para "stiff" (defecto 6)
	maxAccel: number?, -- aceleración máxima en deg/s² antes de "transition" (defecto 4000)
	limits: Limits?, -- límites de pose por articulación (opcional)
}

export type Issue = {
	joint: string,
	kind: "pose" | "stiff" | "transition",
	firstFrame: number, -- índice del primer fotograma afectado (1-based)
	count: number, -- fotogramas afectados en total
	detail: string,
}

export type Report = {
	score: number,
	issues: { Issue },
}

local DEFAULT_STILL_DEG = 0.5
local DEFAULT_STILL_FRAMES = 6
local DEFAULT_MAX_ACCEL = 4000

local AnimationCritic = {}

local function jointNames(frames: { Frame }): { string }
	local seen: { [string]: boolean } = {}
	local names: { string } = {}
	for _, frame in frames do
		for name in frame.angles do
			if not seen[name] then
				seen[name] = true
				table.insert(names, name)
			end
		end
	end
	table.sort(names)
	return names
end

function AnimationCritic.critique(frames: { Frame }, options: Options?): Result.Result<Report>
	if #frames < 3 then
		return Result.err("se necesitan al menos 3 fotogramas")
	end
	for i = 2, #frames do
		if frames[i].t <= frames[i - 1].t then
			return Result.err(`los tiempos no crecen en el fotograma {i}`)
		end
	end

	local opts = options or {}
	local stillDeg = opts.stillDeg or DEFAULT_STILL_DEG
	local stillFrames = opts.stillFrames or DEFAULT_STILL_FRAMES
	local maxAccel = opts.maxAccel or DEFAULT_MAX_ACCEL
	local limits = opts.limits or {}

	local issues: { Issue } = {}
	local byKey: { [string]: Issue } = {}

	local function record(joint: string, kind: "pose" | "stiff" | "transition", frame: number, detail: string)
		local key = `{joint}:{kind}`
		local existing = byKey[key]
		if existing then
			existing.count += 1
		else
			local issue: Issue = {
				joint = joint,
				kind = kind,
				firstFrame = frame,
				count = 1,
				detail = detail,
			}
			byKey[key] = issue
			table.insert(issues, issue)
		end
	end

	local names = jointNames(frames)

	-- Pose: límites.
	for index, frame in frames do
		for _, name in names do
			local angle = frame.angles[name]
			local limit = limits[name]
			if angle ~= nil and limit ~= nil and (angle < limit.min or angle > limit.max) then
				record(name, "pose", index, `{angle}° fuera de [{limit.min}, {limit.max}]`)
			end
		end
	end

	-- Movimiento por fotograma: delta absoluto por articulación entre i-1 e i.
	local function delta(name: string, i: number): number?
		local a = frames[i - 1].angles[name]
		local b = frames[i].angles[name]
		if a == nil or b == nil then
			return nil
		end
		return math.abs(b - a)
	end

	-- Stiff: articulación quieta durante stillFrames seguidos mientras algo más se mueve.
	for _, name in names do
		local run = 0
		for i = 2, #frames do
			local d = delta(name, i)
			if d ~= nil and d < stillDeg then
				run += 1
				-- Movimiento global en este fotograma (otras articulaciones).
				local bodyMoving = false
				for _, other in names do
					if other ~= name then
						local od = delta(other, i)
						if od ~= nil and od >= stillDeg then
							bodyMoving = true
							break
						end
					end
				end
				if run == stillFrames and bodyMoving then
					record(name, "stiff", i - stillFrames + 1, `quieta {stillFrames} fotogramas con el cuerpo en movimiento`)
				end
			else
				run = 0
			end
		end
	end

	-- Transition: aceleración angular alta entre fotogramas consecutivos.
	for _, name in names do
		for i = 3, #frames do
			local a0 = frames[i - 2].angles[name]
			local a1 = frames[i - 1].angles[name]
			local a2 = frames[i].angles[name]
			if a0 ~= nil and a1 ~= nil and a2 ~= nil then
				local dt1 = frames[i - 1].t - frames[i - 2].t
				local dt2 = frames[i].t - frames[i - 1].t
				local v1 = (a1 - a0) / dt1
				local v2 = (a2 - a1) / dt2
				local accel = math.abs(v2 - v1) / ((dt1 + dt2) / 2)
				if accel > maxAccel then
					record(name, "transition", i - 1, `aceleración {math.floor(accel)} deg/s² > {maxAccel}`)
				end
			end
		end
	end

	-- Cada articulación y tipo con problemas resta 0.5 punto, hasta 10 puntos.
	local score = math.max(0, 10 - 0.5 * #issues)

	return Result.ok({
		score = score,
		issues = issues,
	})
end

return AnimationCritic
