-- Every game setting lives here: rarities, variants, packs, cards, weather, stands.
-- Change the numbers here to rebalance the game; nothing else needs to change.

local Config = {}

---------------------------------------------------------------------------
-- Rarities, from the most common to the rarest
---------------------------------------------------------------------------
export type Rarity = { id: string, name: string, order: number, color: Color3, cash: number }

Config.RARITIES = {
	{ id = "common", name = "Common", order = 1, color = Color3.fromRGB(190, 190, 190), cash = 1 },
	{ id = "uncommon", name = "Uncommon", order = 2, color = Color3.fromRGB(110, 220, 110), cash = 2 },
	{ id = "rare", name = "Rare", order = 3, color = Color3.fromRGB(80, 160, 255), cash = 5 },
	{ id = "epic", name = "Epic", order = 4, color = Color3.fromRGB(180, 90, 255), cash = 25 },
	{ id = "legendary", name = "Legendary", order = 5, color = Color3.fromRGB(255, 190, 40), cash = 120 },
	{ id = "mythic", name = "Mythic", order = 6, color = Color3.fromRGB(255, 70, 90), cash = 600 },
	{ id = "secret", name = "Secret", order = 7, color = Color3.fromRGB(235, 235, 255), cash = 3000 },
	{ id = "divine", name = "Divine", order = 8, color = Color3.fromRGB(255, 140, 230), cash = 15000 },
} :: { Rarity }

Config.RARITY = {} :: { [string]: Rarity }
for _, rarity in Config.RARITIES do
	Config.RARITY[rarity.id] = rarity
end

---------------------------------------------------------------------------
-- Variants ("shiny"): every card rolls its own variant, whatever the pack.
-- A card has a single variant: the rarest one rolled wins.
-- `chance` is in percent. Listed from the rarest to the most common.
---------------------------------------------------------------------------
export type Variant = { id: string, name: string, chance: number, cash: number, color: Color3 }

Config.VARIANTS = {
	{ id = "holo", name = "Holo", chance = 0.5, cash = 50, color = Color3.fromRGB(120, 255, 240) },
	{ id = "rainbow", name = "Rainbow", chance = 5, cash = 10, color = Color3.fromRGB(255, 120, 200) },
	{ id = "gold", name = "Gold", chance = 20, cash = 3, color = Color3.fromRGB(255, 205, 60) },
} :: { Variant }

Config.NORMAL_VARIANT = { id = "normal", name = "Normal", chance = 0, cash = 1, color = Color3.new(1, 1, 1) } :: Variant

Config.VARIANT = { normal = Config.NORMAL_VARIANT } :: { [string]: Variant }
for _, variant in Config.VARIANTS do
	Config.VARIANT[variant.id] = variant
end

-- Fusing FUSE_COUNT identical cards gives one card of the next variant up
Config.FUSE_COUNT = 5
Config.FUSE_NEXT = { normal = "gold", gold = "rainbow", rainbow = "holo" } :: { [string]: string }

-- Chance of the variant itself, in percent (normal = what is left)
function Config.variantChance(variantId: string): number
	if variantId == "normal" then
		local total = 0
		for _, variant in Config.VARIANTS do
			total += variant.chance
		end
		return 100 - total
	end
	return Config.VARIANT[variantId].chance
end

---------------------------------------------------------------------------
-- Cards
---------------------------------------------------------------------------
export type Card = { id: string, name: string, rarity: string, pack: string }

Config.CARDS = {} :: { [string]: Card }

---------------------------------------------------------------------------
-- Packs. Each pack has its own odds (percent per card, total 100):
-- low rarities fade out and rarer ones appear as packs get more expensive.
-- `cash` multiplies the income of the pack's cards so each new pack is worth it.
-- Each pack lists its cards by rarity.
---------------------------------------------------------------------------
export type Pack = {
	id: string,
	name: string,
	order: number,
	price: number,
	cash: number,
	color: Color3,
	odds: { [string]: number },
	cards: { [string]: { { id: string, name: string } } },
}

