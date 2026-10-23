-- The plaza in the middle of the map: a giant brainrot statue, the paths to the plots, decoration
-- and the 4 stations (Shop, Sell, Grading, Towers), each with a brainrot shopkeeper behind the
-- counter. Each station has a prompt (key E) that opens its panel on the player's screen; the
-- server checks the player is close before acting.
-- What moves (the statue, the floating cards, the shopkeepers) is tagged and animated by
-- Ambient.client.luau on each player's side, so it moves smoothly.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(script.Parent.Assets)
local Config = require(ReplicatedStorage.Shared.Config)

local Plaza = {}

local RADIUS = 42 -- size of the plaza
local STATION_RADIUS = 30 -- distance of the stations from the middle
local PLOT_COUNT = 6 -- same as Plots.luau: the paths lead to the plots
local PLOT_INNER = 59 -- where the plots start (PLOT_RADIUS - PLOT_DEPTH / 2 in Plots.luau)
local USE_DISTANCE = 18 -- how close a player must be to use a station
local FLOOR = 0.6 -- height of the plaza's floor
local FONT = Enum.Font.FredokaOne
local COUNTER_TOP = FLOOR + 3.9 -- top of the booths' counters
local KEEPER_DEPTH = 4.4 -- room for the shopkeeper between the counter and the back of the booth
local KEEPER_SHOWN = 3.5 -- how much of the shopkeeper shows above the counter, at least

export type Station = { id: string, name: string, color: Color3, angle: number, prop: string?, prompt: string }

-- Placed between the plots (the plots are at 0, 60, 120... degrees)
Plaza.STATIONS = {
	{ id = "shop", name = "PACK SHOP", color = Color3.fromRGB(90, 200, 120), angle = 270, prop = "decor_chest", prompt = "Buy packs" },
	{ id = "sell", name = "SELL", color = Color3.fromRGB(255, 190, 60), angle = 30, prop = "decor_register", prompt = "Sell cards" },
	{ id = "grade", name = "GRADING", color = Color3.fromRGB(170, 110, 255), angle = 150, prop = "decor_magnifier", prompt = "Grade cards" },
	{ id = "towers", name = "TOWERS", color = Color3.fromRGB(255, 80, 90), angle = 90, prompt = "Fight in the towers" },
} :: { Station }

local positions: { [string]: Vector3 } = {}
local corners: { [string]: { left: Vector3, right: Vector3 } } = {} -- tops of each booth's front pillars
local folder: Folder

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
	p.Parent = props.Parent or folder
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

-- A Creator Store model if it loaded, otherwise nil (the caller builds a simple shape)
local function decor(key: string, position: Vector3, yaw: number?): Model?
	return Assets.place(key, folder, position, yaw)
end

local function cylinder(name: string, position: Vector3, diameter: number, height: number, color: Color3, material: Enum.Material): Part
	return part({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = material,
	})
end

---------------------------------------------------------------------------
-- Decoration
---------------------------------------------------------------------------
-- The centerpiece: a giant statue of a brainrot on a golden pedestal, turning slowly
local function buildStatue()
	local gold = Color3.fromRGB(255, 200, 60)
	part({ Name = "PedestalBase", Size = Vector3.new(14, 1.2, 14), Position = Vector3.new(0, FLOOR + 0.6, 0), Color = Color3.fromRGB(240, 240, 245), Material = Enum.Material.SmoothPlastic })
	part({ Name = "PedestalMiddle", Size = Vector3.new(11, 2.4, 11), Position = Vector3.new(0, FLOOR + 2.4, 0), Color = gold, Material = Enum.Material.SmoothPlastic })
	part({ Name = "PedestalTop", Size = Vector3.new(12.5, 0.8, 12.5), Position = Vector3.new(0, FLOOR + 4, 0), Color = Color3.fromRGB(240, 240, 245), Material = Enum.Material.SmoothPlastic })
	local statue = Assets.place(Config.CENTER_STATUE.card, folder, Vector3.new(0, FLOOR + 4.4, 0), 0, Config.CENTER_STATUE.height)
	if not statue then
		return
	end
	statue.Name = "CenterStatue"
	statue:SetAttribute("Speed", 0.4)
	CollectionService:AddTag(statue, "AmbientSpin")
