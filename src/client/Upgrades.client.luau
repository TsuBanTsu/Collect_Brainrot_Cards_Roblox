-- Upgrade tree (Config.UPGRADE_TREES), like Collect Cat Cards: a small UPGRADES button on the
-- right of the screen opens a cluster of hexagons, one per tree (Luck, Cash, Speed, Power,
-- Auto Open). A tree shows its upgrades as hexagons in branches around a BACK hexagon: each
-- one needs the one before it. Tap one to see it and buy it; BUY ALL buys every upgrade of the
-- tree the player can afford, cheapest first. Upgrades are bought with Cash, anywhere.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(22, 22, 32)
local ACCENT = Color3.fromRGB(80, 200, 120)
local RED = Color3.fromRGB(225, 75, 75)
local GREY = Color3.fromRGB(95, 95, 110)
local CASH_COLOR = Color3.fromRGB(120, 255, 140)

local owned: { [string]: boolean } = {}

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
	return create("TextLabel", props, { create("UIStroke", { Thickness = 2, Transparency = 0.2 }) })
end

local function textButton(props, onClick: () -> ())
	local b = create("TextButton", {
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		BackgroundColor3 = props.BackgroundColor3,
		Font = FONT,
		Text = props.Text,
		TextColor3 = Color3.new(1, 1, 1),
		TextScaled = true,
		ZIndex = props.ZIndex,
		Parent = props.Parent,
	}, {
		create("UICorner", { CornerRadius = UDim.new(0, 12) }),
		create("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("UIPadding", { PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	})
	create("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Parent = b })
	b.Activated:Connect(onClick)
	return b
end

-- A pointy-top hexagon made of three rotated rectangles, with a dark border.
-- `size` is its height in pixels. Returns the holder (a transparent button) and a function to recolor it.
local function hexagon(parent: Instance, center: UDim2, size: number, zIndex: number): (TextButton, (Color3) -> ())
	local holder = create("TextButton", { AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(size * 0.87, size), BackgroundTransparency = 1, Text = "", ZIndex = zIndex, Parent = parent })
	local fills = {}
	-- Side of the hexagon = half its height; a rectangle side x side*sqrt(3), turned 0/60/120 degrees (+90: pointy top)
	for _, layer in { { inset = 0, color = Color3.fromRGB(20, 20, 30), z = zIndex }, { inset = 5, color = Color3.new(1, 1, 1), z = zIndex + 1 } } do
		local radius = (size - layer.inset * 2) / 2
		for _, angle in { 0, 60, 120 } do
			local rect = create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(radius * math.sqrt(3), radius),
				Rotation = angle,
				BackgroundColor3 = layer.color,
				BorderSizePixel = 0,
				ZIndex = layer.z,
				Parent = holder,
			})
			if layer.inset > 0 then
				table.insert(fills, rect)
			end
		end
	end
	local function paint(color: Color3)
		for _, rect in fills do
			rect.BackgroundColor3 = color
		end
	end
	local scale = create("UIScale", { Parent = holder })
	holder.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.08 }):Play()
	end)
	holder.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	return holder, paint
end

---------------------------------------------------------------------------
-- Screen
---------------------------------------------------------------------------
local gui = create("ScreenGui", { Name = "Upgrades", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 3, Parent = player:WaitForChild("PlayerGui") })
local screen = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = gui })
local uiScale = create("UIScale", { Parent = screen })
local function updateScale()
	local camera = Workspace.CurrentCamera
	if camera then
		local scale = math.clamp(math.min(camera.ViewportSize.X / 1280, camera.ViewportSize.Y / 720), 0.5, 1.4)
		uiScale.Scale = scale
		screen.Size = UDim2.fromScale(1 / scale, 1 / scale)
	end
end
updateScale()
if Workspace.CurrentCamera then
	Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- The small button on the right of the HUD
local openButton = create("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.62, 0), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = Color3.fromRGB(60, 190, 90), Text = "", Parent = screen }, {
	create("UICorner", { CornerRadius = UDim.new(0, 16) }),
	create("UIStroke", { Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
	create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(120, 240, 130), Color3.fromRGB(40, 150, 70)) }),
})
textLabel({ Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 46), Text = "⏫", Parent = openButton })
textLabel({ Position = UDim2.new(0, 4, 1, -30), Size = UDim2.new(1, -8, 0, 24), Text = "UPGRADES", Parent = openButton })

