-- Towers: the player's team of Config.TEAM_SIZE cards fights floor after floor, automatically.
-- The server runs the fight at its own pace and tells the player's screen what happens
-- (TowerEvent), so the arena can be drawn on the client. Rewards are given floor by floor:
-- leaving or losing keeps everything already won.
-- Also handles the team choice and the Trait Rerolls.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Plaza = require(script.Parent.Plaza)
local PlayerData = require(script.Parent.PlayerData)

local Towers = {}

type Fighter = { key: string, cardId: string, hp: number, maxHp: number, dmg: number }
-- A run always starts on screen. During the fight the player can turn on `auto` (the tower
-- starts again by itself after each defeat or clear, until the player leaves or turns it off)
-- and `hidden` (the fight goes on in the background: the player is free to move and keeps
-- playing, a button with two swords brings the fight back on screen)
type Run = { stopped: boolean, auto: boolean, hidden: boolean, tower: Config.Tower }

local runs: { [Player]: Run } = {}
local rng = Random.new()
local towerEvent: RemoteEvent
local notify: (Player, string) -> ()
local announce: (string, Color3) -> ()

-- A random card of a pack; for a boss, one of its rarest cards
local function enemyCard(packId: string, boss: boolean): string
	local cards = Config.packCards(packId)
	if boss then
		local rarest = Config.RARITY[cards[#cards].rarity].order
		local list = {}
		for _, card in cards do
			if Config.RARITY[card.rarity].order == rarest then
				table.insert(list, card)
			end
		end
		cards = list
	end
	return cards[rng:NextInteger(1, #cards)].id
end

-- A random card of a pack with that rarity (the boss reward)
local function rewardCard(packId: string, rarityId: string): string?
	local list = {}
	for _, card in Config.packCards(packId) do
		if card.rarity == rarityId then
			table.insert(list, card.id)
		end
	end
	return if #list > 0 then list[rng:NextInteger(1, #list)] else nil
end

-- The rewards of a cleared floor, added to the profile and to `earned`.
-- Returns what this floor gave, for the screen.
local function reward(player: Player, profile, tower: Config.Tower, floor: number, earned)
	local best = profile.Towers[tower.id] or 0
	local first = floor > best
	if first then
		profile.Towers[tower.id] = floor
	end
	local kind = Config.floorKind(floor)
	local given = { cash = 0, packs = 0, pack = Config.towerPack(tower, floor), card = nil :: string?, reroll = false, first = first }

	given.cash = Config.floorGold(tower, floor) * (1 + PlayerData.bonus(profile, "towerCash"))
	if not first then
		given.cash *= Config.TOWER_RERUN_GOLD
	end
	given.cash = math.max(1, math.floor(given.cash))

	if kind.id == "boss" then
		if first then
			given.packs = Config.TOWER_BOSS_PACKS
			local entry = Config.towerBossCard(tower, floor)
			given.card = rewardCard(entry.pack, entry.rarity)
		elseif rng:NextNumber() < Config.TOWER_RERUN_BOSS_PACK_CHANCE then
			given.packs = 1
		end
	elseif kind.id == "miniboss" then
		if first then
			given.packs = if floor % 50 == 0 then Config.TOWER_MINIBOSS_PACKS_BIG else Config.TOWER_MINIBOSS_PACKS
		elseif rng:NextNumber() < Config.TOWER_RERUN_MINIBOSS_PACK_CHANCE then
			given.packs = 1
		end
	end
	if floor % Config.TOWER_TRAIT_FLOORS == 0 then
		given.reroll = true
		profile.TraitRerolls += 1
		earned.rerolls += 1
	end

	-- Packs and cards go to the backpack; when it is full they are sold right away
	if given.packs > 0 then
		if PlayerData.hasRoom(profile, given.packs) then
			profile.Packs[given.pack] = (profile.Packs[given.pack] or 0) + given.packs
			earned.packs += given.packs
		else
			given.cash += Config.packSellPrice(given.pack) * given.packs
			notify(player, "Backpack full: the packs were sold")
		end
	end
	if given.card then
		if PlayerData.hasRoom(profile, 1) then
			PlayerData.addCard(profile, given.card, "normal")
			table.insert(earned.cards, given.card)
		else
			given.cash += Config.sellPrice(Config.cardKey(given.card, "normal"))
			notify(player, "Backpack full: " .. Config.CARDS[given.card].name .. " was sold")
		end
	end
	earned.cash += given.cash
	PlayerData.addCash(player, given.cash)
	if given.packs > 0 or given.card or given.reroll then
		PlayerData.sync(player)
	end
	return given
end

-- Keeps the player's character still in the plaza while the fight is shown
local function freeze(player: Player, frozen: boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = frozen
	end
end

local function fighterInfo(fighters: { Fighter })
	local list = {}
	for index, fighter in fighters do
		list[index] = { key = fighter.key, cardId = fighter.cardId, hp = fighter.hp, maxHp = fighter.maxHp, dmg = fighter.dmg }
	end
	return list
end

-- One climb of the tower, from floor 1 until defeat, clear or leave. Returns the result.
local function climb(player: Player, tower: Config.Tower, team: { string }, run: Run): string
	local profile = PlayerData.get(player)
	local function send(event)
		towerEvent:FireClient(player, event)
	end

	local fighters: { Fighter } = {}
	local hpBonus, dmgBonus = 1 + PlayerData.bonus(profile, "towerHp"), 1 + PlayerData.bonus(profile, "towerDmg")
	for _, key in team do
		local stats = Config.keyStats(key)
		local hp = math.floor(stats.hp * hpBonus)
		table.insert(fighters, { key = key, cardId = (Config.splitKey(key)), hp = hp, maxHp = hp, dmg = math.floor(stats.dmg * dmgBonus) })
	end
	local earned = { cash = 0, packs = 0, rerolls = 0, cards = {} }

	send({ type = "start", tower = tower.id, team = fighterInfo(fighters), best = profile.Towers[tower.id] or 0 })
	task.wait(Config.TOWER_START_TIME)

	local cleared = 0
	local result = "defeat"
	while true do
		local floor = cleared + 1
		if tower.floors and floor > tower.floors then
			result = "cleared"
			break
		end
		if run.stopped then
			result = "left"
			break
		end
		local kind = Config.floorKind(floor)
		local stats = Config.enemyStats(tower, floor)
		local enemy = { cardId = enemyCard(Config.towerPack(tower, floor), kind.id == "boss"), hp = stats.hp, maxHp = stats.hp, dmg = stats.dmg }
		send({ type = "floor", floor = floor, kind = kind.id, enemy = enemy })
		task.wait(Config.TOWER_FLOOR_TIME)

		-- Headbutts: the front card and the enemy hit each other at the same time
		while enemy.hp > 0 and not run.stopped do
			local index = nil
			for i, fighter in fighters do
				if fighter.hp > 0 then
					index = i
					break
				end
			end
			if not index then
				break
			end
			local fighter = fighters[index]
			enemy.hp = math.max(0, enemy.hp - fighter.dmg)
			fighter.hp = math.max(0, fighter.hp - enemy.dmg)
			send({ type = "clash", fighter = index, dealt = fighter.dmg, taken = enemy.dmg, hp = fighter.hp, enemyHp = enemy.hp })
			task.wait(Config.TOWER_CLASH_TIME)
		end
		if run.stopped then
			result = "left"
			break
		end
		if enemy.hp > 0 then
			result = "defeat"
			break
		end

		cleared = floor
		local given = reward(player, profile, tower, floor, earned)
		local heal = if kind.id == "normal" then Config.TOWER_HEAL else 1
		for _, fighter in fighters do
			if fighter.hp > 0 then
				fighter.hp = math.min(fighter.maxHp, fighter.hp + math.ceil(fighter.maxHp * heal))
			end
		end
		send({ type = "cleared", floor = floor, reward = given, team = fighterInfo(fighters) })
		task.wait(if kind.id == "normal" then Config.TOWER_CLEAR_TIME else Config.TOWER_FLOOR_TIME)
	end

	if result == "cleared" then
		announce(player.DisplayName .. " cleared the " .. tower.name .. "!", tower.color)
	end
	if player.Parent then
		-- `again`: autoplay will start a new climb
		send({ type = "end", result = result, floor = cleared, earned = earned, again = run.auto and not run.stopped and result ~= "left" })
		PlayerData.sync(player)
	end
	return result
end

-- On screen: the character waits, anchored, and the main UI steps aside (InTower). In the
-- background: the character is free (TowerAuto, for the swords button and the Towers panel).
local function setHidden(player: Player, run: Run, hidden: boolean)
	run.hidden = hidden
	freeze(player, not hidden)
	player:SetAttribute("InTower", if hidden then nil else run.tower.id)
	player:SetAttribute("TowerAuto", if hidden then run.tower.id else nil)
end

local function runTower(player: Player, tower: Config.Tower)
	local run: Run = { stopped = false, auto = false, hidden = false, tower = tower }
	runs[player] = run
	setHidden(player, run, false)
	while player.Parent do
		local profile = PlayerData.get(player)
		local team = if profile then PlayerData.validTeam(profile) else {}
		if #team == 0 then
			break
		end
		climb(player, tower, team, run)
		if not run.auto or run.stopped then
			break
		end
		-- Autoplay: a short pause, then the next climb (with the team as it is now)
		task.wait(Config.TOWER_AUTO_RESTART_TIME)
		if not run.auto or run.stopped then
			break
		end
	end
	if player.Parent then
		freeze(player, false)
		player:SetAttribute("InTower", nil)
		player:SetAttribute("TowerAuto", nil)
		towerEvent:FireClient(player, { type = "runEnd" })
	end
	runs[player] = nil
end

function Towers.init(remotes: Folder, notifyFn: (Player, string) -> (), announceFn: (string, Color3) -> ())
	towerEvent = remotes:WaitForChild("TowerEvent") :: RemoteEvent
	notify = notifyFn
	announce = announceFn;

	-- The team: up to TEAM_SIZE owned card keys
	(remotes:WaitForChild("SetTeam") :: RemoteEvent).OnServerEvent:Connect(function(player, keys: any)
		local profile = PlayerData.get(player)
		if not profile or type(keys) ~= "table" or #keys > Config.TEAM_SIZE then
			return
		end
		local team = {}
		for _, key in keys do
			if type(key) ~= "string" or #key > 100 then
				return
			end
			table.insert(team, key)
		end
		profile.Team = team
		profile.Team = PlayerData.validTeam(profile)
		PlayerData.sync(player)
	end);

	(remotes:WaitForChild("StartTower") :: RemoteEvent).OnServerEvent:Connect(function(player, towerId: any)
		local profile = PlayerData.get(player)
		local tower = type(towerId) == "string" and Config.TOWER[towerId]
		if not profile or not tower or runs[player] then
			return
		end
		if not Plaza.near(player, "towers") then
			notify(player, "Go to the Towers stand in the plaza")
			return
		end
		local team = PlayerData.validTeam(profile)
		if #team == 0 then
			notify(player, "Choose your team first")
			return
		end
		task.spawn(runTower, player, tower)
	end);

	(remotes:WaitForChild("LeaveTower") :: RemoteEvent).OnServerEvent:Connect(function(player)
		local run = runs[player]
		if run then
			run.stopped = true
		end
	end);

	-- During a run: ("auto", on) turns autoplay on or off, ("hidden", on) sends the fight to the
	-- background or brings it back on screen
	(remotes:WaitForChild("TowerMode") :: RemoteEvent).OnServerEvent:Connect(function(player, mode: any, on: any)
		local run = runs[player]
		if not run or run.stopped or type(on) ~= "boolean" then
			return
		end
		if mode == "auto" then
			run.auto = on
		elseif mode == "hidden" and on ~= run.hidden then
			setHidden(player, run, on)
		end
	end);

	-- A Trait Reroll gives one card of the backpack a new random trait (never the same one again)
	(remotes:WaitForChild("RerollTrait") :: RemoteFunction).OnServerInvoke = function(player: Player, key: any)
		local profile = PlayerData.get(player)
		if not profile or type(key) ~= "string" then
			return nil
		end
		local cardId, variantId, scores, traitId = Config.splitKey(key)
		if not Config.CARDS[cardId] or (profile.Cards[key] or 0) < 1 then
			notify(player, "The card must be in your backpack")
			return nil
		end
		if profile.TraitRerolls < 1 then
			notify(player, "No Trait Reroll left: win some in the towers")
			return nil
		end
		local choices, total = {}, 0
		for _, trait in Config.TRAITS do
			if trait.id ~= traitId then
				table.insert(choices, trait)
				total += trait.weight
			end
		end
		local roll = rng:NextNumber() * total
		local newTrait = choices[#choices]
		for _, trait in choices do
			roll -= trait.weight
			if roll <= 0 then
				newTrait = trait
				break
			end
		end
		profile.TraitRerolls -= 1
		PlayerData.removeCard(profile, key, 1)
		PlayerData.addCard(profile, cardId, variantId, scores, newTrait.id)
		local newKey = Config.cardKey(cardId, variantId, scores, newTrait.id)
		-- A team card keeps its place in the team
		local index = table.find(profile.Team, key)
		if index then
			profile.Team[index] = newKey
		end
		notify(player, Config.CARDS[cardId].name .. " got " .. newTrait.name .. "!")
		PlayerData.sync(player)
		return newKey
	end

	Players.PlayerRemoving:Connect(function(player)
		local run = runs[player]
		if run then
			run.stopped = true
		end
	end)
end

return Towers
