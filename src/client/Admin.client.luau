-- Admin panel: only for admins (the server sets the "Admin" attribute, see Admin.luau, and checks
-- every action again). A small ADMIN button on the right opens it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")

local FONT = Enum.Font.FredokaOne
local DARK = Color3.fromRGB(22, 22, 32)
local PANEL = Color3.fromRGB(38, 38, 54)
local ACCENT = Color3.fromRGB(80, 200, 120)
local RED = Color3.fromRGB(225, 75, 75)
local BLUE = Color3.fromRGB(70, 140, 230)

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

local function label(parent: Instance, text: string, width: number)
	return create("TextLabel", { Size = UDim2.fromOffset(width, 34), BackgroundTransparency = 1, Font = FONT, Text = text, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
end

local function button(parent: Instance, text: string, width: number, color: Color3, onClick: () -> ()): TextButton
	local b = create("TextButton", { Size = UDim2.fromOffset(width, 34), BackgroundColor3 = color, Font = FONT, Text = text, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, Parent = parent }, {
		create("UICorner", { CornerRadius = UDim.new(0, 8) }),
		create("UIStroke", { Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }),
	})
	b.Activated:Connect(onClick)
	return b
end

local function input(parent: Instance, placeholder: string, width: number): TextBox
	return create("TextBox", { Size = UDim2.fromOffset(width, 34), BackgroundColor3 = Color3.fromRGB(240, 240, 248), Font = FONT, PlaceholderText = placeholder, Text = "", TextColor3 = DARK, TextScaled = true, ClearTextOnFocus = false, Parent = parent }, {
		create("UICorner", { CornerRadius = UDim.new(0, 8) }),
		create("UIPadding", { PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }),
	})
end

-- A button that cycles through a list when tapped; returns a getter for the current value
local function chooser(parent: Instance, list: { { id: string, name: string } }, width: number): () -> string
	local index = 1
	local b = button(parent, list[1].name .. " ▸", width, BLUE, function() end)
	b.Activated:Connect(function()
		index = index % #list + 1
		b.Text = list[index].name .. " ▸"
	end)
	return function()
		return list[index].id
	end
end

-- "1.5M", "2b", "300" -> a number
local SUFFIX = { k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21 }
local function parseAmount(text: string): number?
	local number, suffix = string.match(string.lower((string.gsub(text, "[%s,$]", ""))), "^(%-?[%d%.]+)(%a*)$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	if suffix ~= "" then
		local multiplier = SUFFIX[suffix]
		if not multiplier then
			return nil
		end
		value *= multiplier
	end
	return value
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
local gui = create("ScreenGui", { Name = "Admin", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
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

local openButton = button(screen, "🛠 ADMIN", 110, Color3.fromRGB(90, 90, 110), function() end)
openButton.AnchorPoint = Vector2.new(1, 0.5)
openButton.Position = UDim2.new(1, -14, 0.32, 0)
openButton.Size = UDim2.fromOffset(110, 40)

local window = create("ScrollingFrame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.52),
	Size = UDim2.fromOffset(640, 520),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.05,
	ScrollBarThickness = 8,
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(),
	Visible = false,
	Parent = screen,
}, {
	create("UICorner", { CornerRadius = UDim.new(0, 14) }),
	create("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 200, 60) }),
	create("UIPadding", { PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }),
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
})
openButton.Activated:Connect(function()
	window.Visible = not window.Visible
end)

local rows = 0
local function row(): Frame
	rows += 1
	return create("Frame", { LayoutOrder = rows, Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, Parent = window }, {
		create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }),
	})
end

local title = row()
label(title, "ADMIN PANEL", 300).TextColor3 = Color3.fromRGB(255, 200, 60)
button(title, "CLOSE", 90, RED, function()
	window.Visible = false
end)

local targetRow = row()
label(targetRow, "Player", 110)
local targetBox = input(targetRow, "empty = you", 220)

local function send(action: string, args: { [string]: any })
	args.target = targetBox.Text
	remotes.AdminAction:FireServer(action, args)
end

-- Cash
local cashRow = row()
label(cashRow, "Cash", 110)
local cashBox = input(cashRow, "1.5M, 2B, 300...", 160)
button(cashRow, "GIVE", 80, ACCENT, function()
	local amount = parseAmount(cashBox.Text)
	if amount then
		send("cash", { amount = amount })
	end
end)
for _, quick in { "1M", "1B", "1T" } do
	button(cashRow, "+" .. quick, 64, PANEL, function()
		send("cash", { amount = parseAmount(quick) })
	end)
end

-- Packs
local packRow = row()
label(packRow, "Packs", 110)
local packs = {}
for _, pack in Config.PACKS do
	table.insert(packs, { id = pack.id, name = pack.name })
end
local getPack = chooser(packRow, packs, 220)
local packCount = input(packRow, "count", 80)
button(packRow, "GIVE", 80, ACCENT, function()
	send("packs", { pack = getPack(), count = tonumber(packCount.Text) or 1 })
end)

-- Cards
local cardRow = row()
label(cardRow, "Card", 110)
local cardBox = input(cardRow, "card name", 180)
local getVariant = chooser(cardRow, { { id = "normal", name = "Normal" }, { id = "gold", name = "Gold" }, { id = "rainbow", name = "Rainbow" }, { id = "holo", name = "Holo" } }, 110)
local cardCount = input(cardRow, "count", 70)
button(cardRow, "GIVE", 80, ACCENT, function()
	send("card", { card = cardBox.Text, variant = getVariant(), count = tonumber(cardCount.Text) or 1 })
end)

-- Weather
local weatherRow = row()
label(weatherRow, "Weather", 110)
for _, weather in Config.WEATHERS do
	button(weatherRow, weather.name, 112, weather.color:Lerp(Color3.new(0, 0, 0), 0.25), function()
		send("weather", { weather = weather.id })
	end)
end
local weatherStop = row()
label(weatherStop, "", 110)
button(weatherStop, "STOP WEATHER", 160, PANEL, function()
	send("weather", { weather = "stop" })
end)

-- Towers
local towerRow = row()
label(towerRow, "Tower", 110)
local towers = {}
for _, tower in Config.TOWERS do
	table.insert(towers, { id = tower.id, name = tower.name })
end
local getTower = chooser(towerRow, towers, 200)
local floorBox = input(towerRow, "best floor", 110)
button(towerRow, "SET", 80, ACCENT, function()
	send("tower", { tower = getTower(), floor = tonumber(floorBox.Text) or 0 })
end)

-- Trait Rerolls and upgrades
local miscRow = row()
label(miscRow, "Other", 110)
button(miscRow, "+10 TRAIT REROLLS", 170, PANEL, function()
	send("rerolls", { count = 10 })
end)
button(miscRow, "ALL UPGRADES", 140, ACCENT, function()
	send("upgrades", { all = true })
end)
button(miscRow, "NO UPGRADES", 130, PANEL, function()
	send("upgrades", { all = false })
end)

-- Reset: tap twice to confirm
local resetRow = row()
label(resetRow, "Data", 110)
local armed = false
local resetButton: TextButton
resetButton = button(resetRow, "RESET DATA", 200, RED, function()
	if not armed then
		armed = true
		resetButton.Text = "SURE? TAP AGAIN"
		task.delay(3, function()
			armed = false
			resetButton.Text = "RESET DATA"
		end)
		return
	end
	armed = false
	resetButton.Text = "RESET DATA"
	send("reset", {})
end)

-- Only admins see it
local function refresh()
	gui.Enabled = player:GetAttribute("Admin") == true
end
player:GetAttributeChangedSignal("Admin"):Connect(refresh)
refresh()
