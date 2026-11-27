--!strict
--[[
	HUD con el kit Folk Stud UI. Izquierda: TIENDA, RANGO, MEJORAS e ÍNDICE. Derecha: FRUTAS,
	MODOS, INICIO y AJUSTES. RANGO usa la ventana de rebirth del kit con datos reales.
	Las secciones sin sistema muestran un aviso "Próximamente". La lógica la decide el servidor.
]]

print("[FolkHud] iniciando")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Progression = require(ReplicatedStorage.Shared.Util.Progression)
local Rewards = require(ReplicatedStorage.Shared.Util.Rewards)
local Shop = require(ReplicatedStorage.Shared.Definitions.Shop)
local Potions = require(ReplicatedStorage.Shared.Definitions.Potions)
local MarketplaceService = game:GetService("MarketplaceService")
-- Si el módulo de imágenes no está, el HUD sigue funcionando con sus iconos de respaldo.
local okAssets, UiAssets = pcall(function()
	return require(ReplicatedStorage.Shared.Definitions.UiAssets)
end)
if not okAssets then
	warn("[FolkHud] no encontré UiAssets; uso los iconos de respaldo")
	UiAssets = { get = function(_: string): string? return nil end }
end
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.helpers

local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("Remotes", 15)
local walletFx = if remotes then remotes:FindFirstChild("WalletFx") :: RemoteEvent? else nil
local rankUpRemote = if remotes then remotes:FindFirstChild("RankUp") :: RemoteEvent? else nil
local exchangeRemote = if remotes then remotes:FindFirstChild("ExchangeCurrency") :: RemoteEvent? else nil
local usePotionRemote = if remotes then remotes:FindFirstChild("UsePotion") :: RemoteEvent? else nil
local buyPotionRemote = if remotes then remotes:FindFirstChild("BuyPotion") :: RemoteEvent? else nil
local backpackRemote = if remotes then remotes:FindFirstChild("BackpackList") :: RemoteFunction? else nil
if walletFx == nil or rankUpRemote == nil then
	warn("[FolkHud] no encontré los remotos de economía: la interfaz se muestra, pero sin ganancias en vivo")
end

local SOON = "Próximamente"
local WHITE = Color3.new(1, 1, 1)

local function compact(n: number): string
	if n >= 1e6 then
		return string.format("%.1fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%dK", math.floor(n / 1e3))
	end
	return tostring(math.floor(n))
end

local function attributeNumber(name: string): number
	return tonumber(player:GetAttribute(name)) or 0
end

local function currentRank(): Rewards.RankDef
	return Rewards.rankOrDefault(tostring(player:GetAttribute("Rank") or "novato"))
end

local function setLabel(parent: Instance, name: string, value: string)
	local l = parent:FindFirstChild(name)
	if l ~= nil and l:IsA("TextLabel") then
		l.Text = value
	end
end

