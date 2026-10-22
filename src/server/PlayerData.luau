-- Player profiles: loading, saving (DataStore), income math
-- and syncing to the client (attributes + a full profile event).

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerData = {}

local DATA_VERSION = 1
local AUTOSAVE_INTERVAL = 60

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore("BrainrotCards_v" .. DATA_VERSION)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable, progress will not be saved:", result)
	end
end

local profiles: { [Player]: any } = {}
local syncRemote: RemoteEvent

local function defaultProfile()
	return {
		Cash = Config.STARTING_CASH,
		TotalCash = 0,
		PacksOpened = 0,
		Cards = {}, -- ["cardId|variantId"] or ["cardId|variantId|scores"] = count (cards in the backpack, not on a stand)
		Stands = {}, -- [tostring(slot)] = card key
		Packs = {}, -- [packId] = unopened packs in the backpack
		BackpackLevel = 0, -- number of backpack upgrades bought
		Index = {}, -- [cardId] = true once pulled at least once
		Pity = {}, -- [packId] = packs opened since the last card of Config.PITY_RARITY or better
		LastOnline = 0, -- os.time() of the last save, for offline income
		DailyDay = 0, -- day number of the last daily reward claimed
		DailyStreak = 0,
		Codes = {}, -- [code] = true once redeemed
	}
end

local function reconcile(data)
	local profile = defaultProfile()
	if type(data) == "table" then
		for key, value in data do
			if profile[key] ~= nil and type(value) == type(profile[key]) then
				profile[key] = value
			end
		end
	end
	-- Drop cards that no longer exist in Config
	for key in profile.Cards do
		local cardId = Config.splitKey(key)
		if not Config.CARDS[cardId] then
			profile.Cards[key] = nil
		end
	end
	for packId in profile.Packs do
		if not Config.PACK[packId] then
			profile.Packs[packId] = nil
		end
	end
	for slot, key in profile.Stands do
		local cardId = Config.splitKey(key)
		if not Config.CARDS[cardId] or (tonumber(slot) or 0) > Config.STAND_COUNT then
			profile.Stands[slot] = nil
		end
	end
	return profile
end

