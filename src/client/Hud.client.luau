-- Player UI: cash, weather, backpack, packs (with the card reveal), cards and stands, Index,
-- rewards, notifications and the plaza stations (Shop, Sell, Grading, Towers). The fights
-- themselves are drawn by Tower.client.luau. Everything is created from code. Sizes are designed for a
-- 1280x720 screen and a UIScale resizes the whole UI to fit any screen.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
local SoundService = game:GetService("SoundService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
local PackArt = require(ReplicatedStorage.Shared.PackArt)
local Format = require(ReplicatedStorage.Shared.Format)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(22, 22, 32)
local PANEL = Color3.fromRGB(34, 34, 48)
local ACCENT = Color3.fromRGB(80, 200, 120)
local RED = Color3.fromRGB(225, 75, 75)
local CASH_COLOR = Color3.fromRGB(120, 255, 140)
local GREY = Color3.fromRGB(110, 110, 125)

local refreshTowers: () -> ()
local profile = { cards = {}, stands = {}, packs = {}, backpackLevel = 0, index = {}, pity = {}, dailyDay = 0, dailyStreak = 0, team = {}, towers = {}, traitRerolls = 0, upgrades = {}, standCount = Config.BASE_STANDS }
local autoOpen = false -- pack opening: AUTO is on (upgrade tree)

---------------------------------------------------------------------------
-- Small helpers to build the UI
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

local function corner(radius: number?)
	return create("UICorner", { CornerRadius = UDim.new(0, radius or 10) })
end

local function stroke(thickness: number?, color: Color3?)
	return create("UIStroke", { Thickness = thickness or 2, Color = color or Color3.new(0, 0, 0), ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

local function gradient(top: Color3, bottom: Color3)
	return create("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bottom) })
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

local function button(props, onClick: () -> ())
	local color = props.BackgroundColor3 or ACCENT
	local text = props.Text or ""
	props.Text = ""
	props.AutoButtonColor = true
	-- White background so the gradient below gives the button its real color
	props.BackgroundColor3 = Color3.new(1, 1, 1)
	-- The text lives in a child label: a UIGradient tints its own object's text, never its children
	local b = create("TextButton", props, {
		corner(10),
		stroke(3.5),
		gradient(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.25)),
		textLabel({
			Name = "Label",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(1, -12, 1, -8),
			Text = text,
		}),
	})
	local scale = create("UIScale", { Parent = b })
	b.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.06), { Scale = 0.93 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1.04 }):Play()
	end)
	-- Grows a little under the mouse
	b.MouseEnter:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.Activated:Connect(onClick)
	return b
end

local function setButtonColor(b: TextButton, color: Color3)
	local g = b:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.25))
	end
end

local function clearList(list: Instance)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function scrollingList(props, padding: number?)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.ScrollBarThickness = 6
	return create("ScrollingFrame", props, { create("UIListLayout", { Padding = UDim.new(0, padding or 6), SortOrder = Enum.SortOrder.LayoutOrder }) })
end

local function scrollingGrid(props, cell: Vector2, padding: Vector2)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.CanvasSize = UDim2.new()
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	props.ScrollBarThickness = 6
	return create("ScrollingFrame", props, {
		create("UIGridLayout", { CellSize = UDim2.fromOffset(cell.X, cell.Y), CellPadding = UDim2.fromOffset(padding.X, padding.Y), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingTop = UDim.new(0, 14), PaddingLeft = UDim.new(0, 8), PaddingBottom = UDim.new(0, 14) }),
	})
end

-- "Gold Tralalero Tralala"
local function displayName(cardId: string, variantId: string): string
	local card = Config.CARDS[cardId]
	if variantId == "normal" then
		return card.name
	end
	return Config.VARIANT[variantId].name .. " " .. card.name
end

local function nameColor(cardId: string, variantId: string): Color3
	if variantId == "normal" then
		return Config.RARITY[Config.CARDS[cardId].rarity].color
	end
	return Config.VARIANT[variantId].color
end

-- "Gold Tralalero Tralala [MINT 9] (HP Boost)" for an owned card key
local function keyName(key: string): string
	local cardId, variantId = Config.splitKey(key)
	local grade = Config.keyGrade(key)
	local trait = Config.keyTrait(key)
	return displayName(cardId, variantId) .. (if grade then " [" .. grade.name .. "]" else "") .. (if trait then " (" .. trait.name .. ")" else "")
end

-- Most valuable first
local function sortedKeys(cards: { [string]: number }): { string }
	local keys = {}
	for key in cards do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local ia, ib = Config.keyIncome(a), Config.keyIncome(b)
		if ia ~= ib then
			return ia > ib
		end
		return a < b
	end)
	return keys
end

---------------------------------------------------------------------------
-- Screen setup
---------------------------------------------------------------------------
local gui = create("ScreenGui", {
	Name = "Hud",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})

local root = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	Parent = gui,
})
local uiScale = create("UIScale", { Parent = root })
local function updateScale()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local size = camera.ViewportSize
	local scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.5, 1.4)
	uiScale.Scale = scale
	root.Size = UDim2.fromScale(1 / scale, 1 / scale)
end
local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	updateScale()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

---------------------------------------------------------------------------
-- Top bar: cash, income, weather
---------------------------------------------------------------------------
local statsBar = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 44),
	Size = UDim2.fromOffset(650, 64),
	BackgroundColor3 = Color3.new(1, 1, 1),
	Parent = root,
}, {
	corner(16),
	stroke(3),
	gradient(Color3.fromRGB(45, 45, 65), DARK),
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 10) }),
})

local function statBox(order: number, title: string, color: Color3)
	local box = create("Frame", { LayoutOrder = order, Size = UDim2.fromOffset(200, 54), BackgroundTransparency = 1, Parent = statsBar })
	textLabel({ Size = UDim2.new(1, 0, 0, 20), Text = title, TextColor3 = color, Parent = box })
	return textLabel({ Position = UDim2.fromOffset(0, 20), Size = UDim2.new(1, 0, 0, 32), Text = "0", Parent = box })
end

-- Keeps the top bar just under Roblox's own buttons (menu, chat), whatever the screen
local function placeTopBar()
	local ok, inset = pcall(function()
		return GuiService.TopbarInset.Height
	end)
	local top = math.max(44, (if ok then inset else 0) / uiScale.Scale + 6)
	statsBar.Position = UDim2.new(0.5, 0, 0, top)
end
uiScale:GetPropertyChangedSignal("Scale"):Connect(placeTopBar)
pcall(function()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeTopBar)
end)
placeTopBar()

local cashValue = statBox(1, "CASH", CASH_COLOR)
local incomeValue = statBox(2, "PER SECOND", Color3.fromRGB(255, 220, 80))
local backpackValue = statBox(3, "BACKPACK", Color3.fromRGB(120, 190, 255))

local function refreshStats()
	cashValue.Text = "$" .. Format.number(player:GetAttribute("Cash") or 0)
	incomeValue.Text = "$" .. Format.number(player:GetAttribute("Income") or 0) .. "/s"
	local used, size = player:GetAttribute("BackpackUsed") or 0, player:GetAttribute("BackpackSize") or Config.BACKPACK_SLOTS
	backpackValue.Text = used .. "/" .. size
	backpackValue.TextColor3 = if used >= size then RED else Color3.new(1, 1, 1)
end
for _, attr in { "Cash", "Income", "BackpackUsed", "BackpackSize" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshStats)
end
refreshStats()

-- "+$123" drifting down under the Cash counter, below the weather line when money comes in
local lastCash = player:GetAttribute("Cash") or 0
player:GetAttributeChangedSignal("Cash"):Connect(function()
	local cash = player:GetAttribute("Cash") or 0
	local gained = cash - lastCash
	lastCash = cash
	if gained <= 0 then
		return
	end
	local popup = textLabel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, -210 + math.random(-40, 40), 0, statsBar.Position.Y.Offset + 112),
		Size = UDim2.fromOffset(200, 30),
		Text = "+$" .. Format.number(gained),
		TextColor3 = CASH_COLOR,
		ZIndex = 0, -- under the windows
		Parent = root,
	})
	TweenService:Create(popup, TweenInfo.new(1, Enum.EasingStyle.Quad), { Position = popup.Position + UDim2.fromOffset(0, 40), TextTransparency = 1 }):Play()
	local outline = popup:FindFirstChildOfClass("UIStroke")
	if outline then
		TweenService:Create(outline, TweenInfo.new(1), { Transparency = 1 }):Play()
	end
	task.delay(1, function()
		popup:Destroy()
	end)
end)

local weatherLabel = textLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 128),
	-- follows the top bar (see placeTopBar)
	Size = UDim2.fromOffset(520, 22),
	Text = "",
	Parent = root,
})

statsBar:GetPropertyChangedSignal("Position"):Connect(function()
	weatherLabel.Position = UDim2.new(0.5, 0, 0, statsBar.Position.Y.Offset + 84)
end)
weatherLabel.Position = UDim2.new(0.5, 0, 0, statsBar.Position.Y.Offset + 84)

local function refreshWeather()
	local weatherId = ReplicatedStorage:GetAttribute("Weather") or ""
	local weather = Config.WEATHER[weatherId]
	local now = os.time()
	if weather then
		local left = math.max(0, (ReplicatedStorage:GetAttribute("WeatherEnds") or now) - now)
		weatherLabel.Text = string.format("%s: %s (%d:%02d)", weather.name, weather.description, left // 60, left % 60)
		weatherLabel.TextColor3 = weather.color
	else
		local left = math.max(0, (ReplicatedStorage:GetAttribute("NextWeather") or now) - now)
		weatherLabel.Text = string.format("Next weather in %d:%02d", left // 60, left % 60)
		weatherLabel.TextColor3 = Color3.fromRGB(200, 200, 215)
	end
end
task.spawn(function()
	while true do
		refreshWeather()
		task.wait(1)
	end
end)

---------------------------------------------------------------------------
-- Notifications and server announcements
---------------------------------------------------------------------------
local toastList = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.fromOffset(700, 200),
	BackgroundTransparency = 1,
	ZIndex = 20,
	Parent = root,
}, { create("UIListLayout", { VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }) })

