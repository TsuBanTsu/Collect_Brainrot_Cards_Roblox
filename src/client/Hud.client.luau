-- Player UI: cash, weather, backpack, packs (with the card reveal), cards and stands, Index,
-- rewards, notifications and the plaza stations (Shop, Sell, Grading, Towers). The fights
-- themselves are drawn by Tower.client.luau. Everything is created from code. Sizes are designed for a
-- 1280x720 screen and a UIScale resizes the whole UI to fit any screen.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local CardArt = require(ReplicatedStorage.Shared.CardArt)
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
local profile = { cards = {}, stands = {}, packs = {}, backpackLevel = 0, index = {}, pity = {}, dailyDay = 0, dailyStreak = 0, team = {}, towers = {}, traitRerolls = 0 }

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
		Position = UDim2.new(0.5, -210 + math.random(-40, 40), 0, 160),
		Size = UDim2.fromOffset(200, 30),
		Text = "+$" .. Format.number(gained),
		TextColor3 = CASH_COLOR,
		ZIndex = 5,
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
	Position = UDim2.new(0.5, 0, 0, 118),
	Size = UDim2.fromOffset(520, 22),
	Text = "",
	Parent = root,
})

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
local packsList = scrollingList({ Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -76), Parent = packsPanel }, 8)

local openPack: (string) -> ()

local function oddsText(pack: Config.Pack): string
	local parts = {}
	for _, rarity in Config.RARITIES do
		local chance = pack.odds[rarity.id]
		if chance then
			table.insert(parts, string.format('<font color="#%s">%s %s%%</font>', rarity.color:ToHex(), rarity.name, tostring(chance)))
		end
	end
	return table.concat(parts, "  ")
end

local function pityText(pack: Config.Pack): string
	local rarity = Config.pityRarity(pack.id)
	local left = Config.PITY_PACKS - (profile.pity[pack.id] or 0)
	return string.format("%s or better guaranteed in %d pack%s", rarity.name, left, if left > 1 then "s" else "")
end

-- A pack row with its name, odds and a line under them; buttons are added by the caller
local function packRow(parent: Instance, pack: Config.Pack, title: string, info: string): Frame
	local row = create("Frame", { LayoutOrder = pack.order, Size = UDim2.new(1, -10, 0, 90), BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent }, { corner(12), stroke(2), gradient(pack.color:Lerp(DARK, 0.45), pack.color:Lerp(DARK, 0.75)) })
	textLabel({ Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(420, 32), Text = title, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	textLabel({ Position = UDim2.fromOffset(14, 40), Size = UDim2.fromOffset(440, 20), Text = oddsText(pack), RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	textLabel({ Position = UDim2.fromOffset(14, 64), Size = UDim2.fromOffset(440, 18), Text = info, TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	return row
end

local function refreshPacks()
	clearList(packsList)
	local any = false
	for _, pack in Config.PACKS do
		local count = profile.packs[pack.id] or 0
		if count > 0 then
			any = true
			local row = packRow(packsList, pack, pack.name .. "  x" .. count, pityText(pack))
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 52), Text = "OPEN", BackgroundColor3 = ACCENT }, function()
				openPack(pack.id)
			end).Parent = row
		end
	end
	if not any then
		textLabel({ Size = UDim2.new(1, -10, 0, 60), Text = "No packs yet: buy some at the Pack Shop in the middle of the map!", TextWrapped = true, TextColor3 = GREY, Parent = packsList })
	end
end

---------------------------------------------------------------------------
-- Pack Shop (plaza station): packs go to the backpack, bigger backpacks
---------------------------------------------------------------------------
local SHOP_COLOR = Color3.fromRGB(90, 200, 120)
local shopPanel = makePanel("Shop", "PACK SHOP", SHOP_COLOR, Vector2.new(760, 500))
local shopList = scrollingList({ Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -76), Parent = shopPanel }, 8)
local buyButtons: { { button: TextButton, price: number } } = {}
local upgradeRow = create("Frame", { LayoutOrder = 0, Size = UDim2.new(1, -10, 0, 70), BackgroundColor3 = Color3.new(1, 1, 1), Parent = shopList }, { corner(12), stroke(2), gradient(Color3.fromRGB(70, 110, 170), Color3.fromRGB(35, 50, 80)) })
local upgradeText = textLabel({ Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -230, 0, 54), Text = "", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = upgradeRow })
local upgradeButton = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(190, 52), Text = "UPGRADE", BackgroundColor3 = ACCENT }, function()
	remotes.UpgradeBackpack:FireServer()
