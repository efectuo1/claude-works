--!strict
--[[
	Edificios del hub: cabañas de troncos y establo rojo.
	La puerta mira a +Z local; `cabin` la gira hacia `facing` (al contrario del vector, o sea hacia la plaza).
	Un mismo constructor sirve para los dos: `Style` decide troncos o tablones, tejado, puerta simple o doble.
	Todas las medidas están en unidades base y se multiplican por `scale`.
]]

local HubPrimitives = require(script.Parent.HubPrimitives)

local part = HubPrimitives.part
local soft = HubPrimitives.soft
local emitter = HubPrimitives.emitter
local signBoard = HubPrimitives.signBoard

local HubStructures = {}

export type Style = {
	courseA: Color3,
	courseB: Color3,
	core: Color3,
	roof: Color3,
	roofLine: Color3,
	beam: Color3,
	trim: Color3,
	door: Color3,
	signColor: Color3,
	shutter: Color3,
	logs: boolean,
	doubleDoor: boolean,
	chimney: boolean,
	windowBoxes: boolean,
}

local STONE = Color3.fromRGB(165, 165, 178)
local GLOW = Color3.fromRGB(255, 236, 150)
local GOLD = Color3.fromRGB(255, 200, 60)
local FLOWERS = {
	Color3.fromRGB(255, 80, 160),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(255, 120, 40),
}

HubStructures.CABIN = table.freeze({
	courseA = Color3.fromRGB(247, 214, 146),
	courseB = Color3.fromRGB(232, 186, 112),
	core = Color3.fromRGB(150, 100, 58),
	roof = Color3.fromRGB(222, 58, 52),
	roofLine = Color3.fromRGB(150, 32, 32),
	beam = Color3.fromRGB(122, 78, 42),
	trim = Color3.fromRGB(122, 78, 42),
	door = Color3.fromRGB(120, 68, 36),
	signColor = Color3.fromRGB(96, 60, 34),
	shutter = Color3.fromRGB(40, 170, 200),
	logs = true,
	doubleDoor = false,
	chimney = true,
	windowBoxes = true,
} :: Style)

HubStructures.BARN = table.freeze({
	courseA = Color3.fromRGB(214, 60, 52),
	courseB = Color3.fromRGB(196, 48, 44),
	core = Color3.fromRGB(150, 36, 34),
	roof = Color3.fromRGB(150, 45, 42),
	roofLine = Color3.fromRGB(105, 28, 28),
	beam = Color3.fromRGB(245, 240, 232),
	trim = Color3.fromRGB(245, 240, 232),
	door = Color3.fromRGB(170, 40, 38),
	signColor = Color3.fromRGB(50, 110, 235),
	shutter = Color3.fromRGB(245, 240, 232),
	logs = false,
	doubleDoor = true,
	chimney = false,
	windowBoxes = false,
} :: Style)