local function toast(message: string, color: Color3?)
	local label = textLabel({ Size = UDim2.new(1, 0, 0, 30), Text = message, TextColor3 = color or Color3.new(1, 1, 1), ZIndex = 20, Parent = toastList })
	task.delay(3.5, function()
		TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		task.wait(0.4)
		label:Destroy()
	end)
end

local announceLabel = textLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 148),
	Size = UDim2.fromOffset(820, 40),
	Text = "",
	Visible = false,
	ZIndex = 20,
	Parent = root,
})
local announceScale = create("UIScale", { Parent = announceLabel })
local announceToken = 0
local function announce(message: string, color: Color3)
	announceToken += 1
	local token = announceToken
	announceLabel.Text = message
	announceLabel.TextColor3 = color
	announceLabel.Visible = true
	announceScale.Scale = 0.4
	TweenService:Create(announceScale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(5, function()
		if announceToken == token then
			announceLabel.Visible = false
		end
	end)
end

remotes.Notify.OnClientEvent:Connect(function(message: string)
	toast(message)
end)
remotes.Announce.OnClientEvent:Connect(announce)

---------------------------------------------------------------------------
-- A card drawn in the UI (reveal and Index)
---------------------------------------------------------------------------
local function cardFrame(parent: Instance, cardId: string, variantId: string, size: UDim2, zIndex: number?, grade: Config.Grade?, traitId: string?): Frame
	local frame, shine = CardArt.build(parent, cardId, variantId, grade, zIndex, traitId)
	frame.Size = size
	-- Shiny cards and full arts: a light streak sweeps across them every few seconds
	if shine then
		task.spawn(function()
			while frame.Parent do
				shine.Position = UDim2.fromScale(-0.5, 0.5)
				TweenService:Create(shine, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Position = UDim2.fromScale(1.5, 0.5) }):Play()
				task.wait(if variantId == "holo" then 1.6 else 2.8)
			end
		end)
	end
	-- Top rarities: their two-color border turns slowly
	local spin = frame:FindFirstChild("Spin", true)
	if spin then
		task.spawn(function()
			while frame.Parent do
				spin.Rotation = (spin.Rotation + 3) % 360
				task.wait(1 / 30)
			end
		end)
	end
	return frame
end

---------------------------------------------------------------------------
-- Panels
---------------------------------------------------------------------------
local panels = {}

local function makePanel(name: string, title: string, color: Color3, size: Vector2?)
	local panel = create("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.56),
		Size = UDim2.fromOffset((size or Vector2.new(620, 460)).X, (size or Vector2.new(620, 460)).Y),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = root,
	}, { corner(18), stroke(3), gradient(PANEL, DARK) })
	-- Pops open
	local pop = create("UIScale", { Parent = panel })
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			pop.Scale = 0.85
			TweenService:Create(pop, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
	end)
	local header = create("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Color3.new(1, 1, 1), Parent = panel }, { corner(18), gradient(color, color:Lerp(Color3.new(0, 0, 0), 0.35)) })
	textLabel({ Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -80, 0, 36), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = header })
	button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(40, 36), Text = "X", BackgroundColor3 = RED }, function()
		panel.Visible = false
	end).Parent = header
	panels[name] = panel
	return panel
end

local function togglePanel(name: string)
	for key, panel in panels do
		panel.Visible = key == name and not panel.Visible
	end
end

---------------------------------------------------------------------------
-- My packs: the packs in the backpack, opened whenever the player wants
---------------------------------------------------------------------------
local PACKS_COLOR = Color3.fromRGB(255, 150, 60)
local packsPanel = makePanel("Packs", "MY PACKS", PACKS_COLOR, Vector2.new(700, 480))
local packsList = scrollingGrid({ Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 1, -70), Parent = packsPanel }, Vector2.new(140, 250), Vector2.new(22, 12))

local openPack: (string) -> ()

local function pityText(pack: Config.Pack): string
	local rarity = Config.pityRarity(pack.id)
	local left = Config.PITY_PACKS - (profile.pity[pack.id] or 0)
	return string.format("%s or better guaranteed in %d pack%s", rarity.name, left, if left > 1 then "s" else "")
end

local function refreshPacks()
	clearList(packsList)
	local any = false
	for _, pack in Config.PACKS do
		local count = profile.packs[pack.id] or 0
		if count > 0 then
			any = true
			local tile = create("Frame", { LayoutOrder = pack.order, BackgroundTransparency = 1, Parent = packsList })
			local art = create("Frame", { Size = UDim2.fromOffset(140, 196), BackgroundTransparency = 1, Parent = tile })
			PackArt.build(art, pack)
			textLabel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -6), Size = UDim2.fromOffset(56, 30), Text = "x" .. count, Visible = count > 1, TextColor3 = Color3.fromRGB(255, 225, 60), Rotation = 8, ZIndex = 5, Parent = tile })
			button({ Position = UDim2.fromOffset(10, 202), Size = UDim2.fromOffset(120, 44), Text = "OPEN", BackgroundColor3 = ACCENT }, function()
				openPack(pack.id)
			end).Parent = tile
		end
	end
	if not any then
		textLabel({ Size = UDim2.new(0, 600, 0, 60), Text = "No packs yet: buy some at the Pack Shop in the middle of the map!", TextWrapped = true, TextColor3 = GREY, Parent = packsList })
	end
end

---------------------------------------------------------------------------
-- Pack Shop (plaza station): packs go to the backpack, bigger backpacks
---------------------------------------------------------------------------
local SHOP_COLOR = Color3.fromRGB(90, 200, 120)
local shopPanel = makePanel("Shop", "PACK SHOP", SHOP_COLOR, Vector2.new(940, 560))
local upgradeRow = create("Frame", { Position = UDim2.fromOffset(14, 60), Size = UDim2.new(1, -28, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), Parent = shopPanel }, { corner(12), stroke(2), gradient(Color3.fromRGB(70, 110, 170), Color3.fromRGB(35, 50, 80)) })
local upgradeText = textLabel({ Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -230, 0, 36), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = upgradeRow })
local upgradeButton = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(190, 44), Text = "UPGRADE", BackgroundColor3 = ACCENT }, function()
	remotes.UpgradeBackpack:FireServer()
end)
upgradeButton.Parent = upgradeRow

-- Left: every pack as a tile (too expensive ones are dimmed with a lock). Right: the chosen
-- pack, its odds in big letters and the buy buttons.
local shopGrid = scrollingGrid({ Position = UDim2.fromOffset(10, 124), Size = UDim2.new(0, 560, 1, -134), Parent = shopPanel }, Vector2.new(120, 200), Vector2.new(14, 10))
local shopDetail = create("Frame", { Position = UDim2.fromOffset(586, 124), Size = UDim2.new(1, -600, 1, -134), BackgroundColor3 = DARK, Parent = shopPanel }, { corner(14), stroke(2) })
local detailArt = create("Frame", { Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(110, 154), BackgroundTransparency = 1, Parent = shopDetail })
local detailName = textLabel({ Position = UDim2.fromOffset(132, 14), Size = UDim2.new(1, -144, 0, 34), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
local detailPrice = textLabel({ Position = UDim2.fromOffset(132, 50), Size = UDim2.new(1, -144, 0, 28), Text = "", TextColor3 = CASH_COLOR, TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
local detailPity = textLabel({ Position = UDim2.fromOffset(132, 82), Size = UDim2.new(1, -144, 0, 40), Text = "", TextWrapped = true, TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = shopDetail })
local detailOdds = create("Frame", { Position = UDim2.fromOffset(14, 176), Size = UDim2.new(1, -28, 1, -240), BackgroundTransparency = 1, Parent = shopDetail }, {
	create("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local buyButtons: { { button: TextButton, count: number } } = {}
local shopPack = Config.PACKS[1]
for index, count in { 1, 5 } do
	local b = button({ AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(if index == 1 then 0 else 0.5, if index == 1 then 12 else 6, 1, -12), Size = UDim2.new(0.5, -18, 0, 48), Text = "BUY x" .. count, BackgroundColor3 = ACCENT }, function()
		remotes.BuyPack:FireServer(shopPack.id, count)
	end)
	b.Parent = shopDetail
	table.insert(buyButtons, { button = b, count = count })
end
local shopLocks: { [string]: GuiObject } = {}
local refreshShop: () -> ()

local function showShopPack(pack: Config.Pack)
	shopPack = pack
	clearList(detailArt)
	PackArt.build(detailArt, pack)
	detailName.Text = pack.name
	detailName.TextColor3 = pack.color:Lerp(Color3.new(1, 1, 1), 0.3)
	detailPrice.Text = "$" .. Format.number(pack.price) .. " each"
	detailPity.Text = pityText(pack)
	clearList(detailOdds)
	for _, rarity in Config.RARITIES do
		local chance = pack.odds[rarity.id]
		if chance then
			local line = create("Frame", { LayoutOrder = rarity.order, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, Parent = detailOdds })
			textLabel({ Size = UDim2.new(0.68, 0, 1, 0), Text = rarity.name, TextColor3 = rarity.color, TextXAlignment = Enum.TextXAlignment.Left, Parent = line })
			textLabel({ Position = UDim2.fromScale(0.68, 0), Size = UDim2.new(0.32, 0, 1, 0), Text = tostring(chance) .. "%", TextXAlignment = Enum.TextXAlignment.Right, Parent = line })
		end
	end
	refreshShop()
end

for _, pack in Config.PACKS do
	local tile = create("TextButton", { LayoutOrder = pack.order, BackgroundTransparency = 1, Text = "", Parent = shopGrid })
	local art = create("Frame", { Size = UDim2.fromOffset(120, 168), BackgroundTransparency = 1, Parent = tile })
	PackArt.build(art, pack)
	textLabel({ Position = UDim2.fromOffset(0, 172), Size = UDim2.fromOffset(120, 24), Text = "$" .. Format.number(pack.price), TextColor3 = CASH_COLOR, Parent = tile })
	local lock = create("Frame", { Size = UDim2.fromOffset(120, 168), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, ZIndex = 8, Visible = false, Parent = tile }, {
		create("UICorner", { CornerRadius = UDim.new(0.06, 0) }),
		textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.9, 0.2), Text = "LOCKED", ZIndex = 9 }),
	})
	shopLocks[pack.id] = lock
	tile.Activated:Connect(function()
		showShopPack(pack)
	end)
end

refreshShop = function()
	local cash = player:GetAttribute("Cash") or 0
	for _, entry in buyButtons do
		setButtonColor(entry.button, if cash >= shopPack.price * entry.count then ACCENT else GREY)
	end
	for packId, lock in shopLocks do
		lock.Visible = cash < Config.PACK[packId].price
	end
	detailPity.Text = pityText(shopPack)
	local level = profile.backpackLevel or 0
	local upgrade = Config.BACKPACK_UPGRADES[level + 1]
	local label = upgradeButton:FindFirstChild("Label") :: TextLabel
	if upgrade then
		upgradeText.Text = string.format("Backpack: %d slots  →  %d slots", Config.backpackSize(level), Config.backpackSize(level + 1))
		label.Text = "$" .. Format.number(upgrade.price)
		setButtonColor(upgradeButton, if cash >= upgrade.price then ACCENT else GREY)
	else
		upgradeText.Text = string.format("Backpack: %d slots (the biggest one!)", Config.backpackSize(level))
		label.Text = "MAX"
		setButtonColor(upgradeButton, GREY)
	end
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshShop)
showShopPack(Config.PACKS[1])

---------------------------------------------------------------------------
-- Pack opening: the pack shakes until the player taps it, its top tears off, the cards fly
-- out face down and flip one by one, the rarest last, with their "1 in X" chance underneath.
-- The rarer the card, the bigger the show: its back glows in its rarity's color before the
-- flip, light rays turn behind it, the screen flashes.
---------------------------------------------------------------------------
local reveal = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.2,
	Active = true,
	Visible = false,
	ZIndex = 10,
	Parent = root,
})
local revealTitle = textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.12, 0), Size = UDim2.fromOffset(600, 44), Text = "", ZIndex = 11, Parent = reveal })
local revealHint = textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.84, 0), Size = UDim2.fromOffset(400, 34), Text = "TAP TO OPEN!", ZIndex = 11, Visible = false, Parent = reveal })
local packStage = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(300, 420), BackgroundTransparency = 1, ZIndex = 11, Parent = reveal })
local revealRow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.55),
	Size = UDim2.fromOffset(760, 360),
	BackgroundTransparency = 1,
	ZIndex = 11,
	Parent = reveal,
}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 30) }) })
local revealButtons = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.94, 0), Size = UDim2.fromOffset(440, 56), BackgroundTransparency = 1, Visible = false, ZIndex = 11, Parent = reveal }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20) }),
})
local currentPack = "starter"
local setAuto: (boolean) -> ()
local opening = false
local skipping = false
local tapped: BindableEvent? = nil
button({ Size = UDim2.fromOffset(210, 56), Text = "OPEN AGAIN", BackgroundColor3 = ACCENT, ZIndex = 12 }, function()
	openPack(currentPack)
end).Parent = revealButtons
button({ Size = UDim2.fromOffset(160, 56), Text = "CLOSE", BackgroundColor3 = RED, ZIndex = 12 }, function()
	setAuto(false)
	reveal.Visible = false
end).Parent = revealButtons
-- Top right: at the bottom right it sat right on the jump button of phones
local skipButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 70), Size = UDim2.fromOffset(130, 50), Text = "SKIP ⏩", BackgroundColor3 = GREY, ZIndex = 12, Visible = false }, function()
	skipping = true
	if tapped then
		tapped:Fire()
	end