end)
upgradeButton.Parent = upgradeRow

for _, pack in Config.PACKS do
	local row = packRow(shopList, pack, pack.name, "$" .. Format.number(pack.price) .. " each  ·  goes to your backpack")
	for index, count in { 1, 5 } do
		local b = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12 - (2 - index) * 128, 0.5, 0), Size = UDim2.fromOffset(118, 52), Text = "BUY x" .. count, BackgroundColor3 = ACCENT }, function()
			remotes.BuyPack:FireServer(pack.id, count)
		end)
		b.Parent = row
		table.insert(buyButtons, { button = b, price = pack.price * count })
	end
end

local function refreshShop()
	local cash = player:GetAttribute("Cash") or 0
	for _, entry in buyButtons do
		setButtonColor(entry.button, if cash >= entry.price then ACCENT else GREY)
	end
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

---------------------------------------------------------------------------
-- Pack opening: the cards flip one by one with their "1 in X" chance underneath
---------------------------------------------------------------------------
local reveal = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.35,
	Visible = false,
	ZIndex = 10,
	Parent = root,
})
local revealTitle = textLabel({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.2, 0), Size = UDim2.fromOffset(600, 44), Text = "", ZIndex = 11, Parent = reveal })
local revealRow = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.58),
	Size = UDim2.fromOffset(760, 360),
	BackgroundTransparency = 1,
	ZIndex = 11,
	Parent = reveal,
}, { create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 30) }) })
local revealButtons = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.9, 0), Size = UDim2.fromOffset(440, 56), BackgroundTransparency = 1, Visible = false, ZIndex = 11, Parent = reveal }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 20) }),
})
local currentPack = "starter"
local opening = false
button({ Size = UDim2.fromOffset(210, 56), Text = "OPEN AGAIN", BackgroundColor3 = ACCENT, ZIndex = 12 }, function()
	openPack(currentPack)
end).Parent = revealButtons
button({ Size = UDim2.fromOffset(160, 56), Text = "CLOSE", BackgroundColor3 = RED, ZIndex = 12 }, function()
	reveal.Visible = false
end).Parent = revealButtons

local CARD_SIZE = UDim2.fromOffset(200, 280)

local function showPull(slot: Frame, pull)
	local holder = slot:FindFirstChild("Holder") :: Frame
	local back = holder:FindFirstChild("Back") :: Frame
	-- Flip: shrink the back to nothing, then grow the real card
	local shrink = TweenService:Create(holder, TweenInfo.new(0.15), { Size = UDim2.fromOffset(0, 280) })
	shrink:Play()
	shrink.Completed:Wait()
	back:Destroy()
	cardFrame(holder, pull.card, pull.variant, UDim2.fromScale(1, 1), 12)
	TweenService:Create(holder, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = CARD_SIZE }):Play()

	local chance = textLabel({ Position = UDim2.new(0, 0, 1, -48), Size = UDim2.new(1, 0, 0, 34), Text = "1/" .. Format.number(pull.oneIn), TextColor3 = nameColor(pull.card, pull.variant), ZIndex = 13, Parent = slot })
	if pull.new then
		textLabel({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 6, 0, -10), Size = UDim2.fromOffset(70, 28), Text = "NEW!", TextColor3 = Color3.fromRGB(255, 230, 80), Rotation = 12, ZIndex = 14, Parent = slot })
	end
	-- The rarer the pull, the bigger the pop
	if pull.oneIn >= 100 then
		local pop = create("UIScale", { Scale = 1.6, Parent = chance })
		TweenService:Create(pop, TweenInfo.new(0.5, Enum.EasingStyle.Elastic), { Scale = 1 }):Play()
	end
	-- Very rare pulls: the screen flashes in the card's color and the card shakes
	if pull.oneIn >= 1000 then
		local flash = create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = nameColor(pull.card, pull.variant), BackgroundTransparency = 0.2, ZIndex = 30, Parent = root })
		TweenService:Create(flash, TweenInfo.new(0.6), { BackgroundTransparency = 1 }):Play()
		task.delay(0.6, function()
			flash:Destroy()
		end)
		task.spawn(function()
			for i = 1, 8 do
				holder.Rotation = if i % 2 == 0 then 4 else -4
				task.wait(0.04)
			end
			holder.Rotation = 0
		end)
	end
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
	reveal.Visible = true

	local slots = {}
	for index in pulls do
		local slot = create("Frame", { LayoutOrder = index, Size = UDim2.fromOffset(200, 340), BackgroundTransparency = 1, ZIndex = 11, Parent = revealRow })
		local holder = create("Frame", { Name = "Holder", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = CARD_SIZE, BackgroundTransparency = 1, ZIndex = 11, Parent = slot })
		create("Frame", { Name = "Back", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 12, Parent = holder }, {
			corner(14),
			stroke(4),
			gradient(pack.color, pack.color:Lerp(DARK, 0.6)),
			textLabel({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.5, 0.3), Text = "?", ZIndex = 13 }),
		})
		slots[index] = slot
	end
	-- Rarest card last, for suspense
	local order = {}
	for index in pulls do
		table.insert(order, index)
	end
	table.sort(order, function(a, b)
		return pulls[a].oneIn < pulls[b].oneIn
	end)
	task.wait(0.4)
	for _, index in order do
		showPull(slots[index], pulls[index])
		task.wait(if pulls[index].oneIn >= 1000 then 1 else 0.45)
	end
	revealButtons.Visible = true
	opening = false
