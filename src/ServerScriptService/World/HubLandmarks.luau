--!strict
--[[
	Puntos de interés con forma propia: la ruleta de premios y los tableros de clasificación.
	Se construyen en tamaño base alrededor del origen local (X y Z = 0, suelo en `groundY`),
	con la cara hacia +X (la plaza). HubBuilder los agranda y los coloca.
	La pieza llamada exactamente "Ruleta" es la que Bootstrap usa para el botón de girar: no renombrar.
]]

local HubPrimitives = require(script.Parent.HubPrimitives)

local part = HubPrimitives.part
local soft = HubPrimitives.soft
local ball = HubPrimitives.ball
local flatDisc = HubPrimitives.flatDisc
local pillar = HubPrimitives.pillar
local cylinderX = HubPrimitives.cylinderX
local star = HubPrimitives.star
local faceText = HubPrimitives.faceText

local HubLandmarks = {}

local WOOD = Color3.fromRGB(150, 98, 55)
local WOOD_DARK = Color3.fromRGB(105, 66, 36)
local GOLD = Color3.fromRGB(255, 200, 60)
local MARBLE = Color3.fromRGB(236, 238, 248)
local PETALS = {
	Color3.fromRGB(255, 70, 70),
	Color3.fromRGB(255, 215, 40),
	Color3.fromRGB(70, 160, 255),
	Color3.fromRGB(90, 230, 100),
	Color3.fromRGB(255, 130, 40),
	Color3.fromRGB(190, 100, 255),
	Color3.fromRGB(255, 90, 190),
	Color3.fromRGB(60, 230, 235),
}
local GEMS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 120, 40),
	Color3.fromRGB(90, 235, 110),
}

local FACE_PLAZA = CFrame.Angles(0, math.rad(-90), 0) -- la cara -Z de una pieza gira para mirar a +X

