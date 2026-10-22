-- The plaza in the middle of the map: a fountain, the paths to the plots, decoration
-- and the 3 stations (Shop, Sell, Grading). Each station has a prompt (key E) that opens
-- its panel on the player's screen; the server checks the player is close before acting.

local Assets = require(script.Parent.Assets)

local Plaza = {}

local RADIUS = 42 -- size of the plaza
local STATION_RADIUS = 30 -- distance of the stations from the middle
local PLOT_COUNT = 6 -- same as Plots.luau: the paths lead to the plots
local PLOT_INNER = 59 -- where the plots start (PLOT_RADIUS - PLOT_DEPTH / 2 in Plots.luau)
local USE_DISTANCE = 18 -- how close a player must be to use a station
local FLOOR = 0.6 -- height of the plaza's floor
local FONT = Enum.Font.FredokaOne

export type Station = { id: string, name: string, color: Color3, angle: number, prop: string?, prompt: string }

-- Placed between the plots (the plots are at 0, 60, 120... degrees)
Plaza.STATIONS = {
	{ id = "shop", name = "PACK SHOP", color = Color3.fromRGB(90, 200, 120), angle = 270, prompt = "Buy packs" },
	{ id = "sell", name = "SELL", color = Color3.fromRGB(255, 190, 60), angle = 30, prop = "decor_register", prompt = "Sell cards" },
	{ id = "grade", name = "GRADING", color = Color3.fromRGB(170, 110, 255), angle = 150, prop = "decor_magnifier", prompt = "Grade cards" },
} :: { Station }

local positions: { [string]: Vector3 } = {}
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
local function buildFountain()
	if decor("decor_fountain", Vector3.new(0, FLOOR + 0.1, 0)) then
		return
	end
	cylinder("FountainBasin", Vector3.new(0, FLOOR + 0.8, 0), 20, 1.6, Color3.fromRGB(200, 200, 210), Enum.Material.Marble)
	cylinder("FountainWater", Vector3.new(0, FLOOR + 1.2, 0), 18, 1.2, Color3.fromRGB(90, 180, 255), Enum.Material.Glass).Transparency = 0.3
	cylinder("FountainColumn", Vector3.new(0, FLOOR + 3, 0), 3, 5, Color3.fromRGB(200, 200, 210), Enum.Material.Marble)
	cylinder("FountainTop", Vector3.new(0, FLOOR + 5.6, 0), 8, 0.8, Color3.fromRGB(200, 200, 210), Enum.Material.Marble)
end

local function buildTree(position: Vector3, sakura: boolean)
	if decor(if sakura then "decor_sakura" else "decor_tree", position, math.rad(position.X * 7 % 360)) then
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

