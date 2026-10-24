-- The map: spawn in the middle and one plot per player around it
-- (the plaza in the middle is built by Plaza.luau).
-- Each plot has Config.STAND_COUNT stands that show the cards the player placed on them.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Format = require(ReplicatedStorage.Shared.Format)
local Assets = require(script.Parent.Assets)

local Plots = {}

local PLOT_COUNT = 6 -- server size
local PLOT_RADIUS = 78 -- distance from the middle of the map
local PLOT_WIDTH = 46
local PLOT_DEPTH = 38
local MODEL_HEIGHT = 6.5 -- the brainrot floating in front of its card, like a hologram
local MODEL_HOVER = 0.8 -- how high it floats above the projector
local MODEL_MAX_DEPTH = 4.5 -- deeper brainrot models are shrunk to fit in front of the card
local MODEL_MAX_WIDTH = 7 -- and wider ones so they don't reach the next stand (10 studs apart)
local CARD_SIZE = Vector3.new(4.6, 6.4, 0.12) -- the card standing at the back of the pedestal
local FONT = Enum.Font.FredokaOne

type Stand = { base: BasePart, ring: BasePart, light: PointLight, display: Model, lock: BillboardGui, key: string?, color: Color3, lift: number }
type Plot = { index: number, cframe: CFrame, model: Model, owner: Player?, stands: { Stand }, sign: TextLabel, income: TextLabel }

local plots: { Plot } = {}
local mapFolder: Folder

