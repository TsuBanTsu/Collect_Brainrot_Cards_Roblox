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
-- Owned cards are stored as "cardId|variantId", or "cardId|variantId|9.10.8.9"
-- once graded (the 4 scores). Identical cards stack under the same key.
---------------------------------------------------------------------------
function Config.cardKey(cardId: string, variantId: string, scores: { number }?): string
	if scores then
		return cardId .. "|" .. variantId .. "|" .. table.concat(scores, ".")
	end
	return cardId .. "|" .. variantId
end

-- Returns the card id, the variant id and the 4 scores (nil if the card isn't graded)
function Config.splitKey(key: string): (string, string, { number }?)
	local parts = string.split(key, "|")
	if #parts < 2 then
		return key, "normal", nil
	end
	local scores: { number }? = nil
	if parts[3] then
		local list = {}
		for _, score in string.split(parts[3], ".") do
			table.insert(list, tonumber(score) or 1)
		end
		scores = list
	end
	return parts[1], parts[2], scores
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

-- Same, for an owned card key (its grade included)
function Config.keyIncome(key: string): number
	local cardId, variantId = Config.splitKey(key)
	local grade = Config.keyGrade(key)
	return Config.cardIncome(cardId, variantId) * (if grade then grade.cash else 1)
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
Config.MODEL_HEIGHT = 5
-- Found on the Creator Store on 2026-10-22; no free model was found for the missing cards.
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
-- Anime-style skybox (images from the free Creator Store model 13107361022)
Config.SKY = {
	SkyboxBk = "rbxassetid://13107325341",
	SkyboxDn = "rbxassetid://13107329809",
	SkyboxFt = "rbxassetid://13107334845",
	SkyboxLf = "rbxassetid://13107337703",
	SkyboxRt = "rbxassetid://13107340396",
	SkyboxUp = "rbxassetid://13107344387",
}

-- Hand-painted textures (free Creator Store pack of MaterialVariants). They replace the
-- plain Roblox materials everywhere, terrain included: [Roblox material] = variant name and
-- how many studs one tile of the texture covers. Missing textures keep the plain material.
Config.MATERIAL_PACK = 13591987222
Config.MATERIAL_OVERRIDES = {
	Grass = { variant = "Grass", tile = 14 },
	Ground = { variant = "Dirt", tile = 12 },
	Rock = { variant = "Stone", tile = 24 },
	Sand = { variant = "Sand", tile = 12 },
	WoodPlanks = { variant = "Planks", tile = 8 },
	Wood = { variant = "Bark", tile = 6 },
	Cobblestone = { variant = "Cobblestone", tile = 10 },
	Brick = { variant = "Bricks", tile = 8 },
	Pavement = { variant = "Tiles", tile = 10 },
	Concrete = { variant = "Concrete", tile = 12 },
	Fabric = { variant = "Cloth", tile = 6 },
	Metal = { variant = "Iron", tile = 6 },
} :: { [string]: { variant: string, tile: number } }

return Config