-- Ventana sencilla con el estilo del kit: cartel con borde negro, texto y botón.
local function buildNotice(name: string, title: string, body: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui:SetAttribute("FolkStud", "notice")
	-- el kit calcula el tamaño de cada ventana con estos dos atributos; sin ellos falla al arrancar
	gui:SetAttribute("NeedW", 560 + 64)
	gui:SetAttribute("NeedH", 300 + 90)
	gui.Parent = pg

	local root = H.new("Frame", { Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(560, 300) }, gui)
	H.new("UIScale", { Name = "Fit" }, root)
	local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	H.new("UIScale", { Name = "Pop" }, stage)

	H.shadow(stage, "Sombra", 0, 6, 560, 300, 14, 1)
	local card = H.rect(stage, "Window", 0, 0, 560, 300, 14, 1)
	H.ink(card, 4)
	H.studs(card, Vector2.new(50, 46), 0.8, 12, 1)
	H.text(stage, "Title", title, 280, 46, 46, 5)
	H.text(stage, "Body", body, 280, 150, 26, 5)
	local ok = H.button(stage, "Ok", 140, 218, 280, 60, 16, M.COLOR.lime, 5, { action = "close" })
	H.text(ok, "Label", "ENTENDIDO", 140, 30, 34, ok.ZIndex + 1)
	M.live(gui, {})
	return gui
end

local notice = buildNotice("FolkAviso", "", "")

local function showNotice(title: string, body: string)
	setLabel(notice.Root.Stage, "Title", title)
	setLabel(notice.Root.Stage, "Body", body)
	M.show(notice, true)
end

-- ---------- Ventana de rangos (ventana de rebirth del kit) ----------
local rankGui = M.rebirth(pg, {
	name = "FolkRango",
	title = "Rangos",
	icon = M.ART.rebirth,
	from = "",
	to = "",
	gainFrom = "",
	gainTo = "",
	warn = "",
	barText = "",
	barFrac = 0,
	skip = "Cerrar",
	skipSub = "",
})
rankGui.Enabled = false
local rankStage = rankGui.Root.Stage
local giftButton = rankStage:FindFirstChild("Gift")
if giftButton ~= nil then
	giftButton:Destroy() -- sin regalos todavía: no mostrar un botón que no hace nada
end
local rankLabel = rankStage:FindFirstChild("Rebirth")
if rankLabel ~= nil and rankLabel:FindFirstChild("Label") ~= nil then
	(rankLabel.Label :: TextLabel).Text = "SUBIR DE RANGO"
end

local function refreshRankWindow()
	local rank = currentRank()
	local nxt = Rewards.nextRank(rank.id)
	local level = math.max(1, math.floor(attributeNumber("Level")))

	setLabel(rankStage, "From", rank.name)
	setLabel(rankStage, "To", if nxt ~= nil then nxt.name else "MÁXIMO")
	local plateFrom = rankStage:FindFirstChild("PlateFrom")
	local plateTo = rankStage:FindFirstChild("PlateTo")
	if plateFrom ~= nil then
		setLabel(plateFrom, "Value", `Oro x{rank.goldMult}`)
	end
	if plateTo ~= nil then
		setLabel(plateTo, "Value", `Oro x{if nxt ~= nil then nxt.goldMult else rank.goldMult}`)
	end
	if nxt ~= nil then
		setLabel(rankStage, "Warn", `Coste: {compact(nxt.cost.gold)} oro · {nxt.cost.gems} gemas · nivel {nxt.minLevel}`)
		setLabel(rankStage, "BarText", `Nivel {level} / {nxt.minLevel}`)
		M.setBar(rankGui, math.clamp(level / nxt.minLevel, 0, 1))
	else
		setLabel(rankStage, "Warn", "Ya estás en el rango máximo")
		setLabel(rankStage, "BarText", "Rango máximo")
		M.setBar(rankGui, 1)
	end
end

local function openRank()
	refreshRankWindow()
	M.show(rankGui, true)
end

M.live(rankGui, {
	rebirth = function()
		if rankUpRemote ~= nil then
			rankUpRemote:FireServer()
		end
	end,
	skip = function()
		M.show(rankGui, false)
	end,
})

-- ---------- Tienda: cambio oro <-> gemas. Pases y códigos quedan como "Próximamente" hasta tener sus IDs ----------
local EXCHANGE_RATE = 200 -- igual que Economy.EXCHANGE.goldPerGem en el servidor
local EXCHANGE_ERRORS: { [string]: string } = {
	cantidad_invalida = "La cantidad no es válida",
	oro_insuficiente = "Te falta oro para ese cambio",
	gemas_insuficientes = "Te faltan gemas para ese cambio",
	direccion_invalida = "Ese cambio no existe",
	profile_not_loaded = "Tu progreso todavía se está cargando",
	payload_invalido = "La petición no es válida",
	demasiadas_peticiones = "Espera un momento y vuelve a probar",
}

local function buildShopWindow(): ScreenGui
	local W, Hh = 640, 850
	local gui = Instance.new("ScreenGui")
	gui.Name = "FolkTienda"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui:SetAttribute("FolkStud", "shop")
	gui:SetAttribute("NeedW", W + 64)
	gui:SetAttribute("NeedH", Hh + 90)
	gui.Parent = pg

	local root = H.new("Frame", { Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, Hh) }, gui)
	H.new("UIScale", { Name = "Fit" }, root)
	local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	H.new("UIScale", { Name = "Pop" }, stage)

	H.shadow(stage, "Sombra", 0, 6, W, Hh, 14, 1)
	local win = H.rect(stage, "Window", 0, 0, W, Hh, 14, 1)
	H.ink(win, 4)
	H.studs(win, Vector2.new(50, 46), 0.8, 12, 1)
	H.text(stage, "Title", "Tienda", W / 2, 0, 50, 8)
	local close = H.button(stage, "Close", W - 42, -26, 66, 70, 12, M.COLOR.red, 9, { plain = true, action = "close" })
	H.text(close, "X", "X", 33, 32, 56, 10)

	H.text(stage, "Saldo", "", W / 2, 96, 26, 5)

	-- Pestañas de sección: TODO, CAMBIO, PASES, FRUTAS
	local tabBtn: { [string]: any } = {}
	local tabW, tabGap = 118, 8
	for i, name in { "todo", "cambio", "pases", "frutas", "pociones" } do
		local x = (W - (5 * tabW + 4 * tabGap)) / 2 + (i - 1) * (tabW + tabGap)
		local b = H.button(stage, "Tab_" .. name, x, 130, tabW, 46, 12, M.COLOR.purple, 6, { action = "tab", offer = name, lip = 5 })
		tabBtn[name] = b
		H.text(b, "Label", string.upper(name), tabW / 2, 23, 22, b.ZIndex + 1)
	end

	local function exchangeCard(y: number, name: string, title: string, rate: string, pal: { Color3 }, direction: string)
		local cw = W - 60
		local card = H.rect(stage, name, 30, y, cw, 150, 16, 2)
		H.grad(card, pal[1], pal[3])
		H.ink(card, 4)
		H.text(card, "Titulo", title, cw / 2, 30, 34, 4)
		H.text(card, "Tasa", rate, cw / 2, 70, 24, 4)
		local labels = { "x1", "x10", "MÁX" }
		local offers = { "1", "10", "max" }
		local bw, gap = 150, 15
		for i, label in labels do
			local x = (cw - (3 * bw + 2 * gap)) / 2 + (i - 1) * (bw + gap)
			local b = H.button(card, "Cambio" .. offers[i], x, 96, bw, 44, 12, M.COLOR.lime, 5, { action = "exchange", offer = direction .. ":" .. offers[i] })
			H.text(b, "Label", label, bw / 2, 22, 28, b.ZIndex + 1)
		end
	end
	exchangeCard(196, "ExOro", "ORO A GEMAS", "200 oro = 1 gema", M.COLOR.gold, "goldToGems")
	exchangeCard(366, "ExGemas", "GEMAS A ORO", "1 gema = 200 oro", M.COLOR.green, "gemsToGold")

	-- Pociones: se compran con gemas y van a la mochila. Solo se ven en su pestaña.
	local potionNodes: { any } = {}
	local function potionCard(y: number, potionId: string, title: string, rate: string, pal: { Color3 })
		local def = Potions[potionId]
		local price = if def then def.gemPrice else 0
		local cw = W - 60
		local card = H.rect(stage, "Pocion_" .. potionId, 30, y, cw, 150, 16, 2)
		H.grad(card, pal[1], pal[3])
		H.ink(card, 4)
		H.text(card, "Titulo", title, cw / 2, 30, 34, 4)
		H.text(card, "Tasa", rate, cw / 2, 70, 24, 4)
		local b = H.button(card, "Comprar", (cw - 380) / 2, 96, 380, 44, 12, M.COLOR.lime, 5, { action = "buyPotion", offer = potionId })
		H.text(b, "Label", "COMPRAR · " .. price .. " gemas", 190, 22, 26, b.ZIndex + 1)
		table.insert(potionNodes, card)
	end
	potionCard(196, "xp_potion_10", "XP x2 · 10 MIN", "Multiplica tu XP mientras dura", M.COLOR.purple)
	potionCard(366, "xp_potion_15", "XP x2 · 15 MIN", "Multiplica tu XP mientras dura", M.COLOR.blue)

	local secPases = H.text(stage, "SecPases", "PASES", W / 2, 528, 30, 5)
	local paseNodes: { any } = { secPases }
	for i, item in Shop.GAMEPASSES do
		local y = 560 + (i - 1) * 62
		local row = H.rect(stage, "Pase" .. item.id, 30, y, W - 60, 52, 14, 2)
		table.insert(paseNodes, row)
		H.grad(row, M.COLOR.pink[1], M.COLOR.pink[3])
		H.ink(row, 4)
		if item.id == "doble_oro" then
			row:SetAttribute("Glint", true) -- destello dorado del kit: la mejor oferta
		end
		H.text(row, "Texto", item.title .. " · " .. item.desc, (W - 60 - 180) / 2, 26, 22, 4)
		local b = H.button(row, "Comprar", W - 60 - 170, 6, 160, 40, 12, M.COLOR.lime, 5, { action = "pass", offer = item.id })
		H.text(b, "Label", "R$ " .. item.price, 80, 20, 26, b.ZIndex + 1)
	end
	local secCodigos = H.text(stage, "SecCodigos", "CÓDIGOS", W / 2, 766, 30, 5)
	local codigoSoon = H.text(stage, "CodigosSoon", SOON, W / 2, 804, 26, 5)
	local codigoNodes: { any } = { secCodigos, codigoSoon }
	local exchangeCards: { any } = { stage:FindFirstChild("ExOro"), stage:FindFirstChild("ExGemas") }
	local frutasSoon = H.text(stage, "FrutasSoon", "Frutas y jutsus llegan en una próxima parte", W / 2, 430, 26, 5)

	local function showTab(tab: string)
		local todo = tab == "todo"
		local cambio = todo or tab == "cambio"
		local pases = todo or tab == "pases"
		for _, n in exchangeCards do n.Visible = cambio end
		for _, n in paseNodes do n.Visible = pases end
		for _, n in potionNodes do n.Visible = tab == "pociones" end
		for _, n in codigoNodes do n.Visible = todo end
		frutasSoon.Visible = tab == "frutas"
		for id, b in tabBtn do
			local label = b:FindFirstChild("Label") :: TextLabel
			label.Text = if id == tab then "> " .. string.upper(id) .. " <" else string.upper(id)
		end
	end

	M.live(gui, {
		buyPotion = function(offer: any)
			if buyPotionRemote ~= nil then
				buyPotionRemote:FireServer({ itemId = tostring(offer) })
			end
		end,
		tab = function(offer: any)
			showTab(tostring(offer))
		end,
		pass = function(offer: any)
			for _, item in Shop.GAMEPASSES do
				if item.id == offer then
					if player:GetAttribute("Pase_" .. item.id) == true then
						showNotice(item.title, "Ya lo tienes: su efecto está activo.")
					elseif item.gamePassId == 0 then
						showNotice(item.title, "Este pase todavía no está a la venta.")
					else
						MarketplaceService:PromptGamePassPurchase(player, item.gamePassId)
					end
					return
				end
			end
		end,
		exchange = function(offer: any)
			local direction, amountText = string.match(tostring(offer), "^(%a+):(%w+)$")
			if direction == nil or amountText == nil then
				return
			end
			local amount: number?
			if amountText == "max" then
				local have = if direction == "goldToGems" then math.floor(attributeNumber("Gold") / EXCHANGE_RATE) else attributeNumber("Gems")
				amount = math.floor(have)
			else
				amount = tonumber(amountText)
			end
			if amount == nil or amount < 1 then
				showNotice("Cambio", "No tienes lo suficiente para ese cambio")
				return
			end
			if exchangeRemote == nil then
				showNotice("Cambio no disponible", "Falta el servidor de cambio")
				return
			end
			exchangeRemote:FireServer({ direction = direction, amount = amount })
		end,
	})
	showTab("todo")
	return gui