-- The tree window: dims the world behind it
local window = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Active = true, Visible = false, ZIndex = 5, Parent = screen })
local cashLabel = textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(500, 40), Text = "", TextColor3 = CASH_COLOR, ZIndex = 20, Parent = window })
-- Everything inside `board` is laid out around its middle and scaled down to fit the screen
local board = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 6, Parent = window })
local boardScale = create("UIScale", { Parent = board })

-- Info card of the chosen upgrade, on the left
local info = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 16, 0.5, 0), Size = UDim2.fromOffset(250, 210), BackgroundColor3 = DARK, BackgroundTransparency = 0.1, Visible = false, ZIndex = 20, Parent = window }, {
	create("UICorner", { CornerRadius = UDim.new(0, 14) }),
	create("UIStroke", { Thickness = 3 }),
})
local infoName = textLabel({ Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 34), Text = "", ZIndex = 21, Parent = info })
local infoEffect = textLabel({ Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 26), Text = "", TextColor3 = Color3.fromRGB(220, 220, 235), ZIndex = 21, Parent = info })
local infoCost = textLabel({ Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 30), Text = "", TextColor3 = CASH_COLOR, ZIndex = 21, Parent = info })
local infoBuy: TextButton

local currentTree: Config.UpgradeTree? = nil
local selected: Config.Upgrade? = nil
local showTree: (Config.UpgradeTree) -> ()
local showHub: () -> ()

local function cash(): number
	return player:GetAttribute("Cash") or 0
end

local function stateOf(node: Config.Upgrade): string
	if owned[node.id] then
		return "owned"
	elseif node.requires and not owned[node.requires] then
		return "locked"
	end
	return "available"
end

local function refreshInfo()
	local node = selected
	info.Visible = node ~= nil
	if not node then
		return
	end
	local state = stateOf(node)
	infoName.Text = (if node.star then "★ " else "") .. node.name
	infoEffect.Text = Config.upgradeText(node.stat, node.value)
	if state == "owned" then
		infoCost.Text = "OWNED"
		infoCost.TextColor3 = ACCENT
		infoBuy.Visible = false
	elseif state == "locked" then
		infoCost.Text = "$" .. Format.number(node.cost) .. "  ·  🔒 " .. Config.UPGRADES[node.requires :: string].name .. " first"
		infoCost.TextColor3 = Color3.fromRGB(200, 200, 210)
		infoBuy.Visible = false
	else
		infoCost.Text = "$" .. Format.number(node.cost)
		infoCost.TextColor3 = if cash() >= node.cost then CASH_COLOR else RED
		infoBuy.Visible = true
		infoBuy.BackgroundColor3 = if cash() >= node.cost then ACCENT else GREY
	end
end

infoBuy = textButton({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(160, 52), Text = "BUY", BackgroundColor3 = ACCENT, ZIndex = 22, Parent = info }, function()
	if selected then
		remotes.BuyUpgrade:FireServer(selected.id)
	end
end)

-- EXIT and BUY ALL at the bottom
textButton({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -12, 1, -24), Size = UDim2.fromOffset(170, 60), Text = "EXIT", BackgroundColor3 = RED, ZIndex = 20, Parent = window }, function()
	window.Visible = false
end)
local buyAllButton = textButton({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0.5, 12, 1, -24), Size = UDim2.fromOffset(200, 60), Text = "BUY ALL", BackgroundColor3 = ACCENT, ZIndex = 20, Parent = window }, function()
	if currentTree then
		remotes.BuyAllUpgrades:FireServer(currentTree.id)
	end
end)

local function clearBoard()
	for _, child in board:GetChildren() do
		if not child:IsA("UIScale") then
			child:Destroy()
		end
	end
end

