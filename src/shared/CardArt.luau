-- Draws a card: a thick border in its rarity's color around a dark panel, the brainrot's
-- picture (its 2D illustration, its 3D model in a ViewportFrame, or else the thumbnail of its
-- Creator Store model), its name and Cash. Variants add a colored reflection and a badge in the
-- top right corner, a trait a badge in the top left one. Graded cards sit in a plastic sleeve
-- with their grade written above. The rarest cards of each pack are full arts.
-- Used by the UI and by the cards standing on the plots (SurfaceGui).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Format = require(script.Parent.Format)

local CardArt = {}

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(24, 22, 36)
local PANEL = Color3.fromRGB(35, 30, 55)
local WHITE = Color3.new(1, 1, 1)

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

-- The border of a card of this rarity. From Secret up it mixes two colors; the UI turns it.
function CardArt.rarityColors(rarity: Config.Rarity): ColorSequence
	if rarity.id == "infinity" then
		return RAINBOW
	elseif rarity.accent then
		return ColorSequence.new({
			ColorSequenceKeypoint.new(0, rarity.color),
			ColorSequenceKeypoint.new(0.5, rarity.accent),
			ColorSequenceKeypoint.new(1, rarity.color),
		})
	end
	return ColorSequence.new(rarity.color:Lerp(WHITE, 0.3), rarity.color)
end

-- The colors of a variant's reflection (or of the card's border for a normal card)
function CardArt.frameColors(cardId: string, variantId: string): ColorSequence
	if variantId == "gold" then
		return GOLD
	elseif variantId == "rainbow" then
		return RAINBOW
	elseif variantId == "holo" then
		return HOLO
	end
	return CardArt.rarityColors(Config.RARITY[Config.CARDS[cardId].rarity])
end

-- The picture of a card: the thumbnail of its 3D model, or "" if it has none
function CardArt.image(cardId: string): string
	local asset = Config.ASSETS[cardId]
	return if asset and asset.id ~= 0 then string.format("rbxthumb://type=Asset&id=%d&w=420&h=420", asset.id) else ""
end

-- The loaded 3D model of a card (Assets.luau puts them in ReplicatedStorage.AssetTemplates)
local function template(cardId: string): Model?
	local templates = ReplicatedStorage:FindFirstChild("AssetTemplates")
	local model = templates and templates:FindFirstChild(cardId)
	return if model and model:IsA("Model") then model else nil
end

-- Shows the model in a ViewportFrame, seen from the front and a bit from above
local function viewport(window: Frame, model: Model, z: number, zoom: number)
	local view = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(200, 200, 200), LightColor = WHITE, LightDirection = Vector3.new(-1, -1, 1), ZIndex = z }, window)
	local copy = model:Clone()
	copy.Parent = view
	local box, size = copy:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	local distance = (size.Magnitude / 2) / math.tan(math.rad(20)) * zoom
	-- Models face -Z: the camera stands on that side
	local direction = Vector3.new(0.35, 0.3, -1).Unit
	camera.CFrame = CFrame.lookAt(box.Position + direction * distance, box.Position)
	camera.Parent = view
	view.CurrentCamera = camera
end

-- The brainrot's picture inside `window`
local function picture(window: Frame, parent: Instance, card: Config.Card, z: number, zoom: number)
	local art = Config.CARD_ART[card.id]
	local model = template(card.id)
	local image = CardArt.image(card.id)
	if art then
		new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://" .. art, ScaleType = Enum.ScaleType.Crop, ZIndex = z }, window)
	-- ViewportFrames stay blank in the stands' SurfaceGuis: there, the 3D model stands right behind
	-- the card, so the window stays empty and the name moves into it (see CardArt.build).
	-- The old thumbnail is only for models that aren't loaded.
	elseif parent:IsA("SurfaceGui") then
		return
	elseif model then
		viewport(window, model, z, zoom)
	elseif not model and image ~= "" then
		-- Thumbnails leave a lot of empty space around the model: zoomed in (the window clips it)
		new("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(1.5, 1.5), Image = image, ScaleType = Enum.ScaleType.Fit, ZIndex = z }, window)
	else
		text(window, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.6, 0.5), Text = string.upper(string.sub(card.name, 1, 1)), ZIndex = z })
	end