-- Devuelve el centro de la puerta a ras de suelo, donde se coloca el pad o el cartel.
function HubStructures.cabin(parent: Instance, name: string, position: Vector3, facing: Vector3, scale: number, style: Style, signText: string?): Vector3
	local yaw = math.atan2(-facing.X, -facing.Z)
	local root = CFrame.new(position) * CFrame.Angles(0, yaw, 0)
	local s = scale

	local WIDTH, DEPTH = 7, 6.4
	local DIAMETER, COURSES = 0.9, 6
	local BASE = 0.5
	local wallTop = BASE + DIAMETER * COURSES
	local frontZ = if style.logs then DEPTH / 2 + DIAMETER / 2 else DEPTH / 2 + 0.25

	local function at(x: number, y: number, z: number): CFrame
		return root * CFrame.new(x * s, y * s, z * s)
	end
	local function piece(partName: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
		return part(parent, `{name}{partName}`, size * s, cf, color, material, shape)
	end

	-- Cimiento de piedra y núcleo oscuro: así no se ve el vacío entre troncos.
	piece("Cimiento", Vector3.new(WIDTH + 0.8, BASE, DEPTH + 0.8), at(0, BASE / 2, 0), STONE, Enum.Material.Slate)
	piece("Nucleo", Vector3.new(WIDTH - 0.3, wallTop - BASE, DEPTH - 0.3), at(0, (wallTop + BASE) / 2, 0), style.core, Enum.Material.Wood)

	-- Paredes: seis hiladas de troncos (con las puntas asomando en las esquinas) o de tablones.
	for course = 0, COURSES - 1 do
		local y = BASE + (course + 0.5) * DIAMETER
		local color = if course % 2 == 0 then style.courseA else style.courseB
		for _, side in { 1, -1 } do
			if style.logs then
				piece("Tronco", Vector3.new(WIDTH + 0.9, DIAMETER, DIAMETER), at(0, y, side * DEPTH / 2), color, Enum.Material.Wood, Enum.PartType.Cylinder)
				piece("Tronco", Vector3.new(DEPTH + 0.9, DIAMETER, DIAMETER), at(side * WIDTH / 2, y, 0) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Wood, Enum.PartType.Cylinder)
			else
				piece("Tabla", Vector3.new(WIDTH, DIAMETER - 0.08, 0.5), at(0, y, side * DEPTH / 2), color, Enum.Material.Wood)
				piece("Tabla", Vector3.new(0.5, DIAMETER - 0.08, DEPTH), at(side * WIDTH / 2, y, 0), color, Enum.Material.Wood)
			end
		end
	end
	if not style.logs then
		for _, sx in { 1, -1 } do
			for _, sz in { 1, -1 } do
				piece("Esquina", Vector3.new(0.7, wallTop - BASE, 0.7), at(sx * WIDTH / 2, (wallTop + BASE) / 2, sz * DEPTH / 2), style.trim, Enum.Material.Wood)
			end
		end
	end

	-- Puerta.
	local doorH = 3.4
	if style.doubleDoor then
		piece("MarcoPuerta", Vector3.new(4.3, doorH + 0.5, 0.2), at(0, BASE + (doorH + 0.5) / 2, frontZ + 0.02), style.trim, Enum.Material.Wood)
		for _, side in { 1, -1 } do
			piece("Puerta", Vector3.new(1.9, doorH, 0.25), at(side * 1.0, BASE + doorH / 2, frontZ + 0.12), style.door, Enum.Material.Wood)
			for _, tilt in { 1, -1 } do
				piece("AspaPuerta", Vector3.new(0.24, 3.9, 0.12), at(side * 1.0, BASE + doorH / 2, frontZ + 0.3) * CFrame.Angles(0, 0, math.rad(29 * tilt)), style.trim, Enum.Material.Wood)
			end
		end
	else
		piece("MarcoPuerta", Vector3.new(2.5, doorH + 0.4, 0.2), at(0, BASE + (doorH + 0.4) / 2, frontZ + 0.02), style.beam, Enum.Material.Wood)
		piece("Puerta", Vector3.new(1.9, doorH, 0.25), at(0, BASE + doorH / 2, frontZ + 0.12), style.door, Enum.Material.Wood)
		piece("PuertaTabla", Vector3.new(1.9, 0.12, 0.1), at(0, BASE + 1.1, frontZ + 0.27), style.beam, Enum.Material.Wood)
		piece("PuertaTabla", Vector3.new(1.9, 0.12, 0.1), at(0, BASE + 2.3, frontZ + 0.27), style.beam, Enum.Material.Wood)
		soft(piece("Pomo", Vector3.new(0.3, 0.3, 0.3), at(0.6, BASE + 1.7, frontZ + 0.32), GOLD, Enum.Material.Metal, Enum.PartType.Ball))
	end
	piece("Dintel", Vector3.new(3.0, 0.35, 0.4), at(0, BASE + doorH + 0.5, frontZ + 0.1), style.beam, Enum.Material.Wood)

	-- Ventanas encendidas a los lados de la puerta.
	local windowY = BASE + 3.2
	for _, side in { 1, -1 } do
		local wx = side * 2.3
		piece("MarcoVentana", Vector3.new(1.7, 1.7, 0.2), at(wx, windowY, frontZ + 0.02), style.beam, Enum.Material.Wood)
		piece("Cristal", Vector3.new(1.3, 1.3, 0.15), at(wx, windowY, frontZ + 0.12), GLOW, Enum.Material.Neon)
		piece("Travesano", Vector3.new(1.3, 0.12, 0.1), at(wx, windowY, frontZ + 0.22), style.beam, Enum.Material.Wood)
		piece("Travesano", Vector3.new(0.12, 1.3, 0.1), at(wx, windowY, frontZ + 0.22), style.beam, Enum.Material.Wood)
		if style.windowBoxes then
			piece("Postigo", Vector3.new(0.4, 1.7, 0.15), at(wx + side * 1.0, windowY, frontZ + 0.06), style.shutter, Enum.Material.Wood)
			piece("Jardinera", Vector3.new(1.9, 0.5, 0.55), at(wx, windowY - 1.15, frontZ + 0.3), style.beam, Enum.Material.Wood)
			for k = -1, 1 do
				local flowerColor = FLOWERS[(k + 2 + (if side > 0 then 0 else 1)) % #FLOWERS + 1]
				soft(piece("Flor", Vector3.new(0.5, 0.5, 0.5), at(wx + k * 0.6, windowY - 0.75, frontZ + 0.32), flowerColor, Enum.Material.Neon, Enum.PartType.Ball))
			end
		end
	end

	-- Escalones de piedra delante de la puerta.
	piece("Escalon", Vector3.new(3.6, 0.3, 1.5), at(0, 0.15, frontZ + 0.8), STONE, Enum.Material.Slate)
	piece("EscalonAlto", Vector3.new(2.8, 0.2, 0.9), at(0, 0.35, frontZ + 0.5), STONE, Enum.Material.Slate)

	-- Tejado en A, empinado (52°), con aleros largos y hileras de tejas.
	local theta = math.rad(52)
	local overhangZ, overhangX = 1.2, 1.0
	local runZ = DEPTH / 2 + overhangZ
	local slabLength = runZ / math.cos(theta)
	local rise = runZ * math.tan(theta)
	local slabWidth = WIDTH + 2 * overhangX
	for _, side in { 1, -1 } do
		local slabCf = at(0, wallTop + rise / 2 + 0.25, side * runZ / 2) * CFrame.Angles(side * theta, 0, 0)
		piece("Tejado", Vector3.new(slabWidth, 0.55, slabLength), slabCf, style.roof, Enum.Material.SmoothPlastic)
		for row = 1, 5 do
			local along = (-slabLength / 2 + row * slabLength / 6) * s
			piece("Teja", Vector3.new(slabWidth, 0.12, 0.22), slabCf * CFrame.new(0, 0.3 * s, along), style.roofLine, Enum.Material.SmoothPlastic)
		end
		piece("Alero", Vector3.new(slabWidth, 0.4, 0.4), slabCf * CFrame.new(0, -0.1 * s, side * slabLength / 2 * s), style.beam, Enum.Material.Wood)
	end
	piece("Cumbrera", Vector3.new(slabWidth + 0.6, 0.7, 0.7), at(0, wallTop + rise + 0.45, 0), style.beam, Enum.Material.Wood, Enum.PartType.Cylinder)

	-- Frontones de los lados: hiladas cada vez más cortas hasta la cumbre.
	for _, side in { 1, -1 } do
		local course = 0
		while true do
			local h = (course + 0.5) * DIAMETER
			local half = math.min(DEPTH / 2 + DIAMETER / 2 - 0.1, runZ * (1 - h / rise) - 0.9)
			if half < 0.6 then
				break
			end
			local color = if course % 2 == 0 then style.courseA else style.courseB
			if style.logs then
				piece("TroncoFrontón", Vector3.new(half * 2, DIAMETER, DIAMETER), at(side * WIDTH / 2, wallTop + h, 0) * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Wood, Enum.PartType.Cylinder)
			else
				piece("TablaFrontón", Vector3.new(0.5, DIAMETER - 0.08, half * 2), at(side * WIDTH / 2, wallTop + h, 0), color, Enum.Material.Wood)
			end
			course += 1
		end
	end

	-- Chimenea de piedra con humo.
	if style.chimney then
		local top = wallTop + 6.5
		piece("Chimenea", Vector3.new(1.3, 7.5, 1.3), at(WIDTH / 2 - 1.2, wallTop - 1 + 3.75, -1.4), Color3.fromRGB(150, 150, 165), Enum.Material.Brick)
		piece("ChimeneaTapa", Vector3.new(1.8, 0.3, 1.8), at(WIDTH / 2 - 1.2, top + 0.15, -1.4), Color3.fromRGB(110, 110, 125), Enum.Material.Slate)
		emitter(parent, (root * CFrame.new((WIDTH / 2 - 1.2) * s, (top + 0.8) * s, -1.4 * s)).Position, Color3.fromRGB(225, 225, 235), 4, 3 * s, 3, 12, 0.9 * s)
	end

	-- Cartel sobre la puerta (cara +Z).
	if signText ~= nil then
		signBoard(parent, `{name}Cartel`, Vector3.new(4.6, 1.2, 0.3) * s, at(0, BASE + doorH + 1.3, frontZ + 0.25), signText, style.signColor, Enum.NormalId.Back, Enum.Material.Wood)
	end

	return (root * CFrame.new(0, 0, frontZ * s)).Position
end

return HubStructures