end

local shopGui = buildShopWindow()

-- ---------- Raíles de botones ----------
local screens: { [string]: ScreenGui } = { FolkRango = rankGui, FolkAviso = notice }
local function addSection(name: string, title: string, body: string?)
	screens[name] = buildNotice(name, title, body or SOON)
end
screens.FolkTienda = shopGui

-- Mochila (kit): el contenido sale del servidor. El kit no se actualiza solo, así que se reconstruye
-- al cambiar el inventario, conservando si estaba abierta.
local POTION_ERRORS: { [string]: string } = {
	no_es_pocion = "Ese objeto no se puede usar",
	sin_pocion = "No te quedan pociones de ese tipo",
	gemas_insuficientes = "Te faltan gemas",
	demasiadas_peticiones = "Espera un momento y vuelve a probar",
	payload_invalido = "La petición no es válida",
	profile_not_loaded = "Tu progreso todavía se está cargando",
	stack_full = "No cabe más de ese objeto",
	item_insuficiente = "Ya no te queda ese objeto",
}

local function fetchBackpack(): { any }
	local list: { any } = {}
	if backpackRemote ~= nil then
		local remote = backpackRemote :: RemoteFunction
		local ok, result = pcall(function()
			return remote:InvokeServer()
		end)
		if ok and type(result) == "table" then
			list = result
		end
	end
	return list