end)
skipButton.Parent = reveal
local minimizeButton: TextButton
-- AUTO (unlocked in the upgrade tree): keeps opening the same pack while there are some left
local autoButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 128), Size = UDim2.fromOffset(130, 46), Text = "AUTO: OFF", BackgroundColor3 = GREY, ZIndex = 12, Visible = false }, function() end)
autoButton.Parent = reveal
setAuto = function(on: boolean)
	autoOpen = on
	local label = autoButton:FindFirstChild("Label") :: TextLabel
	label.Text = if on then "AUTO: ON" else "AUTO: OFF"
	setButtonColor(autoButton, if on then Color3.fromRGB(80, 200, 255) else GREY)
	minimizeButton.Visible = on
end
autoButton.Activated:Connect(function()
	setAuto(not autoOpen)
	if autoOpen and not opening and reveal.Visible then
		task.spawn(openPack, currentPack)
	end
end)

-- Auto opening can be minimized: the packs keep opening without the animation and the cards
-- pulled show in small, with their 1/X, in a list at the top right of the screen
local autoMinimized = false
local autoStrip = create("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 44), Size = UDim2.fromOffset(270, 40), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = DARK, BackgroundTransparency = 0.2, Visible = false, Parent = root }, {
	corner(12),
	stroke(2.5),
	create("UIPadding", { PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6), PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }),
	create("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local stripHeader = create("Frame", { LayoutOrder = 0, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = autoStrip })
local stripTitle = textLabel({ Size = UDim2.new(1, -80, 1, 0), Text = "", TextXAlignment = Enum.TextXAlignment.Left, Parent = stripHeader })
local stripOrder = 0
local STRIP_LINES = 6

local function addStripLine(pull)
	stripOrder += 1
	local card = Config.CARDS[pull.card]
	local name = (if pull.variant == "normal" then "" else Config.VARIANT[pull.variant].name .. " ") .. card.name
	-- Newest on top: the layout order goes down
	local line = create("Frame", { LayoutOrder = -stripOrder, Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = autoStrip })
	textLabel({ Size = UDim2.new(1, -78, 1, 0), Text = name, TextColor3 = nameColor(pull.card, pull.variant), TextXAlignment = Enum.TextXAlignment.Left, Parent = line })
	textLabel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 74, 1, 0), Text = "1/" .. Format.number(pull.oneIn), TextColor3 = if pull.oneIn >= 100 then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(210, 210, 225), TextXAlignment = Enum.TextXAlignment.Right, Parent = line })
	if pull.oneIn >= 100 then
		local pop = create("UIScale", { Scale = 1.3, Parent = line })
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
	-- Only the last few lines stay
	local lines = {}
	for _, child in autoStrip:GetChildren() do
		if child:IsA("Frame") and child ~= stripHeader then
			table.insert(lines, child)
		end
	end
	table.sort(lines, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	for index = STRIP_LINES + 1, #lines do
		lines[index]:Destroy()
	end
end

local function refreshStripTitle()
	local pack = Config.PACK[currentPack]
	stripTitle.Text = "AUTO · " .. pack.name .. " x" .. (profile.packs[currentPack] or 0)
	stripTitle.TextColor3 = pack.color
end

local function stopMinimized()
	autoMinimized = false
	autoStrip.Visible = false
end

-- Expand: back to the full opening, which goes on with the animation
button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -38, 0.5, 0), Size = UDim2.fromOffset(34, 28), Text = "⤢", BackgroundColor3 = Color3.fromRGB(80, 200, 255) }, function()
	stopMinimized()
	if autoOpen and not opening then
		task.spawn(openPack, currentPack)
	end
end).Parent = stripHeader
button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(34, 28), Text = "■", BackgroundColor3 = RED }, function()
	setAuto(false)
	stopMinimized()
end).Parent = stripHeader

minimizeButton = button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 180), Size = UDim2.fromOffset(130, 46), Text = "MINIMIZE", BackgroundColor3 = Color3.fromRGB(80, 120, 200), ZIndex = 12, Visible = false }, function()
	if autoMinimized then
		return
	end
	autoMinimized = true
	reveal.Visible = false
	autoStrip.Visible = true
	refreshStripTitle()
	task.spawn(function()
		while autoMinimized and autoOpen do
			-- An animated opening that was going on finishes first (hidden)
			while opening do
				task.wait(0.1)
			end
			if not autoMinimized or not autoOpen then
				break
			end
			if (profile.packs[currentPack] or 0) < 1 then
				toast("No " .. Config.PACK[currentPack].name .. " left: auto opening stopped", RED)
				setAuto(false)
				stopMinimized()
				break
			end
			local pulls = remotes.OpenPack:InvokeServer(currentPack)
			if pulls then
				local order = {}
				for _, pull in pulls do
					table.insert(order, pull)
				end
				table.sort(order, function(a, b)
					return a.oneIn < b.oneIn
				end)
				for _, pull in order do
					addStripLine(pull)
				end
			end
			task.wait(0.2)
			refreshStripTitle()
			task.wait(1.2 / (1 + Config.upgradeBonus(profile.upgrades, "openSpeed")))
		end
	end)
end)
minimizeButton.Parent = reveal

local CARD_SIZE = UDim2.fromOffset(200, 280)
local CARD_PANEL = Color3.fromRGB(35, 30, 55)

-- The back of a card, like the floating cards of the plaza: pack-colored border, dark panel
local function cardBack(holder: Frame, pack: Config.Pack): Frame
	local back = create("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = pack.color, ZIndex = 12, Parent = holder }, {
		create("UICorner", { CornerRadius = UDim.new(0.07, 0) }),
		stroke(2),
	})
	create("Frame", { Position = UDim2.fromScale(0.06, 0.045), Size = UDim2.fromScale(0.88, 0.91), BackgroundColor3 = CARD_PANEL, ZIndex = 13, Parent = back }, {
		create("UICorner", { CornerRadius = UDim.new(0.07, 0) }),
		stroke(3, Color3.new(1, 1, 1)),
		textLabel({ Position = UDim2.fromScale(0.15, 0.18), Size = UDim2.fromScale(0.7, 0.42), Text = "?", TextColor3 = pack.color:Lerp(Color3.new(1, 1, 1), 0.3), ZIndex = 14 }),
		textLabel({ Position = UDim2.fromScale(0.08, 0.68), Size = UDim2.fromScale(0.84, 0.13), Text = "BRAINROT", ZIndex = 14 }),
	})
	return back
end

