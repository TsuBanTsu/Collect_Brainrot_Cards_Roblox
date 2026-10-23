-- Tower fights, drawn on the player's screen: an arena high in the sky (built on this client
-- only), the team on the left, the enemy on the right, headbutts, damage numbers and rewards.
-- The server (Towers.luau) runs the fight and sends each step through the TowerEvent remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(22, 22, 32)
local RED = Color3.fromRGB(225, 75, 75)
local ACCENT = Color3.fromRGB(80, 200, 120)
local CASH_COLOR = Color3.fromRGB(120, 255, 140)

local ORIGIN = Vector3.new(0, 1500, 3000) -- far from the map, only this client sees it
local MODEL_HEIGHT = 8
local FRONT_X = 8 -- distance of the fighters from the middle
local BENCH = { Vector3.new(-18, 0, -10), Vector3.new(-28, 0, -5) } -- the team cards waiting their turn
local CAMERA_OFFSET = Vector3.new(0, 10, 34)

---------------------------------------------------------------------------
-- Small helpers
---------------------------------------------------------------------------
local function create(className: string, props, children: { Instance }?): any
	local inst = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			(inst :: any)[key] = value
		end
	end
	for _, child in (children or {}) :: { Instance } do
		child.Parent = inst
	end
	inst.Parent = props.Parent
	return inst
end