-- Scales the board so a `width` x `height` layout fits between the info card and the buttons
local function fitBoard(width: number, height: number)
	local camera = Workspace.CurrentCamera
	local available = (if camera then camera.ViewportSize else Vector2.new(1280, 720)) / uiScale.Scale
	local scale = math.min(1, (available.X - 560) / width, (available.Y - 200) / height)
	boardScale.Scale = math.max(0.45, scale)
end

---------------------------------------------------------------------------
-- The hub: one big hexagon per tree around the middle
---------------------------------------------------------------------------
local HUB_SIZE = 150
-- Where each tree's hexagon goes around the middle one (in hexagon widths/heights)
local HUB_SPOTS = {
	luck = Vector2.new(-0.87, -0.5),
	cash = Vector2.new(0.87, -0.5),
	speed = Vector2.new(-0.87, 0.5),
	power = Vector2.new(0.87, 0.5),
	auto = Vector2.new(0, -1),
}

local function treeProgress(tree: Config.UpgradeTree): (number, number)
	local have, total = 0, 0
	for _, node in Config.UPGRADE_LIST do
		if node.tree == tree.id then
			total += 1
			if owned[node.id] then
				have += 1
			end
		end
	end
	return have, total
end

showHub = function()
	currentTree = nil
	selected = nil
	refreshInfo()
	clearBoard()
	buyAllButton.Visible = false
	local have, total = 0, #Config.UPGRADE_LIST
	for id in owned do
		if Config.UPGRADES[id] then
			have += 1
		end
	end
	local middle, paintMiddle = hexagon(board, UDim2.fromOffset(0, 0), HUB_SIZE, 7)
	paintMiddle(Color3.fromRGB(90, 220, 90))
	textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.8, 0.22), Text = "UPGRADES", ZIndex = 10, Parent = middle })
	textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.6, 0.16), Text = have .. "/" .. total, ZIndex = 10, Parent = middle })
	for _, tree in Config.UPGRADE_TREES do
		local spot = HUB_SPOTS[tree.id] or Vector2.zero
		local hex, paint = hexagon(board, UDim2.fromOffset(spot.X * HUB_SIZE * 0.95, spot.Y * HUB_SIZE * 1.12), HUB_SIZE, 7)
		paint(tree.color)
		local treeHave, treeTotal = treeProgress(tree)
		textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromScale(0.5, 0.28), Text = tree.icon, ZIndex = 10, Parent = hex })
		textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.82, 0.18), Text = tree.name, ZIndex = 10, Parent = hex })
		textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.76), Size = UDim2.fromScale(0.5, 0.13), Text = treeHave .. "/" .. treeTotal, TextColor3 = if treeHave == treeTotal then Color3.fromRGB(255, 230, 80) else Color3.new(1, 1, 1), ZIndex = 10, Parent = hex })
		hex.Activated:Connect(function()
			showTree(tree)
		end)
	end
	fitBoard(HUB_SIZE * 2.8, HUB_SIZE * 3.3)
end

---------------------------------------------------------------------------
-- A tree: BACK in the middle, its branches all around
---------------------------------------------------------------------------
local NODE_SIZE = 62
local STEP = 33 -- distance between two hexagons of a branch, along it
local SIDE = 27 -- zigzag: every other hexagon steps to the side
-- Directions of the branches (degrees, 0 = right, 90 = down) for 1 to 4 branches
local BRANCH_ANGLES = { { -90 }, { -90, 90 }, { -90, 150, 30 }, { -135, -45, 135, 45 } }

local nodeViews: { [string]: { paint: (Color3) -> (), price: TextLabel, hex: TextButton } } = {}

local function paintNode(node: Config.Upgrade)
	local view = nodeViews[node.id]
	if not view then
		return
	end
	local state = stateOf(node)
	local tree = currentTree :: Config.UpgradeTree
	if state == "owned" then
		view.paint(tree.color)
		view.price.Text = "✔"
		view.price.TextColor3 = Color3.new(1, 1, 1)
	elseif state == "available" then
		view.paint(tree.color:Lerp(Color3.new(1, 1, 1), 0.55))
		view.price.Text = "$" .. Format.number(node.cost)
		view.price.TextColor3 = if cash() >= node.cost then CASH_COLOR else Color3.fromRGB(255, 140, 140)
	else
		view.paint(Color3.fromRGB(70, 70, 85))
		view.price.Text = "🔒"
		view.price.TextColor3 = Color3.fromRGB(200, 200, 210)
	end