end

---------------------------------------------------------------------------
-- Cards and stands
---------------------------------------------------------------------------
local CARDS_COLOR = Color3.fromRGB(80, 160, 255)
local cardsPanel = makePanel("Cards", "MY CARDS", CARDS_COLOR, Vector2.new(900, 480))
local backpackTitle = textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(300, 26), Text = "Backpack", TextXAlignment = Enum.TextXAlignment.Left, Parent = cardsPanel })
local inventoryList = scrollingList({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(0, 560, 1, -104), Parent = cardsPanel })
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

local function refreshCards()
	clearList(inventoryList)
	local inBackpack = 0
	for _, list in { profile.cards, profile.packs } do
		for _, count in list do
			inBackpack += count
		end
	end
	backpackTitle.Text = string.format("Backpack %d/%d (cards and packs)", inBackpack, Config.backpackSize(profile.backpackLevel or 0))
	local keys = sortedKeys(profile.cards)
	for order, key in keys do
		local count = profile.cards[key]
		local _, variantId, scores, traitId = Config.splitKey(key)
		local nextVariant = if scores or traitId then nil else Config.FUSE_NEXT[variantId]
		local row = cardRow(inventoryList, order, key, count, if nextVariant then 256 else 100)
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(90, 36), Text = "PLACE", BackgroundColor3 = ACCENT }, function()
			remotes.PlaceCard:FireServer(key)
		end).Parent = row
		if nextVariant then
			local canFuse = count >= Config.FUSE_COUNT
			local fuse = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -106, 0.5, 0), Size = UDim2.fromOffset(150, 36), Text = string.format("FUSE %d/%d", math.min(count, Config.FUSE_COUNT), Config.FUSE_COUNT), BackgroundColor3 = if canFuse then Config.VARIANT[nextVariant].color:Lerp(DARK, 0.2) else GREY }, function()
				if canFuse then
					remotes.Fuse:FireServer(key)
				else
					toast("Get " .. Config.FUSE_COUNT .. " of this card to fuse it into " .. Config.VARIANT[nextVariant].name)
				end
			end)
			fuse.Parent = row
		end
	end
	if #keys == 0 then
		textLabel({ Size = UDim2.new(1, -10, 0, 30), Text = "No cards yet: buy a pack at the Pack Shop and open it!", TextColor3 = GREY, Parent = inventoryList })
	end

	clearList(standsList)
	local used = 0
	for slot = 1, Config.STAND_COUNT do
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
	standsTitle.Text = string.format("Stands %d/%d", used, Config.STAND_COUNT)