end

-- Giant cards floating around the statue, showing their back (the game's logo)
local function buildFloatingCards()
	local count = 6
	local colors = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(255, 190, 60), Color3.fromRGB(90, 200, 120), Color3.fromRGB(80, 170, 255), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 110, 200) }
	for i = 1, count do
		local color = colors[(i - 1) % #colors + 1]
		local card = part({ Name = "FloatingCard", Size = Vector3.new(3.6, 5, 0.25), Position = Vector3.new(0, FLOOR + 11, 0), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CastShadow = false })
		for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 40
			gui.LightInfluence = 0
			gui.Parent = card
			local inner = Instance.new("Frame")
			inner.AnchorPoint = Vector2.new(0.5, 0.5)
			inner.Position = UDim2.fromScale(0.5, 0.5)
			inner.Size = UDim2.fromScale(0.84, 0.88)
			inner.BackgroundColor3 = Color3.fromRGB(35, 30, 55)
			inner.Parent = gui
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0.08, 0)
			corner.Parent = inner
			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.new(1, 1, 1)
			stroke.Thickness = 4
			stroke.Parent = inner
			label(inner, { Position = UDim2.fromScale(0.1, 0.18), Size = UDim2.fromScale(0.8, 0.45), Text = "?", TextColor3 = color })
			label(inner, { Position = UDim2.fromScale(0.08, 0.68), Size = UDim2.fromScale(0.84, 0.16), Text = "BRAINROT", TextColor3 = Color3.new(1, 1, 1) })
		end
		card:SetAttribute("Radius", 17)
		card:SetAttribute("Height", FLOOR + 13)
		card:SetAttribute("Phase", (i - 1) / count * math.pi * 2)
		card:SetAttribute("Speed", 0.35)
		CollectionService:AddTag(card, "AmbientOrbit")
	end
end

-- A string of colored pennants hanging between two points, sagging in the middle
local PENNANT_COLORS = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(255, 210, 60), Color3.fromRGB(80, 170, 255), Color3.fromRGB(90, 210, 120), Color3.fromRGB(255, 120, 200) }

