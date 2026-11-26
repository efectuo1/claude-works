--!strict
--[[
	Premios de la ruleta del hub. Datos puros: el servidor elige el premio, el cliente solo lo muestra.
	weight es relativo: la probabilidad de un premio es weight / suma de pesos.
	Los premios "fruit" y "jutsu" son provisionales: aún no hay catálogo de frutas ni de jutsus.
]]

export type Prize = {
	id: string,
	label: string,
	kind: "fruit" | "jutsu" | "gem" | "gold",
	amount: number,
	weight: number,
}

local PRIZES: { Prize } = {
	{ id = "fruit_common", label = "Fruta común", kind = "fruit", amount = 1, weight = 30 },
	{ id = "jutsu_scroll", label = "Pergamino de jutsu", kind = "jutsu", amount = 1, weight = 25 },
	{ id = "gems_small", label = "50 gemas", kind = "gem", amount = 50, weight = 25 },
	{ id = "gold_small", label = "1000 oro", kind = "gold", amount = 1000, weight = 15 },
	{ id = "fruit_rare", label = "Fruta rara", kind = "fruit", amount = 1, weight = 5 },
}

local Roulette = {}

function Roulette.prizes(): { Prize }
	return PRIZES
end

-- Elige un premio con roll en [0, 1). nil solo si la lista está vacía.
function Roulette.pick(prizes: { Prize }, roll: number): Prize?
	local total = 0
	for _, prize in prizes do
		total += prize.weight
	end
	if total <= 0 then
		return nil
	end
	local target = math.clamp(roll, 0, 1) * total
	local accumulated = 0
	for _, prize in prizes do
		accumulated += prize.weight
		if target < accumulated then
			return prize
		end
	end
	-- Redondeo en el extremo: se queda con el último.
	return prizes[#prizes]
end

-- Comprueba que los premios tienen id único, peso positivo y cantidad positiva. Devuelve el primer problema.
function Roulette.validate(prizes: { Prize }): string?
	local seen: { [string]: boolean } = {}
	for index, prize in prizes do
		if seen[prize.id] then
			return `premio {index}: id repetido ({prize.id})`
		end
		seen[prize.id] = true
		if prize.weight <= 0 then
			return `premio {prize.id}: weight debe ser positivo`
		end
		if prize.amount < 1 then
			return `premio {prize.id}: amount debe ser al menos 1`
		end
	end
	return nil
end

return table.freeze(Roulette)
