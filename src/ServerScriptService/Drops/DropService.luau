--!strict
--[[
	Servicio de drops (solo servidor). Las probabilidades nunca se calculan en el cliente.
	La fuente de aleatoriedad se inyecta para poder testear de forma determinista.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Result = require(Shared.Util.Result)
local Types = require(Shared.Types)

export type RandomSource = () -> number -- debe devolver un valor en [0, 1)
export type Roll = { itemId: string, quantity: number }
export type DropService = {
	roll: (tableId: string, luck: number?) -> Result.Result<Roll>,
}

local MAX_UNIT = 0.9999999

-- Suerte en [0, MAX_LUCK]. Peso efectivo = peso^(1 - suerte): los pesos grandes (comunes)
-- pierden peso relativo y los pequeños (raros) lo ganan. Sin suerte, el reparto es el original.
-- Es independiente del orden de las entradas. Con suerte 1 todos quedarían iguales, por eso se limita.
local MAX_LUCK = 0.9

local function effectiveWeight(weight: number, luck: number): number
	if luck <= 0 then
		return weight
	end
	return weight ^ (1 - luck)
end

local function sampleUnit(random: RandomSource): number
	return math.clamp(random(), 0, MAX_UNIT)
end

local function validateTable(tableId: string, dropTable: Types.DropTable): Result.Result<boolean>
	if #dropTable.entries == 0 then
		return Result.err(`{tableId}: la tabla no tiene entradas`)
	end
	for index, entry in dropTable.entries do
		if entry.weight <= 0 or entry.weight % 1 ~= 0 then
			return Result.err(`{tableId}[{index}]: el peso debe ser un entero positivo`)
		end
		if entry.minQuantity < 1 or entry.maxQuantity < entry.minQuantity then
			return Result.err(`{tableId}[{index}]: rango de cantidad inválido`)
		end
	end
	return Result.ok(true)
end

local function pickEntry(entries: { Types.DropEntry }, random: RandomSource, luck: number): Types.DropEntry
	local totalWeight = 0
	for _, entry in entries do
		totalWeight += effectiveWeight(entry.weight, luck)
	end

	local threshold = sampleUnit(random) * totalWeight
	local accumulated = 0
	for _, entry in entries do
		accumulated += effectiveWeight(entry.weight, luck)
		if threshold < accumulated then
			return entry
		end
	end
	return entries[#entries] -- inalcanzable con pesos válidos; defensa ante redondeo
end

local DropService = {}

-- Valida todas las tablas al construir el servicio: un error de datos falla al arrancar,
-- no en mitad de una partida.
function DropService.new(tables: { [string]: Types.DropTable }, random: RandomSource): Result.Result<DropService>
	for tableId, dropTable in tables do
		local validation = validateTable(tableId, dropTable)
		if not validation.ok then
			return Result.err(validation.error)
		end
	end

	local service = {}

	function service.roll(tableId: string, luck: number?): Result.Result<Roll>
		local dropTable = tables[tableId]
		if dropTable == nil then
			return Result.err(`tabla de drop desconocida: {tableId}`)
		end

		local safeLuck = math.clamp(luck or 0, 0, MAX_LUCK)
		local entry = pickEntry(dropTable.entries, random, safeLuck)
		local span = entry.maxQuantity - entry.minQuantity + 1
		local quantity = entry.minQuantity + math.floor(sampleUnit(random) * span)
		return Result.ok({ itemId = entry.itemId, quantity = quantity })
	end

	return Result.ok(service)
end

return DropService
