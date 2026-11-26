--!strict
--[[
	Catálogo de la tienda como datos. Los pases son de Robux (gamepasses).
	gamePassId = 0 significa "todavía no creado en el Creator Hub": la tienda lo muestra sin venderlo.
	Precios y efectos son PROVISIONALES: cámbialos aquí, sin tocar la interfaz ni el servidor.
	perk: efecto del pase. Se aplica en el servidor (GamePassService) y en Rewards/KillLootHandler.
]]

local Shop = {}

export type GamePass = { id: string, title: string, desc: string, price: number, gamePassId: number, perk: { goldMult: number?, gemMult: number?, luck: number? } }

Shop.GAMEPASSES = {
	{ id = "doble_oro", title = "Oro x2", desc = "Doble oro de los mobs", price = 399, gamePassId = 0, perk = { goldMult = 2 } },
	{ id = "suerte_vip", title = "Suerte VIP", desc = "+10 % de suerte en objetos", price = 299, gamePassId = 0, perk = { luck = 0.10 } },
	{ id = "gemas_x2", title = "Gemas x2", desc = "Doble probabilidad de gemas", price = 499, gamePassId = 0, perk = { gemMult = 2 } },
}

return table.freeze(Shop)
