-- The map: spawn in the middle and one plot per player around it
-- (the plaza in the middle is built by Plaza.luau).
-- Each plot has Config.STAND_COUNT stands that show the cards the player placed on them.

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
local FONT = Enum.Font.FredokaOne

type Stand = { base: BasePart, ring: BasePart, light: PointLight, display: Model, key: string? }
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
	outline.Thickness = 2
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
	spawn.Position = Vector3.new(0, 0.6, 18) -- in front of the fountain (Plaza.luau)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = mapFolder

	-- Big floating title in the middle
	local anchor = part({ Name = "Title", Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, 28, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = mapFolder })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(40, 10)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 400
	billboard.Parent = anchor
	label(billboard, { Size = UDim2.fromScale(1, 1), Text = "COLLECT BRAINROT CARDS", TextColor3 = Color3.fromRGB(255, 220, 90) })
end

local function cylinder(props): Part
	props.Shape = Enum.PartType.Cylinder
	return part(props)
end

-- A cylinder standing up: `cframe` is its center, `height` along Y
local function upright(cframe: CFrame): CFrame
	return cframe * CFrame.Angles(0, 0, math.rad(90))
end

-- A round display pedestal: marble base, dark top and a ring that glows with the card's rarity
local function buildStand(plotModel: Model, cframe: CFrame): Stand
	-- Invisible block: the stand's position for the card, the model and the floating info
	local base = part({
		Name = "Stand",
		Size = Vector3.new(7, 1.6, 6),
		CFrame = cframe * CFrame.new(0, 0.8, 0),
		Transparency = 1,
		Parent = plotModel,
	})
	cylinder({ Name = "Pedestal", Size = Vector3.new(1.4, 6.6, 6.6), CFrame = upright(cframe * CFrame.new(0, 0.7, 0)), Color = Color3.fromRGB(235, 232, 240), Material = Enum.Material.Marble, Parent = plotModel })
	cylinder({ Name = "Top", Size = Vector3.new(0.2, 6, 6), CFrame = upright(cframe * CFrame.new(0, 1.5, 0)), Color = Color3.fromRGB(45, 42, 60), Material = Enum.Material.Slate, Parent = plotModel })
	local ring = cylinder({ Name = "Ring", Size = Vector3.new(0.2, 7, 7), CFrame = upright(cframe * CFrame.new(0, 1.45, 0)), Color = Color3.fromRGB(90, 90, 105), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = plotModel })
	local light = Instance.new("PointLight")
	light.Range = 10
	light.Brightness = 1.2
	light.Shadows = false
	light.Enabled = false
	light.Parent = ring
	local display = Instance.new("Model")
	display.Name = "Display"
	display.Parent = plotModel
	return { base = base, ring = ring, light = light, display = display, key = nil }
end

local WOOD = Color3.fromRGB(140, 100, 65)

