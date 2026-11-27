--!strict
--[[
	Inventario: todo lo que se guarda en la mochila (pociones, llaves, frutas, accesorios, materiales).
	Oro y gemas NO están aquí: son monedas de la cartera y se ven en la barra superior.
	Cada categoría tiene su color y su emblema dibujado con formas (sin depender de iconos).
	Las tarjetas se redibujan al cambiar de pestaña o de selección; sus clics se conectan a mano
	porque M.live solo conecta los botones que ya existían cuando se llamó.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.helpers

local InventoryWindow = {}

export type Item = { id: string, name: string, rarity: string, category: string, count: number, desc: string?, stats: { { string } }?, use: string? }
export type Options = {
	items: { Item },
	onUse: (itemId: string) -> (),
	notice: (title: string, body: string) -> (),
}

local W, HEIGHT = 1000, 660
local WOOD = Color3.fromRGB(150, 90, 50)
local BLACK = Color3.new(0, 0, 0)
local WHITE = Color3.new(1, 1, 1)

local CATEGORIES = {
	{ id = "pocion", name = "POCIONES", pal = M.COLOR.purple },
	{ id = "llave", name = "LLAVES", pal = M.COLOR.gold },
	{ id = "fruta", name = "FRUTAS", pal = M.COLOR.lime },
	{ id = "accesorio", name = "ACCESORIOS", pal = M.COLOR.pink },
	{ id = "material", name = "MATERIALES", pal = M.COLOR.blue },
}
local PAL_OF: { [string]: { Color3 } } = {}
for _, c in CATEGORIES do
	PAL_OF[c.id] = c.pal
end

local RARITY_NAME: { [string]: string } = { Common = "COMÚN", Rare = "RARO", Epic = "ÉPICO", Legendary = "LEGENDARIO" }
local RARITY_COLOR: { [string]: Color3 } = {
	Common = Color3.fromRGB(255, 255, 255),
	Rare = Color3.fromRGB(47, 208, 255),
	Epic = Color3.fromRGB(230, 90, 255),
	Legendary = Color3.fromRGB(255, 230, 0),
}

-- Forma sencilla centrada en (cx, cy) dentro de su padre. Se usa para dibujar emblemas.
local function shape(parent: Instance, cx: number, cy: number, w: number, h: number, col: Color3, radius: number, rot: number?): Frame
	local f = H.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy),
		Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = col,
		Rotation = rot or 0,
		ZIndex = parent.ZIndex + 1,
	}, parent) :: Frame
	H.new("UICorner", { CornerRadius = UDim.new(0, radius) }, f)
	return f
end

-- Emblema por categoría: cada una tiene una silueta propia.
local function emblem(parent: Instance, category: string, size: number)
	local root = H.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(size, size), ZIndex = 6 }, parent)
	local pal = PAL_OF[category] or M.COLOR.blue
	local s = size
	if category == "pocion" then
		local body = shape(root, s / 2, s * 0.62, s * 0.6, s * 0.6, pal[1], s * 0.3)
		H.ink(body, 4)
		local neck = shape(root, s / 2, s * 0.28, s * 0.24, s * 0.3, pal[2], 4)
		H.ink(neck, 3)
		local cork = shape(root, s / 2, s * 0.1, s * 0.3, s * 0.12, WOOD, 4)
		H.ink(cork, 3)
		shape(body, s * 0.36, s * 0.42, s * 0.12, s * 0.22, WHITE, 6)
	elseif category == "llave" then
		local ring = shape(root, s * 0.3, s * 0.5, s * 0.42, s * 0.42, pal[1], s * 0.21)
		H.ink(ring, 4)
		shape(ring, s * 0.5, s * 0.5, s * 0.16, s * 0.16, BLACK, s * 0.08)
		local shaft = shape(root, s * 0.64, s * 0.5, s * 0.5, s * 0.12, pal[1], 4)
		H.ink(shaft, 3)
		local tooth1 = shape(root, s * 0.8, s * 0.6, s * 0.1, s * 0.2, pal[1], 3)
		H.ink(tooth1, 3)
		local tooth2 = shape(root, s * 0.92, s * 0.6, s * 0.1, s * 0.14, pal[1], 3)
		H.ink(tooth2, 3)
	elseif category == "fruta" then
		local body = shape(root, s / 2, s * 0.58, s * 0.72, s * 0.72, pal[1], s * 0.36)
		H.ink(body, 4)
		local stem = shape(root, s / 2, s * 0.14, s * 0.07, s * 0.2, Color3.fromRGB(120, 70, 30), 3)
		H.ink(stem, 2)
		local leaf = shape(root, s * 0.64, s * 0.15, s * 0.32, s * 0.16, pal[2], s * 0.08, -20)
		H.ink(leaf, 3)
		shape(body, s * 0.36, s * 0.4, s * 0.14, s * 0.2, WHITE, 6)
	elseif category == "accesorio" then
		local ring = shape(root, s / 2, s * 0.58, s * 0.66, s * 0.66, pal[1], s * 0.33)
		ring.BackgroundTransparency = 1
		H.ink(ring, 9, pal[1])
		local gem = shape(root, s / 2, s * 0.12, s * 0.3, s * 0.3, pal[2], 4, 45)
		H.ink(gem, 3)
	else -- material
		local diamond = shape(root, s / 2, s / 2, s * 0.58, s * 0.58, pal[1], 6, 45)
		H.ink(diamond, 4)
		shape(diamond, s * 0.42, s * 0.42, s * 0.16, s * 0.16, WHITE, 6, 45)
	end
	return root
