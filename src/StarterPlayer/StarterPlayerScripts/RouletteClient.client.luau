--!strict
--[[
	Muestra el resultado de la ruleta durante unos segundos. Solo visual: el servidor elige y entrega el premio.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

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
local rouletteResultRemote = remotes:WaitForChild("RouletteResult") :: RemoteEvent

local ERROR_TEXT: { [string]: string } = {
	cooldown = "La ruleta aún se está enfriando",
	rate_limited = "Espera un momento",
	sin_premios = "La ruleta no tiene premios",
	premio_pendiente = "Ese premio llegará en una próxima parte. Gira otra vez",
	profile_not_loaded = "Tu progreso todavía se está cargando",
}

local gui = Instance.new("ScreenGui")
gui.Name = "RouletteHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "RouletteResult"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0.12)
label.Size = UDim2.fromScale(0.4, 0.07)
label.BackgroundTransparency = 0.3
label.BackgroundColor3 = Color3.fromRGB(255, 200, 60)
label.TextColor3 = Color3.fromRGB(30, 20, 10)
label.TextScaled = true
label.Font = Enum.Font.GothamBlack
label.Visible = false
label.Parent = gui
polish(label, 14, Color3.fromRGB(255, 255, 255))

local hideAt = 0
rouletteResultRemote.OnClientEvent:Connect(function(result: any)
	if result.ok then
		label.Text = `¡Ruleta: {result.label}!`
	else
		label.Text = ERROR_TEXT[result.error] or "No se pudo girar"
	end
	label.Visible = true
	-- Entrada con rebote: el resultado llama la atención sin tapar la pantalla.
	label.Size = UDim2.fromScale(0.25, 0.04)
	TweenService:Create(label, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = UDim2.fromScale(0.4, 0.07) }):Play()
	hideAt = os.clock() + 3
end)

task.spawn(function()
	while true do
		if label.Visible and os.clock() >= hideAt then
			label.Visible = false
		end
		task.wait(0.2)
	end
end)