-- Wooden fence along a line, from `from` to `to` (plot space)
local function buildFence(model: Model, cframe: CFrame, from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	local posts = math.max(1, math.floor(length / 6))
	local direction = (to - from).Unit
	for i = 0, posts do
		local position = from + direction * (length * i / posts)
		part({ Name = "FencePost", Size = Vector3.new(0.8, 3.2, 0.8), CFrame = cframe * CFrame.new(position + Vector3.new(0, 1.6, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = model })
	end
	local middle = (from + to) / 2
	for _, height in { 1.3, 2.5 } do
		part({
			Name = "FenceRail",
			Size = Vector3.new(0.35, 0.45, length),
			CFrame = cframe * CFrame.lookAt(middle + Vector3.new(0, height, 0), to + Vector3.new(0, height, 0)),
			Color = WOOD:Lerp(Color3.new(1, 1, 1), 0.1),
			Material = Enum.Material.WoodPlanks,
			Parent = model,
		})
	end
end

local function buildPlot(index: number): Plot
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local position = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
	-- -Z of the plot faces the middle of the map
	local cframe = CFrame.lookAt(position, Vector3.zero)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = mapFolder

	-- Tiled floor on a stone curb
	part({ Name = "Curb", Size = Vector3.new(PLOT_WIDTH + 2, 2.5, PLOT_DEPTH + 2), CFrame = cframe * CFrame.new(0, -0.75, 0), Color = Color3.fromRGB(165, 160, 155), Material = Enum.Material.Cobblestone, Parent = model })
	part({ Name = "Floor", Size = Vector3.new(PLOT_WIDTH, 0.6, PLOT_DEPTH), CFrame = cframe * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(215, 175, 130), Material = Enum.Material.WoodPlanks, Parent = model })

	-- Fence on the sides and at the back; the front, facing the plaza, stays open
	local halfW, halfD = PLOT_WIDTH / 2 + 0.5, PLOT_DEPTH / 2 + 0.5
	buildFence(model, cframe, Vector3.new(-halfW, 0.5, -halfD), Vector3.new(-halfW, 0.5, halfD))
	buildFence(model, cframe, Vector3.new(halfW, 0.5, -halfD), Vector3.new(halfW, 0.5, halfD))
	buildFence(model, cframe, Vector3.new(-halfW, 0.5, halfD), Vector3.new(halfW, 0.5, halfD))

	-- Bushes in the back corners, flowers at the front
	for _, side in { -1, 1 } do
		for i, size in { 5, 3.6 } do
			part({
				Name = "Bush",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size, size),
				CFrame = cframe * CFrame.new(side * (PLOT_WIDTH / 2 - 2.5 - (i - 1) * 3.4), 0.6 + size * 0.35, PLOT_DEPTH / 2 - 2.5 - (i - 1) * 1.5),
				Color = Color3.fromRGB(70, 150, 65),
				Material = Enum.Material.Grass,
				Parent = model,
			})
		end
		Assets.place("decor_flowers", model, (cframe * CFrame.new(side * (PLOT_WIDTH / 2 - 2.5), 0.6, -PLOT_DEPTH / 2 + 2.5)).Position)
	end

	-- Owner sign at the back, facing the middle: dark board in a wooden frame
	local signCFrame = cframe * CFrame.new(0, 7.5, PLOT_DEPTH / 2 - 1.5)
	part({ Name = "SignFrame", Size = Vector3.new(23.2, 8.2, 0.8), CFrame = signCFrame * CFrame.new(0, 0, 0.3), Color = WOOD, Material = Enum.Material.Wood, Parent = model })
	local board = part({ Name = "Sign", Size = Vector3.new(22, 7, 0.6), CFrame = signCFrame, Color = Color3.fromRGB(35, 32, 50), Material = Enum.Material.SmoothPlastic, Parent = model })
	for _, x in { -10, 10 } do
		part({ Name = "SignPost", Size = Vector3.new(1, 4, 1), CFrame = cframe * CFrame.new(x, 2.4, PLOT_DEPTH / 2 - 1.2), Color = WOOD, Material = Enum.Material.Wood, Parent = model })
	end
	local gui = surfaceGui(board, Enum.NormalId.Front, 30)
	local sign = label(gui, { Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.5), Text = "Free plot" })
	local income = label(gui, { Position = UDim2.fromScale(0.05, 0.6), Size = UDim2.fromScale(0.9, 0.32), Text = "", TextColor3 = Color3.fromRGB(120, 255, 140) })

	-- Two rows of stands
	local stands = {}
	local perRow = math.ceil(Config.STAND_COUNT / 2)
	for slot = 1, Config.STAND_COUNT do
		local row = if slot <= perRow then 0 else 1
		local column = (slot - 1) % perRow
		local x = (column - (perRow - 1) / 2) * 10
		local z = -6 + row * 13
		stands[slot] = buildStand(model, cframe * CFrame.new(x, 0.6, z))
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

	-- The card itself, standing at the front of the pedestal
	local cardPart = part({
		Name = "Card",
		Size = Vector3.new(3, 4.2, 0.12),
		CFrame = top * CFrame.new(0, 2.4, -2.1) * CFrame.Angles(math.rad(-12), 0, 0),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = stand.display,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = surfaceGui(cardPart, face, 70)
		CardArt.build(gui, cardId, variantId, grade)
	end
	if variantId == "holo" or variantId == "rainbow" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = color
		sparkles.Parent = cardPart
	end

	-- The brainrot model, if it could be loaded
	local _, yaw = top:ToOrientation()
	Assets.place(cardId, stand.display, (top * CFrame.new(0, 0, 0.8)).Position, yaw)

	-- Floating info
	local billboard = Instance.new("BillboardGui")
	-- Sized in studs: it gets smaller with distance, so the 8 labels of a plot don't pile up
	billboard.Size = UDim2.fromScale(7, 2.2)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 8, 0)
	billboard.MaxDistance = 35
	billboard.LightInfluence = 0
	billboard.Adornee = stand.base
	billboard.Parent = stand.display
	local prefix = if variantId == "normal" then "" else variant.name .. " "
	local suffix = if grade then " [" .. grade.grade .. "]" else ""
	label(billboard, { Size = UDim2.new(1, 0, 0.55, 0), Text = prefix .. card.name .. suffix, TextColor3 = color })
	label(billboard, { Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, 0, 0.45, 0), Text = "$" .. Format.number(Config.keyIncome(key)) .. "/s", TextColor3 = Color3.fromRGB(120, 255, 140) })
end

local function setStand(stand: Stand, key: string?)
	if stand.key == key then
		return
	end
	stand.key = key
	stand.display:ClearAllChildren()
	stand.ring.Color = Color3.fromRGB(90, 90, 105)
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
			plot.sign.Text = player.DisplayName .. "'s Plot"
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
	plot.sign.Text = "Free plot"
	plot.income.Text = ""
	for _, stand in plot.stands do
		setStand(stand, nil)
	end
end

-- Shows the player's stands as saved in their profile
function Plots.refresh(player: Player, stands: { [string]: string })
	local plot = plotOf(player)
	if not plot then
		return
	end
	for slot, stand in plot.stands do
		setStand(stand, stands[tostring(slot)])
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
