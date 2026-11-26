--!strict
--[[
	Cliente mínimo de combate: solo envía intenciones (habilidad + objetivo más cercano) y muestra estado.
	Daño, rango, niveles y cooldowns los decide el servidor; lo que se ve aquí es una estimación local.
	Teclas 1 a 4 o botones táctiles. Interfaz en escala (UDim2) con tamaño mínimo táctil.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Abilities = require(ReplicatedStorage.Shared.Definitions.Abilities)
local Quests = require(ReplicatedStorage.Shared.Definitions.Quests)
local TestConfig = require(ReplicatedStorage.Shared.Definitions.TestConfig)
local Types = require(ReplicatedStorage.Shared.Types)

local MIN_TOUCH_SIZE = 56 -- píxeles mínimos por botón (objetivo táctil)
local HOTKEYS: { Enum.KeyCode } = { Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four }
local MULTI_HIT_GAP = 0.25 -- debe coincidir con el servidor

local player = Players.LocalPlayer

-- Estilo común de la interfaz: esquinas redondeadas y un borde dorado suave.
local function polish(instance: GuiObject, radius: number, strokeColor: Color3?)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColor or Color3.fromRGB(255, 220, 140)
	stroke.Thickness = 2
	stroke.Transparency = 0.2
	stroke.Parent = instance
end
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local castRemote = remotes:WaitForChild("CastAbility") :: RemoteEvent
local startQuestRemote = remotes:WaitForChild("StartQuest") :: RemoteEvent
local castResultRemote = remotes:WaitForChild("CastResult") :: RemoteEvent
local abilityFxRemote = remotes:WaitForChild("AbilityFx") :: RemoteEvent
local mobsFolder = workspace:WaitForChild("Mobs")

-- Habilidades ordenadas por nivel requerido y luego por id: el orden decide la tecla asignada.
local orderedAbilities: { Types.AbilityDef } = {}
for _, ability in Abilities do
	table.insert(orderedAbilities, ability)
end
table.sort(orderedAbilities, function(a, b)
	if a.requiredLevel ~= b.requiredLevel then
		return a.requiredLevel < b.requiredLevel
	end
	return a.id < b.id
end)

-- Mensajes para los motivos de rechazo que devuelve el servidor.
local ERROR_TEXT: { [string]: string } = {
	cooldown = "En enfriamiento",
	out_of_range = "Fuera de alcance",
	invalid_target = "Objetivo no válido",
	no_targets = "Sin enemigos en el área",
	locked = "Nivel insuficiente",
	no_character = "Sin personaje",
	rate_limited = "Espera un momento",
	profile_not_loaded = "Cargando tu perfil...",
	payload_invalid = "Petición no válida",
}

-- Color de cada habilidad en su efecto visual.
local FX_COLORS: { [string]: Color3 } = {
	punch_magma = Color3.fromRGB(255, 110, 30),
	ember_lance = Color3.fromRGB(255, 190, 60),
	ash_storm = Color3.fromRGB(200, 120, 255),
	smoke_clone = Color3.fromRGB(120, 255, 180),
}

-- Mob vivo más cercano. Solo cuenta humanoids con vida, así un mob muerto no se apunta.
local function findNearestMob(): (string?, number?)
	local character = player.Character
	local myRoot = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if myRoot == nil or not myRoot:IsA("BasePart") then
		return nil, nil
	end
	local bestName: string? = nil
	local bestDistance = math.huge
	for _, child in mobsFolder:GetChildren() do
		local root = child:FindFirstChild("HumanoidRootPart")
		local humanoid = child:FindFirstChildOfClass("Humanoid")
		if root ~= nil and root:IsA("BasePart") and humanoid ~= nil and humanoid.Health > 0 then
			local distance = (root.Position - myRoot.Position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestName = child.Name
			end
		end
	end
	return bestName, if bestName then bestDistance else nil
end

-- Interfaz.
local gui = Instance.new("ScreenGui")
gui.Name = "CombatHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.Position = UDim2.fromScale(0.5, 0.12)
statusLabel.Size = UDim2.fromScale(0.4, 0.06)
statusLabel.BackgroundTransparency = 0.4
statusLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.Text = "Busca un mob"
statusLabel.Parent = gui

polish(statusLabel, 14)
local statusLimit = Instance.new("UISizeConstraint")
statusLimit.MinSize = Vector2.new(180, 28)
statusLimit.Parent = statusLabel

local bar = Instance.new("Frame")
bar.Name = "AbilityBar"
bar.AnchorPoint = Vector2.new(0.5, 1)
bar.Position = UDim2.fromScale(0.5, 0.915)
bar.Size = UDim2.fromScale(0.5, 0.07)
bar.BackgroundTransparency = 1
bar.Parent = gui
bar.Visible = false -- plegada por defecto: las teclas 1-4 siguen funcionando

-- Botón para desplegar las habilidades. Discreto, abajo al centro.
local abilityToggle = Instance.new("TextButton")
abilityToggle.Name = "AbilityToggle"
abilityToggle.AnchorPoint = Vector2.new(0.5, 1)
abilityToggle.Position = UDim2.fromScale(0.5, 0.985)
abilityToggle.Size = UDim2.fromScale(0.14, 0.04)
abilityToggle.BackgroundColor3 = Color3.fromRGB(12, 14, 24)
abilityToggle.BackgroundTransparency = 0.22
abilityToggle.BorderSizePixel = 0
abilityToggle.AutoButtonColor = true
abilityToggle.Font = Enum.Font.GothamBold
abilityToggle.TextColor3 = Color3.fromRGB(240, 243, 252)
abilityToggle.TextScaled = true
abilityToggle.Text = "HABILIDADES [+]"
local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = abilityToggle
local toggleLimit = Instance.new("UISizeConstraint")
toggleLimit.MinSize = Vector2.new(120, 32)
toggleLimit.Parent = abilityToggle
abilityToggle.Activated:Connect(function()
	bar.Visible = not bar.Visible
	abilityToggle.Text = if bar.Visible then "HABILIDADES [-]" else "HABILIDADES [+]"
end)
abilityToggle.Parent = gui

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.Padding = UDim.new(0.02, 0)
layout.Parent = bar

local lastCastAt: { [string]: number } = {}
local buttons: { [string]: TextButton } = {}

local function setStatus(text: string)
	statusLabel.Text = text
end

-- Mensajes de acción (rechazos, éxitos). Duran un instante y el estado normal no los pisa.
local feedbackUntil = 0
local function showFeedback(text: string)
	feedbackUntil = os.clock() + 2.5
	statusLabel.Text = text
end

-- Nivel visible: lo escribe el servidor como atributo. Si aún no existe, nivel 1.
local function currentLevel(): number
	return (player:GetAttribute("Level") :: number?) or 1
end

-- Segundos que faltan de enfriamiento según la estimación local. Siempre 0 en modo de pruebas.
local function remainingCooldown(ability: Types.AbilityDef): number
	if TestConfig.NO_COOLDOWNS then
		return 0
	end
	return (lastCastAt[ability.id] or 0) + ability.cooldown - os.clock()
end

local function cast(ability: Types.AbilityDef)
	if remainingCooldown(ability) > 0 then
		return
	end
	if not TestConfig.NO_LEVELS and currentLevel() < ability.requiredLevel then
		showFeedback(`Necesitas nivel {ability.requiredLevel}`)
		return
	end

	local targetId, distance = findNearestMob()

	-- Modo de pruebas: sin mob, la habilidad sale igual (el servidor la acepta con daño 0).
	if targetId == nil or distance == nil then
		if TestConfig.ALLOW_CAST_WITHOUT_TARGET then
			lastCastAt[ability.id] = os.clock()
			castRemote:FireServer({ abilityId = ability.id })
			return
		end
		showFeedback(if ability.kind == "area" then "Sin enemigos en el área" else "Sin objetivo cerca")
		return
	end

	if ability.kind == "area" then
		-- El área no apunta: basta con que haya un enemigo dentro del radio.
		if distance > ability.radius and not TestConfig.ALLOW_CAST_WITHOUT_TARGET then
			showFeedback("Sin enemigos en el área")
			return
		end
		lastCastAt[ability.id] = os.clock()
		castRemote:FireServer({ abilityId = ability.id, targetId = targetId })
		return
	end

	-- El mob más cercano es el que cuenta: si ni ese llega, ningún otro llega.
	if distance > ability.range then
		showFeedback(`Acércate: {math.floor(distance)} de {ability.range} studs`)
		return
	end
	lastCastAt[ability.id] = os.clock()
	castRemote:FireServer({ abilityId = ability.id, targetId = targetId })
end

-- Respuesta del servidor: éxito con daño, o motivo del rechazo.
castResultRemote.OnClientEvent:Connect(function(result: any)
	local name = if result.abilityId and Abilities[result.abilityId] then Abilities[result.abilityId].displayName else "Habilidad"
	if result.ok then
		showFeedback(`{name}: {result.damage} de daño`)
		return
	end
	showFeedback(ERROR_TEXT[result.error] or "No se pudo usar")
	-- Un rechazo que no es enfriamiento no debe bloquear el botón en el cliente.
	if result.error ~= "cooldown" and result.abilityId ~= nil then
		lastCastAt[result.abilityId] = nil
	end
end)

-- Una esfera de color que crece y se desvanece.
local function sphereAt(position: Vector3, color: Color3)
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Ball
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(2, 2, 2)
	part.Position = position
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Parent = workspace
	TweenService:Create(part, TweenInfo.new(0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(9, 9, 9), Transparency = 1 }):Play()
	Debris:AddItem(part, 0.5)
end

-- Efecto por tipo: área = anillo que se expande; multi = esferas seguidas; single = una esfera.
local function playFx(fx: any)
	local ability = Abilities[fx.abilityId]
	if ability == nil then
		return
	end
	local color = FX_COLORS[ability.id] or Color3.new(1, 1, 1)

	if ability.kind == "area" then
		local ring = Instance.new("Part")
		ring.Shape = Enum.PartType.Cylinder
		ring.Material = Enum.Material.Neon
		ring.Color = color
		ring.Size = Vector3.new(0.4, 2, 2)
		-- El cilindro apunta a lo largo de X; girarlo 90° en Z lo deja plano en el suelo.
		ring.CFrame = CFrame.new(fx.position) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = true
		ring.CanCollide = false
		ring.CanQuery = false
		ring.CanTouch = false
		ring.Parent = workspace
		local diameter = ability.radius * 2
		TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.new(0.4, diameter, diameter), Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.6)
		return
	end

	local count = if ability.kind == "multi" then ability.hits else 1
	for index = 1, count do
		task.delay((index - 1) * MULTI_HIT_GAP, function()
			sphereAt(fx.position, color)
		end)
	end
end

abilityFxRemote.OnClientEvent:Connect(playFx)

for index, ability in orderedAbilities do
	local button = Instance.new("TextButton")
	button.Name = `Ability_{ability.id}`
	button.Size = UDim2.fromScale(0.22, 1)
	button.BackgroundColor3 = Color3.fromRGB(40, 44, 70)
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.TextStrokeTransparency = 0.4
	button.AutoButtonColor = true
	button.LayoutOrder = index
	button.Text = `{index}\n{ability.displayName}`
	button.Parent = bar

	polish(button, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MinSize = Vector2.new(MIN_TOUCH_SIZE, MIN_TOUCH_SIZE)
	limit.Parent = button

	button.Activated:Connect(function()
		cast(ability)
	end)
	buttons[ability.id] = button
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	for index, key in HOTKEYS do
		if input.KeyCode == key and orderedAbilities[index] ~= nil then
			cast(orderedAbilities[index])
		end
	end
end)

-- Botón de misión: inicia la primera misión definida (el servidor valida y puede rechazarla).
-- Misión que muestra el botón. Se elige por id, no por orden alfabético.
local firstQuestId: string? = if Quests.first_hunt ~= nil then "first_hunt" else nil
if firstQuestId ~= nil then
	local questId: string = firstQuestId
	local questButton = Instance.new("TextButton")
	questButton.Name = "StartQuestButton"
	questButton.AnchorPoint = Vector2.new(1, 0)
	questButton.Position = UDim2.fromScale(0.985, 0.12)
	questButton.Size = UDim2.fromScale(0.19, 0.045)
	questButton.BackgroundColor3 = Color3.fromRGB(60, 90, 60)
	questButton.TextColor3 = Color3.fromRGB(255, 255, 255)
	questButton.TextScaled = true
	questButton.Font = Enum.Font.GothamMedium
	questButton.Text = `Misión: {Quests[questId].title}`
	questButton.Parent = gui

	polish(questButton, 12, Color3.fromRGB(150, 255, 150))
local questLimit = Instance.new("UISizeConstraint")
	questLimit.MinSize = Vector2.new(MIN_TOUCH_SIZE * 2, MIN_TOUCH_SIZE)
	questLimit.Parent = questButton

	questButton.Activated:Connect(function()
		startQuestRemote:FireServer({ questId = questId })
	end)
end

-- Refresco de estado, cooldowns y niveles (estimación local; el servidor decide).
local accumulated = 0
RunService.Heartbeat:Connect(function(dt: number)
	accumulated += dt
	if accumulated < 0.1 then
		return
	end
	accumulated = 0

	local level = currentLevel()
	local name, distance = findNearestMob()
	if os.clock() >= feedbackUntil and name ~= nil and distance ~= nil then
		local model = mobsFolder:FindFirstChild(name)
		local shown = if model then model:GetAttribute("DisplayName") else nil
		setStatus(`{if typeof(shown) == "string" then shown else name} · {math.floor(distance)} studs`)
	end

	for index, ability in orderedAbilities do
		local button = buttons[ability.id]
		local remaining = remainingCooldown(ability)
		if not TestConfig.NO_LEVELS and level < ability.requiredLevel then
			button.Text = `{index}\nNivel {ability.requiredLevel}`
			button.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
		elseif remaining > 0 then
			button.Text = `{index}\n{string.format("%.1f", remaining)}s`
			button.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
		else
			button.Text = `{index}\n{ability.displayName}`
			button.BackgroundColor3 = Color3.fromRGB(40, 44, 70)
		end
	end
end)
