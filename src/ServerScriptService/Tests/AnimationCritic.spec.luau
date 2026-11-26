--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationCritic = require(ReplicatedStorage.Shared.Util.AnimationCritic)
local TestHarness = require(ServerScriptService.Tests.TestHarness)
local expect = TestHarness.expect

local function frames(list: { { number } }, names: { string })
	local out = {}
	for i, row in list do
		local angles: { [string]: number } = {}
		for j, name in names do
			angles[name] = row[j]
		end
		table.insert(out, { t = (i - 1) * 0.1, angles = angles })
	end
	return out
end

local function kinds(report: AnimationCritic.Report): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, issue in report.issues do
		set[`{issue.joint}:{issue.kind}`] = true
	end
	return set
end

return {
	run = function(): boolean
		return TestHarness.run("AnimationCritic", {
			["rechaza menos de 3 fotogramas"] = function()
				local result = AnimationCritic.critique(frames({ { 0 }, { 1 } }, { "Hip" }))
				expect(not result.ok, "debería fallar con 2 fotogramas")
			end,

			["un movimiento suave no produce incidencias"] = function()
				local rows = {}
				for i = 1, 10 do
					table.insert(rows, { i * 2, i * 2 })
				end
				local result = AnimationCritic.critique(frames(rows, { "Hip", "Knee" }))
				expect(result.ok, "debería aceptar la secuencia")
				if result.ok then
					expect(#result.value.issues == 0, "no debería haber incidencias")
					expect(result.value.score == 10, "la puntuación debería ser 10")
				end
			end,

			["detecta pose fuera de límites"] = function()
				local rows = { { 0 }, { 10 }, { 200 }, { 10 }, { 0 } }
				local result = AnimationCritic.critique(frames(rows, { "Elbow" }), {
					limits = { Elbow = { min = -150, max = 150 } },
				})
				expect(result.ok, "debería aceptar la secuencia")
				if result.ok then
					expect(kinds(result.value)["Elbow:pose"], "debería marcar pose en Elbow")
				end
			end,

			["detecta articulación quieta mientras el cuerpo se mueve"] = function()
				local rows = {}
				for i = 1, 12 do
					table.insert(rows, { i * 5, 30 })
				end
				local result = AnimationCritic.critique(frames(rows, { "Hip", "Arm" }))
				expect(result.ok, "debería aceptar la secuencia")
				if result.ok then
					expect(kinds(result.value)["Arm:stiff"], "Arm debería marcarse como stiff")
				end
			end,

			["detecta un cambio brusco de velocidad"] = function()
				local rows = { { 0 }, { 1 }, { 2 }, { 60 }, { 61 } }
				local result = AnimationCritic.critique(frames(rows, { "Knee" }), { maxAccel = 1000 })
				expect(result.ok, "debería aceptar la secuencia")
				if result.ok then
					expect(kinds(result.value)["Knee:transition"], "Knee debería marcarse como transition")
				end
			end,
		})
	end,
}