local function buildLamp(position: Vector3)
	-- Turned toward the middle so all the lamps look the same way from the plaza
	local _, yaw = CFrame.lookAt(position, Vector3.new(0, position.Y, 0)):ToOrientation()
	if decor("decor_lamp", position, yaw) then
		return
	end
	part({ Name = "LampPole", Size = Vector3.new(0.8, 12, 0.8), Position = position + Vector3.new(0, 6, 0), Color = Color3.fromRGB(50, 50, 60), Material = Enum.Material.Metal })
	local bulb = part({ Name = "LampBulb", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), Position = position + Vector3.new(0, 12.5, 0), Color = Color3.fromRGB(255, 230, 160), Material = Enum.Material.Neon, CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.2
	light.Color = Color3.fromRGB(255, 220, 160)
	light.Parent = bulb
end

local function buildDecoration()
	buildFountain()
	-- Flowers around the fountain
	for i = 0, 7 do
		local angle = math.rad(i * 45 + 22.5)
		decor("decor_flowers", Vector3.new(math.cos(angle) * 15, FLOOR, math.sin(angle) * 15), angle)
	end
	-- Lamps and benches on the edge of the plaza, facing the middle
	for i = 0, PLOT_COUNT - 1 do
		local angle = math.rad(i * 60)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local side = Vector3.new(-direction.Z, 0, direction.X)
		for _, s in { -1, 1 } do
			buildLamp(direction * (RADIUS - 3) + side * s * 8 + Vector3.new(0, FLOOR, 0))
		end
		local benchAngle = math.rad(i * 60 + 30)
		if i % 2 == 1 then -- between the stations
			local benchDirection = Vector3.new(math.cos(benchAngle), 0, math.sin(benchAngle))
			local cframe = CFrame.lookAt(benchDirection * (RADIUS - 6), Vector3.zero)
			local _, yaw = cframe:ToOrientation()
			decor("decor_bench", cframe.Position + Vector3.new(0, FLOOR, 0), yaw)
		end
	end
	-- Trees between the plots, outside the plaza
	for i = 0, PLOT_COUNT - 1 do
		local angle = math.rad(i * 60 + 30)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		buildTree(direction * 62, i % 2 == 0)
		buildTree(direction * 82, i % 2 == 1)
	end
end

---------------------------------------------------------------------------
-- Ground: the plaza and the paths to the plots
---------------------------------------------------------------------------
local function buildGround()
	-- Thick parts going down into the ground, so no gap shows whatever the terrain height
	cylinder("Plaza", Vector3.new(0, -0.9, 0), RADIUS * 2, 3, Color3.fromRGB(225, 210, 185), Enum.Material.Cobblestone)
	cylinder("PlazaRing", Vector3.new(0, -0.9, 0), RADIUS * 2 + 3, 2.8, Color3.fromRGB(175, 135, 110), Enum.Material.Brick)
	cylinder("PlazaInner", Vector3.new(0, 0.2, 0), 26, 1, Color3.fromRGB(215, 200, 170), Enum.Material.Cobblestone)
	for i = 0, PLOT_COUNT - 1 do
		local angle = math.rad(i * 60)
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local length = PLOT_INNER - RADIUS + 4
		local center = direction * (RADIUS + length / 2 - 2)
		part({
			Name = "Path",
			Size = Vector3.new(10, 3, length),
			CFrame = CFrame.lookAt(center + Vector3.new(0, -0.95, 0), direction * 1000 + Vector3.new(0, -0.95, 0)),
			Color = Color3.fromRGB(200, 180, 150),
			Material = Enum.Material.Cobblestone,
		})
	end
end

---------------------------------------------------------------------------
-- Stations
---------------------------------------------------------------------------
local function buildStation(station: Station)
	local angle = math.rad(station.angle)
	local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
	-- The counter faces the middle of the plaza: players stand between it and the fountain
	local position = direction * STATION_RADIUS
	local cframe = CFrame.lookAt(position, Vector3.zero)
	local _, yaw = cframe:ToOrientation()
	positions[station.id] = position

	local model = Instance.new("Model")
	model.Name = "Station_" .. station.id
	model.Parent = folder

	-- Market stall behind the counter
	local stall = Assets.place("decor_stall", model, (cframe * CFrame.new(0, FLOOR, 3)).Position, yaw)
	if not stall then
		for _, x in { -6, 6 } do
			part({ Name = "Post", Size = Vector3.new(0.8, 10, 0.8), CFrame = cframe * CFrame.new(x, 5, 4), Color = Color3.fromRGB(130, 90, 55), Material = Enum.Material.Wood, Parent = model })
		end
		part({ Name = "Awning", Size = Vector3.new(14, 0.6, 8), CFrame = cframe * CFrame.new(0, 10.2, 1.5) * CFrame.Angles(math.rad(-12), 0, 0), Color = station.color, Material = Enum.Material.Fabric, Parent = model })
	end

	-- Counter
	local counter = part({ Name = "Counter", Size = Vector3.new(12, 3.6, 3), CFrame = cframe * CFrame.new(0, 2, 0), Color = Color3.fromRGB(150, 105, 65), Material = Enum.Material.WoodPlanks, Parent = model })
	part({ Name = "CounterTop", Size = Vector3.new(12.6, 0.4, 3.6), CFrame = counter.CFrame * CFrame.new(0, 2, 0), Color = station.color, Material = Enum.Material.SmoothPlastic, Parent = model })
	if station.prop then
		Assets.place(station.prop, model, (counter.CFrame * CFrame.new(3, 2.2, 0)).Position, yaw + math.pi)
	end

	-- Sign above the stall, readable from the plaza
	local board = part({ Name = "Sign", Size = Vector3.new(14, 4, 0.6), CFrame = cframe * CFrame.new(0, 14.5, 2), Color = Color3.fromRGB(40, 35, 55), Parent = model })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0
	gui.Parent = board
	label(gui, { Size = UDim2.fromScale(1, 1), Text = station.name, TextColor3 = station.color })
	for _, x in { -6.5, 6.5 } do
		part({ Name = "SignPost", Size = Vector3.new(0.6, 14, 0.6), CFrame = cframe * CFrame.new(x, 7, 2.2), Color = Color3.fromRGB(60, 50, 70), Parent = model })
	end

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
