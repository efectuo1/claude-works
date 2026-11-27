--!strict
--[[
	Caja de texto que nunca se sale de su sitio: ajusta líneas y reduce el tamaño hasta caber.
	Úsala para cualquier texto que pueda ser largo (descripciones, nombres, premios). Los textos cortos
	de títulos siguen con H.text del kit.
]]

local Label = {}

local BLACK = Color3.new(0, 0, 0)

-- `size` es el tamaño máximo; si el texto no cabe, baja hasta 10 para que quepa en la caja.
function Label.box(parent: Instance, name: string, text: string, x: number, y: number, w: number, h: number, size: number, z: number?, color: Color3?, align: Enum.TextXAlignment?): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.fromOffset(x, y)
	label.Size = UDim2.fromOffset(w, h)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.Text = text
	label.TextScaled = true
	label.TextWrapped = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextXAlignment = align or Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.ZIndex = z or 5
	label.Parent = parent

	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.MinTextSize = 10
	limit.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = BLACK
	stroke.Parent = label
	return label
end

return Label
