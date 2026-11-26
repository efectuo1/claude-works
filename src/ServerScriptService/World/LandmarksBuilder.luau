--!strict
--[[
	Zonas de servicio: tienda (este) y arena de modalidades (oeste).
	Geometría provisional y carteles. Se rehace en cada arranque. La lógica va en sus servicios.
]]

local ModeHouses = require(script.Parent.ModeHouses)
local MapLayout = require(script.Parent.MapLayout)

local LandmarksBuilder = {}

type HeightAt = (x: number, z: number) -> number

local TOLDOS = {
	Color3.fromRGB(255, 120, 180),
	Color3.fromRGB(255, 210, 60),
	Color3.fromRGB(80, 230, 255),
	Color3.fromRGB(120, 230, 120),
}
local COUNTER = Color3.fromRGB(205, 140, 80)
local ARENA_WOOD = Color3.fromRGB(170, 110, 60)
local ARENA_POST = Color3.fromRGB(110, 70, 40)
local WATER = Color3.fromRGB(120, 200, 255)

local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.Size = size
	piece.CFrame = cf
	piece.Color = color
	piece.Material = material
	piece.Parent = parent
	return piece
end

-- Disco horizontal: el cilindro se gira 90° en Z para quedar plano en el suelo.
local function disc(parent: Instance, name: string, diameter: number, thickness: number, position: Vector3, color: Color3, material: Enum.Material): Part
	local piece = box(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)), color, material)
	piece.Shape = Enum.PartType.Cylinder
	piece.CanCollide = thickness > 0.5
	return piece
end

local function sign(parent: Instance, name: string, text: string, position: Vector3)
	local anchor = box(parent, name, Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	anchor.CanCollide = false
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(300, 64)
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.3
	label.BackgroundColor3 = Color3.fromRGB(40, 30, 20)
	label.TextColor3 = Color3.fromRGB(255, 230, 150)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.Parent = gui
	gui.Parent = anchor
end

local function buildShop(folder: Instance, height: HeightAt)
	local region = MapLayout.region("shop")
	if region == nil then
		return
	end
	local origin = Vector3.new(region.center.X, height(region.center.X, region.center.Y), region.center.Y)
	local shop = Instance.new("Folder")
	shop.Name = "Tienda"
	shop.Parent = folder

	local offsets = { Vector3.new(-12, 0, 0), Vector3.new(12, 0, 0), Vector3.new(0, 0, -12), Vector3.new(0, 0, 12) }
	for index, offset in offsets do
		local base = origin + offset
		box(shop, `Mostrador_{index}`, Vector3.new(6, 3, 4), CFrame.new(base + Vector3.new(0, 1.5, 0)), COUNTER, Enum.Material.Wood)
		box(shop, `Toldo_{index}`, Vector3.new(7, 0.6, 5), CFrame.new(base + Vector3.new(0, 4, 0)), TOLDOS[index], Enum.Material.Fabric)
	end
	box(shop, "Poste", Vector3.new(1, 10, 1), CFrame.new(origin + Vector3.new(0, 5, 0)), ARENA_POST, Enum.Material.Wood)
	sign(shop, "Cartel_Tienda", "Tienda", origin + Vector3.new(0, 11, 0))
end

local function buildArena(folder: Instance, height: HeightAt)
	local region = MapLayout.region("modes")
	if region == nil then
		return
	end
	local origin = Vector3.new(region.center.X, height(region.center.X, region.center.Y), region.center.Y)
	local arena = Instance.new("Folder")
	arena.Name = "ArenaModalidades"
	arena.Parent = folder

	disc(arena, "Agua", 66, 0.4, origin + Vector3.new(0, 0.2, 0), WATER, Enum.Material.Glass)
	disc(arena, "Suelo", 52, 0.6, origin + Vector3.new(0, 0.5, 0), ARENA_WOOD, Enum.Material.Wood)
	for i = 1, 12 do
		local angle = (i - 1) / 12 * math.pi * 2
		local pos = origin + Vector3.new(math.cos(angle) * 26, 3, math.sin(angle) * 26)
		box(arena, `Pilar_{i}`, Vector3.new(1.4, 6, 1.4), CFrame.new(pos), ARENA_POST, Enum.Material.Wood)
	end
	sign(arena, "Cartel_Modalidades", "Oleadas\n(entra aquí)", origin + Vector3.new(0, 10, 0))
end

function LandmarksBuilder.build(height: HeightAt)
	local folder = workspace:FindFirstChild("Landmarks") or Instance.new("Folder")
	folder.Name = "Landmarks"
	folder.Parent = workspace
	folder:ClearAllChildren()
	buildShop(folder, height)
	buildArena(folder, height)
	ModeHouses.build(folder, height)
end

return LandmarksBuilder
