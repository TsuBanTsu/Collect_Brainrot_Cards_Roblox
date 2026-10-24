-- Buying packs (they go to the backpack) and opening them: rolls the rarity of each card with the pack's own odds (plus luck and
-- pity), picks the card, then rolls its variant (Holo, Rainbow, Gold or normal).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Weather = require(script.Parent.Weather)

local Packs = {}

local rng = Random.new()

export type Pull = { card: string, variant: string, oneIn: number, new: boolean }

-- Rarity ids of a pack, from the most common to the rarest
local function packRarities(pack: Config.Pack): { string }
	local list = {}
	for rarityId in pack.odds do
		table.insert(list, rarityId)
	end
	table.sort(list, function(a, b)
		return Config.RARITY[a].order < Config.RARITY[b].order
	end)
	return list
end

-- Luck multiplies the chances of every rarity above the pack's most common one.
-- `minOrder` (pity) removes the rarities below it.
local function rollRarity(pack: Config.Pack, luck: number, minOrder: number): string
	local rarities = packRarities(pack)
	local weights = {}
	local total = 0
	for index, rarityId in rarities do
		local weight = pack.odds[rarityId]
		if index > 1 then
			weight *= luck
		end
		if Config.RARITY[rarityId].order < minOrder then
			weight = 0
		end
		weights[rarityId] = weight
		total += weight
	end
	if total <= 0 then
		return rarities[#rarities]
	end
	local roll = rng:NextNumber() * total
	for _, rarityId in rarities do
		roll -= weights[rarityId]
		if roll <= 0 and weights[rarityId] > 0 then
			return rarityId
		end
	end
	return rarities[#rarities]
end

-- Rarest first: a card has a single variant, the rarest one rolled wins
local function rollVariant(shiny: number): string
	for _, variant in Config.VARIANTS do
		if rng:NextNumber() * 100 < variant.chance * shiny then
			return variant.id
		end
	end
	return "normal"
end

local function rollCard(pack: Config.Pack, rarityId: string): string
	local list = pack.cards[rarityId]
	return list[rng:NextInteger(1, #list)].id
end

-- Puts `count` packs in the backpack. Returns true, or false and a reason
function Packs.buy(player: Player, packId: string, count: number): (boolean, string?)
	local profile = PlayerData.get(player)
	local pack = Config.PACK[packId]
	if not profile or not pack then
		return false, "Unknown pack"
	end
	if profile.Cash < pack.price * count then
		return false, "Not enough Cash"
	end
	if not PlayerData.hasRoom(profile, count) then
		return false, "Your backpack is full: sell some cards or get a bigger backpack"
	end
	profile.Cash -= pack.price * count
	profile.Packs[packId] = (profile.Packs[packId] or 0) + count
	PlayerData.sync(player)
	return true
end

-- Opens a pack from the backpack. Returns the pulls, or nil and a reason
function Packs.open(player: Player, packId: string): ({ Pull }?, string?)
	local profile = PlayerData.get(player)
	local pack = Config.PACK[packId]
	if not profile or not pack then
		return nil, "Unknown pack"
	end
	if (profile.Packs[packId] or 0) < 1 then
		return nil, "You don't have this pack: buy it at the Shop"
	end
	-- The pack frees its own slot, its cards take the others
	if not PlayerData.hasRoom(profile, Config.CARDS_PER_PACK - 1) then
		return nil, "Your backpack is full: sell some cards or get a bigger backpack"
	end
	PlayerData.removePack(profile, packId, 1)
	profile.PacksOpened += 1

	local buffs = Weather.buffs()
	local pityOrder = Config.pityRarity(packId).order
	local pityReady = (profile.Pity[packId] or 0) >= Config.PITY_PACKS - 1
	local gotPityRarity = false

	local pulls: { Pull } = {}
	for index = 1, Config.CARDS_PER_PACK do
		-- The pity guarantee applies to the last card of the pack
		local minOrder = if pityReady and index == Config.CARDS_PER_PACK and not gotPityRarity then pityOrder else 0
		local rarityId = rollRarity(pack, buffs.luck * (1 + PlayerData.bonus(profile, "luck")), minOrder)
		if Config.RARITY[rarityId].order >= pityOrder then
			gotPityRarity = true
		end
		local cardId = rollCard(pack, rarityId)
		local variantId = rollVariant(buffs.shiny * (1 + PlayerData.bonus(profile, "shiny")))
		local isNew = not profile.Index[cardId]
		PlayerData.addCard(profile, cardId, variantId)
		table.insert(pulls, { card = cardId, variant = variantId, oneIn = Config.oneIn(cardId, variantId), new = isNew })
	end
	profile.Pity[packId] = if gotPityRarity then 0 else (profile.Pity[packId] or 0) + 1

	PlayerData.sync(player)
	return pulls
end

return Packs
