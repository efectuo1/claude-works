--!strict
-- Casas del hub, una por modalidad. Las activas llevan al jugador al portal de su modalidad.
-- La casa "En espera" no tiene acción: solo muestra "Próximamente".
-- Son piezas provisionales: el arte definitivo se pone en Studio.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local MapLayout = require(ServerScriptService.World.MapLayout)

type HeightAt = (number, number) -> number

local WOOD = Color3.fromRGB(150, 98, 52)
local ROOF = Color3.fromRGB(176, 40, 40)
local DOOR = Color3.fromRGB(70, 44, 24)

-- Posiciones de las casas, alrededor del punto de aparición del hub.
local HOUSES = {
	{ id = "Oleadas", x = -40, z = -24, active = true },
	{ id = "Jefes", x = 40, z = -24, active = true },
	{ id = "EnEspera", x = 0, z = -60, active = false },
}

local ModeHouses = {}

local function part(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.Position = position
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(parent: Instance, name: string, text: string, position: Vector3)
	local anchor = part(parent, name .. "_Ancla", Vector3.new(0.4, 0.4, 0.4), position, WOOD, Enum.Material.Wood)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(220, 60)
	gui.AlwaysOnTop = false
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Parent = gui
end

local function build(parent: Instance, height: HeightAt, destinations: { [string]: Vector3 })
	for _, house in HOUSES do
		local y = height(house.x, house.z)
		local origin = Vector3.new(house.x, y, house.z)
		local model = Instance.new("Model")
		model.Name = "Casa_" .. house.id
		model.Parent = parent

		part(model, "Cuerpo", Vector3.new(12, 8, 12), origin + Vector3.new(0, 4, 0), WOOD, Enum.Material.Wood)
		part(model, "Tejado", Vector3.new(14, 2, 14), origin + Vector3.new(0, 9, 0), ROOF, Enum.Material.Slate)
		local door = part(model, "Puerta", Vector3.new(3, 5, 0.4), origin + Vector3.new(0, 2.5, 6.2), DOOR, Enum.Material.Wood)

		sign(model, "Cartel", house.active and house.id or house.id .. "\nPróximamente", origin + Vector3.new(0, 13, 0))

		if house.active then
			local destination = destinations[house.id]
			if destination ~= nil then
				local prompt = Instance.new("ProximityPrompt")
				prompt.ActionText = "Ir a " .. house.id
				prompt.ObjectText = "Casa"
				prompt.HoldDuration = 0.3
				prompt.MaxActivationDistance = 12
				prompt.Parent = door
				prompt.Triggered:Connect(function(player: Player)
					local character = player.Character
					if character ~= nil then
						character:PivotTo(CFrame.new(destination + Vector3.new(0, 3, 0)))
					end
				end)
			end
		end
	end
end

-- Destinos: a la altura de los portales de cada modalidad.
-- Oleadas: junto a los portales de la arena. Jefes: junto a los portales de la sala de jefes.
function ModeHouses.build(parent: Instance, height: HeightAt)
	local modes = MapLayout.region("modes")
	local arenaY = if modes then height(modes.center.X, modes.center.Y) + 4 else 4
	local arenaCenter = if modes then Vector3.new(modes.center.X, arenaY, modes.center.Y) else Vector3.new(-190, 4, 0)
	local destinations = {
		Oleadas = arenaCenter + Vector3.new(0, 0, 30),
		Jefes = Vector3.new(0, 6, 180), -- debe coincidir con portalPosition de Bootstrap
	}
	build(parent, height, destinations)
end

return ModeHouses