end

-- A rounded tab sticking out over a top corner of the card, so it never hides the rarity
local function badge(parent: Instance, anchorX: number, label: string, color: Color3, colors: ColorSequence?, z: number)
	local frame = new("Frame", { AnchorPoint = Vector2.new(anchorX, 0.5), Position = UDim2.fromScale(if anchorX == 0 then -0.04 else 1.04, 0.015), Size = UDim2.fromScale(0.42, 0.095), Rotation = if anchorX == 0 then -8 else 8, BackgroundColor3 = if colors then WHITE else color, ZIndex = z }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, frame)
	new("UIStroke", { Thickness = 2, Color = DARK, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, frame)
	if colors then
		new("UIGradient", { Rotation = 20, Color = colors }, frame)
	end
	text(frame, { Position = UDim2.fromScale(0.08, 0.1), Size = UDim2.fromScale(0.84, 0.8), Text = label, ZIndex = z + 1 })
end

local TRAIT_LABELS = { dmg = "DMG", hp = "HP", coin = "$$$" }

-- Builds the card inside `parent` (filling it). Returns the outer frame (the sleeve for a graded
-- card) and its "shine", a light streak the UI can move across Gold, Rainbow and Holo cards.
-- The UI also turns every UIGradient named "Spin" (the borders of the top rarities).
function CardArt.build(parent: Instance, cardId: string, variantId: string, grade: Config.Grade?, zIndex: number?, traitId: string?): (Frame, Frame?)
	local card = Config.CARDS[cardId]
	local rarity = Config.RARITY[card.rarity]
	local z = zIndex or 1
	local fullArt = Config.isFullArt(cardId)

	-- Graded cards: a clear plastic sleeve, the grade on a label above the card
	local root: Frame
	local holder: Instance = parent
	if grade then
		root = new("Frame", { Name = "Sleeve", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(220, 235, 255), BackgroundTransparency = 0.55, ZIndex = z }, parent)
		new("UICorner", { CornerRadius = UDim.new(0.05, 0) }, root)
		new("UIStroke", { Thickness = 3, Color = WHITE, Transparency = 0.1 }, root)
		local label = new("Frame", { Position = UDim2.fromScale(0.05, 0.02), Size = UDim2.fromScale(0.9, 0.11), BackgroundColor3 = DARK, ZIndex = z + 1 }, root)
		new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, label)
		new("UIStroke", { Thickness = 3, Color = grade.color }, label)
		text(label, { Position = UDim2.fromScale(0.04, 0.12), Size = UDim2.fromScale(0.66, 0.76), Text = grade.name, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = z + 2 })
		text(label, { Position = UDim2.fromScale(0.72, 0.02), Size = UDim2.fromScale(0.25, 0.96), Text = tostring(grade.grade), TextColor3 = grade.color, ZIndex = z + 2 })
		holder = new("Frame", { Position = UDim2.fromScale(0.08, 0.19), Size = UDim2.fromScale(0.84, 0.79), BackgroundTransparency = 1, ZIndex = z }, root)
		z += 2
	end

	-- Outer frame: the thick border in the rarity's color
	local frame = new("Frame", { Name = "Card", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = z }, holder)
	new("UICorner", { CornerRadius = UDim.new(0.07, 0) }, frame)
	new("UIGradient", { Name = if rarity.accent then "Spin" else "Border", Rotation = 45, Color = CardArt.rarityColors(rarity) }, frame)
	new("UIStroke", { Thickness = 2, Color = DARK, Transparency = 0.2 }, frame)
	root = root or frame

	-- Dark inner panel with a white outline
	local inner = new("Frame", { Position = UDim2.fromScale(0.06, 0.045), Size = UDim2.fromScale(0.88, 0.91), BackgroundColor3 = PANEL, ClipsDescendants = true, ZIndex = z + 1 }, frame)
	new("UICorner", { CornerRadius = UDim.new(0.07, 0) }, inner)
	new("UIStroke", { Thickness = 2.5, Color = WHITE, Transparency = 0.1 }, inner)

	-- Picture: a window in the middle, or the whole card for full arts
	local window = new("Frame", {
		Position = if fullArt then UDim2.fromScale(0, 0) else UDim2.fromScale(0.07, 0.13),
		Size = if fullArt then UDim2.fromScale(1, 1) else UDim2.fromScale(0.86, 0.55),
		BackgroundColor3 = WHITE,
		ClipsDescendants = true,
		ZIndex = z + 2,
	}, inner)
	new("UICorner", { CornerRadius = UDim.new(if fullArt then 0.07 else 0.1, 0) }, window)
	new("UIGradient", {
		Rotation = if fullArt then 60 else 90,
		Color = if fullArt
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, rarity.color:Lerp(WHITE, 0.25)),
				ColorSequenceKeypoint.new(0.55, (rarity.accent or rarity.color):Lerp(PANEL, 0.35)),
				ColorSequenceKeypoint.new(1, PANEL),
			})
			else ColorSequence.new(rarity.color:Lerp(PANEL, 0.25), PANEL),
	}, window)
	picture(window, parent, card, z + 3, if fullArt then 0.75 else 0.9)

	-- Variants: a colored reflection over the picture
	if variantId ~= "normal" then
		local foil = new("Frame", { Name = "Foil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = if variantId == "rainbow" then 0.58 else 0.4, ZIndex = z + 4 }, inner)
		new("UIGradient", { Rotation = 35, Color = CardArt.frameColors(cardId, variantId), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0) }) }, foil)
	end

	-- Full arts: dark fades behind the texts so they stay readable over the picture
	if fullArt then
		for _, top in { true, false } do
			local fade = new("Frame", { Position = UDim2.fromScale(0, if top then 0 else 0.55), Size = UDim2.fromScale(1, if top then 0.2 else 0.45), BackgroundColor3 = DARK, BorderSizePixel = 0, ZIndex = z + 5 }, inner)
			new("UIGradient", { Rotation = if top then 90 else -90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.15), NumberSequenceKeypoint.new(1, 1) }) }, fade)
		end
	end

	-- Rarity at the top, name and Cash at the bottom
	text(inner, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.025), Size = UDim2.fromScale(0.9, 0.085), Text = string.upper(rarity.name), TextColor3 = rarity.color, ZIndex = z + 6 })
	local onStand = parent:IsA("SurfaceGui") and not Config.CARD_ART[cardId]
	text(inner, {
		Position = if onStand then UDim2.fromScale(0.08, 0.25) elseif fullArt then UDim2.fromScale(0.06, 0.72) else UDim2.fromScale(0.06, 0.7),
		Size = if onStand then UDim2.fromScale(0.84, 0.32) else UDim2.fromScale(0.88, 0.15),
		Text = card.name,
		TextWrapped = true,
		ZIndex = z + 6,
	})
	text(inner, { Position = UDim2.fromScale(0.15, 0.87), Size = UDim2.fromScale(0.7, 0.09), Text = "$" .. Format.number(Config.cardIncome(cardId, variantId)) .. "/s", TextColor3 = Color3.fromRGB(255, 225, 60), ZIndex = z + 6 })

	-- Badges: the trait top left, the variant top right
	local trait = traitId and Config.TRAIT[traitId]
	if trait then
		badge(frame, 0, TRAIT_LABELS[trait.id] or string.upper(trait.name), trait.color, nil, z + 7)
	end
	if variantId ~= "normal" then
		local variant = Config.VARIANT[variantId]
		badge(frame, 1, string.upper(variant.name), variant.color, CardArt.frameColors(cardId, variantId), z + 7)
	end

	-- Light streak for shiny cards and full arts
	local shine: Frame? = nil
	if variantId ~= "normal" or fullArt then
		local streak = new("Frame", { Name = "Shine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(-0.5, 0.5), Size = UDim2.fromScale(0.35, 1.6), Rotation = 20, BackgroundColor3 = WHITE, BackgroundTransparency = 0.6, BorderSizePixel = 0, ZIndex = z + 9 }, inner)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, streak)
		shine = streak
	end
	return root, shine
end

return CardArt
