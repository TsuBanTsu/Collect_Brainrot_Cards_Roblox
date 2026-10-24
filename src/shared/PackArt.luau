-- Draws a booster pack: a foil bag in the pack's color, crimped at the top and bottom, with
-- its name and the brainrot of its rarest card on the front.
-- Used by the pack opening, and later by the shop and the backpack.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

local PackArt = {}

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(24, 22, 36)
local WHITE = Color3.new(1, 1, 1)

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
	props.TextColor3 = props.TextColor3 or WHITE
	local label = new("TextLabel", props, parent)
	new("UIStroke", { Thickness = 2.5, Transparency = 0.1 }, label)
	return label
end

-- The rarest card of a pack: its face is printed on the pack
local function coverCard(pack: Config.Pack): string?
	local best, bestId = 0, nil
	for rarityId, list in pack.cards do
		local order = Config.RARITY[rarityId].order
		if order > best and list[1] then
			best, bestId = order, list[1].id
		end
	end
	return bestId
end

-- The crimp lines of a seal: thin dark lines close together, pressed into the foil
local CRIMP_LINES = 28

local function crimpLine(parent: Instance, i: number, z: number): Frame
	return new("Frame", { Name = "Ridge" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((i - 0.5) / CRIMP_LINES, 0.5), Size = UDim2.new(0, 2, 0.62, 0), BackgroundColor3 = DARK, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = z + 1 }, parent)
end

-- A piece of seal: the bag's color, a little darker, with the foil's light from the top and a
-- dark outline like the bag's
local function strip(parent: Instance, name: string, color: Color3, z: number): Frame
	local piece = new("Frame", { Name = name, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, piece)
	new("UIStroke", { Thickness = 3, Color = DARK }, piece)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(WHITE, 0.2)),
		ColorSequenceKeypoint.new(1, color:Lerp(DARK, 0.3)),
	}) }, piece)
	return piece
end

-- A crimped strip (the sealed edge of the bag), as wide as the bag
local function crimp(parent: Instance, name: string, top: boolean, color: Color3, z: number): Frame
	local seal = strip(parent, name, color, z)
	seal.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	seal.Position = UDim2.fromScale(0.02, if top then 0 else 1)
	seal.Size = UDim2.fromScale(0.96, 0.09)
	for i = 1, CRIMP_LINES do
		crimpLine(seal, i, z)
	end
	return seal
end

-- The top seal can be torn off in one piece: `PackArt.setTear(pack, progress)` peels it from
-- the left. The part already torn ("Torn") lifts up around the point where the tear is, like a
-- strip of foil, while the rest ("Rest") stays on the bag; both are the same continuous strip,
-- its ridges handed from one to the other as the tear goes. "TearLine" is the ragged white
-- edge left on the bag, shown as far as the tear has gone.
local TEAR_BITS = 40
local TEAR_ANGLE = 32 -- degrees the torn part has turned up when the tear reaches the right

local function tearableTop(parent: Instance, color: Color3, z: number): Frame
	local top = new("Frame", { Name = "Top", Position = UDim2.fromScale(0.02, 0), Size = UDim2.fromScale(0.96, 0.09), BackgroundTransparency = 1, ZIndex = z }, parent)
	local torn = strip(top, "Torn", color, z)
	torn.Visible = false
	local rest = strip(top, "Rest", color, z)
	rest.Size = UDim2.fromScale(1, 1)
	for i = 1, CRIMP_LINES do
		crimpLine(rest, i, z)
	end
	local line = new("Frame", { Name = "TearLine", Position = UDim2.fromScale(0.02, 0.078), Size = UDim2.fromScale(0.96, 0.022), BackgroundTransparency = 1, ZIndex = z - 1 }, parent)
	for i = 1, TEAR_BITS do
		-- Small turned squares at slightly random heights: a torn, uneven edge
		local y = 0.5 + (((i * 37) % 11) / 11 - 0.5) * 0.7
		new("Frame", { Name = "Bit" .. i, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((i - 0.5) / TEAR_BITS, y), Size = UDim2.new(1 / TEAR_BITS * 1.6, 0, 1, 0), Rotation = 45, BackgroundColor3 = Color3.fromRGB(250, 250, 245), BorderSizePixel = 0, Visible = false, ZIndex = z - 1 }, line)
	end
	return top
end