-- Light rays turning behind a rare card
local function rays(slot: Frame, color: Color3)
	local center = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(100, 140), Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, ZIndex = 10, Parent = slot })
	for i = 1, 6 do
		create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(46, 460), Rotation = i * 30, BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = 11, Parent = center }, {
			create("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1) }) }),
		})
	end
	local scale = create("UIScale", { Scale = 0, Parent = center })
	TweenService:Create(scale, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.spawn(function()
		while center.Parent do
			center.Rotation += 1
			task.wait(1 / 30)
		end
	end)
end

local function shake(target: GuiObject, times: number, angle: number)
	for i = 1, times do
		target.Rotation = if i % 2 == 0 then angle else -angle
		task.wait(0.04)
	end
	target.Rotation = 0
end

-- Built-in Roblox sounds (no upload needed)
local SOUNDS = {
	tear = { id = "rbxasset://sounds/swordslash.wav", volume = 0.6, pitch = 1.3 },
	whoosh = { id = "rbxasset://sounds/swordlunge.wav", volume = 0.35, pitch = 1.4 },
	flip = { id = "rbxasset://sounds/clickfast.wav", volume = 0.7, pitch = 1 },
	rare = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, pitch = 1 },
	tick = { id = "rbxasset://sounds/button.wav", volume = 0.4, pitch = 1.6 },
}
local soundCache: { [string]: Sound } = {}
local function sfx(name: string, pitch: number?)
	local info = SOUNDS[name]
	local sound = soundCache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.SoundId = info.id
		sound.Volume = info.volume
		sound.Parent = SoundService
		soundCache[name] = sound
	end
	local copy = sound:Clone()
	copy.PlaybackSpeed = (pitch or 1) * info.pitch
	copy.Parent = SoundService
	copy:Play()
	task.delay(3, function()
		copy:Destroy()
	end)
end

-- Little stars bursting out of a point of `parent` (a pack tearing, a rare card landing)
local function burst(parent: GuiObject, center: UDim2, color: Color3, amount: number, distance: number)
	for _ = 1, amount do
		local angle = math.random() * math.pi * 2
		local far = distance * (0.5 + math.random() * 0.7)
		local star = textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = center, Size = UDim2.fromOffset(26, 26), Text = if math.random() < 0.5 then "✦" else "★", TextColor3 = color:Lerp(Color3.new(1, 1, 1), math.random() * 0.5), Rotation = math.random(0, 360), ZIndex = 25, Parent = parent })
		local goal = center + UDim2.fromOffset(math.cos(angle) * far, math.sin(angle) * far)
		TweenService:Create(star, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = goal, Rotation = star.Rotation + 180, TextTransparency = 1 }):Play()
		local outline = star:FindFirstChildOfClass("UIStroke")
		if outline then
			TweenService:Create(outline, TweenInfo.new(0.7), { Transparency = 1 }):Play()
		end
		task.delay(0.75, function()
			star:Destroy()
		end)
	end
end

-- Confetti raining over the whole screen (the rarest pulls)
local function confetti(colors: { Color3 }, amount: number)
	for i = 1, amount do
		local piece = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(), 0, -0.05, 0), Size = UDim2.fromOffset(math.random(10, 18), math.random(6, 10)), Rotation = math.random(0, 360), BackgroundColor3 = colors[(i - 1) % #colors + 1], BorderSizePixel = 0, ZIndex = 28, Parent = reveal })
		local fall = 1.6 + math.random() * 1.4
		TweenService:Create(piece, TweenInfo.new(fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In), { Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.3, 0, 1.08, 0), Rotation = piece.Rotation + math.random(-540, 540) }):Play()
		task.delay(fall, function()
			piece:Destroy()
		end)
	end
end

-- The whole reveal shakes for a moment
local function screenShake(duration: number, strength: number)
	task.spawn(function()
		local started = os.clock()
		while os.clock() - started < duration do
			local fade = 1 - (os.clock() - started) / duration
			reveal.Position = UDim2.fromOffset((math.random() - 0.5) * strength * fade, (math.random() - 0.5) * strength * fade)
			task.wait(1 / 30)
		end
		reveal.Position = UDim2.fromOffset(0, 0)
	end)
end

-- Upgrade tree: openings play faster (Quick Hands...)
local function openSpeed(): number
	return 1 + Config.upgradeBonus(profile.upgrades, "openSpeed")
end
local function pause(seconds: number)
	task.wait(seconds / openSpeed())
end

local function showPull(slot: Frame, pull)
	local holder = slot:FindFirstChild("Holder") :: Frame
	local back = holder:FindFirstChild("Back") :: Frame
	local rarity = Config.RARITY[Config.CARDS[pull.card].rarity]
	local color = nameColor(pull.card, pull.variant)

	-- Teasing: from Epic up (or any shiny), the back glows in the card's color and shakes
	if not skipping and (rarity.order >= Config.RARITY.epic.order or pull.variant ~= "normal") then
		TweenService:Create(back, TweenInfo.new(0.3), { BackgroundColor3 = color }):Play()
		create("UIStroke", { Thickness = 6, Color = color, Transparency = 0.2, Parent = back })
		sfx("tick", 0.8 + math.min(rarity.order, 10) * 0.08)
		shake(holder, if pull.oneIn >= 1000 then 14 else 7, if pull.oneIn >= 1000 then 6 else 3)
	end
	-- Very rare pulls: the screen goes dark for a moment before the flip
	if not skipping and pull.oneIn >= 10000 then
		TweenService:Create(reveal, TweenInfo.new(0.4), { BackgroundTransparency = 0.02 }):Play()
		pause(0.8)
	end

	-- Flip: shrink the back to nothing, then grow the real card
	local shrink = TweenService:Create(holder, TweenInfo.new(0.15), { Size = UDim2.fromOffset(0, 280) })
	shrink:Play()
	shrink.Completed:Wait()
	back:Destroy()
	if pull.oneIn >= 100 then
		rays(slot, color)
	end
	cardFrame(holder, pull.card, pull.variant, UDim2.fromScale(1, 1), 12)
	TweenService:Create(holder, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = CARD_SIZE }):Play()
	sfx(if pull.oneIn >= 100 or pull.variant ~= "normal" then "rare" else "flip", if pull.oneIn >= 1000 then 0.8 else 1)

	-- A glow in the card's color behind it, stronger for rarer cards
	local glowStrength = math.clamp(rarity.order / 8, 0.25, 1)
	local glow = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(100, 140), Size = UDim2.fromOffset(200, 280), BackgroundTransparency = 1, ZIndex = 11, Parent = slot }, {
		create("UICorner", { CornerRadius = UDim.new(0.08, 0) }),
		create("UIStroke", { Thickness = 10, Color = color, Transparency = 1 - glowStrength * 0.8 }),
	})
	local glowScale = create("UIScale", { Scale = 0.9, Parent = glow })
	TweenService:Create(glowScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1.06 }):Play()
	task.spawn(function()
		while glow.Parent do
			TweenService:Create(glowScale, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Scale = 1.1 }):Play()
			pause(0.8)
			TweenService:Create(glowScale, TweenInfo.new(0.8, Enum.EasingStyle.Sine), { Scale = 1.03 }):Play()
			pause(0.8)
		end
	end)

	-- From Epic up (or shiny): the rarity in big letters over the card, and stars
	if rarity.order >= Config.RARITY.epic.order or pull.variant ~= "normal" then
		local callout = if pull.variant ~= "normal" then string.upper(Config.VARIANT[pull.variant].name) .. "!" else string.upper(rarity.name) .. "!"
		local tag = textLabel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(100, -14), Size = UDim2.fromOffset(240, 40), Text = callout, TextColor3 = color, Rotation = -6, ZIndex = 21, Parent = slot })
		local tagScale = create("UIScale", { Scale = 2.4, Parent = tag })
		TweenService:Create(tagScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		if not skipping then
			burst(slot, UDim2.fromOffset(100, 140), color, if pull.oneIn >= 1000 then 22 else 12, if pull.oneIn >= 1000 then 260 else 170)
		end
	end

	local chance = textLabel({ Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 34), Text = "1/" .. Format.number(pull.oneIn), TextColor3 = color, ZIndex = 13, Parent = slot })
	if pull.new then
		textLabel({ AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0, -14, 0, 252), Size = UDim2.fromOffset(70, 28), Text = "NEW!", TextColor3 = Color3.fromRGB(255, 230, 80), Rotation = -12, ZIndex = 20, Parent = slot })
	end
	-- The rarer the pull, the bigger the pop
	if pull.oneIn >= 100 then
		local pop = create("UIScale", { Scale = 1.6, Parent = chance })
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	end
	-- Very rare pulls: the screen flashes in the card's color and the card shakes
	if pull.oneIn >= 1000 then
		local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = color, BackgroundTransparency = 0.2, ZIndex = 30, Parent = root })
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function()
			flash:Destroy()
		end)
		task.spawn(shake, holder, 8, 4)
		if not skipping then
			screenShake(0.5, 18)
			confetti({ color, rarity.color, Color3.fromRGB(255, 230, 80), Color3.new(1, 1, 1) }, if pull.oneIn >= 10000 then 90 else 50)
		end
	end
	if pull.oneIn >= 10000 then
		TweenService:Create(reveal, TweenInfo.new(0.6), { BackgroundTransparency = 0.2 }):Play()
	end
end