end

function InventoryWindow.build(pg: PlayerGui, options: Options): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FolkMochila"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui:SetAttribute("FolkStud", "inventory")
	gui:SetAttribute("NeedW", W + 64)
	gui:SetAttribute("NeedH", HEIGHT + 90)
	gui.Parent = pg

	local root = H.new("Frame", { Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, HEIGHT) }, gui)
	H.new("UIScale", { Name = "Fit" }, root)
	local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	H.new("UIScale", { Name = "Pop" }, stage)

	H.shadow(stage, "Sombra", 0, 6, W, HEIGHT, 14, 1)
	local win = H.rect(stage, "Window", 0, 0, W, HEIGHT, 14, 1)
	H.ink(win, 4)
	H.studs(win, Vector2.new(50, 46), 0.8, 12, 1)
	H.text(stage, "Title", "INVENTARIO", W / 2, 44, 50, 8)
	H.text(stage, "Sub", "Oro y gemas van aparte, arriba a la derecha", W / 2, 96, 22, 5)
	local close = H.button(stage, "Close", W - 42, -26, 66, 70, 12, M.COLOR.red, 9, { plain = true, action = "close" })
	H.text(close, "X", "X", 33, 32, 56, 10)

	-- Pestañas por categoría: cada una con su color.
	local selectedCategory = "pocion"
	local selectedId: string? = nil
	local tabs: { [string]: GuiObject } = {}
	local tabW, tabGap = 180, 10
	local startX = (W - (#CATEGORIES * tabW + (#CATEGORIES - 1) * tabGap)) / 2
	for index, category in CATEGORIES do
		local x = startX + (index - 1) * (tabW + tabGap)
		local b = H.button(stage, "Tab_" .. category.id, x, 124, tabW, 52, 14, category.pal, 6, { action = "tab", offer = category.id, lip = 5 })
		tabs[category.id] = b
		H.text(b, "Label", category.name, tabW / 2, 23, 22, b.ZIndex + 1)
	end

	-- Panel de la cuadrícula (izquierda) y panel de detalle (derecha).
	local panel = H.rect(stage, "Panel", 30, 196, 620, 440, 18, 2, Color3.fromRGB(40, 20, 70))
	H.ink(panel, 4)
	local grid = H.new("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.fromOffset(592, 412),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ZIndex = 3,
	}, panel) :: ScrollingFrame
	H.new("UIGridLayout", { CellSize = UDim2.fromOffset(140, 150), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
	H.new("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingTop = UDim.new(0, 6) }, grid)

	local detail = H.rect(stage, "Detalle", 670, 196, 300, 440, 18, 2, Color3.fromRGB(40, 20, 70))
	H.ink(detail, 4)

	local function itemsOf(category: string): { Item }
		local list: { Item } = {}
		for _, item in options.items do
			if item.category == category then
				table.insert(list, item)
			end
		end
		return list
	end

	local function findItem(id: string?): Item?
		for _, item in options.items do
			if item.id == id then
				return item
			end
		end
		return nil
	end

	local renderDetail: () -> ()
	local renderGrid: () -> ()

	local function select(id: string)
		selectedId = id
		renderGrid()
		renderDetail()
	end

	-- Tarjeta de un objeto: emblema, nombre, rareza y cantidad. El borde blanco marca la selección.
	local function card(item: Item, order: number)
		local pal = PAL_OF[item.category] or M.COLOR.blue
		local isSelected = item.id == selectedId
		local face = H.new("TextButton", {
			Name = "Item_" .. item.id,
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = pal[1],
			Size = UDim2.fromOffset(140, 150),
			LayoutOrder = order,
			ZIndex = 4,
		}, grid)
		H.new("UICorner", { CornerRadius = UDim.new(0, 14) }, face)
		H.grad(face, pal[1], pal[2])
		H.ink(face, if isSelected then 6 else 3, if isSelected then WHITE else BLACK)
		emblem(face, item.category, 80).Position = UDim2.fromOffset(30, 14)
		H.text(face, "Nombre", item.name, 70, 110, 17, 7)
		H.text(face, "Rareza", RARITY_NAME[item.rarity] or item.rarity, 70, 132, 15, 7, RARITY_COLOR[item.rarity] or WHITE)
		local badge = H.rect(face, "Badge", 94, 6, 40, 24, 12, 8, BLACK)
		H.text(badge, "Cantidad", `x{item.count}`, 20, 12, 16, 9)
		face.MouseButton1Click:Connect(function()
			select(item.id)
		end)
		return face
	end

	renderGrid = function()
		for _, child in grid:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		local list = itemsOf(selectedCategory)
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
		for index, item in list do
			card(item, index)
		end
		if #list == 0 then
			local empty = H.text(panel, "Vacio", "No tienes objetos de esta categoría todavía", 310, 220, 22, 6)
			empty.Name = "Vacio"
		else
			local old = panel:FindFirstChild("Vacio")
			if old then
				old:Destroy()
			end
		end
	end

	-- Panel de detalle: emblema grande, datos y botón de uso.
	renderDetail = function()
		for _, child in detail:GetChildren() do
			if child.Name ~= "UICorner" and child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local item = findItem(selectedId)
		local pal = PAL_OF[selectedCategory] or M.COLOR.blue
		if item == nil then
			H.text(detail, "Ayuda", "Elige un objeto para verlo aquí", 150, 210, 22, 6)
			return
		end
		emblem(detail, item.category, 130).Position = UDim2.fromOffset(85, 30)
		local nameLabel = H.text(detail, "Nombre", item.name, 150, 200, 28, 6)
		nameLabel.Name = "Nombre"
		H.text(detail, "Rareza", RARITY_NAME[item.rarity] or item.rarity, 150, 234, 22, 6, RARITY_COLOR[item.rarity] or WHITE)
		local desc = H.new("TextLabel", {
			Name = "Descripcion",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(24, 262),
			Size = UDim2.fromOffset(252, 90),
			TextWrapped = true,
			TextScaled = false,
			TextSize = 20,
			TextColor3 = WHITE,
			Text = item.desc or "",
			ZIndex = 6,
		}, detail)
		H.new("UIStroke", { Thickness = 3, Color = BLACK }, desc)
		H.text(detail, "Cantidad", `Tienes: {item.count}`, 150, 366, 22, 6)
		local use = H.button(detail, "Usar", 40, 384, 220, 46, 14, pal, 6, { action = "use", offer = item.id, lip = 4 })
		H.text(use, "Label", if selectedCategory == "pocion" then "USAR" else "SIN USO TODAVÍA", 110, 23, 22, use.ZIndex + 1)
	end

	M.live(gui, {
		tab = function(offer: any)
			selectedCategory = tostring(offer)
			for id, b in tabs do
				local stroke = b:FindFirstChildOfClass("UIStroke")
				local active = id == selectedCategory
				if stroke then
					stroke.Color = if active then WHITE else BLACK
					stroke.Thickness = if active then 5 else 4
				end
			end
			-- Al cambiar de pestaña se selecciona el primer objeto de la categoría, si lo hay.
			local list = itemsOf(selectedCategory)
			selectedId = if #list > 0 then list[1].id else nil
			renderGrid()
			renderDetail()
		end,
		use = function(offer: any)
			local id = if type(offer) == "string" then offer else selectedId
			if id == nil then
				return
			end
			if selectedCategory == "pocion" then
				options.onUse(id)
			else
				options.notice("Inventario", "Este objeto todavía no tiene uso. Llegará con sus sistemas.")
			end
		end,
	})

	-- Estado inicial: primera pestaña y primer objeto.
	local firstList = itemsOf(selectedCategory)
	selectedId = if #firstList > 0 then firstList[1].id else nil
	renderGrid()
	renderDetail()
	return gui
end

return InventoryWindow