-- Tears the top of a pack built by PackArt.build up to `progress` (0: sealed, 1: torn all the
-- way across). Returns the torn strip, for the opening to throw away at the end.
function PackArt.setTear(art: Frame, progress: number): Frame
	local top = art:FindFirstChild("Top") :: Frame
	local torn = top:FindFirstChild("Torn") :: Frame
	local rest = top:FindFirstChild("Rest") :: Frame
	local line = art:FindFirstChild("TearLine") :: Frame
	local p = math.clamp(progress, 0, 1)

	-- The rest of the seal, still on the bag, right of the tear
	rest.Visible = p < 1
	rest.Position = UDim2.fromScale(p, 0)
	rest.Size = UDim2.fromScale(1 - p, 1)

	-- The torn part turns up around its right end (the tear). Gui objects turn around their
	-- middle, so its middle is placed where it lands once turned, in pixels then in scale.
	torn.Visible = p > 0
	local size = top.AbsoluteSize
	local width, height = math.max(size.X, 1), math.max(size.Y, 1)
	local angle = math.rad(p * TEAR_ANGLE)
	local half = Vector2.new(-p * width / 2, -height / 2) -- from the turning point to the middle, before turning
	local turned = Vector2.new(half.X * math.cos(angle) - half.Y * math.sin(angle), half.X * math.sin(angle) + half.Y * math.cos(angle))
	local center = Vector2.new(p * width, height) + turned
	torn.AnchorPoint = Vector2.new(0.5, 0.5)
	torn.Size = UDim2.fromScale(p, 1)
	torn.Position = UDim2.fromScale(center.X / width, center.Y / height)
	torn.Rotation = math.deg(angle)

	-- Each ridge goes with the piece it is on
	for i = 1, CRIMP_LINES do
		local ridge = (torn:FindFirstChild("Ridge" .. i) or rest:FindFirstChild("Ridge" .. i)) :: Frame
		local x = (i - 0.5) / CRIMP_LINES
		if x < p then
			ridge.Parent = torn
			ridge.Position = UDim2.fromScale(x / p, 0.5)
		else
			ridge.Parent = rest
			ridge.Position = UDim2.fromScale((x - p) / math.max(1 - p, 0.001), 0.5)
		end
	end
	for i = 1, TEAR_BITS do
		(line:FindFirstChild("Bit" .. i) :: Frame).Visible = (i - 0.5) / TEAR_BITS <= p
	end
	return torn
end

-- Builds the pack inside `parent` (filling it). The top seal is named "Top" so the opening
-- can tear it off (see tearableTop).
function PackArt.build(parent: Instance, pack: Config.Pack, zIndex: number?): Frame
	local z = zIndex or 1
	local frame = new("Frame", { Name = "Pack", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = z }, parent)

	local body = new("Frame", { Name = "Body", Position = UDim2.fromScale(0.02, 0.06), Size = UDim2.fromScale(0.96, 0.88), BackgroundColor3 = WHITE, ZIndex = z }, frame)
	new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, body)
	new("UIStroke", { Thickness = 3, Color = DARK }, body)
	new("UIGradient", { Rotation = 70, Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, pack.color:Lerp(WHITE, 0.35)),
		ColorSequenceKeypoint.new(0.45, pack.color),
		ColorSequenceKeypoint.new(1, pack.color:Lerp(DARK, 0.45)),
	}) }, body)
	-- Foil shine across the bag: a diagonal band drawn by a gradient on a frame the size of the
	-- bag, so it stays inside its rounded edges (a turned frame would stick out above and below)
	local shine = new("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = z + 1 }, body)
	new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, shine)
	new("UIGradient", { Rotation = 18, Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.18, 1),
		NumberSequenceKeypoint.new(0.3, 0.72),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(1, 1),
	}) }, shine)

	-- The pack's own illustration, if it has one: it covers the front of the bag
	local art = Config.PACK_ART[pack.id]
	if art then
		local picture = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = "rbxassetid://" .. art, ScaleType = Enum.ScaleType.Crop, ZIndex = z + 2 }, body)
		new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, picture)
		crimp(frame, "Top", true, pack.color, z + 4)
		crimp(frame, "Bottom", false, pack.color, z + 4)
		return frame
	end

	-- The rarest brainrot of the pack in a round window
	local window = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.14), Size = UDim2.fromScale(0.78, 0.5), BackgroundColor3 = DARK, BackgroundTransparency = 0.25, ClipsDescendants = true, ZIndex = z + 2 }, body)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, window)
	new("UIStroke", { Thickness = 3, Color = WHITE, Transparency = 0.15 }, window)
	local cardId = coverCard(pack)
	local templates = ReplicatedStorage:FindFirstChild("AssetTemplates")
	local model = cardId and templates and templates:FindFirstChild(cardId)
	if model and model:IsA("Model") and not parent:IsA("SurfaceGui") then
		local view = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Ambient = Color3.fromRGB(200, 200, 200), LightColor = WHITE, LightDirection = Vector3.new(-1, -1, 1), ZIndex = z + 3 }, window)
		local copy = model:Clone()
		copy.Parent = view
		local box, size = copy:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.FieldOfView = 40
		local direction = Vector3.new(0.35, 0.3, -1).Unit
		camera.CFrame = CFrame.lookAt(box.Position + direction * (size.Magnitude / 2) / math.tan(math.rad(20)) * 0.85, box.Position)
		camera.Parent = view
		view.CurrentCamera = camera
	else
		text(window, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.5), Text = "?", TextColor3 = pack.color:Lerp(WHITE, 0.4), ZIndex = z + 3 })
	end

	-- Name: "BEACH" big, "PACK" under it
	local short = string.upper((string.gsub(pack.name, " Pack$", "")))
	text(body, { Position = UDim2.fromScale(0.06, 0.67), Size = UDim2.fromScale(0.88, 0.15), Text = short, ZIndex = z + 3 })
	text(body, { Position = UDim2.fromScale(0.25, 0.82), Size = UDim2.fromScale(0.5, 0.08), Text = "BRAINROT PACK", TextColor3 = Color3.fromRGB(255, 225, 60), ZIndex = z + 3 })

	tearableTop(frame, pack.color, z + 4)
	crimp(frame, "Bottom", false, pack.color, z + 4)
	return frame
end

return PackArt
