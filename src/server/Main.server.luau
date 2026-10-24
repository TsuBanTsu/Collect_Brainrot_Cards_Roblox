-- Server entry point: builds the map, then handles the shop, packs, stands, fusion,
-- selling, grading, income every second, weather, daily rewards and codes.
-- The towers (fights) live in Towers.luau.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Admin = require(script.Parent.Admin)
local Assets = require(script.Parent.Assets)
local Environment = require(script.Parent.Environment)
local Grading = require(script.Parent.Grading)
local Packs = require(script.Parent.Packs)
local Plaza = require(script.Parent.Plaza)
local PlayerData = require(script.Parent.PlayerData)
local Plots = require(script.Parent.Plots)
local Towers = require(script.Parent.Towers)
local Weather = require(script.Parent.Weather)

---------------------------------------------------------------------------
-- Remotes: the channels between the server and the player's UI
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "Remotes"
for _, name in { "ProfileSync", "RequestSync", "Notify", "Announce", "PlaceCard", "RemoveCard", "PlaceBest", "Fuse", "ClaimDaily", "BuyPack", "UpgradeBackpack", "SellCard", "SellPack", "TowerEvent", "SetTeam", "StartTower", "LeaveTower", "TowerMode", "Teleport", "BuyUpgrade", "BuyAllUpgrades", "AdminAction" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
for _, name in { "OpenPack", "RedeemCode", "Grade", "RerollTrait" } do
	local remote = Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

local function notify(player: Player, message: string)
	remotes.Notify:FireClient(player, message)
end

-- Big message for everyone on the server
local function announce(message: string, color: Color3)
	remotes.Announce:FireAllClients(message, color)
end

---------------------------------------------------------------------------
-- Setup
---------------------------------------------------------------------------
Environment.setup()
Assets.loadAll()
Plots.init()
Plaza.build(Plots.folder())
PlayerData.init(remotes)
Weather.init(announce)
Towers.init(remotes, notify, announce)

local function refreshPlot(player: Player)
	local profile = PlayerData.get(player)
	if profile then
		Plots.refresh(player, profile.Stands, PlayerData.standCount(profile))
	end
end

-- Walking speed with the upgrades
local function applyWalkSpeed(player: Player)
	local profile = PlayerData.get(player)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if profile and humanoid then
		humanoid.WalkSpeed = Config.WALK_SPEED * (1 + PlayerData.bonus(profile, "walk"))
	end
end

local function onCharacter(player: Player, character: Model)
	-- A new character gets an empty backpack: give the pack tools back
	task.defer(PlayerData.sync, player)
	task.spawn(function()
		character:WaitForChild("Humanoid", 5)
		applyWalkSpeed(player)
	end)
	local cframe = Plots.spawnCFrame(player)
	if cframe then
		local root = character:WaitForChild("HumanoidRootPart", 5) :: BasePart?
		if root then
			task.wait() -- let the default spawn finish first
			character:PivotTo(cframe)
		end
	end
end

local function onPlayerAdded(player: Player)
	if not Plots.assign(player) then
		player:Kick("This server is full, please join another one.")
		return
	end
	local _, offline = PlayerData.load(player)
	refreshPlot(player)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	if offline > 0 then
		notify(player, "Your stands earned $" .. Format.number(offline) .. " while you were away!")
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	Plots.release(player)
end)

---------------------------------------------------------------------------
-- Shop (at the plaza): packs go to the backpack, bigger backpacks
---------------------------------------------------------------------------
local function atStation(player: Player, stationId: string): boolean
	if Plaza.near(player, stationId) then
		return true
	end
	notify(player, "Go to the " .. stationId .. " stand in the plaza")
	return false
end

local function validCount(count: any): boolean
	return type(count) == "number" and count == math.floor(count) and count >= 1 and count <= 100
end

remotes.BuyPack.OnServerEvent:Connect(function(player, packId: any, count: any)
	if type(packId) ~= "string" or not validCount(count) or not atStation(player, "shop") then
		return
	end
	local ok, reason = Packs.buy(player, packId, count)
	if ok then
		local pack = Config.PACK[packId]
		notify(player, (if count > 1 then count .. "x " else "") .. pack.name .. " added to your backpack")
	else
		notify(player, reason or "Could not buy the pack")
	end
end)

remotes.UpgradeBackpack.OnServerEvent:Connect(function(player)
	local profile = PlayerData.get(player)
	if not profile or not atStation(player, "shop") then
		return
	end
	local upgrade = Config.BACKPACK_UPGRADES[profile.BackpackLevel + 1]
	if not upgrade then
		notify(player, "Your backpack is already the biggest one")
		return
	end
	if profile.Cash < upgrade.price then
		notify(player, "Not enough Cash")
		return
	end
	profile.Cash -= upgrade.price
	profile.BackpackLevel += 1
	notify(player, "Backpack upgraded: " .. PlayerData.backpackSize(profile) .. " slots!")
	PlayerData.sync(player)
end)

