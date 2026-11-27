--!strict
--[[
	Ventana de premios con dos pestañas:
	- DIARIO: racha de 7 días; cada día entras y reclamas el premio de hoy.
	- TIEMPO: hitos de minutos seguidos en la sesión; más tiempo, mejor premio.
	El estado sale del servidor (RewardsState). El cliente solo lo dibuja: el servidor decide qué se entrega.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.helpers
local DailyReward = require(ReplicatedStorage.Shared.Util.DailyReward)
local PlaytimeRewards = require(ReplicatedStorage.Shared.Util.PlaytimeRewards)
local Items = require(ReplicatedStorage.Shared.Definitions.Items)
local Label = require(ReplicatedStorage.Ui.Label)

local RewardsWindow = {}

export type Options = {
	remotes: Folder,
	notice: (title: string, body: string) -> (),
}

type State = { streak: number, nextStreak: number, claimedToday: boolean, cycleDay: number, elapsed: number, claimed: { number } }

local W, HEIGHT = 1000, 660
local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local DAY_PALS = { M.COLOR.lime, M.COLOR.blue, M.COLOR.purple, M.COLOR.amber, M.COLOR.pink, M.COLOR.orange, M.COLOR.red }
local TIME_PAL = M.COLOR.hudBlue

local ERRORS: { [string]: string } = {
	ya_reclamado_hoy = "Ya reclamaste el regalo de hoy. Vuelve mañana.",
	aun_no_disponible = "Todavía no has llegado a ese tiempo.",
	ya_reclamado = "Ese premio ya lo reclamaste en esta sesión.",
	inventario_lleno = "No cabe en el inventario ahora mismo.",
	demasiadas_peticiones = "Espera un momento antes de volver a pulsar.",
	perfil_no_cargado = "Tu perfil todavía se está cargando.",
}

-- Texto de un premio en una línea: "300 ORO · 2 GEMAS · Llave Dorada x1".
local function describe(reward: { gold: number?, gems: number?, itemId: string?, quantity: number? }): string
	local parts = {}
	if reward.gold ~= nil then
		table.insert(parts, `{reward.gold} ORO`)
	end
	if reward.gems ~= nil then
		table.insert(parts, `{reward.gems} GEMAS`)
	end
	if reward.itemId ~= nil then
		local item = Items[reward.itemId]
		local name = if item then item.displayName else reward.itemId
		table.insert(parts, `{name} x{reward.quantity or 1}`)
	end
	return table.concat(parts, " · ")
end

local function invoke(remotes: Folder, name: string, arg: any?): any?
	local remote = remotes:FindFirstChild(name)
	if remote == nil or not remote:IsA("RemoteFunction") then
		return nil
	end
	local ok, result = pcall(function()
		return remote:InvokeServer(arg)
	end)
	if ok then
		return result
	end
	return nil
end

function RewardsWindow.build(pg: PlayerGui, options: Options): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "FolkPremios"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui:SetAttribute("FolkStud", "rewards")
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
	H.text(stage, "Title", "PREMIOS", W / 2, 44, 50, 8, M.COLOR.amber[1])
	H.text(stage, "Sub", "Entra cada día y juega más tiempo seguido", W / 2, 96, 22, 5)
	local close = H.button(stage, "Close", W - 42, -26, 66, 70, 12, M.COLOR.red, 9, { plain = true, action = "close" })
	H.text(close, "X", "X", 33, 32, 56, 10)

	-- Pestañas: DIARIO y TIEMPO.
	local tabs: { [string]: GuiObject } = {}
	local panes: { [string]: Frame } = {}
	local current = "diario"
	for index, info in { { id = "diario", name = "DIARIO", pal = M.COLOR.amber }, { id = "tiempo", name = "TIEMPO", pal = TIME_PAL } } do
		local x = 230 + (index - 1) * 270
		local b = H.button(stage, "Tab_" .. info.id, x, 124, 240, 52, 14, info.pal, 6, { action = "tab", offer = info.id, lip = 5 })
		H.text(b, "Label", info.name, 120, 23, 26, b.ZIndex + 1)
		tabs[info.id] = b
		local pane = H.new("Frame", { Name = "Pane_" .. info.id, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 2, Visible = index == 1 }, stage) :: Frame
		panes[info.id] = pane
	end

	local daily = panes.diario
	local timePane = panes.tiempo
	local message = H.text(stage, "Mensaje", "", W / 2, HEIGHT - 26, 22, 7, WHITE)
	local timeInfo = H.text(timePane, "Sesion", "", W / 2, 200, 30, 6, WHITE)

	local state: State? = nil
	local fetchedAt = os.clock()
	local refresh: () -> ()

	local function flash(text: string)
		message.Text = text
	end

	local function claimDaily()
		local result = invoke(options.remotes, "ClaimDaily")
		if type(result) == "table" and result.ok then
			flash(`Racha: {result.streak} días. Premio recibido.`)
		elseif type(result) == "table" then
			flash(ERRORS[result.error] or "No se pudo reclamar.")
		end
		refresh()
	end

	local function claimTime(index: number)
		local result = invoke(options.remotes, "ClaimPlaytime", index)
		if type(result) == "table" and result.ok then
			flash("Premio de tiempo recibido.")
		elseif type(result) == "table" then
			flash(ERRORS[result.error] or "No se pudo reclamar.")
		end
		refresh()
	end

	-- Dibuja el pane de DIARIO: 7 días, el de hoy resaltado y el botón de reclamar.
	local function renderDaily(s: State)
		for _, child in daily:GetChildren() do
			child:Destroy()
		end
		H.text(daily, "Racha", `Racha actual: {s.streak} días`, W / 2, 200, 30, 6, WHITE)
		local tileW, gap = 124, 12
		local startX = (W - (7 * tileW + 6 * gap)) / 2
		for day = 1, 7 do
			local reward = DailyReward.days()[day]
			local x = startX + (day - 1) * (tileW + gap)
			local isToday = day == s.cycleDay
			local pal = DAY_PALS[day]
			local tile = H.rect(daily, `Dia_{day}`, x, 240, tileW, 200, 16, 3, pal[1])
			H.grad(tile, pal[1], pal[2])
			H.ink(tile, if isToday then 6 else 3, if isToday then WHITE else BLACK)
			H.text(tile, "Dia", `DÍA {day}`, tileW / 2, 24, 22, 4)
			local main = if reward.gold ~= nil then `{reward.gold}` elseif reward.gems ~= nil then `{reward.gems}` else "ÍTEM"
			local caption = if reward.gold ~= nil then "ORO" elseif reward.gems ~= nil then "GEMAS" else ""
			H.text(tile, "Valor", main, tileW / 2, 90, 40, 4)
			H.text(tile, "Caption", caption, tileW / 2, 124, 18, 4)
			-- Si el día trae un objeto, se nombra debajo (el oro y las gemas ya están arriba).
			local itemDef = if reward.itemId ~= nil then Items[reward.itemId] else nil
			local extra = if itemDef then `{itemDef.displayName} x{reward.quantity or 1}` else ""
			Label.box(tile, "Extra", extra, 8, 146, tileW - 16, 34, 16, 4)
			if isToday then
				H.text(tile, "Hoy", if s.claimedToday then "LISTO" else "HOY", tileW / 2, 186, 20, 5, WHITE)
			end
		end
		local canClaim = not s.claimedToday
		local label = if canClaim then "RECLAMAR EL REGALO DE HOY" else "YA RECLAMADO · VUELVE MAÑANA"
		local claimPal = if canClaim then M.COLOR.lime else M.COLOR.purple
		local button = H.button(daily, "Reclamar", W / 2 - 240, 484, 480, 74, 18, claimPal, 6, { plain = true, lip = 5 })
		H.text(button, "Label", label, 240, 37, 24, button.ZIndex + 1)
		if canClaim then
			button.MouseButton1Click:Connect(claimDaily)
		end
	end

	-- Dibuja el pane de TIEMPO: un hito por fila, con barra de progreso y botón.
	local function renderTime(s: State)
		for _, child in timePane:GetChildren() do
			if child.Name ~= "Sesion" then
				child:Destroy()
			end
		end
		local claimedSet: { [number]: boolean } = {}
		for _, index in s.claimed do
			claimedSet[index] = true
		end
		local elapsed = s.elapsed + (os.clock() - fetchedAt)
		for index, tier in PlaytimeRewards.tiers() do
			local y = 240 + (index - 1) * 80
			local needed = tier.minutes * 60
			local row = H.rect(timePane, `Hito_{index}`, 30, y, 940, 68, 16, 3, Color3.fromRGB(40, 20, 70))
			H.ink(row, 3)
			H.text(row, "Minutos", `{tier.minutes} MIN`, 20, 34, 30, 4, M.COLOR.amber[1], "left")
			Label.box(row, "Premio", describe(tier), 190, 12, 350, 44, 22, 4, WHITE, Enum.TextXAlignment.Left)
			local track = H.rect(row, "Barra", 560, 26, 220, 16, 8, 4, BLACK)
			local fraction = math.clamp(elapsed / needed, 0, 1)
			local fill = H.rect(track, "Relleno", 0, 0, math.floor(220 * fraction), 16, 8, 5, TIME_PAL[1])
			H.grad(fill, TIME_PAL[1], TIME_PAL[2])
			local done = claimedSet[index] == true
			local ready = elapsed >= needed and not done
			local label = if done then "RECLAMADO" elseif ready then "RECLAMAR" else `FALTAN {math.ceil((needed - elapsed) / 60)} MIN`
			local pal = if ready then M.COLOR.lime elseif done then M.COLOR.purple else M.COLOR.red
			local button = H.button(row, "Boton", 800, 10, 160, 48, 14, pal, 5, { plain = true, lip = 4 })
			H.text(button, "Label", label, 80, 24, 17, button.ZIndex + 1)
			if ready then
				button.MouseButton1Click:Connect(function()
					claimTime(index)
				end)
			end
		end
		timeInfo.Text = `Llevas {math.floor(elapsed / 60)} min seguidos en esta sesión`
	end

	refresh = function()
		local result = invoke(options.remotes, "RewardsState")
		if type(result) == "table" then
			state = result :: any
			fetchedAt = os.clock()
		end
		local s = state
		if s ~= nil then
			renderDaily(s)
			renderTime(s)
		end
	end

	-- Cambio de pestaña: solo se muestra un pane a la vez.
	local function showTab(id: string)
		current = id
		for key, pane in panes do
			pane.Visible = key == id
		end
		for key, b in tabs do
			local stroke = b:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if key == id then WHITE else BLACK
				stroke.Thickness = if key == id then 5 else 4
			end
		end
	end

	M.live(gui, {
		tab = function(offer: any)
			showTab(tostring(offer))
		end,
	})
	showTab(current)

	gui:GetPropertyChangedSignal("Enabled"):Connect(function()
		if gui.Enabled then
			task.spawn(refresh)
		end
	end)

	-- Mientras la ventana está abierta, el tiempo y los hitos se actualizan solos.
	task.spawn(function()
		while true do
			task.wait(5)
			if gui.Enabled then
				refresh()
			end
		end
	end)

	return gui
end

return RewardsWindow