local function part(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Parent" then
			(p :: any)[key] = value
		end
	end
	p.Parent = props.Parent
	return p
end

local function label(parent: Instance, props): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = FONT
	l.TextScaled = true
	l.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(l :: any)[key] = value
	end
	local outline = Instance.new("UIStroke")
	outline.Thickness = 3
	outline.Parent = l
	l.Parent = parent
	return l
end

local function surfaceGui(target: BasePart, face: Enum.NormalId, pixelsPerStud: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.Parent = target
	return gui
end

---------------------------------------------------------------------------
-- Building the map
---------------------------------------------------------------------------
local function buildCenter()
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.6, 18) -- in front of the statue (Plaza.luau)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = mapFolder

	-- Big floating title in the middle
	local anchor = part({ Name = "Title", Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, 42, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = mapFolder })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(30, 7.5)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 400
	billboard.Parent = anchor
	label(billboard, { Size = UDim2.fromScale(1, 1), Text = "COLLECT BRAINROT CARDS", TextColor3 = Color3.fromRGB(255, 220, 90) })
end

-- A square podium in the plot's color, with a strip that glows with the card's rarity
local function buildStand(plotModel: Model, cframe: CFrame, color: Color3, lift: number): Stand
	-- Invisible block: the stand's position for the card, the model and the floating info
	local base = part({
		Name = "Stand",
		Size = Vector3.new(7, 1.6, 6),
		CFrame = cframe * CFrame.new(0, 0.8, 0),
		Transparency = 1,
		Parent = plotModel,
	})
	part({ Name = "Podium", Size = Vector3.new(7, 1.3, 6), CFrame = cframe * CFrame.new(0, 0.65, 0), Color = color:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.SmoothPlastic, Parent = plotModel })
	part({ Name = "Top", Size = Vector3.new(6.4, 0.3, 5.4), CFrame = cframe * CFrame.new(0, 1.45, 0), Color = Color3.fromRGB(245, 245, 250), Material = Enum.Material.SmoothPlastic, Parent = plotModel })
	local ring = part({ Name = "Ring", Size = Vector3.new(7.3, 0.25, 6.3), CFrame = cframe * CFrame.new(0, 1.3, 0), Color = color:Lerp(Color3.new(1, 1, 1), 0.4), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = plotModel })
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.5
	light.Shadows = false
	light.Enabled = false
	light.Parent = ring
	local display = Instance.new("Model")
	display.Name = "Display"
	display.Parent = plotModel
	-- Shown on stands the owner hasn't unlocked yet (upgrade tree: Stand Builder)
	local lock = Instance.new("BillboardGui")
	lock.Size = UDim2.fromScale(5, 1.6)
	lock.StudsOffsetWorldSpace = Vector3.new(0, 2.5, 0)
	lock.MaxDistance = 50
	lock.LightInfluence = 0
	lock.Enabled = false
	lock.Adornee = base
	lock.Parent = plotModel
	label(lock, { Size = UDim2.fromScale(1, 1), Text = "🔒 UPGRADES", TextColor3 = Color3.fromRGB(220, 220, 230) })
	return { base = base, ring = ring, light = light, display = display, lock = lock, key = nil, color = color, lift = lift }
end

local function buildPlot(index: number): Plot
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local position = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
	-- -Z of the plot faces the middle of the map
	local cframe = CFrame.lookAt(position, Vector3.zero)
	local color = Config.PLOT_COLORS[(index - 1) % #Config.PLOT_COLORS + 1]
	local white = Color3.fromRGB(248, 248, 252)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = mapFolder

	-- Studded floor in a slightly lighter shade of the plot's color, on a base in the plot's color
	part({ Name = "Curb", Size = Vector3.new(PLOT_WIDTH + 2, 2.5, PLOT_DEPTH + 2), CFrame = cframe * CFrame.new(0, -0.75, 0), Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "Floor", Size = Vector3.new(PLOT_WIDTH, 0.6, PLOT_DEPTH), CFrame = cframe * CFrame.new(0, 0.3, 0), Color = color:Lerp(white, 0.2), Material = Enum.Material.Plastic, TopSurface = Enum.SurfaceType.Studs, Parent = model })

	-- Low walls on the sides with a white trim; the front, facing the plaza, stays open
	local halfW, halfD = PLOT_WIDTH / 2 + 0.25, PLOT_DEPTH / 2 + 0.25
	for _, side in { -1, 1 } do
		part({ Name = "Wall", Size = Vector3.new(1.5, 4, PLOT_DEPTH + 2), CFrame = cframe * CFrame.new(side * halfW, 2.5, 0), Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({ Name = "Trim", Size = Vector3.new(1.9, 0.6, PLOT_DEPTH + 2.4), CFrame = cframe * CFrame.new(side * halfW, 4.8, 0), Color = white, Material = Enum.Material.SmoothPlastic, Parent = model })
	end
	-- Back wall: a tall facade that carries the owner's sign, high above the stands' labels
	part({ Name = "BackWall", Size = Vector3.new(PLOT_WIDTH + 3, 24, 1.5), CFrame = cframe * CFrame.new(0, 12.5, halfD), Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "BackTrim", Size = Vector3.new(PLOT_WIDTH + 3.4, 0.8, 1.9), CFrame = cframe * CFrame.new(0, 24.6, halfD), Color = white, Material = Enum.Material.SmoothPlastic, Parent = model })
	for _, x in { -1, 1 } do
		part({ Name = "Pillar", Size = Vector3.new(2.2, 25, 2.2), CFrame = cframe * CFrame.new(x * (PLOT_WIDTH / 2 + 0.5), 12.6, halfD), Color = color:Lerp(Color3.new(0, 0, 0), 0.25), Material = Enum.Material.SmoothPlastic, Parent = model })
	end

	-- Bushes in the back corners, flowers at the front
	for _, side in { -1, 1 } do
		for i, size in { 5, 3.6 } do
			local bushPosition = (cframe * CFrame.new(side * (PLOT_WIDTH / 2 - 2.5 - (i - 1) * 3.4), 0.6, PLOT_DEPTH / 2 - 2.5 - (i - 1) * 1.5)).Position
			if Assets.place("decor_bush", model, bushPosition, side * i, size) then
				continue
			end
			part({
				Name = "Bush",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = cframe * CFrame.new(side * (PLOT_WIDTH / 2 - 2.5 - (i - 1) * 3.4), 0.6 + size * 0.35, PLOT_DEPTH / 2 - 2.5 - (i - 1) * 1.5),
				Color = Color3.fromRGB(60, 190, 70),
				Material = Enum.Material.SmoothPlastic,
				Parent = model,
			})
		end
		Assets.place("decor_flowers", model, (cframe * CFrame.new(side * (PLOT_WIDTH / 2 - 2.5), 0.6, -PLOT_DEPTH / 2 + 2.5)).Position)
	end

	-- Owner sign on the facade: a light board with dark text, like a shop sign
	local signCFrame = cframe * CFrame.new(0, 19.5, halfD - 1)
	part({ Name = "SignFrame", Size = Vector3.new(25, 7.6, 0.6), CFrame = signCFrame * CFrame.new(0, 0, 0.1), Color = Color3.fromRGB(120, 80, 50), Material = Enum.Material.SmoothPlastic, Parent = model })
	local board = part({ Name = "Sign", Size = Vector3.new(24, 6.6, 0.6), CFrame = signCFrame * CFrame.new(0, 0, -0.1), Color = Color3.fromRGB(245, 230, 195), Material = Enum.Material.SmoothPlastic, Parent = model })
	local gui = surfaceGui(board, Enum.NormalId.Front, 30)
	local sign = label(gui, { Position = UDim2.fromScale(0.04, 0.1), Size = UDim2.fromScale(0.92, 0.8), Text = "Free Base", TextColor3 = Color3.fromRGB(110, 70, 40) })
	local signStroke = sign:FindFirstChildOfClass("UIStroke")
	if signStroke then
		signStroke:Destroy()
	end

	-- Huge income counter floating above the base
	local anchor = part({ Name = "IncomeAnchor", Size = Vector3.new(1, 1, 1), CFrame = cframe * CFrame.new(0, 27, halfD), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(30, 6)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 300
	billboard.Parent = anchor
	local income = label(billboard, { Size = UDim2.fromScale(1, 1), Text = "", TextColor3 = Color3.new(1, 1, 1) })
	local incomeStroke = income:FindFirstChildOfClass("UIStroke")
	if incomeStroke then
		incomeStroke.Thickness = 4
	end

	-- Three rows of 4 stands (the last ones are unlocked in the upgrade tree)
	local stands = {}
	local perRow = 4
	for slot = 1, Config.STAND_COUNT do
		local row = (slot - 1) // perRow
		local column = (slot - 1) % perRow
		local x = (column - (perRow - 1) / 2) * 10
		local z = -10 + row * 10.5
		-- The back rows' labels float a bit higher, so they don't sit behind the front row's
		stands[slot] = buildStand(model, cframe * CFrame.new(x, 0.6, z), color, row * 2)
	end

	return { index = index, cframe = cframe, model = model, owner = nil, stands = stands, sign = sign, income = income }
end

-- The folder that holds the map, for the other map builders
function Plots.folder(): Folder
	return mapFolder
end

function Plots.init()
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace
	buildCenter()
	for index = 1, PLOT_COUNT do
		plots[index] = buildPlot(index)
	end
end

---------------------------------------------------------------------------
-- What a stand shows
---------------------------------------------------------------------------
local function showCard(stand: Stand, key: string)
	local cardId, variantId = Config.splitKey(key)
	local card = Config.CARDS[cardId]
	local rarity = Config.RARITY[card.rarity]
	local variant = Config.VARIANT[variantId] or Config.NORMAL_VARIANT
	local grade = Config.keyGrade(key)
	local color = if variantId == "normal" then rarity.color else variant.color
	local top = stand.base.CFrame * CFrame.new(0, stand.base.Size.Y / 2, 0)

	-- The pedestal's ring glows with the card's color
	stand.ring.Color = color
	stand.ring.Material = Enum.Material.Neon
	stand.light.Color = color
	stand.light.Enabled = true

	-- The card itself, standing up at the back of the pedestal, tilted back a little
	local cardPart = part({
		Name = "Card",
		Size = CARD_SIZE,
		CFrame = top * CFrame.new(0, CARD_SIZE.Y / 2 + 0.2, 2.2) * CFrame.Angles(math.rad(8), 0, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = stand.display,
	})
	-- Its face is drawn by each player's client, like the cards of the UI (StandCards.client.luau)
	cardPart:SetAttribute("CardKey", key)
	CollectionService:AddTag(cardPart, "StandCard")
	if variantId == "holo" or variantId == "rainbow" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = cardPart
	end

	-- The brainrot floats in front of its card, as if the card projected it: a glowing
	-- projector disc under it and a beam of light from the card to it
	local projector = part({
		Name = "Projector",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 4.4, 4.4),
		CFrame = top * CFrame.new(0, 0.08, -0.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		Parent = stand.display,
	})
	local model = Assets.get(cardId, MODEL_HEIGHT)
	if model then
		local size = model:GetExtentsSize()
		local fit = math.min(1, MODEL_MAX_DEPTH / size.Z, MODEL_MAX_WIDTH / size.X)
		if fit < 1 then
			model:ScaleTo(model:GetScale() * fit)
		end
		local _, yaw = top:ToOrientation()
		model:PivotTo(CFrame.new((top * CFrame.new(0, MODEL_HOVER, -0.6)).Position) * CFrame.Angles(0, yaw, 0))
		model.Parent = stand.display
		-- Bobs gently on the player's screen (Ambient.client.luau)
		CollectionService:AddTag(model, "AmbientHover")

		local from = Instance.new("Attachment")
		from.Parent = cardPart
		local to = Instance.new("Attachment")
		to.Parent = projector
		to.WorldPosition = (top * CFrame.new(0, MODEL_HOVER + size.Y * fit / 2, -0.6)).Position
		local beam = Instance.new("Beam")
		beam.Attachment0 = from
		beam.Attachment1 = to
		beam.Width0 = CARD_SIZE.X * 0.8
		beam.Width1 = math.max(2, size.X * fit)
		beam.FaceCamera = true
		beam.Color = ColorSequence.new(color)
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0.75, 0.9)
		beam.Segments = 1
		beam.Parent = cardPart
	end

	-- Sparkles around rare cards and shiny variants
	if Config.RARITY[card.rarity].order >= Config.RARITY.legendary.order or variantId ~= "normal" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		emitter.Lifetime = NumberRange.new(1, 1.8)
		emitter.Speed = NumberRange.new(1.5, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rate = 4 + Config.RARITY[card.rarity].order * 2
		emitter.Parent = cardPart
	end

	-- Floating info, like the big brainrot games: name, rarity in its color, Cash per second.
	-- Sized in studs: it gets smaller with distance, so the 8 labels of a plot don't pile up
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(7, 2.8)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, CARD_SIZE.Y + 3.5 + stand.lift, 0)
	billboard.MaxDistance = 40
	billboard.LightInfluence = 0
	billboard.Adornee = stand.base
	billboard.Parent = stand.display
	local prefix = if variantId == "normal" then "" else variant.name .. " "
	local suffix = if grade then " [" .. grade.grade .. "]" else ""
	label(billboard, { Size = UDim2.fromScale(1, 0.36), Text = prefix .. card.name .. suffix })
	local rarityLabel = label(billboard, { Position = UDim2.fromScale(0, 0.36), Size = UDim2.fromScale(1, 0.3), Text = string.upper(rarity.name), TextColor3 = rarity.color })
	if rarity.order >= Config.RARITY.secret.order then
		-- The top rarities get a rainbow name
		rarityLabel.TextColor3 = Color3.new(1, 1, 1)
		local gradient = Instance.new("UIGradient")
		gradient.Color = CardArt.frameColors(cardId, "rainbow")
		gradient.Parent = rarityLabel
	end
	label(billboard, { Position = UDim2.fromScale(0, 0.66), Size = UDim2.fromScale(1, 0.34), Text = "$" .. Format.number(Config.keyIncome(key)) .. "/s", TextColor3 = Color3.fromRGB(255, 225, 60) })
end

local function setStand(stand: Stand, key: string?)
	if stand.key == key then
		return
	end
	stand.key = key
	stand.display:ClearAllChildren()
	stand.ring.Color = stand.color:Lerp(Color3.new(1, 1, 1), 0.4)
	stand.ring.Material = Enum.Material.SmoothPlastic
	stand.light.Enabled = false
	if key then
		showCard(stand, key)
	end
end

---------------------------------------------------------------------------
-- Owners
---------------------------------------------------------------------------
local function plotOf(player: Player): Plot?
	for _, plot in plots do
		if plot.owner == player then
			return plot
		end
	end
	return nil
end

function Plots.assign(player: Player): boolean
	for _, plot in plots do
		if not plot.owner then
			plot.owner = player
			plot.sign.Text = player.DisplayName .. "'s Base"
			player:SetAttribute("Plot", plot.index)
			return true
		end
	end
	return false
end

function Plots.release(player: Player)
	local plot = plotOf(player)
	if not plot then
		return
	end
	plot.owner = nil
	plot.sign.Text = "Free Base"
	plot.income.Text = ""
	for _, stand in plot.stands do
		setStand(stand, nil)
		stand.lock.Enabled = false
	end
end

-- Shows the player's stands as saved in their profile; stands past `unlocked` show a lock
function Plots.refresh(player: Player, stands: { [string]: string }, unlocked: number)
	local plot = plotOf(player)
	if not plot then
		return
	end
	for slot, stand in plot.stands do
		setStand(stand, stands[tostring(slot)])
		stand.lock.Enabled = slot > unlocked
	end
end

function Plots.setIncome(player: Player, income: number)
	local plot = plotOf(player)
	if plot then
		plot.income.Text = "$" .. Format.number(income) .. "/s"
	end
end

-- Where the player appears: at the front of their plot, facing the stands
function Plots.spawnCFrame(player: Player): CFrame?
	local plot = plotOf(player)
	if not plot then
		return nil
	end
	return plot.cframe * CFrame.new(0, 4, -PLOT_DEPTH / 2 + 3) * CFrame.Angles(0, math.pi, 0)
end

return Plots