---------------------------------------------------------------------------
-- Opening packs from the backpack (anywhere)
---------------------------------------------------------------------------
local lastOpen: { [Player]: number } = {}

remotes.OpenPack.OnServerInvoke = function(player: Player, packId: any)
	if type(packId) ~= "string" then
		return nil
	end
	-- Small cooldown so the opening animation can play and nobody spams the server
	local now = os.clock()
	if now - (lastOpen[player] or 0) < 0.4 then
		return nil
	end
	lastOpen[player] = now

	local pulls, reason = Packs.open(player, packId)
	if not pulls then
		notify(player, reason or "Could not open the pack")
		return nil
	end
	for _, pull in pulls do
		if pull.oneIn >= Config.ANNOUNCE_ONE_IN then
			local card = Config.CARDS[pull.card]
			local variant = Config.VARIANT[pull.variant]
			local name = (if pull.variant == "normal" then "" else variant.name .. " ") .. card.name
			local color = if pull.variant == "normal" then Config.RARITY[card.rarity].color else variant.color
			announce(player.DisplayName .. " pulled " .. name .. " (1/" .. Format.number(pull.oneIn) .. ")!", color)
		end
	end
	return pulls
end

Players.PlayerRemoving:Connect(function(player)
	lastOpen[player] = nil
end)

---------------------------------------------------------------------------
-- Stands
---------------------------------------------------------------------------
local function validSlot(profile, slot: any): boolean
	return type(slot) == "number" and slot == math.floor(slot) and slot >= 1 and slot <= PlayerData.standCount(profile)
end

local function firstFreeSlot(profile): number?
	for slot = 1, PlayerData.standCount(profile) do
		if not profile.Stands[tostring(slot)] then
			return slot
		end
	end
	return nil
end

-- Moves a card from the inventory to a stand (the card already there goes back to the inventory)
local function place(profile, key: string, slot: number): boolean
	if not PlayerData.removeCard(profile, key, 1) then
		return false
	end
	local previous = profile.Stands[tostring(slot)]
	if previous then
		profile.Cards[previous] = (profile.Cards[previous] or 0) + 1
	end
	profile.Stands[tostring(slot)] = key
	return true
end

local function afterStandChange(player: Player)
	PlayerData.sync(player)
	refreshPlot(player)
end

remotes.PlaceCard.OnServerEvent:Connect(function(player, key: any, slot: any)
	local profile = PlayerData.get(player)
	if not profile or type(key) ~= "string" then
		return
	end
	if slot == nil then
		slot = firstFreeSlot(profile)
		if not slot then
			notify(player, "All your stands are full: remove a card first")
			return
		end
	end
	if not validSlot(profile, slot) then
		return
	end
	if place(profile, key, slot) then
		afterStandChange(player)
	end
end)

remotes.RemoveCard.OnServerEvent:Connect(function(player, slot: any)
	local profile = PlayerData.get(player)
	if not profile or not validSlot(profile, slot) then
		return
	end
	local key = profile.Stands[tostring(slot)]
	if key and not PlayerData.hasRoom(profile, 1) then
		notify(player, "Your backpack is full")
		return
	end
	if key then
		profile.Stands[tostring(slot)] = nil
		profile.Cards[key] = (profile.Cards[key] or 0) + 1
		afterStandChange(player)
	end
end)