-- The pack in the middle of the screen wobbles until it is tapped (or after a few seconds),
-- then its top tears off and it drops away
local function tearPack(pack: Config.Pack)
	clearList(packStage)
	packStage.Rotation = 0
	packStage.Position = UDim2.fromScale(0.5, 0.52)
	local art = PackArt.build(packStage, pack, 12)
	-- Light rays in the pack's color turn behind it
	local packRays = create("Frame", { Name = "Rays", Size = UDim2.fromOffset(200, 280), Position = UDim2.fromOffset(50, 70), BackgroundTransparency = 1, ZIndex = 10, Parent = packStage })
	rays(packRays, pack.color)
	local scale = create("UIScale", { Scale = 0.3, Parent = packStage })
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

	local event = Instance.new("BindableEvent")
	tapped = event
	local hitbox = create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 20, Parent = packStage })
	hitbox.Activated:Connect(function()
		event:Fire()
	end)
	revealHint.Visible = true
	local waiting = true
	task.spawn(function()
		local t = 0
		while waiting do
			t += 1
			packStage.Rotation = math.sin(t * 0.5) * (2 + math.min(t, 60) / 15)
			task.wait(1 / 30)
		end
	end)
	task.delay(if autoOpen then 0.3 else 4 / openSpeed(), function()
		event:Fire()
	end)
	if not skipping then
		event.Event:Wait()
	end
	waiting = false
	tapped = nil
	revealHint.Visible = false
	hitbox:Destroy()
	packStage.Rotation = 0
	scale:Destroy()

	if not skipping then
		local packRaysNow = packStage:FindFirstChild("Rays")
		if packRaysNow then
			packRaysNow:Destroy()
		end
		-- The top tears off in one strip, from left to right: the torn part peels up a little
		-- more as the tear goes, leaving a ragged white edge on the bag, then comes off
		local duration = 0.6 / openSpeed()
		local started = os.clock()
		local nextTick = 0
		local top: Frame = PackArt.setTear(art, 0)
		while true do
			local progress = math.min(1, (os.clock() - started) / duration)
			-- Slow at first, then faster, like pulling foil
			top = PackArt.setTear(art, progress * progress * (3 - 2 * progress))
			if progress >= nextTick then
				sfx("tick", 0.7 + progress * 0.5)
				burst(packStage, UDim2.fromScale(progress, 0.07), Color3.new(1, 1, 1), 1, 40)
				nextTick += 0.2
			end
			if progress >= 1 then
				break
			end
			task.wait()
		end
		sfx("tear")
		TweenService:Create(top, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = UDim2.new(0.6, 0, -0.9, 0), Rotation = 25 }):Play()
		-- Light pours out of the open top
		local glow = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.07), Size = UDim2.new(0.9, 0, 0, 10), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 30, Parent = packStage }, {
			create("UICorner", { CornerRadius = UDim.new(1, 0) }),
		})
		TweenService:Create(glow, TweenInfo.new(0.35), { Size = UDim2.new(1.3, 0, 0, 60), BackgroundTransparency = 1 }):Play()
		burst(reveal, UDim2.fromScale(0.5, 0.25), pack.color, 12, 200)
		pause(0.35)
		TweenService:Create(packStage, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = UDim2.fromScale(0.5, 1.4) }):Play()
		pause(0.2)
	end
	task.delay(0.4, function()
		clearList(packStage)
	end)
end

openPack = function(packId: string)
	if opening then
		return
	end
	local pack = Config.PACK[packId]
	if (profile.packs[packId] or 0) < 1 then
		toast("No " .. pack.name .. " left: buy more at the Pack Shop", RED)
		return
	end
	opening = true
	skipping = false
	currentPack = packId
	local pulls = remotes.OpenPack:InvokeServer(packId)
	if not pulls then
		opening = false
		return
	end
	for _, panel in panels do
		panel.Visible = false
	end
	clearList(revealRow)
	revealButtons.Visible = false
	revealTitle.Text = pack.name
	revealTitle.TextColor3 = pack.color
	reveal.BackgroundTransparency = 0.2
	reveal.Visible = true
	skipButton.Visible = true
	autoButton.Visible = Config.upgradeBonus(profile.upgrades, "autoOpen") > 0

	tearPack(pack)

	-- The cards fly out of the pack face down
	local slots = {}
	for index in pulls do
		local slot = create("Frame", { LayoutOrder = index, Size = UDim2.fromOffset(200, 340), BackgroundTransparency = 1, ZIndex = 11, Parent = revealRow })
		local holder = create("Frame", { Name = "Holder", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, (2 - index) * 230, 0, 60), Size = UDim2.fromOffset(60, 84), Rotation = (index - 2) * 40 + 180, BackgroundTransparency = 1, ZIndex = 12, Parent = slot })
		cardBack(holder, pack)
		if not skipping then
			sfx("whoosh", 0.9 + index * 0.1)
		end
		TweenService:Create(holder, TweenInfo.new(if skipping then 0.01 else 0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0), Size = CARD_SIZE, Rotation = 0 }):Play()
		slots[index] = slot
		if not skipping then
			pause(0.12)
		end
	end
	-- Rarest card last, for suspense
	local order = {}
	for index in pulls do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		return pulls[a].oneIn < pulls[b].oneIn
	end)
	pause(if skipping then 0.05 else 0.5)
	for _, index in order do
		showPull(slots[index], pulls[index])
		if not skipping then
			pause(if pulls[index].oneIn >= 1000 then 1 else 0.45)
		end
	end
	skipButton.Visible = false
	revealButtons.Visible = true
	opening = false
	if autoOpen then
		task.wait(0.8)
		if autoOpen and reveal.Visible and not opening then
			if (profile.packs[packId] or 0) > 0 then
				task.spawn(openPack, packId)
			else
				setAuto(false)
			end
		end
	end
end

-- While a pack opens, the top bar steps aside; while any window is open, the shopkeepers'
-- name tags (always drawn on top of the world) are hidden so they never cross the UI
reveal:GetPropertyChangedSignal("Visible"):Connect(function()
	statsBar.Visible = not reveal.Visible
	weatherLabel.Visible = not reveal.Visible
	-- Phones: the thumbstick and jump button hide while a pack opens, so no tap lands on them
	GuiService.TouchControlsEnabled = not reveal.Visible
end)
local hotbarHidden = false
local windowOpen = false -- a pack opening or any window is on screen
local refreshOpenHeld: () -> () -- the OPEN PACK button, set up further down
task.spawn(function()
	while true do
		local covered = reveal.Visible
		for _, panel in panels do
			covered = covered or panel.Visible
		end
		for _, tag in CollectionService:GetTagged("HideUnderUi") do
			(tag :: BillboardGui).Enabled = not covered
		end
		if covered ~= windowOpen then
			windowOpen = covered
			refreshOpenHeld()
		end
		-- The Roblox hotbar would cover the bottom of the windows (on phones above all)
		if covered ~= hotbarHidden then
			hotbarHidden = covered
			pcall(function()
				StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, not covered)
			end)
		end
		task.wait(0.25)
	end
end)

-- Packs in the Roblox backpack (PackTools.luau): click or tap while holding one to open it.
-- A big OPEN button also shows while a pack is in hand, easier to hit on phones.
local heldPack: string? = nil
local openHeld = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(200, 54), Text = "OPEN PACK", BackgroundColor3 = ACCENT, Visible = false }, function()
	if heldPack then
		openPack(heldPack)
	end
end)
openHeld.Parent = root
-- During an opening or while a window (shop, My Packs...) is open: no OPEN PACK button
function refreshOpenHeld()
	openHeld.Visible = heldPack ~= nil and not windowOpen and not reveal.Visible
end
reveal:GetPropertyChangedSignal("Visible"):Connect(refreshOpenHeld)

local function watchTool(tool: Instance)
	local packId = tool:IsA("Tool") and tool:GetAttribute("PackId")
	if not packId or tool:GetAttribute("Watched") then
		return
	end
	tool:SetAttribute("Watched", true)
	local t = tool :: Tool
	t.Activated:Connect(function()
		openPack(packId)
	end)
	t.Equipped:Connect(function()
		heldPack = packId
		refreshOpenHeld()
	end)
	t.Unequipped:Connect(function()
		if heldPack == packId then
			heldPack = nil
			refreshOpenHeld()
		end
	end)
end

local function watchContainer(container: Instance)
	for _, child in container:GetChildren() do
		watchTool(child)
	end
	container.ChildAdded:Connect(watchTool)
end

player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchContainer(child)
	end
end)
local backpackFolder = player:FindFirstChildOfClass("Backpack")
if backpackFolder then
	watchContainer(backpackFolder)
end
player.CharacterAdded:Connect(function(character)
	heldPack = nil
	refreshOpenHeld()
	watchContainer(character)
end)
if player.Character then
	watchContainer(player.Character)
end

---------------------------------------------------------------------------
-- Cards and stands
---------------------------------------------------------------------------
local CARDS_COLOR = Color3.fromRGB(80, 160, 255)
local cardsPanel = makePanel("Cards", "MY CARDS", CARDS_COLOR, Vector2.new(900, 480))
local backpackTitle = textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(300, 26), Text = "Backpack", TextXAlignment = Enum.TextXAlignment.Left, Parent = cardsPanel })
local inventoryList = scrollingGrid({ Position = UDim2.fromOffset(12, 88), Size = UDim2.new(0, 560, 1, -96), Parent = cardsPanel }, Vector2.new(120, 208), Vector2.new(14, 12))
local standsTitle = textLabel({ Position = UDim2.fromOffset(590, 60), Size = UDim2.fromOffset(150, 26), Text = "Stands", TextXAlignment = Enum.TextXAlignment.Left, Parent = cardsPanel })
button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 58), Size = UDim2.fromOffset(150, 30), Text = "PLACE BEST", BackgroundColor3 = ACCENT }, function()
	remotes.PlaceBest:FireServer()
end).Parent = cardsPanel
local standsList = scrollingList({ Position = UDim2.fromOffset(584, 92), Size = UDim2.new(1, -596, 1, -104), Parent = cardsPanel })

