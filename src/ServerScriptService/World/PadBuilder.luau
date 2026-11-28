--!strict
--[[
	Pads visibles de entrada y salida: disco de neón con aro, columna de luz, chispas, luz y rótulo.
	El prompt no exige línea de visión y se activa desde poca distancia, así que un pilar o el suelo
	no lo tapan. El disco se puede pisar: el jugador también puede entrar caminando sobre él.
]]

local HubPrimitives = require(script.Parent.HubPrimitives)

local PadBuilder = {}

local DISC_RADIUS = 3.5

local function shade(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Crea el pad. `position` es el centro del disco; el disco queda apoyado en el suelo o plataforma.
function PadBuilder.build(parent: Instance, name: string, position: Vector3, color: Color3, title: string): Part
	local pad = HubPrimitives.flatDisc(parent, name, DISC_RADIUS, 0.6, position, color, Enum.Material.Neon)

	-- Aro oscuro alrededor del disco, para que destaque sobre la arena y el adoquín.
	local ring = HubPrimitives.flatDisc(pad, "Aro", DISC_RADIUS + 1, 0.4, position + Vector3.new(0, -0.1, 0), shade(color, 0.45), Enum.Material.SmoothPlastic)
	ring.CanCollide = false

	-- Columna de luz translúcida, más ancha que el antiguo haz fino.
	local beam = HubPrimitives.pillar(pad, "Haz", 14, 5, position + Vector3.new(0, 7.3, 0), color, Enum.Material.Neon)
	beam.Transparency = 0.78
	HubPrimitives.soft(beam)

	HubPrimitives.emitter(pad, position + Vector3.new(0, 1, 0), color, 7, 5, 2.5, 25, 0.5)

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 1.2
	light.Parent = pad

	-- MaxDistance corto: el rótulo solo aparece al acercarse (HubBuilder lo multiplica por la escala del punto de interés).
	local gui = Instance.new("BillboardGui")
	gui.Name = "Rotulo"
	gui.Size = UDim2.fromOffset(230, 48)
	gui.StudsOffset = Vector3.new(0, 9, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 40
	gui.Adornee = pad
	gui.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 34)
	label.BackgroundTransparency = 0.15
	label.Text = title
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 3
	stroke.Parent = label

	return pad
end

-- Prompt del pad. `onTrigger` recibe al jugador que lo activa.
function PadBuilder.prompt(pad: BasePart, actionText: string, objectText: string, onTrigger: (Player) -> ()): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(onTrigger)
	return prompt
end

return PadBuilder
