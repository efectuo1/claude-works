--!strict
--[[
	Pads visibles de entrada y salida: disco de neón, haz de luz, rótulo y ProximityPrompt.
	El prompt no exige línea de visión y se activa desde poca distancia, así que un pilar o el suelo
	no lo tapan. El disco se puede pisar: el jugador también puede entrar caminando sobre él.
]]

local PadBuilder = {}

local function flatDisc(parent: Instance, name: string, radius: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material): Part
	local disc = Instance.new("Part")
	disc.Name = name
	disc.Shape = Enum.PartType.Cylinder
	disc.Size = Vector3.new(thickness, radius * 2, radius * 2)
	disc.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	disc.Anchored = true
	disc.Color = color
	disc.Material = material
	disc.TopSurface = Enum.SurfaceType.Smooth
	disc.BottomSurface = Enum.SurfaceType.Smooth
	disc.Parent = parent
	return disc
end

-- Crea el pad. `position` es el centro del disco; el disco queda apoyado en el suelo o plataforma.
function PadBuilder.build(parent: Instance, name: string, position: Vector3, color: Color3, title: string): Part
	local pad = flatDisc(parent, name, 3.5, 0.6, position, color, Enum.Material.Neon)

	local beam = Instance.new("Part")
	beam.Name = "Haz"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Size = Vector3.new(0.5, 10, 0.5)
	beam.Position = position + Vector3.new(0, 5.3, 0)
	beam.Color = color
	beam.Material = Enum.Material.Neon
	beam.Transparency = 0.5
	beam.Parent = pad

	local gui = Instance.new("BillboardGui")
	gui.Name = "Rotulo"
	gui.Size = UDim2.fromOffset(220, 46)
	gui.StudsOffset = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Adornee = pad
	gui.Parent = pad

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	label.BackgroundTransparency = 0.25
	label.Text = title
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.3, 0)
	corner.Parent = label

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