Config.CARDS_PER_PACK = 3

Config.PACKS = {
	{
		id = "starter",
		order = 1,
		name = "Starter Pack",
		price = 50,
		cash = 1,
		color = Color3.fromRGB(120, 200, 120),
		odds = { common = 60, uncommon = 30, rare = 9, epic = 1 },
		cards = {
			common = { { id = "noobini", name = "Noobini Pizzanini" }, { id = "lirili", name = "Lirili Larila" }, { id = "timcheese", name = "Tim Cheese" } },
			uncommon = { { id = "fluriflura", name = "Fluriflura" }, { id = "pipikiwi", name = "Pipi Kiwi" } },
			rare = { { id = "trippi", name = "Trippi Troppi" } },
			epic = { { id = "boneca", name = "Boneca Ambalabu" } },
		},
	},
	{
		id = "italian",
		order = 2,
		name = "Italian Pack",
		price = 1000,
		cash = 8,
		color = Color3.fromRGB(80, 170, 255),
		odds = { common = 30, uncommon = 40, rare = 25, epic = 4.5, legendary = 0.5 },
		cards = {
			common = { { id = "talpa", name = "Talpa di Fero" }, { id = "svinino", name = "Svinino Bombondino" } },
			uncommon = { { id = "patapim", name = "Brr Brr Patapim" }, { id = "bananita", name = "Bananita Dolphinita" } },
			rare = { { id = "chimpanzini", name = "Chimpanzini Bananini" } },
			epic = { { id = "ballerina", name = "Ballerina Cappuccina" } },
			legendary = { { id = "tralalero", name = "Tralalero Tralala" } },
		},
	},
	{
		id = "chaos",
		order = 3,
		name = "Chaos Pack",
		price = 25000,
		cash = 60,
		color = Color3.fromRGB(255, 110, 70),
		odds = { uncommon = 35, rare = 45, epic = 16, legendary = 3.5, mythic = 0.5 },
		cards = {
			uncommon = { { id = "trictrac", name = "Tric Trac Baraboom" }, { id = "rhino", name = "Rhino Toasterino" } },
			rare = { { id = "cappuccino", name = "Cappuccino Assassino" }, { id = "burbaloni", name = "Burbaloni Luliloli" } },
			epic = { { id = "orangutini", name = "Orangutini Ananassini" } },
			legendary = { { id = "tungtung", name = "Tung Tung Tung Sahur" }, { id = "odin", name = "Odin Din Din Dun" } },
			mythic = { { id = "matteo", name = "Matteo" } },
		},
	},
	{
		id = "sky",
		order = 4,
		name = "Sky Pack",
		price = 500000,
		cash = 500,
		color = Color3.fromRGB(120, 220, 255),
		odds = { rare = 50, epic = 35, legendary = 12, mythic = 2.8, secret = 0.2 },
		cards = {
			rare = { { id = "bombombini", name = "Bombombini Gusini" }, { id = "girafa", name = "Girafa Celestre" } },
			epic = { { id = "frigo", name = "Frigo Camelo" }, { id = "cocofanto", name = "Cocofanto Elefanto" } },
			legendary = { { id = "bombardiro", name = "Bombardiro Crocodilo" } },
			mythic = { { id = "gangster", name = "Gangster Footera" } },
			secret = { { id = "lavaca", name = "La Vaca Saturno Saturnita" } },
		},
	},
	{
		id = "galaxy",
		order = 5,
		name = "Galaxy Pack",
		price = 10000000,
		cash = 4000,
		color = Color3.fromRGB(170, 90, 255),
		odds = { epic = 55, legendary = 33, mythic = 10, secret = 1.9, divine = 0.1 },
		cards = {
			epic = { { id = "glorbo", name = "Glorbo Fruttodrillo" }, { id = "blueberrinni", name = "Blueberrinni Octopussini" } },
			legendary = { { id = "espresso", name = "Espresso Signora" }, { id = "chicleteira", name = "Chicleteira Bicicleteira" } },
			mythic = { { id = "tralaleritos", name = "Los Tralaleritos" } },
			secret = { { id = "garama", name = "Garama and Madundung" } },
			divine = { { id = "strawberry", name = "Strawberry Elephant" } },
		},
	},
} :: { Pack }