-- Ruleta de colores en un bastidor de madera, con luces en el aro y una flecha roja arriba.
function HubLandmarks.wheel(parent: Instance, groundY: number)
	local radius = 7
	local centerY = groundY + 13
	local wheelCf = CFrame.new(0, centerY, 0)
	local postZ = radius + 1.9

	flatDisc(parent, "RuletaPlataforma", 10, 0.8, Vector3.new(0, groundY + 0.4, 0), MARBLE, Enum.Material.Marble)
	flatDisc(parent, "RuletaPlataformaAlta", 8, 0.8, Vector3.new(0, groundY + 1.2, 0), Color3.fromRGB(190, 205, 235), Enum.Material.Marble)

	-- Bastidor: dos postes altos, travesaño del eje y remates dorados.
	for _, side in { 1, -1 } do
		pillar(parent, "RuletaPoste", 24, 1.6, Vector3.new(-0.2, groundY + 1.6 + 12, side * postZ), WOOD, Enum.Material.Wood)
		ball(parent, "RuletaRemate", 2.4, CFrame.new(-0.2, groundY + 26.2, side * postZ), GOLD, Enum.Material.SmoothPlastic)
		part(parent, "RuletaTornapunta", Vector3.new(1.0, 8, 1.0), CFrame.new(-0.2, groundY + 5, side * (postZ + 1.8)) * CFrame.Angles(math.rad(-side * 24), 0, 0), WOOD_DARK, Enum.Material.Wood)
	end
	part(parent, "RuletaTravesano", Vector3.new(1.2, 1.4, postZ * 2), CFrame.new(-1.1, centerY, 0), WOOD_DARK, Enum.Material.Wood)

	-- Rueda: aro dorado, cara oscura y ocho pétalos de colores (los dos primeros niveles se solapan en el centro).
	cylinderX(parent, "RuletaAro", 1.0, (radius + 0.8) * 2, wheelCf * CFrame.new(-0.1, 0, 0), GOLD, Enum.Material.SmoothPlastic)
	cylinderX(parent, "Ruleta", 1.0, radius * 2, wheelCf * CFrame.new(0.25, 0, 0), Color3.fromRGB(40, 36, 96), Enum.Material.SmoothPlastic)
	for index = 0, 7 do
		local angle = math.rad(index * 45)
		local petal = part(parent, "RuletaPetalo", Vector3.new(0.3, radius * 0.78, radius * 0.46), wheelCf * CFrame.Angles(angle, 0, 0) * CFrame.new(0.78 + index * 0.012, radius * 0.58, 0), PETALS[index + 1], Enum.Material.Neon)
		soft(petal)
	end
	for index = 0, 15 do
		local angle = math.rad(index * 22.5)
		local bulbColor = if index % 2 == 0 then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(255, 225, 80)
		soft(ball(parent, "RuletaBombilla", 0.95, wheelCf * CFrame.Angles(angle, 0, 0) * CFrame.new(1.0, radius + 0.1, 0), bulbColor, Enum.Material.Neon))
	end
	cylinderX(parent, "RuletaCentro", 1.4, 3.4, wheelCf * CFrame.new(1.3, 0, 0), GOLD, Enum.Material.SmoothPlastic)
	local core = soft(ball(parent, "RuletaNucleo", 1.7, wheelCf * CFrame.new(2.0, 0, 0), Color3.fromRGB(255, 60, 60), Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 220, 140)
	light.Range = 28
	light.Brightness = 1.2
	light.Parent = core

	-- Flecha roja que marca el premio.
	local pointer = part(parent, "RuletaFlecha", Vector3.new(0.7, 2.4, 2.4), wheelCf * CFrame.new(1.5, radius + 1.3, 0) * CFrame.Angles(math.rad(45), 0, 0), Color3.fromRGB(255, 50, 50), Enum.Material.Neon)
	soft(pointer)

	-- Cartel entre los postes y estrellas a los lados.
	local signY = groundY + 23.4
	local board = part(parent, "RuletaCartel", Vector3.new(17, 3, 0.6), CFrame.new(0, signY, 0) * FACE_PLAZA, Color3.fromRGB(255, 90, 40), Enum.Material.SmoothPlastic)
	faceText(board, "RULETA", Enum.NormalId.Front)
	part(parent, "RuletaCartelMarco", Vector3.new(18, 3.8, 0.4), CFrame.new(-0.4, signY, 0) * FACE_PLAZA, GOLD, Enum.Material.SmoothPlastic)
	for _, side in { 1, -1 } do
		star(parent, "RuletaEstrella", CFrame.new(0.5, signY + 3.2, side * 6.5) * FACE_PLAZA, 2.8, if side > 0 then Color3.fromRGB(255, 225, 60) else Color3.fromRGB(80, 230, 255))
	end
end

-- Tres tableros de clasificación con marco dorado, cabecera de color, trofeo y estrella encima.
local BOARDS = {
	{ z = -11, title = "VICTORIAS", glyph = "🏆", header = Color3.fromRGB(60, 130, 255) },
	{ z = 0, title = "CLASIFICACIÓN", glyph = "⭐", header = Color3.fromRGB(170, 80, 255) },
	{ z = 11, title = "RANGO", glyph = "👑", header = Color3.fromRGB(255, 140, 40) },
}

function HubLandmarks.boards(parent: Instance, groundY: number, rng: Random)
	for _, info in BOARDS do
		local centerY = groundY + 8.2
		for _, side in { 1, -1 } do
			pillar(parent, "TableroPoste", 11, 1.0, Vector3.new(-0.5, groundY + 5.5, info.z + side * 4.4), WOOD, Enum.Material.Wood)
		end
		part(parent, "MarcoTablero", Vector3.new(0.4, 7.6, 10.0), CFrame.new(-0.5, centerY + 0.6, info.z), GOLD, Enum.Material.SmoothPlastic)
		local panel = part(parent, "Clasificacion", Vector3.new(9.0, 5.2, 0.6), CFrame.new(0, centerY - 0.2, info.z) * FACE_PLAZA, Color3.fromRGB(28, 36, 92), Enum.Material.SmoothPlastic)
		faceText(panel, info.glyph, Enum.NormalId.Front)
		local header = part(parent, "TableroCabecera", Vector3.new(9.0, 1.7, 0.7), CFrame.new(0.05, centerY + 3.6, info.z) * FACE_PLAZA, info.header, Enum.Material.SmoothPlastic)
		faceText(header, info.title, Enum.NormalId.Front)
		star(parent, "TableroEstrella", CFrame.new(0.2, centerY + 5.9, info.z) * FACE_PLAZA, 2.2, GOLD)
	end

	-- Montón de gemas de colores detrás de los tableros: rombos girados y bolas de neón.
	for index = 0, 17 do
		local row = index // 6
		local column = index % 6
		local size = rng:NextNumber(1.6, 2.6)
		local position = Vector3.new(-5 - row * 2.4 + rng:NextNumber(-0.4, 0.4), groundY + size / 2 + row * 1.2, (column - 2.5) * 3.6 + rng:NextNumber(-0.4, 0.4))
		local color = GEMS[index % #GEMS + 1]
		if index % 3 == 0 then
			soft(ball(parent, "Gema", size, CFrame.new(position), color, Enum.Material.Neon))
		else
			local tilt = CFrame.Angles(math.rad(rng:NextNumber(0, 50)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(0, 50)))
			soft(part(parent, "Gema", Vector3.new(size, size, size), CFrame.new(position) * tilt, color, Enum.Material.Neon))
		end
	end
end

return HubLandmarks