end

local InventoryWindow = require(ReplicatedStorage.Ui.InventoryWindow)
local RewardsWindow = require(ReplicatedStorage.Ui.RewardsWindow)

-- Inventario: todos los objetos de la mochila por categoría. Oro y gemas no están aquí.
local function buildBackpack(): ScreenGui
	local items: { any } = {}
	for _, it in fetchBackpack() do
		table.insert(items, {
			id = it.id,
			name = it.name,
			rarity = it.rarity,
			category = it.category or "material",
			count = it.count or 1,
			desc = it.desc,
			stats = it.stats,
			use = it.use,
		})
	end
	return InventoryWindow.build(pg, {
		items = items,
		onUse = function(id: string)
			if usePotionRemote ~= nil then
				usePotionRemote:FireServer({ itemId = id })
			end
		end,
		notice = showNotice,
	})
end

local function refreshBackpack()
	local old = screens.FolkMochila
	local wasOpen = old ~= nil and old.Enabled
	local gui = buildBackpack()
	gui.Enabled = wasOpen
	screens.FolkMochila = gui
	if old ~= nil then
		old:Destroy()
	end
end
screens.FolkMochila = buildBackpack()

-- Premios: regalo diario (racha de 7 días) y premios por tiempo seguido.
if remotes ~= nil then
	screens.FolkPremios = RewardsWindow.build(pg, { remotes = remotes :: Folder, notice = showNotice })
end
screens.FolkMochila.Enabled = false
addSection("FolkMejoras", "Mejoras", "Las mejoras de frutas y jutsus llegarán en una próxima parte.\nMientras tanto, sube de rango para desbloquear más ganancias.")
addSection("FolkIndice", "Índice", "Tienda: cambia oro y gemas, y mira los pases.\nRango: sube de nivel para multiplicar tus ganancias.\nModos: oleadas en la arena.\nAjustes y frutas: pronto.")
addSection("FolkFrutas", "Frutas y jutsus", "Por ahora combates con las habilidades 1 a 4, o con los botones de abajo.\nLas frutas se añadirán más adelante.")
addSection("FolkInicio", "Inicio", "Bienvenido. Mata zombis para ganar oro y gemas.\nEntra al portal de oleadas cuando quieras un reto.\nAbre la tienda para cambiar oro por gemas.")
addSection("FolkAjustes", "Ajustes", "Los ajustes de sonido y gráficos llegarán en una próxima parte.")

local left = M.hud(pg, {
	name = "FolkHudLeft",
	buttons = {
		{ label = "TIENDA", icon = M.ART.shop, color = M.COLOR.hudShop, opens = "FolkTienda" },
		{ label = "RANGO", icon = M.ART.rebirth, color = M.COLOR.hudPurple, opens = "FolkRango" },
		{ label = "MEJORAS", icon = UiAssets.get("mejoras") or M.ART.star, color = M.COLOR.lime, opens = "FolkMejoras" },
		{ label = "ÍNDICE", icon = UiAssets.get("indice") or M.ART.star, color = M.COLOR.hudBlue, opens = "FolkIndice" },
			{ label = "MOCHILA", icon = UiAssets.get("mochila") or M.ART.star, color = M.COLOR.amber, opens = "FolkMochila" },
	},
})
local right = M.hud(pg, {
	name = "FolkHudRight",
	buttons = {
		{ label = "FRUTAS", icon = UiAssets.get("frutas") or M.ART.star, color = M.COLOR.orange, opens = "FolkFrutas" },
		{ label = "MODOS", icon = UiAssets.get("modos") or M.ART.star, color = M.COLOR.purple, opens = "FolkModos" },
		{ label = "PREMIOS", icon = M.ART.gift, color = M.COLOR.amber, opens = "FolkPremios" },
		{ label = "INICIO", icon = UiAssets.get("inicio") or M.ART.star, color = M.COLOR.pink, opens = "FolkInicio" },
		{ label = "AJUSTES", icon = UiAssets.get("ajustes") or M.ART.star, color = M.COLOR.crimson, opens = "FolkAjustes" },
	},
})
right.Root.AnchorPoint = Vector2.new(1, 0.5)
right.Root.Position = UDim2.new(1, -22, 0.5, 0)
M.hudLive(left, screens)
M.hudLive(right, screens)