local function cardRow(parent: Instance, order: number, key: string, count: number?, buttonsWidth: number?)
	local cardId, variantId = Config.splitKey(key)
	local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = PANEL, Parent = parent }, { corner(8), stroke(1.5) })
	local suffix = if count and count > 1 then "  x" .. count else ""
	local width = -20 - (buttonsWidth or 0)
	textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, width, 0, 22), Text = keyName(key) .. suffix, TextColor3 = nameColor(cardId, variantId), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	textLabel({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, width, 0, 18), Text = "$" .. Format.number(Config.keyIncome(key)) .. "/s  ·  1/" .. Format.number(Config.oneIn(cardId, variantId)), TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	return row
end

local inventorySignature: string? = nil
local function refreshCards()
	local inBackpack = 0
	for _, list in { profile.cards, profile.packs } do
		for _, count in list do
			inBackpack += count
		end
	end
	backpackTitle.Text = string.format("Backpack %d/%d (cards and packs)", inBackpack, player:GetAttribute("BackpackSize") or Config.backpackSize(profile.backpackLevel or 0))
	local keys = sortedKeys(profile.cards)
	-- Every card is a little 3D scene: only rebuild the grid when the cards really changed
	local signature = {}
	for _, key in keys do
		table.insert(signature, key .. "=" .. profile.cards[key])
	end
	local newSignature = table.concat(signature, ";")
	if newSignature ~= inventorySignature then
		inventorySignature = newSignature
		clearList(inventoryList)
		for order, key in keys do
			local count = profile.cards[key]
			local cardId, variantId, scores, traitId = Config.splitKey(key)
			local nextVariant = if scores or traitId then nil else Config.FUSE_NEXT[variantId]
			local tile = create("Frame", { LayoutOrder = order, BackgroundTransparency = 1, Parent = inventoryList })
			local holder = create("Frame", { Size = UDim2.fromOffset(120, 168), BackgroundTransparency = 1, Parent = tile })
			cardFrame(holder, cardId, variantId, UDim2.fromScale(1, 1), 1, Config.keyGrade(key), traitId)
			if count > 1 then
				textLabel({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 4, 0, 172), Size = UDim2.fromOffset(50, 26), Text = "x" .. count, TextColor3 = Color3.fromRGB(255, 225, 60), Rotation = -6, ZIndex = 20, Parent = tile })
			end
			local width = if nextVariant then 58 else 120
			button({ Position = UDim2.fromOffset(0, 174), Size = UDim2.fromOffset(width, 32), Text = "PLACE", BackgroundColor3 = ACCENT }, function()
				remotes.PlaceCard:FireServer(key)
			end).Parent = tile
			if nextVariant then
				local canFuse = count >= Config.FUSE_COUNT
				button({ Position = UDim2.fromOffset(62, 174), Size = UDim2.fromOffset(58, 32), Text = if canFuse then "FUSE" else string.format("%d/%d", count, Config.FUSE_COUNT), BackgroundColor3 = if canFuse then Config.VARIANT[nextVariant].color:Lerp(DARK, 0.2) else GREY }, function()
					if canFuse then
						remotes.Fuse:FireServer(key)
					else
						toast("Get " .. Config.FUSE_COUNT .. " of this card to fuse it into " .. Config.VARIANT[nextVariant].name)
					end
				end).Parent = tile
			end
		end
		if #keys == 0 then
			textLabel({ Text = "No cards yet: open a pack!", TextWrapped = true, TextColor3 = GREY, Parent = inventoryList })
		end
	end

	clearList(standsList)
	local used = 0
	for slot = 1, profile.standCount or Config.BASE_STANDS do
		local key = profile.stands[tostring(slot)]
		if key then
			used += 1
			local row = cardRow(standsList, slot, key, nil, 50)
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(40, 36), Text = "X", BackgroundColor3 = RED }, function()
				remotes.RemoveCard:FireServer(slot)
			end).Parent = row
		else
			create("Frame", { LayoutOrder = slot, Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = DARK, Parent = standsList }, {
				corner(8),
				stroke(1.5, GREY),
				textLabel({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = "Stand " .. slot .. ": empty", TextColor3 = GREY, TextScaled = false, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left }),
			})
		end
	end
	standsTitle.Text = string.format("Stands %d/%d", used, profile.standCount or Config.BASE_STANDS)
end

---------------------------------------------------------------------------
-- Sell (plaza station): cards for a share of their pack price, packs for part of their price
---------------------------------------------------------------------------
local SELL_COLOR = Color3.fromRGB(255, 190, 60)
local sellPanel = makePanel("Sell", "SELL", SELL_COLOR, Vector2.new(760, 500))
textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 22), Text = "Rarer and shinier cards sell for more. Cards on your stands can't be sold.", TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = sellPanel })
local sellList = scrollingList({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 1, -104), Parent = sellPanel })

-- Sell prices with the upgrade tree's bonus
local function sellBonus(): number
	return 1 + Config.upgradeBonus(profile.upgrades, "sell")
end

-- A row with "SELL 1" and "SELL ALL" buttons
local function sellRow(order: number, title: string, color: Color3, info: string, count: number, onSell: (number) -> ())
	local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = PANEL, Parent = sellList }, { corner(8), stroke(1.5) })
	textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -250, 0, 22), Text = title .. (if count > 1 then "  x" .. count else ""), TextColor3 = color, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	textLabel({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -250, 0, 18), Text = info, TextColor3 = CASH_COLOR, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -118, 0.5, 0), Size = UDim2.fromOffset(100, 36), Text = "SELL 1", BackgroundColor3 = SELL_COLOR:Lerp(DARK, 0.2) }, function()
		onSell(1)
	end).Parent = row
	if count > 1 then
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(100, 36), Text = "SELL ALL", BackgroundColor3 = RED }, function()
			onSell(count)
		end).Parent = row
	end
end

local function refreshSell()
	clearList(sellList)
	local order = 0
	for _, pack in Config.PACKS do
		local count = profile.packs[pack.id] or 0
		if count > 0 then
			order += 1
			sellRow(order, pack.name, pack.color, "$" .. Format.number(math.floor(Config.packSellPrice(pack.id) * sellBonus())) .. " each", count, function(amount)
				remotes.SellPack:FireServer(pack.id, amount)
			end)
		end
	end
	-- Cheapest cards first: they are the ones players usually sell
	local keys = sortedKeys(profile.cards)
	for i = #keys, 1, -1 do
		local key = keys[i]
		local cardId, variantId = Config.splitKey(key)
		order += 1
		sellRow(order, keyName(key), nameColor(cardId, variantId), "$" .. Format.number(math.floor(Config.sellPrice(key) * sellBonus())) .. " each", profile.cards[key], function(amount)
			remotes.SellCard:FireServer(key, amount)
		end)
	end
	if order == 0 then
		textLabel({ Size = UDim2.new(1, -10, 0, 30), Text = "Nothing to sell", TextColor3 = GREY, Parent = sellList })
	end
end

---------------------------------------------------------------------------
-- Grading (plaza station): 4 scores from 1 to 10, the average gives the grade
---------------------------------------------------------------------------
local GRADE_COLOR = Color3.fromRGB(170, 110, 255)
local gradePanel = makePanel("Grade", "GRADING", GRADE_COLOR, Vector2.new(760, 500))
do
	local parts = {}
	for i = #Config.GRADES, 1, -1 do
		local grade = Config.GRADES[i]
		if grade.cash > 1 then
			table.insert(parts, string.format('<font color="#%s">%d: %s</font>', grade.color:ToHex(), grade.grade, Format.multiplier(grade.cash)))
		end
	end
	textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 22), Text = "Grade multiplies Cash and sell price  ·  " .. table.concat(parts, "  "), RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = gradePanel })
end
local gradeList = scrollingList({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 1, -104), Parent = gradePanel })
local showGrade: (any) -> ()
local grading = false

local function refreshGrade()
	clearList(gradeList)
	local order = 0
	-- Cards not graded yet first, then the graded ones (a reroll keeps the better grade)
	local keys = sortedKeys(profile.cards)
	local rank = {}
	for index, key in keys do
		rank[key] = index + (if Config.keyGrade(key) then #keys else 0)
	end
	table.sort(keys, function(a, b)
		return rank[a] < rank[b]
	end)
	for _, key in keys do
		local cardId, variantId = Config.splitKey(key)
		local grade = Config.keyGrade(key)
		order += 1
		local cost = if grade then Config.regradeCost(cardId, variantId) else Config.gradeCost(cardId, variantId)
		local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = PANEL, Parent = gradeList }, { corner(8), stroke(1.5) })
		local count = profile.cards[key]
		textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -220, 0, 22), Text = keyName(key) .. (if count > 1 then "  x" .. count else ""), TextColor3 = nameColor(cardId, variantId), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local info = "$" .. Format.number(Config.keyIncome(key)) .. "/s"
		if grade then
			info ..= string.format('   <font color="#%s">%s</font>  ·  reroll: keeps the better grade', grade.color:ToHex(), grade.name)
		end
		textLabel({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -220, 0, 18), Text = info, RichText = true, TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local canPay = (player:GetAttribute("Cash") or 0) >= cost
		local color = if grade then Color3.fromRGB(120, 80, 200) else GRADE_COLOR
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(190, 36), Text = (if grade then "REROLL $" else "GRADE $") .. Format.number(cost), BackgroundColor3 = if canPay then color else GREY }, function()
			if grading then
				return
			end
			if (player:GetAttribute("Cash") or 0) < cost then
				toast("Not enough Cash to grade this card", RED)
				return
			end
			grading = true
			local result = remotes.Grade:InvokeServer(key)
			if result then
				showGrade(result)
			end
			grading = false
		end).Parent = row
	end
	if order == 0 then
		textLabel({ Size = UDim2.new(1, -10, 0, 30), Text = "No card to grade: open some packs first", TextColor3 = GREY, Parent = gradeList })
	end
end

-- The grading result: the 4 scores appear one by one, then the grade
local gradeReveal = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Visible = false,
	ZIndex = 10,
	Parent = root,
})
local gradeCardHolder = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, -200, 0.52, 0), Size = CARD_SIZE, BackgroundTransparency = 1, ZIndex = 11, Parent = gradeReveal })
local gradeScores = create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0.5, -60, 0.48, 0), Size = UDim2.fromOffset(360, 230), BackgroundTransparency = 1, ZIndex = 11, Parent = gradeReveal }, {
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local gradeTitle = textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.16, 0), Size = UDim2.fromOffset(700, 44), Text = "", ZIndex = 11, Parent = gradeReveal })
local gradeResult = textLabel({ AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, -60, 0.48, 125), Size = UDim2.fromOffset(460, 44), Text = "", ZIndex = 12, Parent = gradeReveal })
local gradeClose = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.9, 0), Size = UDim2.fromOffset(160, 56), Text = "OK", BackgroundColor3 = ACCENT, ZIndex = 12 }, function()
	gradeReveal.Visible = false
	gradePanel.Visible = true
end)
-- While a grade shows, the Grading window and the top bar step aside so nothing covers it
gradeReveal:GetPropertyChangedSignal("Visible"):Connect(function()
	statsBar.Visible = not gradeReveal.Visible and not reveal.Visible
	weatherLabel.Visible = statsBar.Visible
end)
gradeClose.Parent = gradeReveal

