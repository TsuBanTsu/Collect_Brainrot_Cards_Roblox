-- The map: ground, spawn in the middle and one plot per player around it.
-- Each plot has Config.STAND_COUNT stands that show the cards the player placed on them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Assets = require(script.Parent.Assets)

local Plots = {}

local PLOT_COUNT = 6 -- server size
local PLOT_RADIUS = 78 -- distance from the middle of the map
local PLOT_WIDTH = 46
local PLOT_DEPTH = 38
local FONT = Enum.Font.FredokaOne

type Stand = { base: BasePart, display: Model, key: string? }
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
	part({ Name = "Ground", Size = Vector3.new(420, 2, 420), Position = Vector3.new(0, -1, 0), Color = Color3.fromRGB(95, 185, 95), Material = Enum.Material.Grass, Parent = mapFolder })
	part({ Name = "Plaza", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 70, 70), CFrame = CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Concrete, Parent = mapFolder })

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, 0.6, 0)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = mapFolder

	-- Big floating title in the middle
	local anchor = part({ Name = "Title", Size = Vector3.new(1, 1, 1), Position = Vector3.new(0, 22, 0), Transparency = 1, CanCollide = false, CanQuery = false, Parent = mapFolder })
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(40, 10)
	billboard.LightInfluence = 0
	billboard.MaxDistance = 400
	billboard.Parent = anchor
	label(billboard, { Size = UDim2.fromScale(1, 1), Text = "COLLECT BRAINROT CARDS", TextColor3 = Color3.fromRGB(255, 220, 90) })
end

local function buildStand(plotModel: Model, cframe: CFrame): Stand
	local base = part({
		Name = "Stand",
		Size = Vector3.new(7, 1.6, 6),
		CFrame = cframe * CFrame.new(0, 0.8, 0),
		Color = Color3.fromRGB(60, 60, 80),
		Material = Enum.Material.SmoothPlastic,
		Parent = plotModel,
	})
	part({ Name = "Trim", Size = Vector3.new(7.3, 0.3, 6.3), CFrame = base.CFrame * CFrame.new(0, 0.85, 0), Color = Color3.fromRGB(255, 210, 80), Material = Enum.Material.Neon, CanCollide = false, Parent = plotModel })
	local display = Instance.new("Model")
	display.Name = "Display"
	display.Parent = plotModel
	return { base = base, display = display, key = nil }
end

local function buildPlot(index: number): Plot
	local angle = (index - 1) / PLOT_COUNT * math.pi * 2
	local position = Vector3.new(math.cos(angle) * PLOT_RADIUS, 0, math.sin(angle) * PLOT_RADIUS)
	-- -Z of the plot faces the middle of the map
	local cframe = CFrame.lookAt(position, Vector3.zero)

	local model = Instance.new("Model")
	model.Name = "Plot" .. index
	model.Parent = mapFolder

	part({ Name = "Floor", Size = Vector3.new(PLOT_WIDTH, 0.6, PLOT_DEPTH), CFrame = cframe * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(240, 235, 220), Material = Enum.Material.WoodPlanks, Parent = model })
	for _, side in { -1, 1 } do
		part({ Name = "Border", Size = Vector3.new(1, 1.4, PLOT_DEPTH), CFrame = cframe * CFrame.new(side * (PLOT_WIDTH / 2 - 0.5), 0.7, 0), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood, Parent = model })
	end

	-- Owner sign at the back, facing the middle
	local board = part({ Name = "Sign", Size = Vector3.new(22, 7, 1), CFrame = cframe * CFrame.new(0, 7, PLOT_DEPTH / 2 - 1), Color = Color3.fromRGB(45, 45, 65), Parent = model })
	part({ Name = "Post", Size = Vector3.new(1, 4, 1), CFrame = cframe * CFrame.new(0, 2, PLOT_DEPTH / 2 - 1), Color = Color3.fromRGB(120, 90, 60), Parent = model })
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
local function variantLook(card: Part, gui: SurfaceGui, variantId: string)
	if variantId == "gold" then
		card.Color = Color3.fromRGB(255, 200, 50)
		card.Material = Enum.Material.Foil
	elseif variantId == "rainbow" then
		local background = Instance.new("Frame")
		background.Size = UDim2.fromScale(1, 1)
		background.ZIndex = 0
		background.BackgroundColor3 = Color3.new(1, 1, 1)
		background.Parent = gui
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = 45
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
		})
		gradient.Parent = background
	elseif variantId == "holo" then
		card.Color = Color3.fromRGB(120, 255, 240)
		card.Material = Enum.Material.Neon
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.fromRGB(200, 255, 255)
		sparkles.Parent = card
	end
end

local function showCard(stand: Stand, key: string)
	local cardId, variantId = Config.splitKey(key)
	local card = Config.CARDS[cardId]
	local rarity = Config.RARITY[card.rarity]
	local variant = Config.VARIANT[variantId] or Config.NORMAL_VARIANT
	local top = stand.base.CFrame * CFrame.new(0, stand.base.Size.Y / 2, 0)

	-- The card itself, standing at the front of the stand
	local cardPart = part({
		Name = "Card",
		Size = Vector3.new(3.2, 4.4, 0.25),
		CFrame = top * CFrame.new(0, 2.5, -1.9) * CFrame.Angles(math.rad(-12), 0, 0),
		Color = rarity.color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
		Parent = stand.display,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = surfaceGui(cardPart, face, 60)
		variantLook(cardPart, gui, variantId)
		label(gui, { Position = UDim2.fromScale(0.06, 0.06), Size = UDim2.fromScale(0.88, 0.3), Text = card.name, TextWrapped = true, ZIndex = 2 })
		label(gui, { Position = UDim2.fromScale(0.06, 0.6), Size = UDim2.fromScale(0.88, 0.14), Text = rarity.name, TextColor3 = rarity.color, ZIndex = 2 })
		if variantId ~= "normal" then
			label(gui, { Position = UDim2.fromScale(0.06, 0.78), Size = UDim2.fromScale(0.88, 0.14), Text = variant.name, TextColor3 = variant.color, ZIndex = 2 })
		end
	end

	-- The brainrot model, if it could be loaded
	local _, yaw = top:ToOrientation()
	Assets.place(cardId, stand.display, (top * CFrame.new(0, 0, 0.8)).Position, yaw)

	-- Floating info
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 9.5, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.Adornee = stand.base
	billboard.Parent = stand.display
	local prefix = if variantId == "normal" then "" else variant.name .. " "
	label(billboard, { Size = UDim2.new(1, 0, 0.55, 0), Text = prefix .. card.name, TextColor3 = if variantId == "normal" then rarity.color else variant.color })
	label(billboard, { Position = UDim2.fromScale(0, 0.55), Size = UDim2.new(1, 0, 0.45, 0), Text = "$" .. Format.number(Config.cardIncome(cardId, variantId)) .. "/s", TextColor3 = Color3.fromRGB(120, 255, 140) })
end

local function setStand(stand: Stand, key: string?)
	if stand.key == key then
		return
	end
	stand.key = key
	stand.display:ClearAllChildren()
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