-- ---------- Progreso y monedas, en una capa de diseño de 1920 x 1080 ----------
local statsGui = Instance.new("ScreenGui")
statsGui.Name = "FolkStats"
statsGui.ResetOnSpawn = false
statsGui.IgnoreGuiInset = true
statsGui.DisplayOrder = 20
statsGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
statsGui.Parent = pg

local design = H.new("Frame", { Name = "Diseno", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1920, 1080) }, statsGui)
local fit = H.new("UIScale", { Name = "Fit" }, design)
local function refit()
	local camera = workspace.CurrentCamera
	if camera ~= nil then
		local vp = camera.ViewportSize
		fit.Scale = math.min(vp.X / 1920, vp.Y / 1080)
	end
end
refit()
if workspace.CurrentCamera ~= nil then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
end

-- Progreso: arriba a la izquierda, morado con borde negro, como las tarjetas del kit.
local xpCard = H.rect(design, "Progreso", 22, 136, 330, 110, 18, 2) -- y=136: deja libre la barra de Roblox y la franja de estadísticas
H.grad(xpCard, M.COLOR.hudPurple[1], M.COLOR.hudPurple[3])
H.ink(xpCard, 4)

local levelCircle = H.rect(xpCard, "Nivel", 14, 22, 66, 66, 33, 3, M.COLOR.gold[1])
H.grad(levelCircle, M.COLOR.gold[1], M.COLOR.gold[3])
H.ink(levelCircle, 4)
H.text(levelCircle, "Label", "1", 33, 33, 40, levelCircle.ZIndex + 1)

H.text(xpCard, "Rank", "NOVATO", 96, 30, 32, 4, nil, "left")
local xpTrack = H.rect(xpCard, "Pista", 96, 56, 218, 22, 11, 4)
H.ink(xpTrack, 3)
local xpFill = H.rect(xpTrack, "Relleno", 0, 0, 0, 22, 11, 5, M.COLOR.lime[1])
H.grad(xpFill, M.COLOR.lime[1], M.COLOR.lime[3])
H.text(xpCard, "Xp", "0 / 10 XP", 96, 92, 22, 4, nil, "left")

-- Estadísticas del rango, debajo del raíl izquierdo.
local statsCard = H.rect(design, "Estadisticas", 22, 812, 330, 128, 18, 2)
H.grad(statsCard, M.COLOR.blue[1], M.COLOR.blue[3])
H.ink(statsCard, 4)
H.text(statsCard, "Luck", "Suerte +0%", 22, 30, 28, 4, nil, "left")
H.text(statsCard, "Gold", "Oro x1", 22, 66, 28, 4, nil, "left")
H.text(statsCard, "Gems", "Gemas x1", 22, 102, 28, 4, nil, "left")

-- Monedas: arriba a la derecha, ámbar con borde negro.
local waveLabel = H.text(design, "Oleada", "", 960, 214, 40, 12)
local walletCard = H.rect(design, "Monedas", 1568, 236, 330, 104, 18, 2) -- y=236: separada del botón de misión
H.grad(walletCard, M.COLOR.amber[1], M.COLOR.amber[3])
H.ink(walletCard, 4)

-- Si hay imagen para la moneda, la muestra encima de su círculo de respaldo.
local function coinImage(shape: GuiObject, key: string)
	local id = UiAssets.get(key)
	if id == nil then
		return
	end
	shape.Visible = false
	local img = Instance.new("ImageLabel")
	img.Name = `Imagen_{key}`
	img.BackgroundTransparency = 1
	img.Image = id
	img.Size = UDim2.fromOffset(shape.Size.X.Offset + 6, shape.Size.Y.Offset + 6)
	img.Position = UDim2.fromOffset(shape.Position.X.Offset - 3, shape.Position.Y.Offset - 3)
	img.ZIndex = 4
	img.Parent = walletCard
end

local goldCoin = H.rect(walletCard, "IconoOro", 16, 14, 42, 42, 21, 3, M.COLOR.gold[1])
H.grad(goldCoin, M.COLOR.gold[1], M.COLOR.gold[3])
H.ink(goldCoin, 3)
H.text(walletCard, "Oro", "0", 72, 35, 34, 4, nil, "left")

local gemCoin = H.rect(walletCard, "IconoGemas", 16, 60, 42, 42, 21, 3, M.COLOR.green[1])
H.grad(gemCoin, M.COLOR.green[1], M.COLOR.green[3])
H.ink(gemCoin, 3)
coinImage(goldCoin, "coin")
coinImage(gemCoin, "gem")
H.text(walletCard, "Gemas", "0", 72, 81, 34, 4, nil, "left")

-- Poción activa: tarjeta abajo a la izquierda con frasco, multiplicador, tiempo y barra que se vacía.
-- El servidor publica XpBoostMult, XpBoostEnd y XpBoostQueue como atributos del jugador.
local boostCard = H.rect(design, "Pocion", 22, 956, 330, 100, 18, 2)
H.grad(boostCard, M.COLOR.lime[1], M.COLOR.lime[3])
H.ink(boostCard, 4)
local boostPop = H.new("UIScale", { Name = "Pop" }, boostCard)
boostCard.Visible = false