local function setupLeaderstats(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	for _, name in { "Cash", "Packs" } do
		local value = Instance.new("NumberValue")
		value.Name = name
		value.Parent = leaderstats
	end
	leaderstats.Parent = player
end

function PlayerData.init(remotes: Folder)
	syncRemote = remotes:WaitForChild("ProfileSync") :: RemoteEvent

	Players.PlayerRemoving:Connect(function(player)
		PlayerData.save(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			task.wait(0.5)
		end
		for _, player in Players:GetPlayers() do
			PlayerData.save(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for _, player in Players:GetPlayers() do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
end

-- Returns the profile and the cash earned while offline
function PlayerData.load(player: Player): (any, number)
	local data = nil
	if store then
		local ok, result = pcall(function()
			return (store :: DataStore):GetAsync("player_" .. player.UserId)
		end)
		if ok then
			data = result
		else
			warn("[PlayerData] Failed to load data for", player.Name, result)
		end
	end
	local profile = reconcile(data)
	profiles[player] = profile

	-- Offline income: the stands kept working while the player was away (capped)
	local offline = 0
	if profile.LastOnline > 0 then
		local away = math.clamp(os.time() - profile.LastOnline, 0, Config.OFFLINE_MAX_HOURS * 3600)
		offline = math.floor(PlayerData.baseIncome(profile) * away)
		if offline > 0 then
			profile.Cash += offline
			profile.TotalCash += offline
		end
	end
	profile.LastOnline = os.time()

	setupLeaderstats(player)
	PlayerData.sync(player)
	return profile, offline
end

function PlayerData.save(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	profile.LastOnline = os.time()
	local ok, err = pcall(function()
		(store :: DataStore):SetAsync("player_" .. player.UserId, profile)
	end)
	if not ok then
		warn("[PlayerData] Failed to save data for", player.Name, err)
	end
end

function PlayerData.get(player: Player)
	return profiles[player]
end

---------------------------------------------------------------------------
-- Income
---------------------------------------------------------------------------
-- Number of packs whose cards have all been pulled at least once
function PlayerData.completedPacks(profile): number
	local completed = 0
	for _, pack in Config.PACKS do
		local all = true
		for _, card in Config.packCards(pack.id) do
			if not profile.Index[card.id] then
				all = false
				break
			end
		end
		if all then
			completed += 1
		end
	end
	return completed
end

-- Cash per second of the stands with the Index bonus, without weather
function PlayerData.baseIncome(profile): number
	local total = 0
	for _, key in profile.Stands do
		total += Config.keyIncome(key)
	end
	return total * Config.indexMultiplier(PlayerData.completedPacks(profile))
end

function PlayerData.addCash(player: Player, amount: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	profile.Cash += amount
	if amount > 0 then
		profile.TotalCash += amount
	end
	PlayerData.updateStats(player)
end

function PlayerData.addCard(profile, cardId: string, variantId: string, scores: { number }?)
	local key = Config.cardKey(cardId, variantId, scores)
	profile.Cards[key] = (profile.Cards[key] or 0) + 1
	profile.Index[cardId] = true
end

---------------------------------------------------------------------------
-- Backpack: cards and unopened packs take one slot each
---------------------------------------------------------------------------
function PlayerData.backpackUsed(profile): number
	local used = 0
	for _, count in profile.Cards do
		used += count
	end
	for _, count in profile.Packs do
		used += count
	end
	return used
end

function PlayerData.backpackSize(profile): number
	return Config.backpackSize(profile.BackpackLevel)
end

-- True if `slots` more items fit in the backpack
function PlayerData.hasRoom(profile, slots: number): boolean
	return PlayerData.backpackUsed(profile) + slots <= PlayerData.backpackSize(profile)
end

function PlayerData.removePack(profile, packId: string, count: number): boolean
	local owned = profile.Packs[packId] or 0
	if owned < count then
		return false
	end
	owned -= count
	profile.Packs[packId] = if owned > 0 then owned else nil
	return true
end

function PlayerData.removeCard(profile, key: string, count: number): boolean
	local owned = profile.Cards[key] or 0
	if owned < count then
		return false
	end
	owned -= count
	profile.Cards[key] = if owned > 0 then owned else nil
	return true
end

---------------------------------------------------------------------------
-- Syncing to the client
---------------------------------------------------------------------------
-- Cheap values, changed often: attributes (read by the UI) and the leaderboard
function PlayerData.updateStats(player: Player, weatherCash: number?)
	local profile = profiles[player]
	if not profile then
		return
	end
	local function set(name: string, value: number)
		if player:GetAttribute(name) ~= value then
			player:SetAttribute(name, value)
		end
	end
	set("Cash", math.floor(profile.Cash))
	set("PacksOpened", profile.PacksOpened)
	if weatherCash then
		set("Income", PlayerData.baseIncome(profile) * weatherCash)
	end
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		(leaderstats:FindFirstChild("Cash") :: NumberValue).Value = math.floor(profile.Cash);
		(leaderstats:FindFirstChild("Packs") :: NumberValue).Value = profile.PacksOpened
	end
end

-- Inventory, stands and Index: sent whole when they change
function PlayerData.sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	PlayerData.updateStats(player)
	player:SetAttribute("CompletedPacks", PlayerData.completedPacks(profile))
	player:SetAttribute("BackpackUsed", PlayerData.backpackUsed(profile))
	player:SetAttribute("BackpackSize", PlayerData.backpackSize(profile))
	syncRemote:FireClient(player, {
		cards = profile.Cards,
		stands = profile.Stands,
		packs = profile.Packs,
		backpackLevel = profile.BackpackLevel,
		index = profile.Index,
		pity = profile.Pity,
		dailyDay = profile.DailyDay,
		dailyStreak = profile.DailyStreak,
	})
end

return PlayerData