local function buildBunting(from: Vector3, to: Vector3, sag: number)
	local function at(t: number): Vector3
		return from:Lerp(to, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local length = flat.Magnitude
	local segments = math.max(6, math.floor(length / 3))
	for i = 1, segments do
		local a, b = at((i - 1) / segments), at(i / segments)
		part({ Name = "Rope", Size = Vector3.new(0.15, 0.15, (b - a).Magnitude + 0.05), CFrame = CFrame.lookAt((a + b) / 2, b), Color = Color3.fromRGB(250, 250, 250), Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, CastShadow = false })
	end
	-- Pennants: two wedges side by side make a triangle pointing down
	local count = math.floor(length / 2.6)
	for i = 1, count - 1 do
		local top = at(i / count)
		local frame = CFrame.lookAt(top, top + flat)
		local color = PENNANT_COLORS[(i - 1) % #PENNANT_COLORS + 1]
		for _, side in { -1, 1 } do
			local wedge = Instance.new("WedgePart")
			wedge.Anchored = true
			wedge.CanCollide = false
			wedge.CanQuery = false
			wedge.CastShadow = false
			wedge.Size = Vector3.new(0.1, 1.8, 0.75)
			wedge.Color = color
			wedge.Material = Enum.Material.SmoothPlastic
			local turn = if side == 1 then CFrame.Angles(0, math.pi, 0) else CFrame.identity
			wedge.CFrame = frame * CFrame.new(0, -0.9, side * 0.375) * turn * CFrame.Angles(math.pi, 0, 0)
			wedge.Parent = folder
		end
	end
end

-- An arch over each path, in the color of the plot it leads to
local function buildArch(index: number)
	local angle = math.rad(index * 60)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local cframe = CFrame.lookAt(direction * (RADIUS + 1), direction * 1000) + Vector3.new(0, FLOOR, 0)
	local color = Config.PLOT_COLORS[index % #Config.PLOT_COLORS + 1]
	local white = Color3.fromRGB(248, 248, 252)
	for _, x in { -6.5, 6.5 } do
		part({ Name = "ArchPillar", Size = Vector3.new(1.8, 11, 1.8), CFrame = cframe * CFrame.new(x, 5.5, 0), Color = color, Material = Enum.Material.SmoothPlastic })
		part({ Name = "ArchFoot", Size = Vector3.new(2.6, 1, 2.6), CFrame = cframe * CFrame.new(x, 0.5, 0), Color = white, Material = Enum.Material.SmoothPlastic })
		part({ Name = "ArchBall", Shape = Enum.PartType.Ball, Size = Vector3.new(2.4, 2.4, 2.4), CFrame = cframe * CFrame.new(x, 13.6, 0), Color = white, Material = Enum.Material.SmoothPlastic })
	end
	part({ Name = "ArchBeam", Size = Vector3.new(15.6, 1.8, 2), CFrame = cframe * CFrame.new(0, 11.6, 0), Color = color, Material = Enum.Material.SmoothPlastic })
	part({ Name = "ArchTrim", Size = Vector3.new(16, 0.4, 2.4), CFrame = cframe * CFrame.new(0, 12.6, 0), Color = white, Material = Enum.Material.SmoothPlastic })
end

local function buildTree(position: Vector3, sakura: boolean)
	if decor(if sakura then "decor_sakura" else "decor_cartoon_tree", position, math.rad(position.X * 7 % 360)) then
		return
	end
	part({ Name = "Trunk", Size = Vector3.new(2.5, 10, 2.5), Position = position + Vector3.new(0, 5, 0), Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
	part({
		Name = "Leaves",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(14, 14, 14),
		Position = position + Vector3.new(0, 14, 0),
		Color = if sakura then Color3.fromRGB(255, 170, 210) else Color3.fromRGB(70, 160, 70),
		Material = Enum.Material.Grass,
		CanCollide = false,
	})
end

local function buildDecoration()
	buildStatue()
	buildFloatingCards()
	for i = 0, PLOT_COUNT - 1 do
		buildArch(i)
	end
	-- Flowers around the statue
	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		decor("decor_flowers", Vector3.new(math.cos(angle) * 15, FLOOR, math.sin(angle) * 15), angle)
	end
	-- Benches on the edge of the plaza, facing the middle
	for i = 0, PLOT_COUNT - 1 do
		local benchAngle = math.rad(i * 60 + 30)
		if i % 2 == 1 and i ~= 1 then -- between the stations (the Towers station takes the bench's place at 90 degrees)
			local benchDirection = Vector3.new(math.cos(benchAngle), 0, math.sin(benchAngle))
			local cframe = CFrame.lookAt(benchDirection * (RADIUS - 6), Vector3.zero)
			local _, yaw = cframe:ToOrientation()
			decor("decor_bench", cframe.Position + Vector3.new(0, FLOOR, 0), yaw)
		end
	end
	-- Trees between the plots, outside the plaza, with bushes, rocks and flowers at their feet
	for i = 0, PLOT_COUNT - 1 do
		local angle = math.rad(i * 60 + 30)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local side = Vector3.new(-direction.Z, 0, direction.X)
		buildTree(direction * 62, i % 2 == 0)
		buildTree(direction * 82, i % 2 == 1)
		decor("decor_bush", direction * 66 + side * 4, angle)
		decor("decor_bush", direction * 78 - side * 4, angle + 2)
		decor("decor_rocks", direction * 72 + side * 3, angle * 3)
		decor("decor_big_flowers", direction * 70 - side * 3, angle)
	end
	-- A ring of bushes around the plaza, leaving the paths free
	for i = 0, PLOT_COUNT - 1 do
		for _, offset in { 14, 46 } do
			local angle = math.rad(i * 60 + offset)
			decor("decor_bush", Vector3.new(math.cos(angle), 0, math.sin(angle)) * (RADIUS + 4), angle * 5)
		end
	end
end

---------------------------------------------------------------------------
-- Ground: the plaza and the paths to the plots
---------------------------------------------------------------------------
local function buildGround()
	-- Thick parts going down into the ground, so no gap shows whatever the terrain height
	-- Warm yellow inside the orange ring, around the blue middle
	cylinder("Plaza", Vector3.new(0, -0.9, 0), RADIUS * 2, 3, Color3.fromRGB(255, 205, 90), Enum.Material.SmoothPlastic)
	cylinder("PlazaRing", Vector3.new(0, -0.9, 0), RADIUS * 2 + 3, 2.8, Color3.fromRGB(255, 150, 40), Enum.Material.SmoothPlastic)
	cylinder("PlazaInner", Vector3.new(0, 0.2, 0), 26, 1, Color3.fromRGB(80, 170, 255), Enum.Material.SmoothPlastic)
	cylinder("PlazaInnerRing", Vector3.new(0, 0.15, 0), 28.5, 0.96, Color3.fromRGB(250, 250, 252), Enum.Material.SmoothPlastic)
	-- Light rays on the floor, like a sunburst around the statue
	for i = 0, 11 do
		local angle = math.rad(i * 30 + 15)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local center = direction * (RADIUS + 14) / 2 + Vector3.new(0, FLOOR + 0.03, 0)
		part({ Name = "FloorRay", Size = Vector3.new(4, 0.06, RADIUS - 16), CFrame = CFrame.lookAt(center, center + direction), Color = Color3.fromRGB(255, 228, 140), Material = Enum.Material.SmoothPlastic, CanQuery = false })
	end
	for i = 0, PLOT_COUNT - 1 do
		local angle = math.rad(i * 60)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = PLOT_INNER - RADIUS + 4
		local center = direction * (RADIUS + length / 2 - 2)
		part({
			Name = "Path",
			Size = Vector3.new(10, 3, length),
			CFrame = CFrame.lookAt(center + Vector3.new(0, -0.95, 0), direction * 1000 + Vector3.new(0, -0.95, 0)),
			Color = Color3.fromRGB(255, 150, 40),
			Material = Enum.Material.Plastic,
			TopSurface = Enum.SurfaceType.Studs,
		})
	end
end

---------------------------------------------------------------------------
-- Stations
---------------------------------------------------------------------------
-- A stool `height` studs tall: the Creator Store bar stool, or else a seat in the station's
-- color on 4 wooden legs
local function buildStool(parent: Instance, base: CFrame, height: number, diameter: number, color: Color3)
	local _, yaw = base:ToOrientation()
	if Assets.place("decor_stool", parent, base.Position, yaw, height) then
		return
	end
	local seat = 0.5
	part({ Name = "StoolSeat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(seat, diameter, diameter), CFrame = base * CFrame.new(0, height - seat / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = Enum.Material.SmoothPlastic, Parent = parent })
	for i = 0, 3 do
		local angle = math.rad(i * 90 + 45)
		local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (diameter / 2 - 0.45)
		part({ Name = "StoolLeg", Size = Vector3.new(0.4, height - seat, 0.4), CFrame = base * CFrame.new(offset + Vector3.new(0, (height - seat) / 2, 0)), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.SmoothPlastic, Parent = parent })
	end
end

local function buildStation(station: Station)
	local angle = math.rad(station.angle)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	-- The counter faces the middle of the plaza: players stand between it and the statue
	local position = direction * STATION_RADIUS
	local cframe = CFrame.lookAt(position, Vector3.zero)
	local _, yaw = cframe:ToOrientation()
	positions[station.id] = position

	local model = Instance.new("Model")
	model.Name = "Station_" .. station.id
	model.Parent = folder

	-- The booth: a cartoon stand in the station's color, open toward the plaza
	local white = Color3.fromRGB(250, 250, 252)
	local dark = station.color:Lerp(Color3.new(0, 0, 0), 0.25)
	local light = station.color:Lerp(white, 0.35)
	part({ Name = "BoothFloor", Size = Vector3.new(16, 0.6, 9), CFrame = cframe * CFrame.new(0, FLOOR + 0.3, 2.5), Color = white, Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "BoothBack", Size = Vector3.new(16, 11, 0.8), CFrame = cframe * CFrame.new(0, FLOOR + 5.5, 6.6), Color = light, Material = Enum.Material.SmoothPlastic, Parent = model })
	for _, x in { -1, 1 } do
		part({ Name = "BoothSide", Size = Vector3.new(0.8, 6, 7.4), CFrame = cframe * CFrame.new(x * 7.6, FLOOR + 3, 2.9), Color = light, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({ Name = "BoothPillar", Size = Vector3.new(1.4, 11, 1.4), CFrame = cframe * CFrame.new(x * 7.6, FLOOR + 5.5, -0.8), Color = white, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({ Name = "BoothPillar", Size = Vector3.new(1.4, 11, 1.4), CFrame = cframe * CFrame.new(x * 7.6, FLOOR + 5.5, 6.6), Color = white, Material = Enum.Material.SmoothPlastic, Parent = model })
	end
	-- Striped awning sloping down toward the plaza, with a scalloped edge
	local stripes = 8
	local width = 17.4 / stripes
	local back, front = Vector3.new(0, FLOOR + 12, 7.2), Vector3.new(0, FLOOR + 10.2, -2.6)
	local slope = CFrame.lookAt((back + front) / 2, front)
	for i = 1, stripes do
		local x = (i - (stripes + 1) / 2) * width
		local color = if i % 2 == 1 then station.color else white
		part({ Name = "Awning", Size = Vector3.new(width, 0.5, (front - back).Magnitude), CFrame = cframe * slope * CFrame.new(x, 0, 0), Color = color, Material = Enum.Material.SmoothPlastic, Parent = model })
		part({
			Name = "AwningEdge",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.5, width, width),
			CFrame = cframe * CFrame.new(x, front.Y - 0.1, front.Z) * CFrame.Angles(0, math.rad(90), 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		})
	end

	-- Counter
	local counter = part({ Name = "Counter", Size = Vector3.new(13, 3.4, 3), CFrame = cframe * CFrame.new(0, FLOOR + 1.7, 0), Color = white, Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "CounterStripe", Size = Vector3.new(13.1, 0.8, 3.1), CFrame = counter.CFrame * CFrame.new(0, -0.6, 0), Color = station.color, Material = Enum.Material.SmoothPlastic, Parent = model })
	part({ Name = "CounterTop", Size = Vector3.new(13.6, 0.5, 3.6), CFrame = counter.CFrame * CFrame.new(0, 1.95, 0), Color = dark, Material = Enum.Material.SmoothPlastic, Parent = model })
	if station.prop then
		Assets.place(station.prop, model, (counter.CFrame * CFrame.new(3.5, 2.2, 0)).Position, yaw + math.pi)
	end

	-- The shopkeeper: a brainrot behind the counter, who turns to look at the player
	local keeper = Config.SHOPKEEPERS[station.id]
	local keeperModel = keeper and Assets.get(keeper.card, keeper.height)
	if keeperModel then
		-- Shrunk if it's too wide or too deep for the booth (some brainrots are planes or sharks)
		local size = keeperModel:GetExtentsSize()
		local fit = math.min(1, 12 / size.X, KEEPER_DEPTH / size.Z)
		if fit < 1 then
			keeperModel:ScaleTo(keeperModel:GetScale() * fit)
			size = keeperModel:GetExtentsSize()
		end
		-- A shrunk brainrot stands on a little stool, so it still shows well above the counter
		local feet = math.max(FLOOR + 0.6, COUNTER_TOP + KEEPER_SHOWN - size.Y)
		local z = 1.6 + size.Z / 2
		if feet > FLOOR + 0.6 then
			buildStool(model, cframe * CFrame.new(0, FLOOR + 0.6, z), feet - FLOOR - 0.6, math.clamp(math.min(size.X, size.Z) + 0.6, 2.5, 4.4), station.color)
		end
		keeperModel:PivotTo(CFrame.new((cframe * CFrame.new(0, feet, z)).Position) * CFrame.Angles(0, yaw, 0))
		keeperModel.Name = "Shopkeeper"
		keeperModel.Parent = model
		CollectionService:AddTag(keeperModel, "AmbientKeeper")
		local card = Config.CARDS[keeper.card]
		local anchor = part({ Name = "KeeperTag", Size = Vector3.new(1, 1, 1), CFrame = cframe * CFrame.new(0, math.min(feet + size.Y + 1.4, FLOOR + 9.4), z), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromScale(8, 2)
		tag.LightInfluence = 0
		tag.MaxDistance = 45
		tag.AlwaysOnTop = true -- the awning would hide it when the camera looks down
		tag.Parent = anchor
		label(tag, { Size = UDim2.fromScale(1, 0.55), Text = if card then card.name else keeper.card })
		label(tag, { Position = UDim2.fromScale(0, 0.55), Size = UDim2.fromScale(1, 0.45), Text = keeper.title, TextColor3 = station.color })
	end

	-- Standing on the front edge of the awning, so nothing hides it
	local board = part({ Name = "Sign", Size = Vector3.new(14, 3.6, 0.8), CFrame = cframe * CFrame.new(0, FLOOR + 13.2, -2.9), Color = Color3.fromRGB(40, 35, 55), Parent = model })
	part({ Name = "SignFrame", Size = Vector3.new(14.8, 4.4, 0.6), CFrame = board.CFrame * CFrame.new(0, 0, 0.3), Color = white, Material = Enum.Material.SmoothPlastic, Parent = model })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, { Position = UDim2.fromScale(0.03, 0.08), Size = UDim2.fromScale(0.94, 0.84), Text = station.name, TextColor3 = station.color })
	corners[station.id] = { left = (cframe * CFrame.new(-7.6, FLOOR + 10.6, -0.8)).Position, right = (cframe * CFrame.new(7.6, FLOOR + 10.6, -0.8)).Position }

	-- Prompt (key E), in front of the counter
	local spot = part({ Name = "PromptSpot", Size = Vector3.new(1, 1, 1), CFrame = cframe * CFrame.new(0, 3, -2.5), Transparency = 1, CanCollide = false, CanQuery = false, Parent = model })
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StationPrompt"
	prompt.ActionText = station.prompt
	prompt.ObjectText = station.name
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("Station", station.id)
	prompt.Parent = spot
end

function Plaza.build(mapFolder: Folder)
	folder = Instance.new("Folder")
	folder.Name = "Plaza"
	folder.Parent = mapFolder
	buildGround()
	buildDecoration()
	for _, station in Plaza.STATIONS do
		buildStation(station)
	end
	-- Pennants from one booth to the next, all around the plaza
	local sorted = table.clone(Plaza.STATIONS)
	table.sort(sorted, function(a, b)
		return a.angle < b.angle
	end)
	for i, station in sorted do
		local nextStation = sorted[i % #sorted + 1]
		local from, to = corners[station.id], corners[nextStation.id]
		-- The closest pair of pillars between the two booths
		local best, bestA, bestB = math.huge, from.left, to.left
		for _, a in { from.left, from.right } do
			for _, b in { to.left, to.right } do
				if (a - b).Magnitude < best then
					best, bestA, bestB = (a - b).Magnitude, a, b
				end
			end
		end
		buildBunting(bestA, bestB, best * 0.08)
	end
end

-- True if the player stands close enough to a station to use it
function Plaza.near(player: Player, stationId: string): boolean
	local position = positions[stationId]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not position or not root then
		return false
	end
	local offset = root.Position - position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= USE_DISTANCE
end

return Plaza