-- frasco dibujado con formas: cuerpo redondo, cuello y tapón
local flaskBody = H.rect(boostCard, "FrascoCuerpo", 18, 44, 48, 48, 24, 5, M.COLOR.purple[1])
H.grad(flaskBody, M.COLOR.purple[1], M.COLOR.purple[3])
H.ink(flaskBody, 3)
local flaskNeck = H.rect(boostCard, "FrascoCuello", 32, 22, 20, 28, 4, 5, WHITE)
H.ink(flaskNeck, 3)
local flaskCap = H.rect(boostCard, "FrascoTapon", 29, 12, 26, 14, 5, 6, Color3.fromRGB(150, 90, 40))
H.ink(flaskCap, 3)
H.rect(flaskBody, "Brillo", 10, 8, 10, 10, 5, 6, WHITE).BackgroundTransparency = 0.35

local boostTitle = H.text(boostCard, "Titulo", "XP x2", 84, 24, 30, 5, nil, "left")
local boostTime = H.text(boostCard, "Tiempo", "0:00", 312, 24, 30, 5, nil, "right")
local boostTrack = H.rect(boostCard, "Pista", 84, 48, 228, 18, 9, 4)
H.ink(boostTrack, 3)
local boostFill = H.rect(boostTrack, "Relleno", 0, 0, 228, 18, 9, 5, M.COLOR.gold[1])
H.grad(boostFill, M.COLOR.gold[1], M.COLOR.gold[3])
H.text(boostCard, "Sub", "Poción de XP", 84, 82, 20, 5, nil, "left")
local boostQueue = H.text(boostCard, "Cola", "", 312, 82, 20, 5, nil, "right")