-- Puts the best-earning cards on the stands
remotes.PlaceBest.OnServerEvent:Connect(function(player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	-- Everything back to the inventory, then the best ones out again
	for slot, key in profile.Stands do
		profile.Cards[key] = (profile.Cards[key] or 0) + 1
		profile.Stands[slot] = nil
	end
	local all = {}
	for key, count in profile.Cards do
		local income = Config.keyIncome(key)
		for _ = 1, math.min(count, PlayerData.standCount(profile)) do
			table.insert(all, { key = key, income = income })
		end
	end
	table.sort(all, function(a, b)
		return a.income > b.income
	end)
	for slot = 1, math.min(#all, PlayerData.standCount(profile)) do
		place(profile, all[slot].key, slot)
	end
	afterStandChange(player)
end)

---------------------------------------------------------------------------
-- Fusion: Config.FUSE_COUNT identical cards -> one card of the next variant
---------------------------------------------------------------------------
remotes.Fuse.OnServerEvent:Connect(function(player, key: any)
	local profile = PlayerData.get(player)
	if not profile or type(key) ~= "string" then
		return
	end
	local cardId, variantId, scores, traitId = Config.splitKey(key)
	local nextVariant = Config.FUSE_NEXT[variantId]
	if not Config.CARDS[cardId] or not nextVariant then
		return
	end
	if scores then
		notify(player, "Graded cards can't be fused")
		return
	end
	if traitId then
		notify(player, "Cards with a trait can't be fused")
		return
	end
	if not PlayerData.removeCard(profile, key, Config.FUSE_COUNT) then
		notify(player, "You need " .. Config.FUSE_COUNT .. " of this card to fuse")
		return
	end
	PlayerData.addCard(profile, cardId, nextVariant)
	notify(player, "Fused into " .. Config.VARIANT[nextVariant].name .. " " .. Config.CARDS[cardId].name .. "!")
	PlayerData.sync(player)
end)

---------------------------------------------------------------------------
-- Selling (at the plaza): cards for a share of their pack price, packs for part of their price
---------------------------------------------------------------------------
remotes.SellCard.OnServerEvent:Connect(function(player, key: any, count: any)
	local profile = PlayerData.get(player)
	if not profile or type(key) ~= "string" or not validCount(count) or not atStation(player, "sell") then
		return
	end
	count = math.min(count, profile.Cards[key] or 0)
	if count < 1 or not PlayerData.removeCard(profile, key, count) then
		return
	end
	local price = math.floor(Config.sellPrice(key) * count * (1 + PlayerData.bonus(profile, "sell")))
	PlayerData.addCash(player, price)
	notify(player, "Sold for $" .. Format.number(price))
	PlayerData.sync(player)
end)

remotes.SellPack.OnServerEvent:Connect(function(player, packId: any, count: any)
	local profile = PlayerData.get(player)
	if not profile or type(packId) ~= "string" or not Config.PACK[packId] or not validCount(count) or not atStation(player, "sell") then
		return
	end
	count = math.min(count, profile.Packs[packId] or 0)
	if count < 1 or not PlayerData.removePack(profile, packId, count) then
		return
	end
	local price = math.floor(Config.packSellPrice(packId) * count * (1 + PlayerData.bonus(profile, "sell")))
	PlayerData.addCash(player, price)
	notify(player, "Sold for $" .. Format.number(price))
	PlayerData.sync(player)
end)

---------------------------------------------------------------------------
-- Grading (at the plaza)
---------------------------------------------------------------------------
local lastGrade: { [Player]: number } = {}

remotes.Grade.OnServerInvoke = function(player: Player, key: any)
	if type(key) ~= "string" then
		return nil
	end
	local now = os.clock()
	if now - (lastGrade[player] or 0) < 0.5 then
		return nil
	end
	lastGrade[player] = now
	if not atStation(player, "grade") then
		return nil
	end
	local result, reason = Grading.grade(player, key)
	if not result then
		notify(player, reason or "Could not grade the card")
		return nil
	end
	if not result.kept and result.grade >= 9 then
		local cardId, variantId = Config.splitKey(key)
		local card = Config.CARDS[cardId]
		local name = (if variantId == "normal" then "" else Config.VARIANT[variantId].name .. " ") .. card.name
		local grade = Config.keyGrade(result.key) :: Config.Grade
		announce(player.DisplayName .. " got a " .. grade.name .. " " .. name .. "!", grade.color)
	end
	return result
end

Players.PlayerRemoving:Connect(function(player)
	lastGrade[player] = nil
end)

---------------------------------------------------------------------------
-- Daily reward and codes
---------------------------------------------------------------------------
remotes.ClaimDaily.OnServerEvent:Connect(function(player)
	local profile = PlayerData.get(player)
	if not profile then
		return
	end
	local today = math.floor(os.time() / 86400)
	if profile.DailyDay == today then
		notify(player, "Come back tomorrow for your next reward!")
		return
	end
	profile.DailyStreak = if profile.DailyDay == today - 1 then math.min(profile.DailyStreak + 1, Config.DAILY_STREAK_MAX) else 1
	profile.DailyDay = today
	local reward = Config.DAILY_REWARD_BASE * profile.DailyStreak
	PlayerData.addCash(player, reward)
	notify(player, "Day " .. profile.DailyStreak .. " reward: $" .. Format.number(reward) .. "!")
	PlayerData.sync(player)
end)

remotes.RedeemCode.OnServerInvoke = function(player: Player, code: any)
	local profile = PlayerData.get(player)
	if not profile or type(code) ~= "string" then
		return "Invalid code"
	end
	code = string.upper((string.gsub(code, "%s", "")))
	local reward = Config.CODES[code]
	if not reward then
		return "Invalid code"
	end
	if profile.Codes[code] then
		return "Code already redeemed"
	end
	profile.Codes[code] = true
	PlayerData.addCash(player, reward.cash)
	return "Code redeemed: +$" .. Format.number(reward.cash)
end

---------------------------------------------------------------------------
-- Upgrade tree (Config.UPGRADE_TREES): bought anywhere with Cash
---------------------------------------------------------------------------
-- Buys one node. Returns true if it was bought
local function buyUpgrade(player: Player, profile, node: Config.Upgrade): boolean
	if profile.Upgrades[node.id] or (node.requires and not profile.Upgrades[node.requires]) or profile.Cash < node.cost then
		return false
	end
	profile.Cash -= node.cost
	profile.Upgrades[node.id] = true
	return true
end

local function afterUpgrades(player: Player)
	applyWalkSpeed(player)
	refreshPlot(player)
	PlayerData.sync(player)
end

remotes.BuyUpgrade.OnServerEvent:Connect(function(player, id: any)
	local profile = PlayerData.get(player)
	local node = type(id) == "string" and Config.UPGRADES[id]
	if not profile or not node then
		return
	end
	if node.requires and not profile.Upgrades[node.requires] then
		notify(player, "Buy " .. Config.UPGRADES[node.requires].name .. " first")
		return
	end
	if not buyUpgrade(player, profile, node) then
		notify(player, if profile.Upgrades[node.id] then "Already owned" else "Not enough Cash")
		return
	end
	notify(player, node.name .. ": " .. Config.upgradeText(node.stat, node.value) .. "!")
	afterUpgrades(player)
end)

-- BUY ALL: the cheapest affordable nodes of a tree, one after the other
remotes.BuyAllUpgrades.OnServerEvent:Connect(function(player, treeId: any)
	local profile = PlayerData.get(player)
	if not profile or type(treeId) ~= "string" then
		return
	end
	local bought = 0
	while true do
		local best: Config.Upgrade? = nil
		for _, node in Config.UPGRADE_LIST do
			if node.tree == treeId and not profile.Upgrades[node.id] and (not node.requires or profile.Upgrades[node.requires]) and node.cost <= profile.Cash then
				if not best or node.cost < best.cost then
					best = node
				end
			end
		end
		if not best or not buyUpgrade(player, profile, best) then
			break
		end
		bought += 1
	end
	notify(player, if bought > 0 then "Bought " .. bought .. " upgrade" .. (if bought > 1 then "s" else "") .. "!" else "Not enough Cash for the next upgrade")
	if bought > 0 then
		afterUpgrades(player)
	end
end)

Admin.init(remotes, notify, { afterUpgrades = afterUpgrades, announce = announce })

---------------------------------------------------------------------------
-- Teleports: the side buttons take the player to their base or to the Pack Shop
---------------------------------------------------------------------------
local lastTeleport: { [Player]: number } = {}

remotes.Teleport.OnServerEvent:Connect(function(player, target: any)
	local now = os.clock()
	if now - (lastTeleport[player] or 0) < 1 or player:GetAttribute("InTower") then
		return
	end
	local goal = if target == "base" then Plots.spawnCFrame(player) elseif target == "shop" then Plaza.teleportCFrame("shop") else nil
	local character = player.Character
	if not goal or not character or not character:FindFirstChild("HumanoidRootPart") then
		return
	end
	lastTeleport[player] = now
	-- Get up from a bench first, or the character stays seated where it was
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.SeatPart then
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
		-- The character jumps off the seat for a moment: move it once it is up, and again a
		-- little later in case that jump put it back where it was
		local started = os.clock()
		while humanoid.SeatPart and os.clock() - started < 0.5 do
			task.wait()
		end
		task.wait(0.1)
		character:PivotTo(goal)
		task.wait(0.2)
	end
	character:PivotTo(goal)
end)

Players.PlayerRemoving:Connect(function(player)
	lastTeleport[player] = nil
end)

remotes.RequestSync.OnServerEvent:Connect(function(player)
	PlayerData.sync(player)
end)

---------------------------------------------------------------------------
-- Income: every second, the stands pay their owner
---------------------------------------------------------------------------
task.spawn(function()
	while true do
		task.wait(1)
		local cashBuff = Weather.buffs().cash
		for _, player in Players:GetPlayers() do
			local profile = PlayerData.get(player)
			if profile then
				local income = PlayerData.baseIncome(profile) * cashBuff
				profile.Cash += income
				profile.TotalCash += income
				PlayerData.updateStats(player, cashBuff)
				Plots.setIncome(player, income)
			end
		end
	end
end)
