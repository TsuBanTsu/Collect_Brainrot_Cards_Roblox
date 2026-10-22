-- Player UI: cash, weather, packs (with the card reveal), cards and stands, Index,
-- rewards and notifications. Everything is created from code. Sizes are designed for a
-- 1280x720 screen and a UIScale resizes the whole UI to fit any screen.

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
local PANEL = Color3.fromRGB(34, 34, 48)
local ACCENT = Color3.fromRGB(80, 200, 120)
local RED = Color3.fromRGB(225, 75, 75)
local CASH_COLOR = Color3.fromRGB(120, 255, 140)
local GREY = Color3.fromRGB(110, 110, 125)

local profile = { cards = {}, stands = {}, index = {}, pity = {}, dailyDay = 0, dailyStreak = 0 }

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 220, 80)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 230, 120)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 160, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(200, 90, 255)),
})

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
		stroke(2.5),
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
		TweenService:Create(scale, TweenInfo.new(0.1), { Scale = 1 }):Play()
	end)
	b.MouseLeave:Connect(function()
		scale.Scale = 1
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
	Size = UDim2.fromOffset(440, 64),
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

local function refreshStats()
	cashValue.Text = "$" .. Format.number(player:GetAttribute("Cash") or 0)
	incomeValue.Text = "$" .. Format.number(player:GetAttribute("Income") or 0) .. "/s"
end
for _, attr in { "Cash", "Income" } do
	player:GetAttributeChangedSignal(attr):Connect(refreshStats)
end
refreshStats()

local weatherLabel = textLabel({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 114),
	Size = UDim2.fromOffset(520, 26),
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
local function cardFrame(parent: Instance, cardId: string, variantId: string, size: UDim2): Frame
	local card = Config.CARDS[cardId]
	local rarity = Config.RARITY[card.rarity]
	local frame = create("Frame", { Size = size, BackgroundColor3 = Color3.new(1, 1, 1), Parent = parent }, { corner(14), stroke(4, rarity.color) })
	if variantId == "rainbow" then
		create("UIGradient", { Rotation = 45, Color = RAINBOW, Parent = frame })
	elseif variantId == "gold" then
		create("UIGradient", { Rotation = 45, Color = ColorSequence.new(Color3.fromRGB(255, 235, 140), Color3.fromRGB(200, 140, 20)), Parent = frame })
	elseif variantId == "holo" then
		create("UIGradient", { Rotation = 45, Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 255, 245)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(220, 180, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 200, 255)),
		}), Parent = frame })
	else
		frame.BackgroundColor3 = rarity.color:Lerp(DARK, 0.55)
	end
	textLabel({ Position = UDim2.fromScale(0.06, 0.05), Size = UDim2.fromScale(0.88, 0.1), Text = rarity.name, TextColor3 = rarity.color, Parent = frame })
	-- Big initials in the middle, until the 3D models get their own pictures
	textLabel({ Position = UDim2.fromScale(0.1, 0.2), Size = UDim2.fromScale(0.8, 0.36), Text = string.upper(string.sub(card.name, 1, 1)), TextColor3 = Color3.new(1, 1, 1), Parent = frame })
	textLabel({ Position = UDim2.fromScale(0.06, 0.6), Size = UDim2.fromScale(0.88, 0.2), Text = card.name, TextWrapped = true, Parent = frame })
	if variantId ~= "normal" then
		local variant = Config.VARIANT[variantId]
		textLabel({ Position = UDim2.fromScale(0.06, 0.83), Size = UDim2.fromScale(0.88, 0.11), Text = string.upper(variant.name), TextColor3 = variant.color, Parent = frame })
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
-- Packs
---------------------------------------------------------------------------
local PACKS_COLOR = Color3.fromRGB(255, 150, 60)
local packsPanel = makePanel("Packs", "PACKS", PACKS_COLOR, Vector2.new(700, 480))
local packsList = scrollingList({ Position = UDim2.fromOffset(14, 64), Size = UDim2.new(1, -28, 1, -76), Parent = packsPanel }, 8)

local openPack: (string) -> ()
local packButtons: { [string]: TextButton } = {}
local pityLabels: { [string]: TextLabel } = {}

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