task.spawn(function()
	local peak = 0 -- el mayor tiempo restante visto: la barra se vacía respecto a él
	local shown = false
	while true do
		local mult = attributeNumber("XpBoostMult")
		local left = attributeNumber("XpBoostEnd") - workspace:GetServerTimeNow()
		local active = mult > 1 and left > 0
		if active then
			peak = math.max(peak, left)
			boostTitle.Text = `XP x{mult}`
			boostTime.Text = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
			boostFill.Size = UDim2.fromOffset(math.floor(math.clamp(left / peak, 0, 1) * 228), 18)
			local queued = attributeNumber("XpBoostQueue")
			boostQueue.Text = if queued > 0 then `+{queued} en cola` else ""
			if not shown then
				shown = true
				boostCard.Visible = true
				boostPop.Scale = 0.6
				TweenService:Create(boostPop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
			end
		else
			peak = 0
			if shown then
				shown = false
				boostCard.Visible = false
			end
		end
		task.wait(0.25)
	end
end)

local function setText(parent: Instance, name: string, value: string)
	setLabel(parent, name, value)
end

local function floatText(x: number, y: number, value: string, color: Color3)
	local name = "Aviso" .. tostring(math.random(1, 1e9))
	H.text(design, name, value, x, y, 46, 12, color, "left")
	local l = design:FindFirstChild(name)
	if l ~= nil and l:IsA("TextLabel") then
		-- Entra con un pequeño rebote de escala y luego sube y se desvanece.
		local pop = Instance.new("UIScale")
		pop.Scale = 0.5
		pop.Parent = l
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(l, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = UDim2.fromOffset(x, y - 60),
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(1.3, function()
			l:Destroy()
		end)
	end
end

-- Cada fila de pase muestra ACTIVO cuando el jugador ya lo tiene.
local function refreshPassLabels()
	for _, item in Shop.GAMEPASSES do
		local row = shopGui.Root.Stage:FindFirstChild("Pase" .. item.id)
		local button = if row then row:FindFirstChild("Comprar") else nil
		local label = if button then button:FindFirstChild("Label") else nil
		if label ~= nil and label:IsA("TextLabel") then
			label.Text = if player:GetAttribute("Pase_" .. item.id) == true then "ACTIVO" else "R$ " .. item.price
		end
	end
end
for _, item in Shop.GAMEPASSES do
	player:GetAttributeChangedSignal("Pase_" .. item.id):Connect(refreshPassLabels)
end
refreshPassLabels()

-- ---------- Refresco de datos ----------
local function refreshProgress()
	local level = math.max(1, math.floor(attributeNumber("Level")))
	local xp = attributeNumber("Xp")
	local floorXp = Progression.xpForLevel(level)
	local nextXp = Progression.xpForLevel(level + 1)
	local span = math.max(nextXp - floorXp, 1)
	local fraction = math.clamp((xp - floorXp) / span, 0, 1)

	setLabel(levelCircle, "Label", tostring(level))
	setText(xpCard, "Xp", `{math.floor(xp - floorXp)} / {span} XP`)
	TweenService:Create(xpFill, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = UDim2.fromOffset(math.floor(fraction * 218), 22) }):Play()
end

local function refreshStats()
	local rank = currentRank()
	setText(xpCard, "Rank", rank.name:upper())
	setText(statsCard, "Luck", `Suerte +{math.floor(rank.luck * 100)}%`)
	setText(statsCard, "Gold", `Oro x{rank.goldMult}`)
	setText(statsCard, "Gems", `Gemas x{rank.gemMult}`)
	setText(walletCard, "Oro", compact(attributeNumber("Gold")))
	setText(walletCard, "Gemas", compact(attributeNumber("Gems")))
	setLabel(shopGui.Root.Stage, "Saldo", `Tienes {math.floor(attributeNumber("Gold"))} oro · {math.floor(attributeNumber("Gems"))} gemas`)
	if rankGui.Enabled then
		refreshRankWindow()
	end
end

player:GetAttributeChangedSignal("Level"):Connect(function()
	refreshProgress()
	refreshStats()
end)
player:GetAttributeChangedSignal("Xp"):Connect(refreshProgress)
player:GetAttributeChangedSignal("Rank"):Connect(refreshStats)
player:GetAttributeChangedSignal("Gold"):Connect(refreshStats)
player:GetAttributeChangedSignal("Gems"):Connect(refreshStats)
refreshProgress()
refreshStats()

-- Respuestas del servidor: ganancias (aviso flotante) y resultado de subir de rango.
local RANK_ERRORS: { [string]: string } = {
	nivel_insuficiente = "Te falta nivel para este rango",
	oro_insuficiente = "Te falta oro para este rango",
	gemas_insuficientes = "Te faltan gemas para este rango",
	rango_maximo = "Ya estás en el rango máximo",
}

if walletFx ~= nil then
	walletFx.OnClientEvent:Connect(function(payload: any)
		if payload.kind == "grant" then
			if payload.gold > 0 then
				floatText(1568, 196, `+{payload.gold} oro`, M.COLOR.gold[1])
			end
			if payload.gems > 0 then
				floatText(1568, 276, `+{payload.gems} gemas`, M.COLOR.lime[1])
			end
		elseif payload.kind == "exchange" then
			if payload.ok then
				floatText(1568, 196, "¡Cambio hecho!", M.COLOR.lime[1])
			else
				showNotice("No se pudo cambiar", EXCHANGE_ERRORS[payload.error] or "Inténtalo de nuevo")
			end
		elseif payload.kind == "potion" then
			if payload.ok then
				floatText(1568, 236, "¡Poción activa!", M.COLOR.gold[1])
				task.spawn(refreshBackpack)
			else
				showNotice("No se pudo usar", POTION_ERRORS[payload.error] or "Inténtalo de nuevo")
			end
		elseif payload.kind == "potion_buy" then
			if payload.ok then
				floatText(1568, 236, "¡Comprado!", M.COLOR.lime[1])
				task.spawn(refreshBackpack)
			else
				showNotice("No se pudo comprar", POTION_ERRORS[payload.error] or "Inténtalo de nuevo")
			end
		elseif payload.kind == "rank" then
			if payload.ok then
				showNotice("¡Nuevo rango!", `Ahora eres {Rewards.rankOrDefault(payload.rank).name}`)
			else
				showNotice("No se pudo subir", RANK_ERRORS[payload.error] or "Inténtalo de nuevo")
			end
			refreshStats()
		end
	end)
end

-- Ventana de modalidades: una tarjeta por modalidad, con su descripción y un botón que lleva a la entrada.
-- La lista de jefes (nivel mínimo y si está bloqueado) viene del servidor al abrirla y al subir de nivel.
local goToModeRemote = if remotes then remotes:FindFirstChild("GoToMode") :: RemoteEvent? else nil
local bossList = if remotes then remotes:FindFirstChild("BossList") :: RemoteFunction? else nil

local function buildModesWindow(): ScreenGui
	local W, Hh = 880, 640
	local gui = Instance.new("ScreenGui")
	gui.Name = "FolkModos"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui:SetAttribute("FolkStud", "modes")
	gui:SetAttribute("NeedW", W + 64)
	gui:SetAttribute("NeedH", Hh + 90)
	gui.Parent = pg

	local root = H.new("Frame", { Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(W, Hh) }, gui)
	H.new("UIScale", { Name = "Fit" }, root)
	local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)
	H.new("UIScale", { Name = "Pop" }, stage)

	H.shadow(stage, "Sombra", 0, 6, W, Hh, 14, 1)
	local win = H.rect(stage, "Window", 0, 0, W, Hh, 14, 1)
	H.ink(win, 4)
	H.studs(win, Vector2.new(50, 46), 0.8, 12, 1)
	H.text(stage, "Title", "Modalidades", W / 2, 0, 50, 8)
	local close = H.button(stage, "Close", W - 42, -26, 66, 70, 12, M.COLOR.red, 9, { plain = true, action = "close" })
	H.text(close, "X", "X", 33, 32, 56, 10)

	local cardW = (W - 90) / 2
	local function modeCard(id: string, x: number, pal: { Color3 }, heading: string, body: string, offer: string): TextLabel
		local card = H.rect(stage, id, x, 110, cardW, 470, 16, 2)
		H.grad(card, pal[1], pal[3])
		H.ink(card, 4)
		H.text(card, "Titulo", heading, cardW / 2, 46, 44, 5)
		local text = H.text(card, "Body", body, cardW / 2, 230, 22, 5)
		local btn = H.button(card, "Ir", (cardW - 320) / 2, 390, 320, 60, 16, M.COLOR.lime, 5, { action = "go", offer = offer })
		H.text(btn, "Label", "IR A LA ENTRADA", 160, 30, 30, btn.ZIndex + 1)
		return text :: TextLabel
	end

	local oleadasBody = table.concat({
		"20 oleadas contra mobs que crecen cada ronda.",
		"",
		"Llegas a la arena y eliges dificultad",
		"en los pads verdes del lobby.",
		"",
		"Hasta 4 jugadores · sin requisito",
	}, "\n")
	modeCard("Oleadas", 30, M.COLOR.lime, "OLEADAS", oleadasBody, "wave")
	modeCard("Jefes", 60 + cardW, M.COLOR.red, "JEFES", "Cargando jefes...", "boss")

	M.live(gui, {
		go = function(offer: any)
			if goToModeRemote ~= nil then
				goToModeRemote:FireServer({ mode = tostring(offer) })
			end
		end,
	})
	return gui
