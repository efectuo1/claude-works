--!strict
--[[
	Piezas básicas del hub: partes ancladas, discos, cilindros, estrellas, carteles y emisores.
	Cabañas, ruleta, tableros y vegetación se construyen solo con estas funciones, así que el
	estilo (bordes lisos, colores vivos, neón) se cambia en un único sitio.
	Convención: un Cylinder de Roblox apunta a lo largo de X; `pillar` lo deja vertical y
	`flatDisc` lo deja tumbado como una moneda.
]]

local HubPrimitives = {}

local WHITE = Color3.new(1, 1, 1)

function HubPrimitives.part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Material = material or Enum.Material.SmoothPlastic
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Parent = parent
	return piece
end

-- Adorno: no estorba al caminar ni a los raycasts.
function HubPrimitives.soft(piece: Part): Part
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	return piece
end

-- Cilindro tumbado a lo largo de X (un tronco): `length` va en X, `diameter` en Y y Z.
function HubPrimitives.cylinderX(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return HubPrimitives.part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, Enum.PartType.Cylinder)
end

-- Cilindro vertical centrado en `center`.
function HubPrimitives.pillar(parent: Instance, name: string, height: number, diameter: number, center: Vector3, color: Color3, material: Enum.Material?): Part
	return HubPrimitives.part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

-- Disco plano tumbado sobre el suelo.
function HubPrimitives.flatDisc(parent: Instance, name: string, radius: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material?): Part
	return HubPrimitives.part(parent, name, Vector3.new(thickness, radius * 2, radius * 2), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material, Enum.PartType.Cylinder)
end

function HubPrimitives.ball(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return HubPrimitives.part(parent, name, Vector3.new(diameter, diameter, diameter), cf, color, material, Enum.PartType.Ball)
end

-- Estrella de ocho puntas: dos cuadrados iguales girados 45°. Mira hacia el -Z de `cf` (grosor en Z).
function HubPrimitives.star(parent: Instance, name: string, cf: CFrame, size: number, color: Color3, thickness: number?)
	local depth = thickness or 0.4
	local first = HubPrimitives.part(parent, name, Vector3.new(size, size, depth), cf, color, Enum.Material.Neon)
	local second = HubPrimitives.part(parent, name, Vector3.new(size, size, depth), cf * CFrame.Angles(0, 0, math.rad(45)), color, Enum.Material.Neon)
	HubPrimitives.soft(first)
	HubPrimitives.soft(second)
end

-- Rombo (gema): un cuadrado girado 45° en Z.
function HubPrimitives.diamond(parent: Instance, name: string, cf: CFrame, size: number, color: Color3, depth: number?): Part
	return HubPrimitives.part(parent, name, Vector3.new(size, size, depth or size * 0.5), cf * CFrame.Angles(0, 0, math.rad(45)), color, Enum.Material.Neon)
end

-- Texto sobre una cara de una pieza, con borde negro para que se lea con cualquier fondo.
function HubPrimitives.faceText(piece: BasePart, text: string, face: Enum.NormalId, textColor: Color3?, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Texto"
	gui.Face = face
	gui.Parent = piece
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = font or Enum.Font.GothamBlack
	label.TextColor3 = textColor or WHITE
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(20, 12, 30)
	stroke.Parent = label
end

-- Cartel de madera o plástico con texto. `face` es la cara que lleva el texto.
function HubPrimitives.signBoard(parent: Instance, name: string, size: Vector3, cf: CFrame, text: string, boardColor: Color3, face: Enum.NormalId, material: Enum.Material?): Part
	local board = HubPrimitives.part(parent, name, size, cf, boardColor, material)
	HubPrimitives.faceText(board, text, face)
	return board
end

-- Chispas o luciérnagas: un ancla invisible con un emisor de partículas.
function HubPrimitives.emitter(parent: Instance, position: Vector3, color: Color3, rate: number, speed: number, lifetime: number, spread: number, size: number?): Part
	local anchor = HubPrimitives.soft(HubPrimitives.part(parent, "Ambiente", Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), color))
	anchor.Transparency = 1
	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(color)
	particles.LightEmission = 1
	particles.Size = NumberSequence.new(size or 0.35)
	particles.Rate = rate
	particles.Speed = NumberRange.new(speed * 0.5, speed)
	particles.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	particles.SpreadAngle = Vector2.new(spread, spread)
	particles.Parent = anchor
	return anchor
end

return HubPrimitives