end

showTree = function(tree: Config.UpgradeTree)
	currentTree = tree
	selected = nil
	refreshInfo()
	clearBoard()
	table.clear(nodeViews)
	buyAllButton.Visible = true

	local back, paintBack = hexagon(board, UDim2.fromOffset(0, 0), NODE_SIZE * 1.15, 7)
	paintBack(Color3.fromRGB(255, 110, 60))
	textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.6, 0.34), Text = "↩", ZIndex = 10, Parent = back })
	textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(0.7, 0.2), Text = "BACK", ZIndex = 10, Parent = back })
	back.Activated:Connect(showHub)

	local angles = BRANCH_ANGLES[math.min(#tree.branches, #BRANCH_ANGLES)]
	local reachX, reachY = NODE_SIZE * 2, NODE_SIZE * 2
	for _, node in Config.UPGRADE_LIST do
		if node.tree ~= tree.id then
			continue
		end
		local angle = math.rad(angles[(node.branch - 1) % #angles + 1])
		local along = Vector2.new(math.cos(angle), math.sin(angle))
		local side = Vector2.new(-along.Y, along.X)
		local position = along * (NODE_SIZE * 0.95 + (node.index - 1) * STEP) + side * (if node.index % 2 == 1 then -SIDE / 2 else SIDE / 2)
		reachX = math.max(reachX, math.abs(position.X) * 2 + NODE_SIZE)
		reachY = math.max(reachY, math.abs(position.Y) * 2 + NODE_SIZE)

		local hex, paint = hexagon(board, UDim2.fromOffset(position.X, position.Y), NODE_SIZE, 7)
		textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromScale(0.86, 0.2), Text = node.name, ZIndex = 10, Parent = hex })
		local price = textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.62), Size = UDim2.fromScale(0.7, 0.2), Text = "", ZIndex = 10, Parent = hex })
		if node.star then
			textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.85, 0.12), Size = UDim2.fromOffset(22, 22), Text = "★", TextColor3 = Color3.fromRGB(255, 220, 60), ZIndex = 11, Parent = hex })
		end
		nodeViews[node.id] = { paint = paint, price = price, hex = hex }
		paintNode(node)
		local function choose()
			selected = node
			refreshInfo()
		end
		hex.Activated:Connect(choose)
		hex.MouseEnter:Connect(choose)
	end
	fitBoard(reachX, reachY)
end

local function refreshAll()
	cashLabel.Text = "$" .. Format.number(cash())
	if not window.Visible then
		return
	end
	if currentTree then
		for _, node in Config.UPGRADE_LIST do
			if node.tree == currentTree.id then
				paintNode(node)
			end
		end
	end
	refreshInfo()
end

openButton.Activated:Connect(function()
	window.Visible = not window.Visible
	if window.Visible then
		showHub()
		refreshAll()
	end
end)

remotes:WaitForChild("ProfileSync").OnClientEvent:Connect(function(data)
	local wasOwned = owned
	owned = data.upgrades or {}
	-- A new upgrade: a little pop on its hexagon
	for id in owned do
		local pop = not wasOwned[id] and nodeViews[id] and nodeViews[id].hex:FindFirstChildOfClass("UIScale")
		if pop then
			pop.Scale = 1.4
			TweenService:Create(pop, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end
	end
	if window.Visible and not currentTree then
		showHub()
	end
	refreshAll()
end)
player:GetAttributeChangedSignal("Cash"):Connect(refreshAll)

-- Hidden while the player watches a tower fight
local function refreshVisible()
	local inTower = player:GetAttribute("InTower") ~= nil or player:GetAttribute("TowerScreen") ~= nil
	openButton.Visible = not inTower
	if inTower then
		window.Visible = false
	end
end
player:GetAttributeChangedSignal("InTower"):Connect(refreshVisible)
player:GetAttributeChangedSignal("TowerScreen"):Connect(refreshVisible)
refreshVisible()
