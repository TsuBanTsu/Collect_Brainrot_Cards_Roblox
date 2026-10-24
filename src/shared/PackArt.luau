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

-- A crimped strip (the sealed edge of the bag)
local function crimp(parent: Instance, name: string, top: boolean, color: Color3, z: number): Frame
	local strip = new("Frame", { Name = name, AnchorPoint = Vector2.new(0, if top then 0 else 1), Position = UDim2.fromScale(0, if top then 0 else 1), Size = UDim2.fromScale(1, 0.09), BackgroundColor3 = color:Lerp(DARK, 0.35), ZIndex = z }, parent)
	new("UICorner", { CornerRadius = UDim.new(0.25, 0) }, strip)
	new("UIStroke", { Thickness = 2, Color = DARK, Transparency = 0.2 }, strip)
	-- The little ridges of the seal
	for i = 1, 14 do
		new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale((i - 0.5) / 14, 0.5), Size = UDim2.fromScale(0.025, 0.6), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = z + 1 }, strip)
	end
	return strip
end

-- Builds the pack inside `parent` (filling it). The top seal is named "Top" so the opening
-- can tear it off.
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
	-- Foil shine across the bag
	local shine = new("Frame", { Name = "Shine", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.3, 0.5), Size = UDim2.fromScale(0.25, 1.3), Rotation = 18, BackgroundColor3 = WHITE, BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = z + 1 }, body)
	new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 1) }) }, shine)

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

	crimp(frame, "Top", true, pack.color, z + 4)
	crimp(frame, "Bottom", false, pack.color, z + 4)
	return frame
end

return PackArt
