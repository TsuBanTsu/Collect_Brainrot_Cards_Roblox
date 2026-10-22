-- Draws a card: frame colored by rarity (gold, rainbow or holo for variants), the brainrot's
-- picture (the thumbnail of its Creator Store model), its name, rarity and grade.
-- Used by the UI and by the cards standing on the plots (SurfaceGui).

local Config = require(script.Parent.Config)

local CardArt = {}

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(24, 22, 36)

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})
local GOLD = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 245, 170)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(240, 180, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 230, 120)),
})
local HOLO = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 255, 245)),
	ColorSequenceKeypoint.new(0.35, Color3.fromRGB(225, 180, 255)),
	ColorSequenceKeypoint.new(0.7, Color3.fromRGB(150, 200, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 255, 210)),
})

local function new(className: string, props, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function text(parent: Instance, props): TextLabel
	props.BackgroundTransparency = 1
	props.Font = FONT
	props.TextScaled = true
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	local label = new("TextLabel", props, parent)
	new("UIStroke", { Thickness = 2, Transparency = 0.15 }, label)
	return label
end

-- The colors of the frame around the card
function CardArt.frameColors(cardId: string, variantId: string): ColorSequence
	if variantId == "gold" then
		return GOLD
	elseif variantId == "rainbow" then
		return RAINBOW
	elseif variantId == "holo" then
		return HOLO
	end
	local color = Config.RARITY[Config.CARDS[cardId].rarity].color
	return ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.35), color:Lerp(Color3.new(0, 0, 0), 0.25))
end

-- The picture of a card: the thumbnail of its 3D model, or "" if it has none
function CardArt.image(cardId: string): string
	local asset = Config.ASSETS[cardId]
	return if asset then string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", asset.id) else ""
end

-- Builds the card inside `parent` (filling it). Returns the card frame and its "shine"
-- frame, a light streak the UI can move across Gold, Rainbow and Holo cards.
function CardArt.build(parent: Instance, cardId: string, variantId: string, grade: Config.Grade?, zIndex: number?): (Frame, Frame?)
	local card = Config.CARDS[cardId]
	local rarity = Config.RARITY[card.rarity]
	local z = zIndex or 1

	-- Outer frame: the colored border
	local frame = new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.07, 0) }, frame)
	new("UIGradient", { Rotation = 45, Color = CardArt.frameColors(cardId, variantId) }, frame)
	new("UIStroke", { Thickness = 2, Color = Color3.new(0, 0, 0), Transparency = 0.3 }, frame)

	-- Inner panel with the picture
	local inner = new("Frame", { Position = UDim2.fromScale(0.05, 0.035), Size = UDim2.fromScale(0.9, 0.93), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = z + 1 }, frame)
	new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, inner)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rarity.color:Lerp(DARK, 0.45), DARK) }, inner)

	-- Top bar: rarity
	text(inner, { Position = UDim2.fromScale(0.06, 0.02), Size = UDim2.fromScale(0.88, 0.09), Text = string.upper(rarity.name), TextColor3 = rarity.color, ZIndex = z + 3 })

	-- Picture window
	local window = new("Frame", { Position = UDim2.fromScale(0.07, 0.12), Size = UDim2.fromScale(0.86, 0.52), BackgroundColor3 = Color3.new(1, 1, 1), ClipsDescendants = true, ZIndex = z + 2 }, inner)
	new("UICorner", { CornerRadius = UDim.new(0.08, 0) }, window)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(rarity.color:Lerp(Color3.new(1, 1, 1), 0.55), rarity.color:Lerp(DARK, 0.2)) }, window)
	local image = CardArt.image(cardId)
	if image ~= "" then
		new("ImageLabel", { BackgroundTransparency = 1, Position = UDim2.fromScale(0.04, 0.04), Size = UDim2.fromScale(0.92, 0.92), Image = image, ScaleType = Enum.ScaleType.Fit, ZIndex = z + 3 }, window)
	else
		text(window, { Position = UDim2.fromScale(0.2, 0.15), Size = UDim2.fromScale(0.6, 0.7), Text = string.upper(string.sub(card.name, 1, 1)), ZIndex = z + 3 })
	end

	-- Name and variant
	text(inner, { Position = UDim2.fromScale(0.06, 0.67), Size = UDim2.fromScale(0.88, 0.17), Text = card.name, TextWrapped = true, ZIndex = z + 3 })
	if variantId ~= "normal" then
		local variant = Config.VARIANT[variantId]
		text(inner, { Position = UDim2.fromScale(0.06, 0.86), Size = UDim2.fromScale(0.88, 0.1), Text = string.upper(variant.name), TextColor3 = variant.color, ZIndex = z + 3 })
	end

	-- Grade badge in the corner of the picture
	if grade then
		local badge = new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(0.97, 0.09), Size = UDim2.fromScale(0.3, 0.13), BackgroundColor3 = DARK, ZIndex = z + 4 }, inner)
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, badge)
		new("UIStroke", { Thickness = 2, Color = grade.color }, badge)
		text(badge, { Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.8), Text = tostring(grade.grade), TextColor3 = grade.color, ZIndex = z + 5 })
	end

	-- Light streak for shiny cards
	local shine: Frame? = nil
	if variantId ~= "normal" then
		local streak = new("Frame", { Name = "Shine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.5, 0.5), Size = UDim2.fromScale(0.35, 1.6), Rotation = 20, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = z + 6 }, frame)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, streak)
		frame.ClipsDescendants = true
		shine = streak
	end
	return frame, shine
end

return CardArt
