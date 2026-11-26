--!strict
--[[
	Imágenes de interfaz. Cada valor es un ID de imagen de Roblox (rbxassetid://...).
	Mientras un valor esté vacío, la interfaz usa su versión de respaldo.

	Cómo rellenarlo:
	1. En Studio: Asset Manager (o Import) → sube el PNG de assets/iconos/ como Decal.
	2. En la barra de comandos de Studio, con el ID del decal:
	   game:GetObjects("rbxassetid://<ID_DEL_DECAL>")[1].Texture
	3. Pega el ID que devuelve (rbxassetid://...) en el campo correspondiente de aquí.
]]

local UiAssets = {}

local IDS: { [string]: string } = {
	coin = "",
	gem = "",
	mejoras = "",
	indice = "",
	frutas = "",
	modos = "",
	inicio = "",
	ajustes = "",
}

function UiAssets.get(key: string): string?
	local id = IDS[key]
	if id == nil or id == "" then
		return nil
	end
	return id
end

return table.freeze(UiAssets)
