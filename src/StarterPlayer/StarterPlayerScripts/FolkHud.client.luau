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
	local W, Hh = 640, 790
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
	exchangeCard(130, "ExOro", "ORO A GEMAS", "200 oro = 1 gema", M.COLOR.gold, "goldToGems")
	exchangeCard(300, "ExGemas", "GEMAS A ORO", "1 gema = 200 oro", M.COLOR.green, "gemsToGold")

	H.text(stage, "SecPases", "PASES", W / 2, 468, 30, 5)
	for i, item in Shop.GAMEPASSES do
		local y = 500 + (i - 1) * 62
		local row = H.rect(stage, "Pase" .. item.id, 30, y, W - 60, 52, 14, 2)
		H.grad(row, M.COLOR.pink[1], M.COLOR.pink[3])
		H.ink(row, 4)
		if item.id == "doble_oro" then
			row:SetAttribute("Glint", true) -- destello dorado del kit: la mejor oferta
		end
		H.text(row, "Texto", item.title .. " · " .. item.desc, (W - 60 - 180) / 2, 26, 22, 4)
		local b = H.button(row, "Comprar", W - 60 - 170, 6, 160, 40, 12, M.COLOR.lime, 5, { action = "pass", offer = item.id })
		H.text(b, "Label", "R$ " .. item.price, 80, 20, 26, b.ZIndex + 1)
	end
	H.text(stage, "SecCodigos", "CÓDIGOS", W / 2, 706, 30, 5)
	H.text(stage, "CodigosSoon", SOON, W / 2, 744, 26, 5)

	M.live(gui, {
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
	return gui
end

local shopGui = buildShopWindow()

-- ---------- Raíles de botones ----------
local screens: { [string]: ScreenGui } = { FolkRango = rankGui, FolkAviso = notice }
local function addSection(name: string, title: string, body: string?)
	screens[name] = buildNotice(name, title, body or SOON)
end
screens.FolkTienda = shopGui
addSection("FolkMejoras", "Mejoras")
addSection("FolkIndice", "Índice")
addSection("FolkFrutas", "Frutas y jutsus")
addSection("FolkModos", "Modalidades", "Oleadas: 20 oleadas y un jefe final. Entra por el portal de la arena.")
addSection("FolkInicio", "Inicio")
addSection("FolkAjustes", "Ajustes")

local left = M.hud(pg, {
	name = "FolkHudLeft",
	buttons = {
		{ label = "TIENDA", icon = M.ART.shop, color = M.COLOR.hudShop, opens = "FolkTienda" },
		{ label = "RANGO", icon = M.ART.rebirth, color = M.COLOR.hudPurple, opens = "FolkRango" },
		{ label = "MEJORAS", icon = UiAssets.get("mejoras") or M.ART.star, color = M.COLOR.lime, opens = "FolkMejoras" },
		{ label = "ÍNDICE", icon = UiAssets.get("indice") or M.ART.star, color = M.COLOR.hudBlue, opens = "FolkIndice" },
	},
})
local right = M.hud(pg, {
	name = "FolkHudRight",
	buttons = {
		{ label = "FRUTAS", icon = UiAssets.get("frutas") or M.ART.star, color = M.COLOR.orange, opens = "FolkFrutas" },
		{ label = "MODOS", icon = UiAssets.get("modos") or M.ART.star, color = M.COLOR.purple, opens = "FolkModos" },
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

-- Modalidad de oleadas: marcador y avisos de la partida.
local WAVE_ERRORS: { [string]: string } = {
	ya_estas_dentro = "Ya estás dentro de la arena",
	arena_llena = "La arena está llena (4 jugadores)",
	faltan_plantillas = "La arena todavía no está lista",
}
local waveFx = if remotes then remotes:FindFirstChild("WaveFx") :: RemoteEvent? else nil
if waveFx ~= nil then
	waveFx.OnClientEvent:Connect(function(payload: any)
		if payload.kind == "wave" then
			waveLabel.Text = `Oleada {payload.wave} / {payload.total}` .. (if payload.boss then "  ·  JEFE" else "")
		elseif payload.kind == "end" then
			waveLabel.Text = ""
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