end

local modesGui = buildModesWindow()
screens.FolkModos = modesGui
local refreshModesWindow: () -> ()
refreshModesWindow = function()
	local lines = { "Entrada: pads rojos en la sala de jefes.", "Hasta 4 jugadores.", "" }
	local okList, list = false, nil
	if bossList ~= nil then
		local remote = bossList :: RemoteFunction
		okList, list = pcall(function()
			return remote:InvokeServer()
		end)
	end
	if okList and type(list) == "table" and #list > 0 then
		for _, boss in list do
			local state = if boss.locked then `nivel {boss.minLevel} · bloqueado` else "disponible"
			table.insert(lines, `{boss.name}: {state}`)
		end
	else
		table.insert(lines, "No hay jefes disponibles ahora.")
	end
	table.insert(lines, "")
	table.insert(lines, `Tu nivel: {attributeNumber("Level")}`)
	local jefes = modesGui:FindFirstChild("Jefes", true)
	local body = if jefes then jefes:FindFirstChild("Body") else nil
	if body ~= nil and body:IsA("TextLabel") then
		body.Text = table.concat(lines, "\n")
	end
end
modesGui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if modesGui.Enabled then
		task.spawn(refreshModesWindow)
	end
end)
player:GetAttributeChangedSignal("Level"):Connect(function()
	task.spawn(refreshModesWindow)
end)
task.spawn(refreshModesWindow)

-- Oleadas y jefes comparten el canal WaveFx. Los mensajes de jefe llevan el campo "boss".
local WAVE_ERRORS: { [string]: string } = {
	ya_estas_dentro = "Ya estás dentro de la arena",
	arena_llena = "La arena está llena (4 jugadores)",
	faltan_plantillas = "La arena todavía no está lista",
	jefe_desconocido = "Ese jefe no existe",
	dificultad_invalida = "Esa dificultad no existe",
	nivel_insuficiente = "Te falta nivel para este jefe",
	otro_jefe_en_curso = "Ya hay otro jefe en curso",
	partida_llena = "La sala está llena (4 jugadores)",
	en_partida = "Sal de la partida actual antes de ir a otra modalidad",
}
local waveFx = if remotes then remotes:FindFirstChild("WaveFx") :: RemoteEvent? else nil
-- Marcador de la partida: oleada, si es de jefe y cuántos mobs quedan vivos.
local waveState = { wave = 0, total = 20, boss = false, alive = nil :: number? }
local function renderWave()
	if waveState.wave == 0 then
		waveLabel.Text = ""
		return
	end
	local text = `Oleada {waveState.wave} / {waveState.total}`
	if waveState.boss then
		text ..= "  ·  JEFE"
	end
	if waveState.alive ~= nil then
		text ..= `  ·  Quedan {waveState.alive}`
	end
	waveLabel.Text = text
end
local function clearWave()
	waveState.wave = 0
	waveState.alive = nil
	renderWave()
end

if waveFx ~= nil then
	waveFx.OnClientEvent:Connect(function(payload: any)
		if payload.kind == "wave" then
			waveState.wave = payload.wave
			waveState.total = payload.total
			waveState.boss = payload.boss == true
			renderWave()
		elseif payload.kind == "alive" then
			waveState.alive = payload.alive
			renderWave()
		elseif payload.kind == "end" and payload.boss ~= nil then
			-- Fin de una sala de jefes.
			clearWave()
			if payload.result == "victoria" then
				showNotice("¡Jefe derrotado!", "Recompensa de jefe entregada.")
			elseif payload.result == "derrota" then
				showNotice("Derrota", "Nadie quedó en la sala. El jefe sigue vivo.")
			elseif payload.result == "salida" then
				showNotice("Has salido", "Vuelves a la entrada de jefes.")
			else
				showNotice("Partida cancelada", "Hubo un problema con la sala de jefes.")
			end
			task.spawn(refreshModesWindow)
		elseif payload.kind == "end" then
			clearWave()
			if payload.result == "victoria" then
				showNotice("¡Oleadas superadas!", "Has superado las 20 oleadas.")
			elseif payload.result == "derrota" then
				showNotice("Derrota", `No queda nadie en la arena. Llegaste a la oleada {payload.wave}.`)
			elseif payload.result == "salida" then
				showNotice("Has salido", "Vuelves a la plaza.")
			else
				showNotice("Partida cancelada", "Hubo un problema con las oleadas.")
			end
		elseif payload.kind == "wave_error" then
			showNotice("No se pudo entrar", WAVE_ERRORS[payload.error] or "Inténtalo de nuevo")
		end
	end)
end


print("[FolkHud] lista")