local function textLabel(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = FONT
	props.TextColor3 = props.TextColor3 or Color3.new(1, 1, 1)
	if props.TextScaled == nil then
		props.TextScaled = true
	end
	return create("TextLabel", props, { create("UIStroke", { Thickness = 2.5, Transparency = 0.1 }) })
end

local function part(props): Part
	props.Anchored = true
	props.CanCollide = false
	props.CanQuery = false
	props.CanTouch = false
	props.CastShadow = false
	props.TopSurface = props.TopSurface or Enum.SurfaceType.Smooth
	props.BottomSurface = Enum.SurfaceType.Smooth
	return create("Part", props)
end

local function tween(object: Instance, time: number, goal, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(object, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Moves a model smoothly (models can't be tweened directly: a CFrameValue drives PivotTo)
local function moveModel(model: Model, goal: CFrame, time: number, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local value = Instance.new("CFrameValue")
	value.Value = model:GetPivot()
	value.Changed:Connect(function(cframe)
		if model.Parent then
			model:PivotTo(cframe)
		end
	end)
	local t = tween(value, time, { Value = goal }, style, direction)
	t.Completed:Connect(function()
		value:Destroy()
	end)
	return t
end

local function nameColor(cardId: string): Color3
	return Config.RARITY[Config.CARDS[cardId].rarity].color
end

---------------------------------------------------------------------------
-- The arena
---------------------------------------------------------------------------
local arena: Model? = nil
local spinners: { { part: BasePart, angle: number, radius: number, height: number, speed: number } } = {}
local floorSign: TextLabel? = nil
local arenaLights: { PointLight } = {}

local function buildArena(tower: Config.Tower)
	local model = Instance.new("Model")
	model.Name = "TowerArena"
	local color = tower.color
	local dark = color:Lerp(DARK, 0.65)
	local function at(offset: Vector3): CFrame
		return CFrame.new(ORIGIN + offset)
	end
	local function cylinder(name: string, offset: Vector3, diameter: number, height: number, partColor: Color3, material: Enum.Material?)
		return part({ Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), CFrame = at(offset) * CFrame.Angles(0, 0, math.rad(90)), Color = partColor, Material = material or Enum.Material.SmoothPlastic, Parent = model })
	end

	-- Ring floor with a glowing edge and a line in the middle
	cylinder("Edge", Vector3.new(0, -1.2, 0), 70, 2, color, Enum.Material.Neon)
	cylinder("Floor", Vector3.new(0, -1, 0), 66, 2, dark)
	cylinder("Center", Vector3.new(0, -0.9, 0), 22, 2, color:Lerp(DARK, 0.35))
	part({ Name = "Line", Size = Vector3.new(0.6, 0.2, 60), CFrame = at(Vector3.new(0, 0.05, 0)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
	for _, side in { -1, 1 } do
		part({ Name = "Spot", Size = Vector3.new(6, 0.2, 6), CFrame = at(Vector3.new(side * FRONT_X, 0.06, 0)), Color = if side < 0 then Color3.fromRGB(80, 170, 255) else RED, Material = Enum.Material.Neon, Transparency = 0.4, Parent = model })
	end

	-- Stands full of colors behind the ring (open on the camera's side)
	for tier = 0, 3 do
		for segment = 0, 31 do
			local angle = math.rad(segment * 360 / 32)
			local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
			if direction.Z < 0.55 then
				local radius = 40 + tier * 4
				local center = direction * radius + Vector3.new(0, tier * 2.5, 0)
				part({
					Name = "Seats",
					Size = Vector3.new(radius * 2 * math.pi / 32 + 0.4, 2.5 + tier * 5, 4),
					CFrame = CFrame.lookAt(ORIGIN + center - Vector3.new(0, (2.5 + tier * 5) / 2 - 2.5, 0), ORIGIN + Vector3.new(0, center.Y, 0)),
					Color = Config.PLOT_COLORS[(segment + tier) % #Config.PLOT_COLORS + 1]:Lerp(DARK, 0.25),
					TopSurface = Enum.SurfaceType.Studs,
					Material = Enum.Material.Plastic,
					Parent = model,
				})
			end
		end
	end

	-- Pillars with fire and colored lights
	arenaLights = {}
	for i = 0, 9 do
		local angle = math.rad(i * 36 + 18)
		local position = Vector3.new(math.sin(angle) * 35, 0, math.cos(angle) * 35)
		if position.Z < 25 then
			part({ Name = "Pillar", Size = Vector3.new(3, 16, 3), CFrame = at(position + Vector3.new(0, 8, 0)), Color = Color3.fromRGB(40, 38, 55), Parent = model })
			local cap = part({ Name = "Cap", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), CFrame = at(position + Vector3.new(0, 17, 0)), Color = color, Material = Enum.Material.Neon, Parent = model })
			create("Fire", { Color = color, SecondaryColor = Color3.new(1, 1, 1), Size = 7, Heat = 12, Parent = cap })
			table.insert(arenaLights, create("PointLight", { Color = color, Range = 30, Brightness = 2, Parent = cap }))
		end
	end

	-- Neon cubes flying around the ring
	spinners = {}
	for i = 1, 14 do
		local cube = part({ Name = "Spinner", Size = Vector3.new(2, 2, 2), CFrame = at(Vector3.new(0, 25, 0)), Color = if i % 2 == 0 then color else Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = model })
		table.insert(spinners, { part = cube, angle = i * math.pi * 2 / 14, radius = 30, height = 22 + (i % 3) * 3, speed = 0.4 + (i % 2) * 0.2 })
	end

	-- Giant sign behind the ring: tower name and floor
	local board = part({ Name = "Sign", Size = Vector3.new(44, 12, 1), CFrame = at(Vector3.new(0, 30, -52)), Color = DARK, Parent = model })
	-- Back face: the one turned toward the camera
	local gui = create("SurfaceGui", { Face = Enum.NormalId.Back, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud, PixelsPerStud = 20, LightInfluence = 0, Parent = board })
	textLabel({ Size = UDim2.fromScale(1, 0.45), Text = string.upper(tower.name), TextColor3 = color, Parent = gui })
	floorSign = textLabel({ Position = UDim2.fromScale(0, 0.45), Size = UDim2.fromScale(1, 0.55), Text = "FLOOR 1", Parent = gui })
	part({ Name = "SignEdge", Size = Vector3.new(46, 14, 0.6), CFrame = at(Vector3.new(0, 30, -52.6)), Color = color, Material = Enum.Material.Neon, Parent = model })

	-- Sparkles in the air
	local air = part({ Name = "Air", Size = Vector3.new(60, 1, 40), CFrame = at(Vector3.new(0, 25, 0)), Transparency = 1, Parent = model })
	create("ParticleEmitter", { Color = ColorSequence.new(color, Color3.new(1, 1, 1)), LightEmission = 1, Rate = 25, Lifetime = NumberRange.new(2, 4), Speed = NumberRange.new(1, 3), Size = NumberSequence.new(0.4, 0), SpreadAngle = Vector2.new(180, 180), Parent = air })

	model.Parent = Workspace
	arena = model
end

---------------------------------------------------------------------------
-- Fighters: a brainrot model with its name and HP bar above it
---------------------------------------------------------------------------
type Unit = { model: Model, bar: Frame, hpText: TextLabel, maxHp: number, height: number, home: CFrame }

local function brainrotModel(cardId: string, height: number): Model
	local templates = ReplicatedStorage:FindFirstChild("AssetTemplates")
	local template = templates and templates:FindFirstChild(cardId)
	local model: Model
	if template and template:IsA("Model") then
		model = template:Clone()
		local _, size = model:GetBoundingBox()
		model:ScaleTo(model:GetScale() * height / size.Y)
	else
		-- No model loaded: a colored block with the card's initial
		model = Instance.new("Model")
		local block = part({ Size = Vector3.new(height * 0.7, height, height * 0.7), Color = nameColor(cardId), Parent = model })
		local gui = create("SurfaceGui", { Face = Enum.NormalId.Front, Parent = block })
		textLabel({ Size = UDim2.fromScale(1, 1), Text = string.sub(Config.CARDS[cardId].name, 1, 1), Parent = gui })
		model.PrimaryPart = block
		model.WorldPivot = block.CFrame * CFrame.new(0, -height / 2, 0)
		model.PrimaryPart = nil
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanQuery = false
		end
	end
	return model
end

local function makeUnit(cardId: string, hp: number, maxHp: number, home: CFrame, height: number, title: string?): Unit
	local model = brainrotModel(cardId, height)
	model:PivotTo(home)
	model.Parent = arena
	local _, size = model:GetBoundingBox()
	local anchor = part({ Name = "BarAnchor", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = home * CFrame.new(0, size.Y + 2, 0), Transparency = 1, Parent = model })
	local billboard = create("BillboardGui", { Size = UDim2.fromOffset(180, 54), AlwaysOnTop = true, LightInfluence = 0, Parent = anchor })
	textLabel({ Size = UDim2.new(1, 0, 0, 22), Text = (if title then title .. " " else "") .. Config.CARDS[cardId].name, TextColor3 = nameColor(cardId), Parent = billboard })
	local back = create("Frame", { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 20), BackgroundColor3 = DARK, Parent = billboard }, { create("UICorner", { CornerRadius = UDim.new(0, 6) }), create("UIStroke", { Thickness = 2 }) })
	local bar = create("Frame", { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1), BackgroundColor3 = ACCENT, Parent = back }, { create("UICorner", { CornerRadius = UDim.new(0, 6) }) })
	local hpText = textLabel({ Size = UDim2.fromScale(1, 1), Text = Format.number(hp), ZIndex = 2, Parent = back })
	return { model = model, bar = bar, hpText = hpText, maxHp = maxHp, height = size.Y, home = home }
end

local function setHp(unit: Unit, hp: number)
	local ratio = math.clamp(hp / unit.maxHp, 0, 1)
	tween(unit.bar, 0.25, { Size = UDim2.fromScale(ratio, 1) })
	unit.bar.BackgroundColor3 = if ratio > 0.5 then ACCENT elseif ratio > 0.25 then Color3.fromRGB(255, 200, 60) else RED
	unit.hpText.Text = Format.number(hp)
end

-- Falls over and sinks into the floor
local function knockOut(unit: Unit)
	local model = unit.model
	moveModel(model, model:GetPivot() * CFrame.new(0, -unit.height, 0) * CFrame.Angles(0, 0, math.rad(80)), 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.55, function()
		model:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Effects: impact burst, damage numbers, camera shake
---------------------------------------------------------------------------
local shake = 0

local function burst(position: Vector3, color: Color3, amount: number)
	local holder = part({ Name = "Burst", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1, Parent = arena })
	local emitter = create("ParticleEmitter", {
		Color = ColorSequence.new(color, Color3.new(1, 1, 1)),
		LightEmission = 1,
		Lifetime = NumberRange.new(0.3, 0.6),
		Speed = NumberRange.new(12, 26),
		Size = NumberSequence.new(1.2, 0),
		SpreadAngle = Vector2.new(180, 180),
		Rate = 0,
		Parent = holder,
	})
	emitter:Emit(amount)
	task.delay(1, function()
		holder:Destroy()
	end)
end

local function floatingText(position: Vector3, text: string, color: Color3, size: number?)
	local holder = part({ Name = "Text", Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(position), Transparency = 1, Parent = arena })
	local billboard = create("BillboardGui", { Size = UDim2.fromOffset(220, size or 44), AlwaysOnTop = true, LightInfluence = 0, Parent = holder })
	local label = textLabel({ Size = UDim2.fromScale(1, 1), Text = text, TextColor3 = color, Parent = billboard })
	local pop = create("UIScale", { Scale = 1.6, Parent = label })
	tween(pop, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(holder, 0.9, { CFrame = holder.CFrame + Vector3.new(math.random(-15, 15) / 10, 4, 0) })
	task.delay(0.6, function()
		tween(label, 0.3, { TextTransparency = 1 })
	end)
	task.delay(0.95, function()
		holder:Destroy()
	end)
end

---------------------------------------------------------------------------
-- The fight HUD
---------------------------------------------------------------------------
local hud = create("ScreenGui", { Name = "TowerHud", ResetOnSpawn = false, IgnoreGuiInset = true, Enabled = false, DisplayOrder = 5, Parent = player:WaitForChild("PlayerGui") })
-- Same scaling as the main UI: designed for 1280x720, resized to fit the screen
local screen = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = hud })
local hudScale = create("UIScale", { Parent = screen })
local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local scale = math.clamp(math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 720), 0.5, 1.4)
		hudScale.Scale = scale
		screen.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local titleLabel = textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.fromOffset(700, 52), Text = "", Parent = screen })
local banner = textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(700, 80), Text = "", Visible = false, Parent = screen })
local bannerScale = create("UIScale", { Parent = banner })
local earnedLabel = textLabel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -30), Size = UDim2.fromOffset(760, 36), Text = "", TextColor3 = CASH_COLOR, Parent = screen })
local leaveButton = create("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -24),
	Size = UDim2.fromOffset(150, 54),
	BackgroundColor3 = RED,
	Font = FONT,
	Text = "LEAVE",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	Parent = screen,
}, { create("UICorner", { CornerRadius = UDim.new(0, 10) }), create("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }) })

-- End screen
local endFrame = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(620, 340), BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Visible = false, Parent = screen }, {
	create("UICorner", { CornerRadius = UDim.new(0, 18) }),
	create("UIStroke", { Thickness = 3 }),
})
local endTitle = textLabel({ Position = UDim2.fromOffset(20, 18), Size = UDim2.new(1, -40, 0, 60), Text = "", Parent = endFrame })
local endInfo = textLabel({ Position = UDim2.fromOffset(20, 90), Size = UDim2.new(1, -40, 0, 150), Text = "", TextScaled = false, TextSize = 26, TextWrapped = true, Parent = endFrame })
local okButton = create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -20),
	Size = UDim2.fromOffset(180, 56),
	BackgroundColor3 = ACCENT,
	Font = FONT,
	Text = "OK",
	TextColor3 = Color3.new(1, 1, 1),
	TextScaled = true,
	Parent = endFrame,
}, { create("UICorner", { CornerRadius = UDim.new(0, 10) }), create("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8) }) })

local function showBanner(text: string, color: Color3)
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	bannerScale.Scale = 0.3
	tween(bannerScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(1.1, function()
		if banner.Text == text then
			banner.Visible = false
		end
	end)
end

---------------------------------------------------------------------------
-- Fight state
---------------------------------------------------------------------------
local tower: Config.Tower? = nil
local team: { Unit? } = {}
local front = 0 -- index of the team card that fights
local enemy: Unit? = nil
local earned = { cash = 0, packs = 0, rerolls = 0, cards = 0 }
local CAMERA_STEP = "TowerCamera"
local cameraBound = false

local function frontCFrame(side: number): CFrame
	-- side -1: the team (facing +X), 1: the enemy (facing -X); models face -Z by default
	return CFrame.new(ORIGIN + Vector3.new(side * FRONT_X, 0, 0)) * CFrame.Angles(0, math.rad(side * 90), 0)
end

local function benchCFrame(slot: number): CFrame
	return CFrame.new(ORIGIN + BENCH[slot]) * CFrame.Angles(0, math.rad(-90), 0)
end

local function refreshEarned()
	local parts = { "$" .. Format.number(earned.cash) }
	if earned.packs > 0 then
		table.insert(parts, "📦 " .. earned.packs .. " pack" .. (if earned.packs > 1 then "s" else ""))
	end
	if earned.rerolls > 0 then
		table.insert(parts, "🎲 " .. earned.rerolls .. " Trait Reroll" .. (if earned.rerolls > 1 then "s" else ""))
	end
	if earned.cards > 0 then
		table.insert(parts, "🃏 " .. earned.cards .. " card" .. (if earned.cards > 1 then "s" else ""))
	end
	earnedLabel.Text = "Won: " .. table.concat(parts, "   ")
end

-- The next card still standing walks to the front
local function promote(index: number)
	local unit = team[index]
	if unit then
		front = index
		unit.home = frontCFrame(-1)
		moveModel(unit.model, unit.home, 0.4)
	end
end

local function cleanup()
	if arena then
		arena:Destroy()
		arena = nil
	end
	team = {}
	enemy = nil
	if cameraBound then
		RunService:UnbindFromRenderStep(CAMERA_STEP)
		cameraBound = false
	end
	local camera = Workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
	hud.Enabled = false
	endFrame.Visible = false
	player:SetAttribute("TowerScreen", nil)
end

local function onStart(event)
	cleanup()
	tower = Config.TOWER[event.tower]
	if not tower then
		return
	end
	buildArena(tower)
	earned = { cash = 0, packs = 0, rerolls = 0, cards = 0 }
	refreshEarned()
	titleLabel.Text = tower.name
	titleLabel.TextColor3 = tower.color
	leaveButton.Visible = true
	hud.Enabled = true
	-- Local attribute: the main UI (Hud.client.luau) stays hidden until the end screen is closed
	player:SetAttribute("TowerScreen", true)

	team = {}
	for index, fighter in event.team do
		local home = if index == 1 then frontCFrame(-1) else benchCFrame(index - 1)
		team[index] = makeUnit(fighter.cardId, fighter.hp, fighter.maxHp, home, MODEL_HEIGHT)
	end
	front = 1

	-- Fixed camera from the open side of the stands, with a little shake on impacts.
	-- Runs right after Roblox's camera scripts and forces Scriptable every frame: set only once,
	-- they could switch it back to following the character (seen on a second run).
	local started = os.clock()
	cameraBound = true
	RunService:BindToRenderStep(CAMERA_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt)
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		local t = os.clock() - started
		local offset = Vector3.zero
		if shake > 0 then
			shake = math.max(0, shake - dt)
			offset = Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake * 6
		end
		local sway = Vector3.new(math.sin(t * 0.3) * 3, 0, 0)
		camera.CFrame = CFrame.lookAt(ORIGIN + CAMERA_OFFSET + sway + offset, ORIGIN + Vector3.new(0, 5, 0))
		for _, spinner in spinners do
			spinner.angle += dt * spinner.speed
			spinner.part.CFrame = CFrame.new(ORIGIN + Vector3.new(math.cos(spinner.angle) * spinner.radius, spinner.height, math.sin(spinner.angle) * spinner.radius)) * CFrame.Angles(t, t * 1.3, 0)
		end
	end)
end

local function onFloor(event)
	if not tower then
		return
	end
	local kind = Config.FLOOR_KINDS[event.kind]
	local floors = if tower.floors then "/" .. tower.floors else ""
	titleLabel.Text = tower.name .. "  ·  FLOOR " .. event.floor .. floors
	if floorSign then
		floorSign.Text = "FLOOR " .. event.floor
	end
	-- Bosses: red lights and a banner
	for _, light in arenaLights do
		light.Color = if event.kind == "normal" then tower.color else RED
	end
	if event.kind ~= "normal" then
		showBanner(kind.name .. "!", if event.kind == "boss" then RED else Color3.fromRGB(255, 170, 40))
	end
	-- The enemy drops from the sky
	local home = frontCFrame(1)
	local unit = makeUnit(event.enemy.cardId, event.enemy.hp, event.enemy.maxHp, home * CFrame.new(0, 25, 0), MODEL_HEIGHT * kind.scale, if event.kind ~= "normal" then kind.name else nil)
	unit.home = home
	enemy = unit
	moveModel(unit.model, home, 0.45, Enum.EasingStyle.Bounce)
	task.delay(0.35, function()
		burst(home.Position, tower and tower.color or RED, 25)
		shake = 0.15
	end)
end

local function onClash(event)
	local unit = team[event.fighter]
	local foe = enemy
	if not unit or not foe then
		return
	end
	if event.fighter ~= front then
		promote(event.fighter)
		task.wait(0.15)
	end
	-- Both step back, then rush into each other
	local meet = 1.5 + foe.height * 0.15
	moveModel(unit.model, unit.home * CFrame.new(0, 0, 1.5), 0.1)
	moveModel(foe.model, foe.home * CFrame.new(0, 0, 1.5), 0.1)
	task.wait(0.1)
	moveModel(unit.model, CFrame.new(ORIGIN + Vector3.new(-meet, 0, 0)) * unit.home.Rotation, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	moveModel(foe.model, CFrame.new(ORIGIN + Vector3.new(meet, 0, 0)) * foe.home.Rotation, 0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.13)

	-- Impact
	local impact = ORIGIN + Vector3.new(0, MODEL_HEIGHT * 0.6, 0)
	burst(impact, Color3.fromRGB(255, 230, 120), 30)
	shake = 0.25
	floatingText(impact + Vector3.new(meet + 1, 2, 0), "-" .. Format.number(event.dealt), Color3.fromRGB(255, 230, 80))
	floatingText(impact + Vector3.new(-meet - 1, 2, 0), "-" .. Format.number(event.taken), RED)
	setHp(unit, event.hp)
	setHp(foe, event.enemyHp)

	-- Bounce back
	moveModel(unit.model, unit.home, 0.25, Enum.EasingStyle.Back)
	moveModel(foe.model, foe.home, 0.25, Enum.EasingStyle.Back)
	if event.hp <= 0 then
		task.delay(0.25, function()
			knockOut(unit)
		end)
		team[event.fighter] = nil
		-- The next one comes forward right away
		for index = event.fighter + 1, #BENCH + 1 do
			if team[index] then
				task.delay(0.6, promote, index)
				break
			end
		end
	end
end

local function onCleared(event)
	local foe = enemy
	enemy = nil
	if foe then
		burst(foe.home.Position + Vector3.new(0, foe.height / 2, 0), tower and tower.color or ACCENT, 50)
		local model = foe.model
		model:ScaleTo(model:GetScale() * 1.15)
		task.delay(0.08, function()
			model:Destroy()
		end)
	end
	local given = event.reward
	earned.cash += given.cash
	earned.packs += given.packs
	earned.rerolls += if given.reroll then 1 else 0
	earned.cards += if given.card then 1 else 0
	refreshEarned()
	floatingText(ORIGIN + Vector3.new(FRONT_X, 6, 0), "+$" .. Format.number(given.cash), CASH_COLOR, 50)
	if given.packs > 0 then
		showBanner("+" .. given.packs .. " " .. Config.PACK[given.pack].name .. (if given.packs > 1 then "s" else "") .. "!", Config.PACK[given.pack].color)
	end
	if given.card then
		showBanner("NEW CARD: " .. Config.CARDS[given.card].name .. "!", nameColor(given.card))
	end
	if given.reroll then
		floatingText(ORIGIN + Vector3.new(FRONT_X, 10, 0), "+1 Trait Reroll", Color3.fromRGB(255, 215, 60), 40)
	end
	-- Healing
	for index, fighter in event.team do
		local unit = team[index]
		if unit and fighter.hp > 0 then
			setHp(unit, fighter.hp)
		end
	end
end

local function onEnd(event)
	leaveButton.Visible = false
	local title, color
	if event.result == "cleared" then
		title, color = "TOWER CLEARED!", Color3.fromRGB(255, 215, 60)
	elseif event.result == "left" then
		title, color = "YOU LEFT", Color3.fromRGB(200, 200, 215)
	else
		title, color = "DEFEATED", RED
	end
	endTitle.Text = title
	endTitle.TextColor3 = color
	local lines = { "Floors cleared: " .. event.floor, "Cash: $" .. Format.number(event.earned.cash) }
	if event.earned.packs > 0 then
		table.insert(lines, "Packs: " .. event.earned.packs)
	end
	if event.earned.rerolls > 0 then
		table.insert(lines, "Trait Rerolls: " .. event.earned.rerolls)
	end
	for _, cardId in event.earned.cards do
		table.insert(lines, "New card: " .. Config.CARDS[cardId].name)
	end
	endInfo.Text = table.concat(lines, "\n")
	endFrame.Visible = true
end

leaveButton.Activated:Connect(function()
	remotes.LeaveTower:FireServer()
	leaveButton.Visible = false
end)
okButton.Activated:Connect(cleanup)

local handlers = { start = onStart, floor = onFloor, clash = onClash, cleared = onCleared, ["end"] = onEnd }
remotes:WaitForChild("TowerEvent").OnClientEvent:Connect(function(event)
	local handler = handlers[event.type]
	if handler then
		task.spawn(handler, event)
	end
end)