Config.PACK = {} :: { [string]: Pack }
for _, pack in Config.PACKS do
	Config.PACK[pack.id] = pack
	for rarityId, list in pack.cards do
		assert(Config.RARITY[rarityId], "Unknown rarity " .. rarityId .. " in " .. pack.id)
		assert(pack.odds[rarityId], "No odds for " .. rarityId .. " in " .. pack.id)
		for _, entry in list do
			assert(not Config.CARDS[entry.id], "Card listed twice: " .. entry.id)
			Config.CARDS[entry.id] = { id = entry.id, name = entry.name, rarity = rarityId, pack = pack.id }
		end
	end
end

-- Cards of a pack, sorted by rarity then name (for the Index)
function Config.packCards(packId: string): { Card }
	local list = {}
	for _, card in Config.CARDS do
		if card.pack == packId then
			table.insert(list, card)
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = Config.RARITY[a.rarity].order, Config.RARITY[b.rarity].order
		if ra ~= rb then
			return ra < rb
		end
		return a.name < b.name
	end)
	return list
end

-- Base chance (0-1) of pulling this exact card in its pack, before any luck or weather
function Config.cardChance(cardId: string): number
	local card = Config.CARDS[cardId]
	local pack = Config.PACK[card.pack]
	return pack.odds[card.rarity] / 100 / #pack.cards[card.rarity]
end

-- Base chance as "1 in X" of this exact card, shown under it when it is revealed.
-- A variant multiplies X by its own rarity (Holo at 0.5% = x200); a normal card shows the card's chance.
function Config.oneIn(cardId: string, variantId: string): number
	local chance = Config.cardChance(cardId)
	if variantId ~= "normal" then
		chance *= Config.variantChance(variantId) / 100
	end
	return math.max(1, math.floor(1 / chance + 0.5))
end

---------------------------------------------------------------------------
-- Grading: a card can be graded once. It gets 4 scores from 1 to 10 and the
-- average gives its grade, which multiplies its Cash and its sell price.
-- The grade is rolled first with `chance` (percent, total 100), then 4 scores
-- whose average fits that grade are made up, so the odds are exactly these.
-- `min` is the lowest average of the grade (the average is rounded: 8.5 -> 9).
---------------------------------------------------------------------------
export type Grade = { grade: number, name: string, min: number, chance: number, cash: number, color: Color3 }

Config.GRADE_CRITERIA = { "Centering", "Corners", "Edges", "Surface" }

Config.GRADES = {
	{ grade = 10, name = "GEM MINT 10", min = 9.5, chance = 0.5, cash = 5, color = Color3.fromRGB(255, 215, 60) },
	{ grade = 9, name = "MINT 9", min = 8.5, chance = 2, cash = 3, color = Color3.fromRGB(255, 120, 200) },
	{ grade = 8, name = "NM-MT 8", min = 7.5, chance = 8, cash = 2, color = Color3.fromRGB(170, 110, 255) },
	{ grade = 7, name = "NEAR MINT 7", min = 6.5, chance = 14.5, cash = 1.6, color = Color3.fromRGB(80, 170, 255) },
	{ grade = 6, name = "EX-MT 6", min = 5.5, chance = 25, cash = 1.3, color = Color3.fromRGB(110, 220, 110) },
	{ grade = 5, name = "EXCELLENT 5", min = 4.5, chance = 25, cash = 1.15, color = Color3.fromRGB(210, 210, 210) },
	{ grade = 4, name = "POOR", min = 1, chance = 25, cash = 1, color = Color3.fromRGB(150, 150, 150) },
} :: { Grade }

-- Grading a card costs the price of its pack x its variant's Cash multiplier
function Config.gradeCost(cardId: string, variantId: string): number
	local card = Config.CARDS[cardId]
	local variant = Config.VARIANT[variantId] or Config.NORMAL_VARIANT
	return Config.PACK[card.pack].price * variant.cash
