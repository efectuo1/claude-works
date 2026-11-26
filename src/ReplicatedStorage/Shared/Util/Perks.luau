--!strict
--[[
	Pases de Robux como efectos numéricos. Lógica pura: quién tiene cada pase lo decide el servidor;
	aquí solo se convierte en multiplicadores. Sin pases, todo vale lo normal (1, 1, 0).
]]

local Perks = {}

export type Perks = { goldMult: number, gemMult: number, luck: number }
export type Effect = { goldMult: number?, gemMult: number?, luck: number? }

-- Igual que el tope de suerte del DropService.
Perks.LUCK_CAP = 0.9

Perks.NONE = table.freeze({ goldMult = 1, gemMult = 1, luck = 0 })

-- Combina varios efectos: los multiplicadores se multiplican, la suerte se suma y luego se limita.
function Perks.combine(effects: { Effect }): Perks
	local result = { goldMult = 1, gemMult = 1, luck = 0 }
	for _, effect in effects do
		result.goldMult *= effect.goldMult or 1
		result.gemMult *= effect.gemMult or 1
		result.luck += effect.luck or 0
	end
	result.luck = math.clamp(result.luck, 0, Perks.LUCK_CAP)
	return result
end

-- Efectos de los pases que el jugador tiene. owns(id) dice si lo tiene.
function Perks.fromPasses(passes: { { id: string, perk: Effect } }, owns: (id: string) -> boolean): Perks
	local effects: { Effect } = {}
	for _, pass in passes do
		if owns(pass.id) then
			table.insert(effects, pass.perk)
		end
	end
	return Perks.combine(effects)
end

return table.freeze(Perks)