for _, pack in Config.PACKS do
	local row = create("Frame", { LayoutOrder = pack.order, Size = UDim2.new(1, -10, 0, 90), BackgroundColor3 = Color3.new(1, 1, 1), Parent = packsList }, { corner(12), stroke(2), gradient(pack.color:Lerp(DARK, 0.45), pack.color:Lerp(DARK, 0.75)) })
	textLabel({ Position = UDim2.fromOffset(14, 6), Size = UDim2.fromOffset(330, 32), Text = pack.name, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	textLabel({ Position = UDim2.fromOffset(350, 10), Size = UDim2.fromOffset(150, 26), Text = "$" .. Format.number(pack.price), TextColor3 = CASH_COLOR, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	textLabel({ Position = UDim2.fromOffset(14, 40), Size = UDim2.fromOffset(500, 20), Text = oddsText(pack), RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	pityLabels[pack.id] = textLabel({ Position = UDim2.fromOffset(14, 64), Size = UDim2.fromOffset(500, 18), Text = "", TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	local b = button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(130, 52), Text = "OPEN", BackgroundColor3 = ACCENT }, function()
		openPack(pack.id)
	end)
	b.Parent = row
	packButtons[pack.id] = b
end

local function refreshPacks()
	local cash = player:GetAttribute("Cash") or 0
	for _, pack in Config.PACKS do
		setButtonColor(packButtons[pack.id], if cash >= pack.price then ACCENT else GREY)
		local hasPity = false
		for rarityId in pack.odds do
			if Config.RARITY[rarityId].order < Config.RARITY[Config.PITY_RARITY].order then
				hasPity = true
			end
		end
		if hasPity then
			local left = Config.PITY_PACKS - (profile.pity[pack.id] or 0)
			pityLabels[pack.id].Text = string.format("%s or better guaranteed in %d pack%s", Config.RARITY[Config.PITY_RARITY].name, left, if left > 1 then "s" else "")
		else
			pityLabels[pack.id].Text = ""
		end
	end
end
player:GetAttributeChangedSignal("Cash"):Connect(refreshPacks)

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
	local front = cardFrame(holder, pull.card, pull.variant, UDim2.fromScale(1, 1))
	front.ZIndex = 12
	for _, child in front:GetDescendants() do
		if child:IsA("GuiObject") then
			child.ZIndex = 13
		end
	end
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
end

openPack = function(packId: string)
	if opening then
		return
	end
	local pack = Config.PACK[packId]
	if (player:GetAttribute("Cash") or 0) < pack.price then
		toast("Not enough Cash for the " .. pack.name, RED)
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
textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(300, 26), Text = "Inventory", TextXAlignment = Enum.TextXAlignment.Left, Parent = cardsPanel })
local inventoryList = scrollingList({ Position = UDim2.fromOffset(12, 92), Size = UDim2.new(0, 560, 1, -104), Parent = cardsPanel })
local standsTitle = textLabel({ Position = UDim2.fromOffset(590, 60), Size = UDim2.fromOffset(150, 26), Text = "Stands", TextXAlignment = Enum.TextXAlignment.Left, Parent = cardsPanel })
button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 58), Size = UDim2.fromOffset(150, 30), Text = "PLACE BEST", BackgroundColor3 = ACCENT }, function()
	remotes.PlaceBest:FireServer()
end).Parent = cardsPanel
local standsList = scrollingList({ Position = UDim2.fromOffset(584, 92), Size = UDim2.new(1, -596, 1, -104), Parent = cardsPanel })

local function cardRow(parent: Instance, order: number, key: string, count: number?)
	local cardId, variantId = Config.splitKey(key)
	local row = create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 48), BackgroundColor3 = PANEL, Parent = parent }, { corner(8), stroke(1.5) })
	local suffix = if count and count > 1 then "  x" .. count else ""
	textLabel({ Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 22), Text = displayName(cardId, variantId) .. suffix, TextColor3 = nameColor(cardId, variantId), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	textLabel({ Position = UDim2.fromOffset(10, 26), Size = UDim2.fromOffset(260, 18), Text = "$" .. Format.number(Config.cardIncome(cardId, variantId)) .. "/s  ·  1/" .. Format.number(Config.oneIn(cardId, variantId)), TextColor3 = Color3.fromRGB(200, 200, 215), TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
	return row
end

local function refreshCards()
	clearList(inventoryList)
	local keys = {}
	for key in profile.cards do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		local ca, va = Config.splitKey(a)
		local cb, vb = Config.splitKey(b)
		return Config.cardIncome(ca, va) > Config.cardIncome(cb, vb)
	end)
	for order, key in keys do
		local count = profile.cards[key]
		local row = cardRow(inventoryList, order, key, count)
		button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(90, 36), Text = "PLACE", BackgroundColor3 = ACCENT }, function()
			remotes.PlaceCard:FireServer(key)
		end).Parent = row
		local _, variantId = Config.splitKey(key)
		local nextVariant = Config.FUSE_NEXT[variantId]
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
		textLabel({ Size = UDim2.new(1, -10, 0, 30), Text = "No cards yet: open a pack!", TextColor3 = GREY, Parent = inventoryList })
	end

	clearList(standsList)
	local used = 0
	for slot = 1, Config.STAND_COUNT do
		local key = profile.stands[tostring(slot)]
		if key then
			used += 1
			local row = cardRow(standsList, slot, key)
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
-- Index: every card of every pack, found or not
---------------------------------------------------------------------------
local INDEX_COLOR = Color3.fromRGB(170, 90, 230)
local indexPanel = makePanel("Index", "INDEX", INDEX_COLOR, Vector2.new(900, 500))
local indexBonus = textLabel({ Position = UDim2.fromOffset(16, 60), Size = UDim2.fromOffset(560, 26), Text = "", TextColor3 = CASH_COLOR, TextXAlignment = Enum.TextXAlignment.Left, Parent = indexPanel })
local indexTabs = create("Frame", { Position = UDim2.fromOffset(12, 92), Size = UDim2.new(1, -24, 0, 40), BackgroundTransparency = 1, Parent = indexPanel }, {
	create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
})
local indexGrid = create("ScrollingFrame", {
	Position = UDim2.fromOffset(12, 142),
	Size = UDim2.new(1, -24, 1, -154),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 6,
	Parent = indexPanel,
}, { create("UIGridLayout", { CellSize = UDim2.fromOffset(150, 210), CellPadding = UDim2.fromOffset(18, 14), SortOrder = Enum.SortOrder.LayoutOrder }) })

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
			textLabel({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(0.9, 0, 0, 20), Text = "1/" .. Format.number(Config.oneIn(card.id, "normal")), Parent = frame })
		else
			local rarity = Config.RARITY[card.rarity]
			create("Frame", { LayoutOrder = order, BackgroundColor3 = DARK, Parent = indexGrid }, {
				corner(14),
				stroke(3, rarity.color:Lerp(DARK, 0.5)),
				textLabel({ Position = UDim2.fromScale(0.06, 0.05), Size = UDim2.fromScale(0.88, 0.1), Text = rarity.name, TextColor3 = rarity.color }),
				textLabel({ Position = UDim2.fromScale(0.2, 0.3), Size = UDim2.fromScale(0.6, 0.3), Text = "?", TextColor3 = GREY }),
				textLabel({ Position = UDim2.fromScale(0.06, 0.8), Size = UDim2.fromScale(0.88, 0.12), Text = "1/" .. Format.number(Config.oneIn(card.id, "normal")), TextColor3 = GREY }),
			})
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
-- Side buttons
---------------------------------------------------------------------------
local sideBar = create("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 14, 0.5, 0),
	Size = UDim2.fromOffset(150, 300),
	BackgroundTransparency = 1,
	Parent = root,
}, { create("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })

for order, entry in { { "Packs", PACKS_COLOR }, { "Cards", CARDS_COLOR }, { "Index", INDEX_COLOR }, { "Rewards", REWARDS_COLOR } } do
	local name, color = entry[1], entry[2]
	button({ LayoutOrder = order, Size = UDim2.fromOffset(150, 56), Text = string.upper(name), BackgroundColor3 = color }, function()
		togglePanel(name)
	end).Parent = sideBar
end

---------------------------------------------------------------------------
-- Profile updates from the server
---------------------------------------------------------------------------
local function refreshAll()
	refreshPacks()
	refreshCards()
	refreshIndex()
	refreshRewards()
end

remotes.ProfileSync.OnClientEvent:Connect(function(data)
	profile = data
	refreshAll()
end)
refreshAll()
remotes.RequestSync:FireServer()