end

function Config.gradeFromScores(scores: { number }): Grade
	local total = 0
	for _, score in scores do
		total += score
	end
	local average = total / #scores
	for _, grade in Config.GRADES do
		if average >= grade.min then
			return grade
		end
	end
	return Config.GRADES[#Config.GRADES]
end

---------------------------------------------------------------------------
-- Traits: a bonus a card gets from a Trait Reroll (won in the towers). A card has at most
-- one trait; rerolling replaces it. `hp` and `dmg` multiply its tower stats, `cash` its
-- Cash per second (and not its stats).
---------------------------------------------------------------------------
export type Trait = { id: string, name: string, weight: number, hp: number, dmg: number, cash: number, color: Color3 }

Config.TRAITS = {
	{ id = "dmg", name = "DMG Boost", weight = 1, hp = 1, dmg = 1.3, cash = 1, color = Color3.fromRGB(255, 110, 80) },
	{ id = "hp", name = "HP Boost", weight = 1, hp = 1.3, dmg = 1, cash = 1, color = Color3.fromRGB(90, 230, 120) },
	{ id = "coin", name = "Coin Boost", weight = 1, hp = 1, dmg = 1, cash = 1.3, color = Color3.fromRGB(255, 215, 60) },
} :: { Trait }

Config.TRAIT = {} :: { [string]: Trait }
for _, trait in Config.TRAITS do
	Config.TRAIT[trait.id] = trait
end

---------------------------------------------------------------------------
-- Owned cards are stored as "cardId|variantId", then "|9.10.8.9" once graded (the 4 scores)
-- and "|traitId" once it has a trait ("cardId|variantId||hp" for a trait without a grade).
-- Identical cards stack under the same key.
---------------------------------------------------------------------------
function Config.cardKey(cardId: string, variantId: string, scores: { number }?, traitId: string?): string
	local key = cardId .. "|" .. variantId
	if scores or traitId then
		key ..= "|" .. (if scores then table.concat(scores, ".") else "")
	end
	if traitId then
		key ..= "|" .. traitId
	end
	return key
end

-- Returns the card id, the variant id, the 4 scores (nil if the card isn't graded)
-- and the trait id (nil if it has none)
function Config.splitKey(key: string): (string, string, { number }?, string?)
	local parts = string.split(key, "|")
	if #parts < 2 then
		return key, "normal", nil, nil
	end
	local scores: { number }? = nil
	if parts[3] and parts[3] ~= "" then
		local list = {}
		for _, score in string.split(parts[3], ".") do
			table.insert(list, tonumber(score) or 1)
		end
		scores = list
	end
	local traitId = if parts[4] and Config.TRAIT[parts[4]] then parts[4] else nil
	return parts[1], parts[2], scores, traitId
end

-- The trait of a card key, or nil if it has none
function Config.keyTrait(key: string): Trait?
	local _, _, _, traitId = Config.splitKey(key)
	return if traitId then Config.TRAIT[traitId] else nil
end

-- The grade of a card key, or nil if it isn't graded
function Config.keyGrade(key: string): Grade?
	local _, _, scores = Config.splitKey(key)
	return if scores then Config.gradeFromScores(scores) else nil
end

-- Cash per second of a card on a stand, before player bonuses (Index, weather)
function Config.cardIncome(cardId: string, variantId: string): number
	local card = Config.CARDS[cardId]
	if not card then
		return 0
	end
	local variant = Config.VARIANT[variantId] or Config.NORMAL_VARIANT
	return Config.RARITY[card.rarity].cash * Config.PACK[card.pack].cash * variant.cash
end

-- Same, for an owned card key (its grade and trait included)
function Config.keyIncome(key: string): number
	local cardId, variantId = Config.splitKey(key)
	local grade = Config.keyGrade(key)
	local trait = Config.keyTrait(key)
	return Config.cardIncome(cardId, variantId) * (if grade then grade.cash else 1) * (if trait then trait.cash else 1)
end

-- Tower stats of a card: the more Cash it makes, the stronger it is. Only its rarity, pack
-- and variant count (not its grade nor a Coin Boost), then the HP or DMG Boost of its trait.
Config.CARD_HP = 10 -- HP per $1/s
Config.CARD_DMG = 2 -- DMG per $1/s

function Config.keyStats(key: string): { hp: number, dmg: number }
	local cardId, variantId = Config.splitKey(key)
	local power = Config.cardIncome(cardId, variantId)
	local trait = Config.keyTrait(key)
	return {
		hp = math.ceil(power * Config.CARD_HP * (if trait then trait.hp else 1)),
		dmg = math.ceil(power * Config.CARD_DMG * (if trait then trait.dmg else 1)),
	}
end

---------------------------------------------------------------------------
-- Backpack and selling
---------------------------------------------------------------------------
-- Cards and unopened packs take one slot each; cards on the stands don't count
Config.BACKPACK_SLOTS = 50
-- Bigger backpacks, bought one after the other at the Shop
Config.BACKPACK_UPGRADES = {
	{ slots = 25, price = 750 },
	{ slots = 25, price = 7500 },
	{ slots = 50, price = 75000 },
	{ slots = 50, price = 750000 },
	{ slots = 100, price = 10000000 },
} :: { { slots: number, price: number } }

function Config.backpackSize(level: number): number
	local size = Config.BACKPACK_SLOTS
	for index = 1, math.min(level, #Config.BACKPACK_UPGRADES) do
		size += Config.BACKPACK_UPGRADES[index].slots
	end
	return size
end

-- A card sells for this many seconds of its Cash (grade included)
Config.SELL_SECONDS = 60
-- An unopened pack sells back for this share of its price
Config.PACK_SELL_RATIO = 0.5

function Config.sellPrice(key: string): number
	return math.max(1, math.floor(Config.keyIncome(key) * Config.SELL_SECONDS))
end

function Config.packSellPrice(packId: string): number
	return math.floor(Config.PACK[packId].price * Config.PACK_SELL_RATIO)
end

---------------------------------------------------------------------------
-- Stands, Index, pity, offline income
---------------------------------------------------------------------------
Config.STAND_COUNT = 8
Config.STARTING_CASH = 150 -- enough for 3 Starter Packs
Config.OFFLINE_MAX_HOURS = 8
Config.INDEX_BONUS = 0.10 -- +10% cash for each pack fully completed in the Index (normal variants)
-- Pity: after PITY_PACKS packs of the same kind without a card of PITY_RARITY or better,
-- the next pack guarantees one
Config.PITY_PACKS = 20
Config.PITY_RARITY = "epic"
-- Pulls this rare (1 in X or more) are announced to the whole server
Config.ANNOUNCE_ONE_IN = 1000

Config.DAILY_REWARD_BASE = 100 -- cash for day 1 of the streak, x streak day (max 7)
Config.DAILY_STREAK_MAX = 7

Config.CODES = {
	BRAINROT = { cash = 250 },
	RELEASE = { cash = 500 },
} :: { [string]: { cash: number } }

-- Index bonus multiplier for a number of completed packs
function Config.indexMultiplier(completedPacks: number): number
	return 1 + Config.INDEX_BONUS * completedPacks
end

---------------------------------------------------------------------------
-- Towers: a team of TEAM_SIZE cards fights floor after floor, automatically. Each floor has
-- one enemy brainrot; the front card and the enemy headbutt each other until one falls,
-- then the next card steps in. HP carry over from floor to floor (it's an endurance test).
-- Enemy power on floor f = start x growth^(f-1), with the same HP and DMG per power as cards.
-- `floors` = nil: the tower never ends (Infinite).
-- `packs`: the pack used for the enemies and the pack rewards, from a floor on.
-- `bossCards`: the card won for the first clear of each boss (1st boss, 2nd boss...), a random
-- card of that pack and rarity; the last one repeats.
---------------------------------------------------------------------------
export type Tower = {
	id: string,
	name: string,
	order: number,
	floors: number?,
	color: Color3,
	start: number,
	growth: number,
	packs: { { from: number, pack: string } },
	bossCards: { { pack: string, rarity: string } },
}

Config.TEAM_SIZE = 3

Config.TOWERS = {
	{
		id = "easy",
		name = "Easy Tower",
		order = 1,
		floors = 100,
		color = Color3.fromRGB(110, 220, 110),
		start = 0.5,
		growth = 1.07,
		packs = { { from = 1, pack = "starter" }, { from = 50, pack = "italian" } },
		bossCards = { { pack = "italian", rarity = "legendary" } },
	},
	{
		id = "medium",
		name = "Medium Tower",
		order = 2,
		floors = 200,
		color = Color3.fromRGB(255, 190, 40),
		start = 100,
		growth = 1.0437,
		packs = { { from = 1, pack = "italian" }, { from = 100, pack = "chaos" } },
		bossCards = { { pack = "chaos", rarity = "legendary" }, { pack = "chaos", rarity = "mythic" } },
	},
	{
		id = "hard",
		name = "Hard Tower",
		order = 3,
		floors = 300,
		color = Color3.fromRGB(255, 70, 90),
		start = 20000,
		growth = 1.0313,
		packs = { { from = 1, pack = "chaos" }, { from = 100, pack = "sky" }, { from = 200, pack = "galaxy" } },
		bossCards = { { pack = "sky", rarity = "legendary" }, { pack = "sky", rarity = "mythic" }, { pack = "galaxy", rarity = "mythic" } },
	},
	{
		id = "infinite",
		name = "Infinite Tower",
		order = 4,
		floors = nil,
		color = Color3.fromRGB(170, 90, 255),
		start = 1,
		growth = 1.06,
		packs = { { from = 1, pack = "starter" }, { from = 50, pack = "italian" }, { from = 150, pack = "chaos" }, { from = 250, pack = "sky" }, { from = 350, pack = "galaxy" } },
		bossCards = { { pack = "italian", rarity = "legendary" }, { pack = "chaos", rarity = "mythic" }, { pack = "sky", rarity = "mythic" }, { pack = "galaxy", rarity = "mythic" }, { pack = "galaxy", rarity = "secret" } },
	},
} :: { Tower }

Config.TOWER = {} :: { [string]: Tower }
for _, tower in Config.TOWERS do
	Config.TOWER[tower.id] = tower
end

-- Mini-bosses and bosses: stronger enemies, bigger rewards. `scale` is the size of their model.
export type FloorKind = { id: string, name: string, every: number, hp: number, dmg: number, gold: number, scale: number }

Config.FLOOR_KINDS = {
	boss = { id = "boss", name = "BOSS", every = 100, hp = 10, dmg = 2, gold = 10, scale = 1.9 },
	miniboss = { id = "miniboss", name = "MINI-BOSS", every = 10, hp = 3, dmg = 1.5, gold = 3, scale = 1.4 },
	normal = { id = "normal", name = "", every = 1, hp = 1, dmg = 1, gold = 1, scale = 1 },
} :: { [string]: FloorKind }

-- After each floor the team heals this share of its max HP (fallen cards stay down),
-- and fully after each mini-boss and boss
Config.TOWER_HEAL = 0.1

-- Rewards. A floor cleared for the first time gives the full Cash; cleared again, only RERUN_GOLD of it.
Config.TOWER_GOLD_SECONDS = 20 -- Cash per floor = enemy power x this
Config.TOWER_RERUN_GOLD = 0.25
-- First clear: packs for each mini-boss (MINIBOSS_PACKS_BIG on floors that are a multiple of 50)
-- and BOSS_PACKS + a card for each boss. Cleared again: a chance of one pack.
Config.TOWER_MINIBOSS_PACKS = 1
Config.TOWER_MINIBOSS_PACKS_BIG = 2
Config.TOWER_BOSS_PACKS = 2
Config.TOWER_RERUN_MINIBOSS_PACK_CHANCE = 0.15
Config.TOWER_RERUN_BOSS_PACK_CHANCE = 0.4
-- A Trait Reroll every TRAIT_FLOORS floors, first clear or not
Config.TOWER_TRAIT_FLOORS = 5

-- Pace of the fights, in seconds
Config.TOWER_START_TIME = 2 -- the arena appears and the camera gets in place
Config.TOWER_CLASH_TIME = 1.1 -- one headbutt
Config.TOWER_FLOOR_TIME = 1.4 -- the enemy comes in (also the pause after a boss)
Config.TOWER_CLEAR_TIME = 0.8 -- the pause after a normal floor

function Config.floorKind(floor: number): FloorKind
	if floor % Config.FLOOR_KINDS.boss.every == 0 then
		return Config.FLOOR_KINDS.boss
	elseif floor % Config.FLOOR_KINDS.miniboss.every == 0 then
		return Config.FLOOR_KINDS.miniboss
	end
	return Config.FLOOR_KINDS.normal
end

function Config.enemyPower(tower: Tower, floor: number): number
	return tower.start * tower.growth ^ (floor - 1)
end

function Config.enemyStats(tower: Tower, floor: number): { hp: number, dmg: number }
	local power = Config.enemyPower(tower, floor)
	local kind = Config.floorKind(floor)
	return { hp = math.ceil(power * Config.CARD_HP * kind.hp), dmg = math.ceil(power * Config.CARD_DMG * kind.dmg) }
end

-- Cash for clearing a floor for the first time
function Config.floorGold(tower: Tower, floor: number): number
	return math.max(1, math.floor(Config.enemyPower(tower, floor) * Config.TOWER_GOLD_SECONDS * Config.floorKind(floor).gold))
end

-- The pack of the enemies and pack rewards on a floor
function Config.towerPack(tower: Tower, floor: number): string
	local packId = tower.packs[1].pack
	for _, entry in tower.packs do
		if floor >= entry.from then
			packId = entry.pack
		end
	end
	return packId
end

function Config.towerBossCard(tower: Tower, floor: number): { pack: string, rarity: string }
	local index = math.clamp(floor // Config.FLOOR_KINDS.boss.every, 1, #tower.bossCards)
	return tower.bossCards[index]
end

---------------------------------------------------------------------------
-- Weather: every WEATHER_INTERVAL seconds a random weather gives the whole server
-- a temporary buff for WEATHER_DURATION seconds.
-- luck: multiplies the chances of every rarity above the pack's most common one.
-- shiny: multiplies the chances of Gold, Rainbow and Holo.
-- cash: multiplies the cash of the stands.
---------------------------------------------------------------------------
export type Weather = { id: string, name: string, weight: number, luck: number, shiny: number, cash: number, color: Color3, description: string }

Config.WEATHER_INTERVAL = 600
Config.WEATHER_DURATION = 180

Config.WEATHERS = {
	{ id = "lucky", name = "Lucky Breeze", weight = 40, luck = 2, shiny = 1, cash = 1, color = Color3.fromRGB(110, 230, 120), description = "x2 Luck" },
	{ id = "shiny", name = "Shiny Storm", weight = 35, luck = 1, shiny = 2, cash = 1, color = Color3.fromRGB(255, 140, 220), description = "x2 Gold, Rainbow and Holo chances" },
	{ id = "golden", name = "Golden Hour", weight = 20, luck = 1, shiny = 1, cash = 2, color = Color3.fromRGB(255, 200, 60), description = "x2 Cash from stands" },
	{ id = "eclipse", name = "Brainrot Eclipse", weight = 5, luck = 2, shiny = 2, cash = 2, color = Color3.fromRGB(150, 80, 255), description = "x2 Luck, x2 Shiny, x2 Cash" },
} :: { Weather }

Config.WEATHER = {} :: { [string]: Weather }
for _, weather in Config.WEATHERS do
	Config.WEATHER[weather.id] = weather
end

---------------------------------------------------------------------------
-- Free Creator Store models shown above the cards on the stands (key = card id).
-- If a model is missing, the stand still shows the card itself.
-- `height` in studs, `yaw` in degrees to turn the model so it faces forward.
---------------------------------------------------------------------------
Config.MODEL_HEIGHT = 9 -- bigger than a player, like in the big brainrot games
-- Found on the Creator Store on 2026-10-22. tools/import-from-pack.lua replaces them in the place
-- with the blocky models of the free "Brainrot Pack [150+]" (137461628889541), saved in
-- ServerStorage > AssetLibrary. id = 0: the model only exists in that library.
Config.ASSETS = {
	noobini = { id = 76207239035844 },
	lirili = { id = 77231614368559 },
	timcheese = { id = 104326039056736 },
	pipikiwi = { id = 94106203385238 },
	trippi = { id = 106304037616485 },
	boneca = { id = 125906339004688 },
	talpa = { id = 70838811468211 },
	patapim = { id = 100538198930997 },
	bananita = { id = 127564277646706 },
	chimpanzini = { id = 83732984780551 },
	ballerina = { id = 86783628613931 },
	tralalero = { id = 111854862176457 },
	cappuccino = { id = 130589530520250 },
	burbaloni = { id = 104208079210912 },
	orangutini = { id = 128360398522638 },
	tungtung = { id = 138151705692565 },
	odin = { id = 83607074504363 },
	bombombini = { id = 85695127778879 },
	girafa = { id = 139505277116681 },
	frigo = { id = 136392638607318 },
	bombardiro = { id = 111138597903728 },
	gangster = { id = 84339185393124 },
	glorbo = { id = 74148908205819 },
	espresso = { id = 97449230983933 },
	chicleteira = { id = 132760270613242 },
	lavaca = { id = 76127116347738 },
	tralaleritos = { id = 102735578731117 },
	strawberry = { id = 14964355116 },
	trictrac = { id = 97300319440209 },
	blueberrinni = { id = 93308616326000 },
	fluriflura = { id = 0 },
	svinino = { id = 0 },
	rhino = { id = 0 },
	cocofanto = { id = 0 },
	matteo = { id = 0 },
	garama = { id = 0 },
} :: { [string]: { id: number, height: number?, size: number?, yaw: number? } }

-- Free Creator Store models that decorate the plaza (same loading as the brainrots).
-- If one is missing, a simple shape built from parts takes its place.
-- `size` (instead of `height`) scales a flat model by its longest side.
Config.DECOR = {
	decor_fountain = { id = 11423259371, height = 9 },
	decor_stall = { id = 15147571772, height = 11 },
	decor_lamp = { id = 15472204631, height = 14 },
	decor_tree = { id = 580221169, height = 22 },
	decor_sakura = { id = 3725991689, height = 20 },
	decor_bench = { id = 23153972, height = 3.5 },
	decor_flowers = { id = 8344171779, height = 3 },
	decor_register = { id = 3559550517, height = 2.2 },
	decor_magnifier = { id = 11935186507, size = 3 },
} :: { [string]: { id: number, height: number?, size: number?, yaw: number? } }

---------------------------------------------------------------------------
-- Look of the world
---------------------------------------------------------------------------
-- Bright cyan cartoon skybox (images from the free Creator Store model 72835926026092)
Config.SKY = {
	SkyboxBk = "rbxassetid://18351376859",
	SkyboxDn = "rbxassetid://18351374919",
	SkyboxFt = "rbxassetid://18351376800",
	SkyboxLf = "rbxassetid://18351376469",
	SkyboxRt = "rbxassetid://18351376457",
	SkyboxUp = "rbxassetid://18351377189",
}

-- One bright color per plot, like the colored bases of the big simulators
Config.PLOT_COLORS = {
	Color3.fromRGB(235, 70, 70),
	Color3.fromRGB(60, 150, 255),
	Color3.fromRGB(255, 170, 40),
	Color3.fromRGB(170, 90, 255),
	Color3.fromRGB(50, 200, 120),
	Color3.fromRGB(255, 100, 190),
} :: { Color3 }

return Config
