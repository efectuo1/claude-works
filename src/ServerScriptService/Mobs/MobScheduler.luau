--!strict
--[[
	Un único hilo del servidor que ejecuta el tick de todos los mobs.
	Antes cada mob tenía su propio task.spawn: con muchos mobs eso significa muchos hilos
	despertándose a la vez. Aquí hay un bucle, un intervalo común y un tick por job por ciclo.
	Un job que falla no detiene a los demás (pcall por job).
]]

export type Job = {
	tick: () -> (),
	isActive: () -> boolean,
}

local MobScheduler = {}

local TICK_SECONDS = 0.2

local jobs: { Job } = {}
local loopStarted = false

-- Ejecuta un ciclo: tick de cada job activo. Los inactivos se retiran.
-- Expuesta también para pruebas, sin esperar al reloj.
function MobScheduler.stepOnce()
	local index = 1
	while index <= #jobs do
		local job = jobs[index]
		if job.isActive() then
			local ok, err = pcall(job.tick)
			if not ok then
				warn(`[MobScheduler] job falló: {err}`)
			end
			index += 1
		else
			-- Borrado por intercambio con el último: no avanza el índice.
			jobs[index] = jobs[#jobs]
			jobs[#jobs] = nil
		end
	end
end

-- Espera antes del primer ciclo: así añadir un job no lo ejecuta de forma síncrona.
local function runLoop()
	while true do
		task.wait(TICK_SECONDS)
		MobScheduler.stepOnce()
	end
end

function MobScheduler.add(job: Job)
	table.insert(jobs, job)
	if not loopStarted then
		loopStarted = true
		task.spawn(runLoop)
	end
end

-- Solo para pruebas: cuántos jobs quedan registrados.
function MobScheduler.count(): number
	return #jobs
end

return MobScheduler
