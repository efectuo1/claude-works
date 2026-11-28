--!strict
--[[
	Vegetación y mobiliario del hub: árboles redondos y pinos de pisos, tocones, setas, rocas,
	hoguera, bancos, vallas, postes con flechas, diana, fardos, barriles, estrellas y gemas.
	Todo se construye en tamaño base y HubBuilder lo escala junto con la plaza. Las posiciones son
	del suelo; las funciones levantan cada pieza lo que haga falta.
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

local HubNature = {}

local TRUNK = Color3.fromRGB(150, 92, 50)
local WOOD_LIGHT = Color3.fromRGB(236, 196, 132)
local WOOD_DARK = Color3.fromRGB(110, 70, 40)
local PAW = Color3.fromRGB(150, 100, 60)
local CANOPY = {
	Color3.fromRGB(80, 225, 85),
	Color3.fromRGB(50, 200, 110),
	Color3.fromRGB(150, 240, 70),
	Color3.fromRGB(35, 180, 110),
}
local PINE = {
	Color3.fromRGB(35, 175, 105),
	Color3.fromRGB(25, 150, 95),
	Color3.fromRGB(60, 200, 110),
}
local GEMS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(180, 110, 255),
	Color3.fromRGB(255, 120, 40),
	Color3.fromRGB(90, 235, 110),
}
local ROCKS = {
	Color3.fromRGB(150, 150, 165),
	Color3.fromRGB(130, 130, 150),
	Color3.fromRGB(172, 168, 165),
}

-- Árbol de copa redonda: tronco grueso y copa de varias bolas de distinto tamaño.
function HubNature.tree(parent: Instance, position: Vector3, rng: Random)
	local trunkHeight = rng:NextNumber(4, 5)
	pillar(parent, "ArbolTronco", trunkHeight, 1.7, position + Vector3.new(0, trunkHeight / 2, 0), TRUNK, Enum.Material.Wood)
	local leaves = CANOPY[rng:NextInteger(1, #CANOPY)]
	local top = position + Vector3.new(0, trunkHeight, 0)
	ball(parent, "ArbolCopa", 7.5, CFrame.new(top + Vector3.new(0, 3.4, 0)), leaves, Enum.Material.Grass)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		local size = rng:NextNumber(4, 5.2)
		local offset = Vector3.new(math.cos(angle) * 2.7, rng:NextNumber(2.4, 4.6), math.sin(angle) * 2.7)
		ball(parent, "ArbolCopaLateral", size, CFrame.new(top + offset), leaves, Enum.Material.Grass)
	end
end

-- Pino de cinco pisos de disco verde, cada uno más estrecho que el de abajo, con una bola en la punta.
function HubNature.pine(parent: Instance, position: Vector3, rng: Random)
	local tone = rng:NextInteger(1, #PINE)
	pillar(parent, "PinoTronco", 3, 1.3, position + Vector3.new(0, 1.5, 0), TRUNK, Enum.Material.Wood)
	for tier = 0, 4 do
		local radius = 4.6 - tier * 0.85
		local color = PINE[(tone + tier) % #PINE + 1]
		flatDisc(parent, "PinoPiso", radius, 1.7, position + Vector3.new(0, 3 + tier * 1.55, 0), color, Enum.Material.Grass)
	end
	ball(parent, "PinoPunta", 1.5, CFrame.new(position + Vector3.new(0, 3 + 4 * 1.55 + 1.3, 0)), PINE[tone], Enum.Material.Grass)
end

-- Seto redondo.
function HubNature.bush(parent: Instance, position: Vector3, rng: Random)
	local size = rng:NextNumber(4.5, 6.5)
	ball(parent, "Seto", size, CFrame.new(position + Vector3.new(0, size * 0.38, 0)), CANOPY[rng:NextInteger(1, #CANOPY)], Enum.Material.Grass)
end

-- Tocón con anillos en la cara de arriba.
function HubNature.stump(parent: Instance, position: Vector3)
	pillar(parent, "Tocon", 1.5, 2.8, position + Vector3.new(0, 0.75, 0), TRUNK, Enum.Material.Wood)
	flatDisc(parent, "ToconTapa", 1.3, 0.12, position + Vector3.new(0, 1.52, 0), WOOD_LIGHT, Enum.Material.Wood)
	flatDisc(parent, "ToconAnillo", 0.7, 0.14, position + Vector3.new(0, 1.55, 0), Color3.fromRGB(205, 160, 100), Enum.Material.Wood)
end

-- Seta de sombrero rojo con lunares.
function HubNature.mushroom(parent: Instance, position: Vector3, size: number)
	pillar(parent, "SetaTallo", 1.4 * size, 0.8 * size, position + Vector3.new(0, 0.7 * size, 0), Color3.fromRGB(250, 240, 220), Enum.Material.SmoothPlastic)
	ball(parent, "SetaSombrero", 2.2 * size, CFrame.new(position + Vector3.new(0, 1.5 * size, 0)), Color3.fromRGB(235, 55, 55), Enum.Material.SmoothPlastic)
	for index = 0, 3 do
		local angle = index * math.pi / 2 + 0.4
		soft(ball(parent, "SetaLunar", 0.4 * size, CFrame.new(position + Vector3.new(math.cos(angle) * 0.75 * size, 1.95 * size, math.sin(angle) * 0.75 * size)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic))
	end
end

-- Roca de pizarra, achatada y girada.
function HubNature.rock(parent: Instance, position: Vector3, rng: Random, size: number)
	local color = ROCKS[rng:NextInteger(1, #ROCKS)]
	part(parent, "Roca", Vector3.new(size, size * rng:NextNumber(0.6, 0.85), size * rng:NextNumber(0.8, 1.1)), CFrame.new(position + Vector3.new(0, size * 0.28, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), color, Enum.Material.Slate)
end

-- Huella de pata: almohadilla y cuatro dedos planos sobre la arena. `angle` marca hacia dónde mira.
function HubNature.pawPrint(parent: Instance, position: Vector3, angle: number)
	soft(flatDisc(parent, "Huella", 1.0, 0.12, position + Vector3.new(0, 0.1, 0), PAW, Enum.Material.Sand))
	for toe = 0, 3 do
		local direction = angle + (toe - 1.5) * 0.5
		local spot = position + Vector3.new(math.sin(direction), 0, math.cos(direction)) * 1.7
		soft(flatDisc(parent, "HuellaDedo", 0.4, 0.12, spot + Vector3.new(0, 0.1, 0), PAW, Enum.Material.Sand))
	end
end

-- Huellas repartidas en un anillo alrededor de `origin`.
function HubNature.pawRing(parent: Instance, origin: Vector3, radius: number, count: number, rng: Random)
	for index = 0, count - 1 do
		local around = index * 2 * math.pi / count + rng:NextNumber(-0.2, 0.2)
		local spot = origin + Vector3.new(math.cos(around) * radius, 0, math.sin(around) * radius)
		HubNature.pawPrint(parent, spot, around + math.pi / 2)
	end
end

-- Racimo de gemas sobre la arena, con giros distintos para que brillen desde cualquier ángulo.
function HubNature.gemCluster(parent: Instance, center: Vector3, rng: Random, count: number)
	for index = 1, count do
		local size = rng:NextNumber(1.3, 2.4)
		local offset = Vector3.new(rng:NextNumber(-3, 3), size / 2, rng:NextNumber(-3, 3))
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(0, 50)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(0, 50)))
		soft(part(parent, "Gema", Vector3.new(size, size, size), CFrame.new(center + offset) * tilt, GEMS[index % #GEMS + 1], Enum.Material.Neon))
	end
end

-- Estrellas de colores tumbadas en el suelo siguiendo un arco de `from` a `to`.
function HubNature.starTrail(parent: Instance, from: Vector3, to: Vector3, count: number, bulge: number, rng: Random)
	local direction = to - from
	local side = Vector3.new(-direction.Z, 0, direction.X).Unit
	for index = 0, count - 1 do
		local t = if count > 1 then index / (count - 1) else 0
		local spot = from + direction * t + side * math.sin(t * math.pi) * bulge + Vector3.new(0, 0.5, 0)
		local flat = CFrame.new(spot) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, rng:NextNumber(0, math.pi))
		star(parent, "EstrellaSuelo", flat, 2.1 + (index % 2) * 0.5, GEMS[index % #GEMS + 1], 0.35)
	end
end

-- Banco de madera. Local: asiento a lo largo de X, el respaldo queda en -Z.
function HubNature.bench(parent: Instance, cf: CFrame)
	part(parent, "BancoAsiento", Vector3.new(4.4, 0.35, 1.4), cf * CFrame.new(0, 1.5, 0), WOOD_LIGHT, Enum.Material.Wood)
	part(parent, "BancoRespaldo", Vector3.new(4.4, 1.0, 0.3), cf * CFrame.new(0, 2.6, -0.6) * CFrame.Angles(math.rad(-10), 0, 0), WOOD_LIGHT, Enum.Material.Wood)
	for _, side in { 1, -1 } do
		part(parent, "BancoPata", Vector3.new(0.4, 1.5, 1.2), cf * CFrame.new(side * 1.8, 0.75, 0), WOOD_DARK, Enum.Material.Wood)
		part(parent, "BancoApoyo", Vector3.new(0.35, 1.3, 0.3), cf * CFrame.new(side * 1.8, 2.1, -0.6), WOOD_DARK, Enum.Material.Wood)
	end
end

-- Hoguera: anillo de piedras, tres troncos cruzados, llama y luz cálida.
function HubNature.campfire(parent: Instance, position: Vector3)
	for index = 0, 9 do
		local angle = index * math.pi * 2 / 10
		HubNature.rock(parent, position + Vector3.new(math.cos(angle) * 2.5, 0, math.sin(angle) * 2.5), Random.new(index + 5), 1.2)
	end
	for index = 0, 2 do
		local angle = index * math.pi * 2 / 3
		cylinderX(parent, "HogueraTronco", 3.2, 0.7, CFrame.new(position + Vector3.new(0, 0.55, 0)) * CFrame.Angles(0, angle, math.rad(18)), WOOD_DARK, Enum.Material.Wood)
	end
	local flame = soft(ball(parent, "HogueraLlama", 1.5, CFrame.new(position + Vector3.new(0, 1.3, 0)), Color3.fromRGB(255, 150, 40), Enum.Material.Neon))
	flame.Transparency = 0.25
	local fire = Instance.new("ParticleEmitter")
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 210, 80), Color3.fromRGB(255, 70, 30))
	fire.LightEmission = 1
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 0) })
	fire.Rate = 22
	fire.Speed = NumberRange.new(3, 5)
	fire.Lifetime = NumberRange.new(0.6, 1.1)
	fire.SpreadAngle = Vector2.new(14, 14)
	fire.Parent = flame
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 160, 70)
	glow.Range = 24
	glow.Brightness = 1.4
	glow.Parent = flame
end

-- Valla de postes y dos travesaños siguiendo un arco del suelo (plano a la altura de `center`).
function HubNature.fenceArc(parent: Instance, center: Vector3, radius: number, fromDeg: number, toDeg: number)
	local arc = math.rad(toDeg - fromDeg) * radius
	local segments = math.max(2, math.floor(math.abs(arc) / 4))
	local points: { Vector3 } = {}
	for index = 0, segments do
		local angle = math.rad(fromDeg + (toDeg - fromDeg) * index / segments)
		table.insert(points, center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
	end
	for index, point in points do
		part(parent, "VallaPoste", Vector3.new(0.55, 2.3, 0.55), CFrame.new(point + Vector3.new(0, 1.15, 0)), WOOD_LIGHT, Enum.Material.Wood)
		local nextPoint = points[index + 1]
		if nextPoint ~= nil then
			local middle = (point + nextPoint) / 2
			local length = (nextPoint - point).Magnitude
			for _, height in { 0.85, 1.6 } do
				part(parent, "VallaTravesano", Vector3.new(0.28, 0.34, length), CFrame.lookAt(middle + Vector3.new(0, height, 0), nextPoint + Vector3.new(0, height, 0)), WOOD_DARK, Enum.Material.Wood)
			end
		end
	end
end

export type Arrow = { text: string, degrees: number, color: Color3 }

-- Poste con flechas de madera que señalan a cada zona. `degrees` gira cada flecha alrededor del poste.
function HubNature.signpost(parent: Instance, position: Vector3, arrows: { Arrow })
	pillar(parent, "PosteSenales", 8, 0.9, position + Vector3.new(0, 4, 0), WOOD_DARK, Enum.Material.Wood)
	ball(parent, "PosteRemate", 1.3, CFrame.new(position + Vector3.new(0, 8.2, 0)), Color3.fromRGB(255, 200, 60), Enum.Material.SmoothPlastic)
	for index, arrow in arrows do
		local base = CFrame.new(position + Vector3.new(0, 7.0 - (index - 1) * 1.6, 0)) * CFrame.Angles(0, math.rad(arrow.degrees), 0)
		local board = part(parent, "FlechaCartel", Vector3.new(5.6, 1.3, 0.3), base * CFrame.new(2.6, 0, 0), arrow.color, Enum.Material.Wood)
		faceText(board, arrow.text, Enum.NormalId.Front)
		faceText(board, arrow.text, Enum.NormalId.Back)
		part(parent, "FlechaPunta", Vector3.new(0.95, 0.95, 0.3), base * CFrame.new(5.45, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), arrow.color, Enum.Material.Wood)
	end
end

-- Diana de tiro con arco sobre un caballete. Local: la diana mira a +Z.
function HubNature.archery(parent: Instance, cf: CFrame)
	for _, side in { 1, -1 } do
		part(parent, "DianaPata", Vector3.new(0.5, 5.2, 0.5), cf * CFrame.new(side * 1.6, 2.4, -0.4) * CFrame.Angles(0, 0, math.rad(-side * 8)), WOOD_DARK, Enum.Material.Wood)
	end
	local rings = {
		{ 4.6, Color3.fromRGB(250, 250, 250) },
		{ 3.7, Color3.fromRGB(235, 55, 55) },
		{ 2.8, Color3.fromRGB(250, 250, 250) },
		{ 1.9, Color3.fromRGB(235, 55, 55) },
		{ 0.9, Color3.fromRGB(255, 220, 50) },
	}
	for index, ring in rings do
		cylinderX(parent, "DianaAnillo", 0.3, ring[1] :: number, cf * CFrame.new(0, 4.4, 0.1 + index * 0.04) * CFrame.Angles(0, math.rad(90), 0), ring[2] :: Color3, Enum.Material.SmoothPlastic)
	end
end

-- Fardo de paja: cilindro dorado con dos cintas oscuras.
function HubNature.hayBale(parent: Instance, position: Vector3, yaw: number)
	local cf = CFrame.new(position + Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, yaw, 0)
	cylinderX(parent, "Fardo", 2.8, 2.3, cf, Color3.fromRGB(238, 205, 95), Enum.Material.Fabric)
	for _, side in { 1, -1 } do
		cylinderX(parent, "FardoCinta", 0.16, 2.4, cf * CFrame.new(side * 0.8, 0, 0), Color3.fromRGB(200, 150, 55), Enum.Material.Fabric)
	end
end

function HubNature.barrel(parent: Instance, position: Vector3)
	pillar(parent, "Barril", 2.4, 1.9, position + Vector3.new(0, 1.2, 0), Color3.fromRGB(165, 105, 58), Enum.Material.Wood)
	for _, height in { 0.6, 1.8 } do
		pillar(parent, "BarrilAro", 0.2, 2.0, position + Vector3.new(0, height, 0), Color3.fromRGB(70, 70, 82), Enum.Material.Metal)
	end
end

function HubNature.crate(parent: Instance, position: Vector3, yaw: number)
	local cf = CFrame.new(position + Vector3.new(0, 1.0, 0)) * CFrame.Angles(0, yaw, 0)
	part(parent, "Caja", Vector3.new(2, 2, 2), cf, Color3.fromRGB(205, 160, 100), Enum.Material.Wood)
	for _, height in { -0.9, 0.9 } do
		part(parent, "CajaTabla", Vector3.new(2.1, 0.25, 2.1), cf * CFrame.new(0, height, 0), WOOD_DARK, Enum.Material.Wood)
	end
end

-- Farola de madera con linterna encendida. La luz es suave para no saturar la plaza.
function HubNature.lamp(parent: Instance, position: Vector3)
	pillar(parent, "Farola", 8, 0.9, position + Vector3.new(0, 4, 0), WOOD_DARK, Enum.Material.Wood)
	part(parent, "FarolaBrazo", Vector3.new(0.4, 0.4, 1.6), CFrame.new(position + Vector3.new(0, 7.6, 0.6)), WOOD_DARK, Enum.Material.Wood)
	part(parent, "FarolaTapa", Vector3.new(2.2, 0.35, 2.2), CFrame.new(position + Vector3.new(0, 9.9, 1.4)), Color3.fromRGB(70, 50, 40), Enum.Material.Wood)
	local glass = soft(part(parent, "FarolaLuz", Vector3.new(1.6, 2.0, 1.6), CFrame.new(position + Vector3.new(0, 8.7, 1.4)), Color3.fromRGB(255, 225, 150), Enum.Material.Neon))
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 225, 150)
	light.Range = 16
	light.Brightness = 0.6
	light.Parent = glass
end

-- Macizo circular de césped con flores de neón.
function HubNature.flowerBed(parent: Instance, center: Vector3, index: number)
	flatDisc(parent, "Macizo", 2.8, 0.5, center + Vector3.new(0, 0.3, 0), Color3.fromRGB(70, 175, 70), Enum.Material.Grass)
	for flower = 0, 7 do
		local angle = flower * math.pi * 2 / 8
		local spot = center + Vector3.new(math.cos(angle) * 2.3, 0.9, math.sin(angle) * 2.3)
		soft(ball(parent, "Flor", 1.1, CFrame.new(spot), GEMS[(index + flower) % #GEMS + 1], Enum.Material.Neon))
	end
end

return HubNature