end

---------------------------------------------------------------------------
-- Sell (plaza station): cards for a share of their pack price, packs for part of their price
---------------------------------------------------------------------------
local SELL_COLOR = Color3.fromRGB(255, 190, 60)
local sellPanel = makePanel("Sell", "SELL", SELL_COLOR, Vector2.new(760, 500))
textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.new(1, -32, 0, 22), Text = "Rarer and shinier cards sell for more. Cards on your stands can't be sold.", TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = sellPanel })
local sellList = scrollingList({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 1, -104), Parent = sellPanel })

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
			sellRow(order, pack.name, pack.color, "$" .. Format.number(Config.packSellPrice(pack.id)) .. " each", count, function(amount)
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
		sellRow(order, keyName(key), nameColor(cardId, variantId), "$" .. Format.number(Config.sellPrice(key)) .. " each", profile.cards[key], function(amount)
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
	for _, key in sortedKeys(profile.cards) do
		local cardId, variantId, scores = Config.splitKey(key)
		if not scores then
			order += 1
			local cost = Config.gradeCost(cardId, variantId)
			local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = PANEL, Parent = gradeList }, { corner(8), stroke(1.5) })
			local count = profile.cards[key]
			textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -220, 0, 22), Text = keyName(key) .. (if count > 1 then "  x" .. count else ""), TextColor3 = nameColor(cardId, variantId), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			textLabel({ Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -220, 0, 18), Text = "$" .. Format.number(Config.keyIncome(key)) .. "/s", TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
			local canPay = (player:GetAttribute("Cash") or 0) >= cost
			button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(190, 36), Text = "GRADE $" .. Format.number(cost), BackgroundColor3 = if canPay then GRADE_COLOR else GREY }, function()
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
	end
	if order == 0 then
		textLabel({ Size = UDim2.new(1, -10, 0, 30), Text = "No card to grade: graded cards can't be graded again", TextColor3 = GREY, Parent = gradeList })
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
local gradeResult = textLabel({ AnchorPoint = Vector2.new(0, 0), Position = UDim2.new(0.5, -60, 0.48, 125), Size = UDim2.fromOffset(360, 44), Text = "", ZIndex = 12, Parent = gradeReveal })
local gradeClose = button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.9, 0), Size = UDim2.fromOffset(160, 56), Text = "OK", BackgroundColor3 = ACCENT, ZIndex = 12 }, function()
	gradeReveal.Visible = false
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
}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 210), CellPadding = UDim2.fromOffset(18, 34), SortOrder = Enum.SortOrder.LayoutOrder }) })

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
		textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -130, 0, 26), Text = tower.name, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local floors = if tower.floors then string.format("Best: %d/%d", best, tower.floors) else string.format("Best: floor %d", best)
		textLabel({ Position = UDim2.fromOffset(10, 31), Size = UDim2.new(1, -130, 0, 19), Text = floors, TextColor3 = Color3.fromRGB(220, 220, 230), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(110, 42), Text = "ENTER", BackgroundColor3 = if #team > 0 then ACCENT else GREY }, function()
			if #team == 0 then
				toast("Add cards to your team first", RED)
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
	root.Visible = player:GetAttribute("InTower") == nil and player:GetAttribute("TowerScreen") == nil
end
player:GetAttributeChangedSignal("InTower"):Connect(refreshInTower)
player:GetAttributeChangedSignal("TowerScreen"):Connect(refreshInTower)
refreshInTower()

---------------------------------------------------------------------------
-- Side buttons
---------------------------------------------------------------------------
local sideBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(150, 300),
	BackgroundTransparency = 1,
	Parent = root,
}, { create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

for order, entry in { { "Packs", PACKS_COLOR, "📦" }, { "Cards", CARDS_COLOR, "🃏" }, { "Index", INDEX_COLOR, "📖" }, { "Rewards", REWARDS_COLOR, "🎁" } } do
	local name, color, icon = entry[1], entry[2], entry[3]
	button({ LayoutOrder = order, Size = UDim2.fromOffset(150, 56), Text = icon .. " " .. string.upper(name), BackgroundColor3 = color }, function()
		togglePanel(name)
	end).Parent = sideBar
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