showGrade = function(result)
	local cardId, variantId = Config.splitKey(result.key)
	local grade = Config.keyGrade(result.key) :: Config.Grade
	clearList(gradeCardHolder)
	clearList(gradeScores)
	gradeResult.Text = ""
	gradeClose.Visible = false
	gradeTitle.Text = "Grading " .. displayName(cardId, variantId) .. "..."
	gradeTitle.TextColor3 = nameColor(cardId, variantId)
	cardFrame(gradeCardHolder, cardId, variantId, UDim2.fromScale(1, 1), 11)
	gradePanel.Visible = false
	gradeReveal.Visible = true

	for index, criterion in Config.GRADE_CRITERIA do
		local score = result.scores[index]
		local row = create("Frame", { LayoutOrder = index, Size = UDim2.new(1, 0, 0, 44), BackgroundColor3 = PANEL, ZIndex = 11, Parent = gradeScores }, { corner(8), stroke(1.5) })
		textLabel({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.6, 0, 1, -12), Text = criterion, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 12, Parent = row })
		local value = textLabel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 4), Size = UDim2.new(0.3, 0, 1, -8), Text = "", TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 12, Parent = row })
		-- The number rolls for a moment before landing on the score
		for _ = 1, 8 do
			value.Text = tostring(math.random(1, 10))
			task.wait(0.05)
		end
		value.Text = tostring(score)
		value.TextColor3 = if score >= 9 then Color3.fromRGB(255, 215, 60) elseif score >= 7 then CASH_COLOR else Color3.new(1, 1, 1)
		local pop = create("UIScale", { Scale = 1.5, Parent = value })
		TweenService:Create(pop, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		task.wait(0.35)
	end

	local total = 0
	for _, score in result.scores do
		total += score
	end
	task.wait(0.3)
	gradeTitle.Text = displayName(cardId, variantId)
	-- The card again, now with its grade badge
	clearList(gradeCardHolder)
	cardFrame(gradeCardHolder, cardId, variantId, UDim2.fromScale(1, 1), 11, grade, (Config.keyTrait(result.key) or {} :: any).id)
	gradeResult.Text = string.format("Average %.2f  ·  %s  ·  %s Cash", total / #result.scores, grade.name, Format.multiplier(grade.cash))
	gradeResult.TextColor3 = grade.color
	if result.kept then
		-- A reroll that rolled worse: the card keeps its old grade
		gradeResult.Text = string.format("Rolled %.2f: worse, your card keeps %s", total / #result.scores, grade.name)
	elseif result.regrade then
		gradeResult.Text = "UPGRADED!  " .. gradeResult.Text
	end
	local pop = create("UIScale", { Scale = if grade.grade >= 8 then 1.8 else 1.2, Parent = gradeResult })
	TweenService:Create(pop, TweenInfo.new(0.6, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	gradeClose.Visible = true
end

---------------------------------------------------------------------------
-- Index: every card of every pack, found or not
---------------------------------------------------------------------------
local INDEX_COLOR = Color3.fromRGB(170, 90, 230)
local indexPanel = makePanel("Index", "INDEX", INDEX_COLOR, Vector2.new(900, 500))
local indexBonus = textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(560, 26), Text = "", TextColor3 = CASH_COLOR, TextXAlignment = Enum.TextXAlignment.Left, Parent = indexPanel })
-- One tab per pack, in a row that scrolls sideways (there are many packs)
local indexTabs = create("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 92),
	Size = UDim2.new(1, -24, 0, 48),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollingDirection = Enum.ScrollingDirection.X,
	ScrollBarThickness = 6,
	Parent = indexPanel,
}, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local indexGrid = create("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 148),
	Size = UDim2.new(1, -24, 1, -160),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	Parent = indexPanel,
}, {
	create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 210), CellPadding = UDim2.fromOffset(18, 34), SortOrder = Enum.SortOrder.LayoutOrder }),
	create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 6), PaddingBottom = UDim.new(0, 34) }),
})

local indexPack = "starter"
local tabButtons: { [string]: TextButton } = {}

local function refreshIndex()
	local completed = player:GetAttribute("CompletedPacks") or 0
	indexBonus.Text = string.format("Completed packs: %d/%d  ·  Cash bonus: +%d%%", completed, #Config.PACKS, math.floor(Config.INDEX_BONUS * completed * 100 + 0.5))
	for _, pack in Config.PACKS do
		local found, total = 0, 0
		for _, card in Config.packCards(pack.id) do
			total += 1
			if profile.index[card.id] then
				found += 1
			end
		end
		local label = tabButtons[pack.id]:FindFirstChild("Label") :: TextLabel
		label.Text = string.format("%s %d/%d", string.gsub(pack.name, " Pack", ""), found, total)
		setButtonColor(tabButtons[pack.id], if pack.id == indexPack then pack.color else GREY)
	end

	clearList(indexGrid)
	for order, card in Config.packCards(indexPack) do
		if profile.index[card.id] then
			local frame = cardFrame(indexGrid, card.id, "normal", UDim2.fromOffset(150, 210))
			frame.LayoutOrder = order
			textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(0.9, 0, 0, 20), Text = "1/" .. Format.number(Config.oneIn(card.id, "normal")), ZIndex = 10, Parent = frame })
		else
			local rarity = Config.RARITY[card.rarity]
			-- Not found yet: the card's back, with a border dimmed in its rarity's color
			local back = create("Frame", { LayoutOrder = order, BackgroundColor3 = rarity.color:Lerp(DARK, 0.55), Parent = indexGrid }, {
				create("UICorner", { CornerRadius = UDim.new(0.07, 0) }),
				stroke(2),
			})
			create("Frame", { Position = UDim2.fromScale(0.06, 0.045), Size = UDim2.fromScale(0.88, 0.91), BackgroundColor3 = Color3.fromRGB(35, 30, 55), Parent = back }, {
				create("UICorner", { CornerRadius = UDim.new(0.07, 0) }),
				stroke(2.5, Color3.new(1, 1, 1)),
				textLabel({ Position = UDim2.fromScale(0.05, 0.025), Size = UDim2.fromScale(0.9, 0.085), Text = string.upper(rarity.name), TextColor3 = rarity.color }),
				textLabel({ Position = UDim2.fromScale(0.2, 0.28), Size = UDim2.fromScale(0.6, 0.35), Text = "?", TextColor3 = rarity.color:Lerp(DARK, 0.3) }),
			})
			textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.new(0.9, 0, 0, 20), Text = "1/" .. Format.number(Config.oneIn(card.id, "normal")), TextColor3 = GREY, Parent = back })
		end
	end
end

for _, pack in Config.PACKS do
	tabButtons[pack.id] = button({ LayoutOrder = pack.order, Size = UDim2.fromOffset(164, 38), Text = pack.name, BackgroundColor3 = GREY }, function()
		indexPack = pack.id
		refreshIndex()
	end)
	tabButtons[pack.id].Parent = indexTabs
end
player:GetAttributeChangedSignal("CompletedPacks"):Connect(refreshIndex)

---------------------------------------------------------------------------
-- Rewards: daily reward and codes
---------------------------------------------------------------------------
local REWARDS_COLOR = Color3.fromRGB(255, 200, 60)
local rewardsPanel = makePanel("Rewards", "REWARDS", REWARDS_COLOR, Vector2.new(520, 380))
local dailyInfo = textLabel({ Position = UDim2.fromOffset(24, 70), Size = UDim2.new(1, -48, 0, 60), Text = "", TextWrapped = true, TextScaled = false, TextSize = 22, Parent = rewardsPanel })
button({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 136), Size = UDim2.fromOffset(280, 52), Text = "CLAIM DAILY REWARD", BackgroundColor3 = ACCENT }, function()
	remotes.ClaimDaily:FireServer()
end).Parent = rewardsPanel
textLabel({ Position = UDim2.fromOffset(24, 214), Size = UDim2.new(1, -48, 0, 28), Text = "Codes", Parent = rewardsPanel })
local codeBox = create("TextBox", {
	Position = UDim2.fromOffset(24, 252),
	Size = UDim2.new(1, -190, 0, 48),
	BackgroundColor3 = DARK,
	Font = FONT,
	PlaceholderText = "Enter a code",
	Text = "",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 24,
	ClearTextOnFocus = false,
	Parent = rewardsPanel,
}, { corner(10), stroke(2) })
button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -24, 0, 252), Size = UDim2.fromOffset(140, 48), Text = "REDEEM", BackgroundColor3 = Color3.fromRGB(80, 160, 255) }, function()
	local result = remotes.RedeemCode:InvokeServer(codeBox.Text)
	toast(result)
	codeBox.Text = ""
end).Parent = rewardsPanel

local function refreshRewards()
	local today = math.floor(os.time() / 86400)
	local streak = profile.dailyStreak or 0
	if profile.dailyDay == today then
		dailyInfo.Text = string.format("Daily reward claimed (day %d). Come back tomorrow!", streak)
	else
		local nextDay = if profile.dailyDay == today - 1 then math.min(streak + 1, Config.DAILY_STREAK_MAX) else 1
		dailyInfo.Text = string.format("Day %d reward: $%s", nextDay, Format.number(Config.DAILY_REWARD_BASE * nextDay))
	end
end

---------------------------------------------------------------------------
-- Towers (plaza station): the team of 3 cards, the Trait Rerolls and the 4 towers
---------------------------------------------------------------------------
local TOWERS_COLOR = Color3.fromRGB(255, 80, 90)
local towersPanel = makePanel("Towers", "TOWERS", TOWERS_COLOR, Vector2.new(940, 540))
textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(520, 26), Text = "Your cards (the more Cash, the stronger)", TextXAlignment = Enum.TextXAlignment.Left, Parent = towersPanel })
local towerCardsList = scrollingList({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(0, 540, 1, -104), Parent = towersPanel })
local teamTitle = textLabel({ Position = UDim2.fromOffset(570, 60), Size = UDim2.fromOffset(200, 26), Text = "Team", TextXAlignment = Enum.TextXAlignment.Left, Parent = towersPanel })
local teamList = create("Frame", { Position = UDim2.fromOffset(566, 92), Size = UDim2.fromOffset(360, 160), BackgroundTransparency = 1, Parent = towersPanel }, {
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})
local rerollLabel = textLabel({ Position = UDim2.fromOffset(570, 254), Size = UDim2.fromOffset(350, 22), Text = "", TextColor3 = Color3.fromRGB(255, 215, 60), TextXAlignment = Enum.TextXAlignment.Left, Parent = towersPanel })
local towerList = create("Frame", { Position = UDim2.fromOffset(566, 282), Size = UDim2.fromOffset(360, 246), BackgroundTransparency = 1, Parent = towersPanel }, {
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
})

local function statsText(key: string): string
	local stats = Config.keyStats(key)
	return "❤ " .. Format.number(stats.hp) .. "   ⚔ " .. Format.number(stats.dmg)
end

local function power(key: string): number
	local stats = Config.keyStats(key)
	return stats.hp * stats.dmg
end

-- Every owned card key (backpack and stands) with its count, strongest first
local function ownedCards(): ({ string }, { [string]: number })
	local counts = {}
	for key, count in profile.cards do
		counts[key] = (counts[key] or 0) + count
	end
	for _, key in profile.stands do
		counts[key] = (counts[key] or 0) + 1
	end
	local keys = {}
	for key in counts do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local pa, pb = power(a), power(b)
		if pa ~= pb then
			return pa > pb
		end
		return a < b
	end)
	return keys, counts
end

local function setTeam(team: { string })
	profile.team = team
	remotes.SetTeam:FireServer(team)
	refreshTowers()
end

local rerolling = false

refreshTowers = function()
	local team = profile.team or {}
	local keys, counts = ownedCards()
	local inTeam = {}
	for _, key in team do
		inTeam[key] = (inTeam[key] or 0) + 1
	end

	clearList(towerCardsList)
	for order, key in keys do
		local cardId, variantId = Config.splitKey(key)
		local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = PANEL, Parent = towerCardsList }, { corner(8), stroke(1.5) })
		local count = counts[key]
		textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -250, 0, 22), Text = keyName(key) .. (if count > 1 then "  x" .. count else ""), TextColor3 = nameColor(cardId, variantId), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		textLabel({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -250, 0, 18), Text = statsText(key), TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local used = inTeam[key] or 0
		local canAdd = #team < Config.TEAM_SIZE and used < count
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(100, 36), Text = if used > 0 and not canAdd then "IN TEAM" else "ADD", BackgroundColor3 = if canAdd then ACCENT else GREY }, function()
			if canAdd then
				local newTeam = table.clone(team)
				table.insert(newTeam, key)
				setTeam(newTeam)
			elseif #team >= Config.TEAM_SIZE then
				toast("Your team is full: remove a card first", RED)
			end
		end).Parent = row
		-- Trait Reroll: only for cards in the backpack
		if (profile.traitRerolls or 0) > 0 and (profile.cards[key] or 0) > 0 then
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -116, 0.5, 0), Size = UDim2.fromOffset(110, 36), Text = "🎲 TRAIT", BackgroundColor3 = Color3.fromRGB(200, 150, 40) }, function()
				if rerolling then
					return
				end
				rerolling = true
				remotes.RerollTrait:InvokeServer(key)
				rerolling = false
			end).Parent = row
		end
	end
	if #keys == 0 then
		textLabel({ Size = UDim2.new(1, -10, 0, 30), Text = "No cards yet: open some packs first!", TextColor3 = GREY, Parent = towerCardsList })
	end

	clearList(teamList)
	teamTitle.Text = string.format("Team %d/%d", #team, Config.TEAM_SIZE)
	for slot = 1, Config.TEAM_SIZE do
		local key = team[slot]
		local row = create("Frame", { LayoutOrder = slot, Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = if key then PANEL else DARK, Parent = teamList }, { corner(8), stroke(1.5, if key then Color3.new(0, 0, 0) else GREY) })
		if key then
			local cardId, variantId = Config.splitKey(key)
			textLabel({ Position = UDim2.fromOffset(10, 3), Size = UDim2.new(1, -66, 0, 22), Text = slot .. ". " .. keyName(key), TextColor3 = nameColor(cardId, variantId), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			textLabel({ Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -66, 0, 17), Text = statsText(key), TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(40, 34), Text = "X", BackgroundColor3 = RED }, function()
				local newTeam = table.clone(team)
				table.remove(newTeam, slot)
				setTeam(newTeam)
			end).Parent = row
		else
			textLabel({ Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), Text = slot .. ". Empty: add a card", TextColor3 = GREY, TextScaled = false, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		end
	end

	rerollLabel.Text = string.format("🎲 Trait Rerolls: %d  (one every %d floors)", profile.traitRerolls or 0, Config.TOWER_TRAIT_FLOORS)

	clearList(towerList)
	for _, tower in Config.TOWERS do
		local best = (profile.towers or {})[tower.id] or 0
		local row = create("Frame", { LayoutOrder = tower.order, Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = Color3.new(1, 1, 1), Parent = towerList }, { corner(10), stroke(2), gradient(tower.color:Lerp(DARK, 0.35), tower.color:Lerp(DARK, 0.7)) })
		textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -200, 0, 26), Text = tower.name, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local floors = if tower.floors then string.format("Best: %d/%d", best, tower.floors) else string.format("Best: floor %d", best)
		textLabel({ Position = UDim2.fromOffset(10, 31), Size = UDim2.new(1, -200, 0, 19), Text = floors, TextColor3 = Color3.fromRGB(220, 220, 230), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		-- A fight going on in the background (hidden, see Tower.client.luau): no new one
		local busyTower = player:GetAttribute("TowerAuto")
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(88, 42), Text = "ENTER", BackgroundColor3 = if #team > 0 and not busyTower then ACCENT else GREY }, function()
			if #team == 0 then
				toast("Add cards to your team first", RED)
				return
			end
			if busyTower then
				toast("Your team is already fighting: tap the swords on the right", RED)
				return
			end
			for _, panel in panels do
				panel.Visible = false
			end
			remotes.StartTower:FireServer(tower.id)
		end).Parent = row
	end
end

button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 58), Size = UDim2.fromOffset(150, 30), Text = "AUTO TEAM", BackgroundColor3 = ACCENT }, function()
	local keys, counts = ownedCards()
	local team = {}
	for _, key in keys do
		for _ = 1, counts[key] do
			if #team < Config.TEAM_SIZE then
				table.insert(team, key)
			end
		end
	end
	setTeam(team)
end).Parent = towersPanel

-- The main UI steps aside while the player is in a tower (Tower.client.luau draws the fight)
local function refreshInTower()
	local inTower = player:GetAttribute("InTower") ~= nil or player:GetAttribute("TowerScreen") ~= nil
	root.Visible = not inTower and player:GetAttribute("UpgradesOpen") == nil
	-- While a tower fight is on screen, no "E" prompt (the tower's own JOIN among them) can fire
	ProximityPromptService.Enabled = not inTower
end
player:GetAttributeChangedSignal("UpgradesOpen"):Connect(refreshInTower)
player:GetAttributeChangedSignal("InTower"):Connect(refreshInTower)
player:GetAttributeChangedSignal("TowerScreen"):Connect(refreshInTower)
refreshInTower()
player:GetAttributeChangedSignal("TowerAuto"):Connect(function()
	refreshTowers()
end)

---------------------------------------------------------------------------
-- Side buttons
---------------------------------------------------------------------------
local sideBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(150, 360),
	BackgroundTransparency = 1,
	Parent = root,
}, { create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

for order, entry in { { "Packs", PACKS_COLOR, "📦" }, { "Cards", CARDS_COLOR, "🃏" }, { "Index", INDEX_COLOR, "📖" }, { "Rewards", REWARDS_COLOR, "🎁" } } do
	local name, color, icon = entry[1], entry[2], entry[3]
	button({ LayoutOrder = order, Size = UDim2.fromOffset(150, 56), Text = icon .. " " .. string.upper(name), BackgroundColor3 = color }, function()
		togglePanel(name)
	end).Parent = sideBar
end

-- Teleports: two buttons at the very top of the screen, in the row of Roblox's own buttons
local teleportRow = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(250, 40), BackgroundTransparency = 1, Parent = root }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }),
})
-- As tall as Roblox's top row allows, so it never runs into the top bar under it
local function placeTeleportRow()
	local ok, inset = pcall(function()
		return GuiService.TopbarInset.Height
	end)
	local height = math.clamp((if ok then inset else 0) / uiScale.Scale - 12, 34, 44)
	teleportRow.Position = UDim2.new(0.5, 0, 0, 6)
	teleportRow.Size = UDim2.fromOffset(250, height)
end
uiScale:GetPropertyChangedSignal("Scale"):Connect(placeTeleportRow)
pcall(function()
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(placeTeleportRow)
end)
placeTeleportRow()
reveal:GetPropertyChangedSignal("Visible"):Connect(function()
	teleportRow.Visible = not reveal.Visible
end)
for order, entry in { { "base", "🏠 BASE", Color3.fromRGB(70, 140, 230) }, { "shop", "🛒 SHOP", SHOP_COLOR } } do
	button({ LayoutOrder = order, Size = UDim2.new(0, 120, 1, 0), Text = entry[2], BackgroundColor3 = entry[3] }, function()
		for _, panel in panels do
			panel.Visible = false
		end
		remotes.Teleport:FireServer(entry[1])
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if rootPart then
			local before = rootPart.Position
			task.spawn(function()
				-- Wait for the move, then put the camera behind the character so it doesn't stay
				-- inside a booth or a wall
				for _ = 1, 20 do
					task.wait(0.05)
					if (rootPart.Position - before).Magnitude > 10 then
						break
					end
				end
				local camera = Workspace.CurrentCamera
				if camera then
					local look = rootPart.CFrame.LookVector
					camera.CFrame = CFrame.lookAt(rootPart.Position - look * 14 + Vector3.new(0, 7, 0), rootPart.Position + Vector3.new(0, 2, 0))
				end
			end)
		end
	end).Parent = teleportRow
end

---------------------------------------------------------------------------
-- Profile updates from the server
---------------------------------------------------------------------------
local function refreshAll()
	refreshPacks()
	refreshShop()
	refreshSell()
	refreshGrade()
	refreshCards()
	refreshIndex()
	refreshRewards()
	refreshTowers()
end

remotes.ProfileSync.OnClientEvent:Connect(function(data)
	profile = data
	refreshAll()
end)

---------------------------------------------------------------------------
-- Plaza stations: their prompt (key E) opens their panel, walking away closes it
---------------------------------------------------------------------------
local STATION_PANELS = { shop = "Shop", sell = "Sell", grade = "Grade", towers = "Towers" }
local stationPrompt: ProximityPrompt? = nil

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local panelName = STATION_PANELS[prompt:GetAttribute("Station") or ""]
	if panelName then
		stationPrompt = prompt
		for key, panel in panels do
			panel.Visible = key == panelName
		end
	end
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		local prompt = stationPrompt
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local spot = prompt and prompt.Parent :: BasePart?
		if prompt and spot and rootPart and (rootPart.Position - spot.Position).Magnitude > 20 then
			stationPrompt = nil
			for _, name in STATION_PANELS do
				panels[name].Visible = false
			end
		end
	end
end)
refreshAll()
remotes.RequestSync:FireServer()

