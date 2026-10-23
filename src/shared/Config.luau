-- Every game setting lives here: rarities, variants, packs, cards, weather, stands.
-- Change the numbers here to rebalance the game; nothing else needs to change.

local Config = {}

---------------------------------------------------------------------------
-- Rarities, from the most common to the rarest
---------------------------------------------------------------------------
export type Rarity = { id: string, name: string, order: number, color: Color3, cash: number, accent: Color3? }

-- One clearly different color per rarity. From Secret up, `accent` is a second color: the
-- card's border is a gradient between the two that turns slowly (Infinity: the whole rainbow).
Config.RARITIES = {
	{ id = "common", name = "Common", order = 1, color = Color3.fromRGB(175, 180, 190), cash = 1 },
	{ id = "uncommon", name = "Uncommon", order = 2, color = Color3.fromRGB(80, 210, 90), cash = 2 },
	{ id = "rare", name = "Rare", order = 3, color = Color3.fromRGB(50, 135, 255), cash = 5 },
	{ id = "epic", name = "Epic", order = 4, color = Color3.fromRGB(165, 75, 255), cash = 25 },
	{ id = "legendary", name = "Legendary", order = 5, color = Color3.fromRGB(255, 165, 20), cash = 120 },
	{ id = "mythic", name = "Mythic", order = 6, color = Color3.fromRGB(255, 55, 75), cash = 600 },
	{ id = "secret", name = "Secret", order = 7, color = Color3.fromRGB(245, 245, 255), accent = Color3.fromRGB(60, 60, 80), cash = 3000 },
	{ id = "divine", name = "Divine", order = 8, color = Color3.fromRGB(255, 105, 200), accent = Color3.fromRGB(255, 235, 250), cash = 15000 },
	{ id = "god", name = "Brainrot God", order = 9, color = Color3.fromRGB(255, 235, 60), accent = Color3.fromRGB(255, 120, 30), cash = 75000 },
	{ id = "og", name = "OG", order = 10, color = Color3.fromRGB(30, 220, 190), accent = Color3.fromRGB(20, 70, 90), cash = 375000 },
	{ id = "celestial", name = "Celestial", order = 11, color = Color3.fromRGB(110, 225, 255), accent = Color3.fromRGB(255, 255, 255), cash = 1875000 },
	{ id = "eternal", name = "Eternal", order = 12, color = Color3.fromRGB(110, 90, 255), accent = Color3.fromRGB(255, 120, 220), cash = 9375000 },
	{ id = "infinity", name = "Infinity", order = 13, color = Color3.fromRGB(60, 255, 150), accent = Color3.fromRGB(255, 80, 80), cash = 46875000 },
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
-- `model`: "Folder/Model name" of its blocky model in the free "Brainrot Pack [150+]"
-- (tools/import-from-pack.lua copies it into ServerStorage > AssetLibrary)
export type Card = { id: string, name: string, rarity: string, pack: string, model: string? }

Config.CARDS = {} :: { [string]: Card }

---------------------------------------------------------------------------
-- Packs. Each pack has its own odds (percent per card, total 100):
-- low rarities fade out and rarer ones appear as packs get more expensive.
-- `cash` multiplies the income of the pack's cards so each new pack is worth it.
-- Prices are set so that a player who plays actively reaches each pack in about:
-- Italian 4 min, Chaos 40 min, Sky 2 h 10, Galaxy 6 h 30, Hacker (the last one) 25 h
-- (tools/balance-sim.py, without offline income, towers, weather or Index bonus, which all
-- speed it up a bit). Packs 1-13 have the "Normal" brainrots, then come the Diamond, Lava,
-- Galaxy and Hacker versions.
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
	cards: { [string]: { { id: string, name: string, model: string? } } },
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
			common = { { id = "noobini", name = "Noobini Pizzanini" }, { id = "lirili", name = "Lirili Larila", model = "Normal/Lirili Larila" }, { id = "timcheese", name = "Tim Cheese", model = "Normal/Tim Cheese" } },
			uncommon = { { id = "fluriflura", name = "Fluriflura", model = "Normal/Fluri Flura" }, { id = "pipikiwi", name = "Pipi Kiwi", model = "Normal/Pipi Kiwi" } },
			rare = { { id = "trippi", name = "Trippi Troppi", model = "Normal/Trippi Troppi" } },
			epic = { { id = "boneca", name = "Boneca Ambalabu", model = "Normal/Boneca Ambalabu" } },
		},
	},
	{
		id = "beach",
		order = 2,
		name = "Beach Pack",
		price = 8200,
		cash = 2.9,
		color = Color3.fromRGB(255, 215, 110),
		odds = { common = 55, uncommon = 30, rare = 12, epic = 2.8, legendary = 0.2 },
		cards = {
			common = { { id = "pipipotato", name = "Pipi Potato", model = "Normal/Pipi Potato" }, { id = "bananadancana", name = "Banana Dancana", model = "Normal/Banana Dancana" } },
			uncommon = { { id = "bambinicrostini", name = "Bambini Crostini", model = "Normal/Bambini Crostini" }, { id = "avocadiniguffo", name = "Avocadini Guffo", model = "Normal/Avocadini Guffo" } },
			rare = { { id = "swagsoda", name = "Swag Soda", model = "Normal/Swag Soda" } },
			epic = { { id = "chillinchili", name = "Chillin Chili", model = "Normal/Chillin Chili" } },
			legendary = { { id = "bananinikittini", name = "Bananini Kittini", model = "Normal/Bananini Kittini" } },
		},
	},
	{
		id = "italian",
		order = 3,
		name = "Italian Pack",
		price = 22000,
		cash = 8,
		color = Color3.fromRGB(80, 170, 255),
		odds = { common = 30, uncommon = 40, rare = 25, epic = 4.5, legendary = 0.5 },
		cards = {
			common = { { id = "talpa", name = "Talpa di Fero", model = "Normal/Talpa Di Fero" }, { id = "svinino", name = "Svinino Bombondino", model = "Normal/Svinina Bombardino" } },
			uncommon = { { id = "patapim", name = "Brr Brr Patapim", model = "Normal/Brr Brr Patapim" }, { id = "bananita", name = "Bananita Dolphinita", model = "Normal/Bananita Dolphinita" } },
			rare = { { id = "chimpanzini", name = "Chimpanzini Bananini", model = "Normal/Chimpanzini Bananini" } },
			epic = { { id = "ballerina", name = "Ballerina Cappuccina", model = "Normal/Ballerina Cappuccina" } },
			legendary = { { id = "tralalero", name = "Tralalero Tralala", model = "Normal/Tralalero Tralala" } },
		},
	},
	{
		id = "jungle",
		order = 4,
		name = "Jungle Pack",
		price = 84000,
		cash = 9.5,
		color = Color3.fromRGB(70, 180, 80),
		odds = { uncommon = 55, rare = 30, epic = 12, legendary = 2.8, mythic = 0.2 },
		cards = {
			uncommon = { { id = "zibrazubrazibralini", name = "Zibra Zubra Zibralini", model = "Normal/Zibra Zubra Zibralini" }, { id = "pandaccinibananini", name = "Pandaccini Bananini", model = "Normal/Pandaccini Bananini" } },
			rare = { { id = "tigroligrefrutonni", name = "Tigroligre Frutonni", model = "Normal/Tigroligre Frutonni" }, { id = "agarrinilapallini", name = "Agarrini La Pallini", model = "Normal/Agarrini La Pallini" } },
			epic = { { id = "gorillowatermelondrillo", name = "Gorillo Watermelondrillo", model = "Normal/Gorillo Watermelondrillo" } },
			legendary = { { id = "bobritobandito", name = "Bobrito Bandito", model = "Normal/Bobrito Bandito" } },
			mythic = { { id = "trippitroppitroppatrippa", name = "Trippi Troppi Troppa Trippa", model = "Normal/Trippi Troppi Troppa Trippa" } },
		},
	},
	{
		id = "kitty",
		order = 5,
		name = "Kitty Pack",
		price = 470000,
		cash = 20,
		color = Color3.fromRGB(255, 160, 205),
		odds = { uncommon = 42, rare = 38, epic = 15.5, legendary = 4, mythic = 0.5 },
		cards = {
			uncommon = { { id = "nyanninicattalini", name = "Nyannini Cattalini", model = "Normal/Nyannini Cattalini" }, { id = "smurfogatto", name = "Smurfo Gatto", model = "Normal/Smurfo Gatto" } },
			rare = { { id = "brribrribicusdicus", name = "Brri Brri Bicus Dicus", model = "Normal/Brri Brri Bicus Dicus" } },
			epic = { { id = "ballerinolololo", name = "Ballerino Lololo", model = "Normal/Ballerino Lololo" } },
			legendary = { { id = "tralalitatralala", name = "Tralalita Tralala", model = "Normal/Tralalita Tralala" } },
			mythic = { { id = "strawberrelliflamingelli", name = "Strawberrelli Flamingelli", model = "Normal/Strawberrelli Flamingelli" } },
		},
	},
	{
		id = "chaos",
		order = 6,
		name = "Chaos Pack",
		price = 2900000,
		cash = 60,
		color = Color3.fromRGB(255, 110, 70),
		odds = { uncommon = 35, rare = 45, epic = 16, legendary = 3.5, mythic = 0.5 },
		cards = {
			uncommon = { { id = "trictrac", name = "Tric Trac Baraboom", model = "Normal/Tric Trac Barabum" }, { id = "rhino", name = "Rhino Toasterino", model = "Normal/Rhino Toasterino" } },
			rare = { { id = "cappuccino", name = "Cappuccino Assassino", model = "Normal/Cappuccino Assassino" }, { id = "burbaloni", name = "Burbaloni Luliloli", model = "Normal/Burbaloni Luliloli" } },
			epic = { { id = "orangutini", name = "Orangutini Ananassini", model = "Normal/Orangutini Ananassini" } },
			legendary = { { id = "tungtung", name = "Tung Tung Tung Sahur" }, { id = "odin", name = "Odin Din Din Dun", model = "Normal/Odin Din Din Dun" } },
			mythic = { { id = "matteo", name = "Matteo", model = "Normal/Matteo" } },
		},
	},
	{
		id = "desert",
		order = 7,
		name = "Desert Pack",
		price = 8500000,
		cash = 55,
		color = Color3.fromRGB(230, 185, 100),
		odds = { rare = 55, epic = 30, legendary = 12, mythic = 2.8, secret = 0.2 },
		cards = {
			rare = { { id = "cactohipopotamo", name = "Cacto Hipopotamo", model = "Normal/Cacto Hipopotamo" }, { id = "lionelcactuseli", name = "Lionel Cactuseli", model = "Normal/Lionel Cactuseli" } },
			epic = { { id = "quesadillacrocodila", name = "Quesadilla Crocodila", model = "Normal/Quesadilla Crocodila" }, { id = "cachorritomelonito", name = "Cachorrito Melonito", model = "Normal/Cachorrito Melonito" } },
			legendary = { { id = "karkerkarkurkur", name = "Karkerkar Kurkur", model = "Normal/Karkerkar Kurkur" } },
			mythic = { { id = "pakrahmatmatina", name = "Pakrahmatmatina", model = "Normal/Pakrahmatmatina" } },
			secret = { { id = "pakrahmatmamat", name = "Pakrahmatmamat", model = "Normal/Pakrahmatmamat" } },
		},
	},
	{
		id = "ocean",
		order = 8,
		name = "Ocean Pack",
		price = 4.2e7,
		cash = 110,
		color = Color3.fromRGB(40, 130, 225),
		odds = { rare = 42, epic = 38, legendary = 15.5, mythic = 4, secret = 0.5 },
		cards = {
			rare = { { id = "chefcrabracadabra", name = "Chef Crabracadabra", model = "Normal/Chef Crabracadabra" }, { id = "torrtuginnidragonfrutini", name = "Torrtuginni Dragonfrutini", model = "Normal/Torrtuginni Dragonfrutini" } },
			epic = { { id = "orcaleroorcala", name = "Orcalero Orcala", model = "Normal/Orcalero Orcala" } },
			legendary = { { id = "trulimerotrulicina", name = "Trulimero Trulicina", model = "Normal/Trulimero Trulicina" } },
			mythic = { { id = "tralaledon", name = "Tralaledon", model = "Normal/Tralaledon" } },
			secret = { { id = "tirilikalikatirilikalako", name = "Tirilikalika Tirilikalako", model = "Normal/Tirilikalika Tirilikalako" } },
		},
	},
	{
		id = "sky",
		order = 9,
		name = "Sky Pack",
		price = 1.6e8,
		cash = 500,
		color = Color3.fromRGB(120, 220, 255),
		odds = { rare = 50, epic = 35, legendary = 12, mythic = 2.8, secret = 0.2 },
		cards = {
			rare = { { id = "bombombini", name = "Bombombini Gusini", model = "Normal/Bombombini Gusini" }, { id = "girafa", name = "Girafa Celestre", model = "Normal/Girafa Celeste" } },
			epic = { { id = "frigo", name = "Frigo Camelo", model = "Normal/Frigo Camelo" }, { id = "cocofanto", name = "Cocofanto Elefanto", model = "Normal/Cocofanto Elefanto" } },
			legendary = { { id = "bombardiro", name = "Bombardiro Crocodilo", model = "Normal/Bombardiro Crocodilo" } },
			mythic = { { id = "gangster", name = "Gangster Footera", model = "Normal/Gangster Footera" } },
			secret = { { id = "lavaca", name = "La Vaca Saturno Saturnita", model = "Normal/La Vacca Saturno Saturnita" } },
		},
	},
	{
		id = "school",
		order = 10,
		name = "School Pack",
		price = 4.7e8,
		cash = 320,
		color = Color3.fromRGB(240, 125, 60),
		odds = { epic = 55, legendary = 30, mythic = 12, secret = 2.8, divine = 0.2 },
		cards = {
			epic = { { id = "noomyexamen", name = "Noo My Examen", model = "Normal/Noo My Examen" }, { id = "yessmyexamen", name = "Yess My Examen", model = "Normal/Yess My Examen" } },
			legendary = { { id = "esoksekolah", name = "Esok Sekolah", model = "Normal/Esok Sekolah" }, { id = "sixseven", name = "Six Seven", model = "Normal/Six Seven" } },
			mythic = { { id = "worl", name = "W Or L", model = "Normal/W Or L" } },
			secret = { { id = "jobjobjobsahur", name = "Job Job Job Sahur", model = "Normal/Job Job Job Sahur" } },
			divine = { { id = "tatatatasahur", name = "Ta Ta Ta Ta Sahur", model = "Normal/Ta Ta Ta Ta Sahur" } },
		},
	},
	{
		id = "dragon",
		order = 11,
		name = "Dragon Pack",
		price = 2.4e9,
		cash = 690,
		color = Color3.fromRGB(210, 45, 45),
		odds = { epic = 42, legendary = 38, mythic = 15.5, secret = 4, divine = 0.5 },
		cards = {
			epic = { { id = "cavallovirtuoso", name = "Cavallo Virtuoso", model = "Normal/Cavallo Virtuoso" }, { id = "lerulerulerule", name = "Lerulerulerule", model = "Normal/Lerulerulerule" } },
			legendary = { { id = "madudung", name = "Madudung", model = "Normal/Madudung" } },
			mythic = { { id = "triplitotralaleritos", name = "Triplito Tralaleritos", model = "Normal/Triplito Tralaleritos" } },
			secret = { { id = "1x1x1x1", name = "1x1x1x1", model = "Normal/1x1x1x1" } },
			divine = { { id = "dragoncannelloni", name = "Dragon Cannelloni", model = "Normal/Dragon Cannelloni" } },
		},
	},
	{
		id = "galaxy",
		order = 12,
		name = "Galaxy Pack",
		price = 5.8e9,
		cash = 4000,
		color = Color3.fromRGB(170, 90, 255),
		odds = { epic = 55, legendary = 33, mythic = 10, secret = 1.9, divine = 0.1 },
		cards = {
			epic = { { id = "glorbo", name = "Glorbo Fruttodrillo", model = "Normal/Glorbo Fruttodrillo" }, { id = "blueberrinni", name = "Blueberrinni Octopussini", model = "Normal/Blueberrinni Octopusini" } },
			legendary = { { id = "espresso", name = "Espresso Signora", model = "Normal/Espresso Signora" }, { id = "chicleteira", name = "Chicleteira Bicicleteira", model = "Normal/Chicleteira Bicicleteira" } },
			mythic = { { id = "tralaleritos", name = "Los Tralaleritos", model = "Normal/Los Tralaleritos" } },
			secret = { { id = "garama", name = "Garama and Madundung", model = "Normal/Garamararam" } },
			divine = { { id = "strawberry", name = "Strawberry Elephant", model = "Normal/Strawberry Elephant" } },
		},
	},
	{
		id = "mystic",
		order = 13,
		name = "Mystic Pack",
		price = 1.8e10,
		cash = 2000,
		color = Color3.fromRGB(130, 60, 200),
		odds = { legendary = 55, mythic = 30, secret = 12, divine = 2.8, god = 0.2 },
		cards = {
			legendary = { { id = "chicleteirinabicicleteirina", name = "Chicleteirina Bicicleteirina", model = "Normal/Chicleteirina Bicicleteirina" }, { id = "ganganzellitrulala", name = "Ganganzelli Trulala", model = "Normal/Ganganzelli Trulala" } },
			mythic = { { id = "illuminatotriangolo", name = "Illuminato Triangolo", model = "Normal/Illuminato Triangolo" } },
			secret = { { id = "lagrandecombinasion", name = "La Grande Combinasion", model = "Normal/La Grande Combinasion" } },
			divine = { { id = "meowl", name = "Meowl", model = "Normal/Meowl" } },
			god = { { id = "pothotspot", name = "Pot Hotspot", model = "Normal/Pot Hotspot" } },
		},
	},
	{
		id = "crystal",
		order = 14,
		name = "Crystal Pack",
		price = 2.9e10,
		cash = 4400,
		color = Color3.fromRGB(170, 230, 255),
		odds = { legendary = 42, mythic = 38, secret = 15.5, divine = 4, god = 0.5 },
		cards = {
			legendary = { { id = "diamond_timcheese", name = "Diamond Tim Cheese", model = "Diamante/Diamond Tim Cheese" }, { id = "diamond_trippi", name = "Diamond Trippi Troppi", model = "Diamante/Diamond Trippi Troppi" } },
			mythic = { { id = "diamond_bananadancana", name = "Diamond Banana Dancana", model = "Diamante/Diamond Banana Dancana" }, { id = "diamond_swagsoda", name = "Diamond Swag Soda", model = "Diamante/Diamond Swag Soda" } },
			secret = { { id = "diamond_talpa", name = "Diamond Talpa di Fero", model = "Diamante/Diamond Talpa Di Fero" } },
			divine = { { id = "diamond_chimpanzini", name = "Diamond Chimpanzini Bananini", model = "Diamante/Diamond Chimpanzini Bananini" } },
			god = { { id = "diamond_zibrazubrazibralini", name = "Diamond Zibra Zubra Zibralini", model = "Diamante/Diamond Zibra Zubra Zibralini" } },
		},
	},
	{
		id = "gem",
		order = 15,
		name = "Gem Pack",
		price = 1.1e11,
		cash = 8200,
		color = Color3.fromRGB(100, 200, 255),
		odds = { legendary = 32, mythic = 40, secret = 20, divine = 6.5, god = 1.5 },
		cards = {
			legendary = { { id = "diamond_agarrinilapallini", name = "Diamond Agarrini La Pallini", model = "Diamante/Diamond Agarrini La Pallini" }, { id = "diamond_trippitroppitroppatrippa", name = "Diamond Trippi Troppi Troppa Trippa", model = "Diamante/Diamond Trippi Troppi Troppa Trippa" } },
			mythic = { { id = "diamond_brribrribicusdicus", name = "Diamond Brri Brri Bicus Dicus", model = "Diamante/Diamond Brri Brri Bicus Dicus" }, { id = "diamond_strawberrelliflamingelli", name = "Diamond Strawberrelli Flamingelli", model = "Diamante/Diamond Strawberrelli Flamingelli" } },
			secret = { { id = "diamond_cappuccino", name = "Diamond Cappuccino Assassino", model = "Diamante/Diamond Cappuccino Assassino" } },
			divine = { { id = "diamond_tungtung", name = "Diamond Tung Tung Tung Sahur", model = "Diamante/Diamond Tung Sahur" } },
			god = { { id = "diamond_cactohipopotamo", name = "Diamond Cacto Hipopotamo", model = "Diamante/Diamond Cacto Hipopotamo" } },
		},
	},
	{
		id = "prism",
		order = 16,
		name = "Prism Pack",
		price = 2.2e11,
		cash = 13000,
		color = Color3.fromRGB(160, 175, 255),
		odds = { mythic = 55, secret = 30, divine = 12, god = 2.8, og = 0.2 },
		cards = {
			mythic = { { id = "diamond_karkerkarkurkur", name = "Diamond Karkerkar Kurkur", model = "Diamante/Diamond Karkerkar Kurkur" }, { id = "diamond_chefcrabracadabra", name = "Diamond Chef Crabracadabra", model = "Diamante/Diamond Chef Crabracadabra" } },
			secret = { { id = "diamond_trulimerotrulicina", name = "Diamond Trulimero Trulicina", model = "Diamante/Diamond Trulimero Trulicina" }, { id = "diamond_bombombini", name = "Diamond Bombombini Gusini", model = "Diamante/Diamond Bombombini Gusini" } },
			divine = { { id = "diamond_cocofanto", name = "Diamond Cocofanto Elefanto", model = "Diamante/Diamond Cocofanto Elefanto" } },
			god = { { id = "diamond_lavaca", name = "Diamond La Vaca Saturno Saturnita", model = "Diamante/Diamond La Vacca Saturno Saturnita" } },
			og = { { id = "diamond_esoksekolah", name = "Diamond Esok Sekolah", model = "Diamante/Diamond Esok Sekolah" } },
		},
	},
	{
		id = "diamond",
		order = 17,
		name = "Diamond Pack",
		price = 7.7e11,
		cash = 29000,
		color = Color3.fromRGB(210, 245, 255),
		odds = { mythic = 42, secret = 38, divine = 15.5, god = 4, og = 0.5 },
		cards = {
			mythic = { { id = "diamond_jobjobjobsahur", name = "Diamond Job Job Job Sahur", model = "Diamante/Diamond Job Job Job Sahur" }, { id = "diamond_lerulerulerule", name = "Diamond Lerulerulerule", model = "Diamante/Diamond Lerulerulerule" } },
			secret = { { id = "diamond_dragoncannelloni", name = "Diamond Dragon Cannelloni", model = "Diamante/Diamond Dragon Cannelloni" }, { id = "diamond_espresso", name = "Diamond Espresso Signora", model = "Diamante/Diamond Espresso Signora" } },
			divine = { { id = "diamond_garama", name = "Diamond Garama and Madundung", model = "Diamante/Diamond Garamararam" } },
			god = { { id = "diamond_ganganzellitrulala", name = "Diamond Ganganzelli Trulala", model = "Diamante/Diamond Ganganzelli Trulala" } },
			og = { { id = "diamond_meowl", name = "Diamond Meowl", model = "Diamante/Diamond Meowl" } },
		},
	},
	{
		id = "ember",
		order = 18,
		name = "Ember Pack",
		price = 6e12,
		cash = 53000,
		color = Color3.fromRGB(255, 150, 60),
		odds = { mythic = 32, secret = 40, divine = 20, god = 6.5, og = 1.5 },
		cards = {
			mythic = { { id = "lava_fluriflura", name = "Lava Fluriflura", model = "Lava/Lava Fluri Flura" }, { id = "lava_boneca", name = "Lava Boneca Ambalabu", model = "Lava/Lava Boneca Ambalabu" } },
			secret = { { id = "lava_bambinicrostini", name = "Lava Bambini Crostini", model = "Lava/Lava Bambini Crostini" }, { id = "lava_chillinchili", name = "Lava Chillin Chili", model = "Lava/Lava Chillin Chili" } },
			divine = { { id = "lava_svinino", name = "Lava Svinino Bombondino", model = "Lava/Lava Svinina Bombardino" } },
			god = { { id = "lava_chimpanzini", name = "Lava Chimpanzini Bananini", model = "Lava/Lava Chimpanzini Bananini" } },
			og = { { id = "lava_zibrazubrazibralini", name = "Lava Zibra Zubra Zibralini", model = "Lava/Lava Zibra Zubra Zibralini" } },
		},
	},
	{
		id = "magma",
		order = 19,
		name = "Magma Pack",
		price = 9.6e12,
		cash = 87000,
		color = Color3.fromRGB(235, 90, 30),
		odds = { secret = 55, divine = 30, god = 12, og = 2.8, celestial = 0.2 },
		cards = {
			secret = { { id = "lava_gorillowatermelondrillo", name = "Lava Gorillo Watermelondrillo", model = "Lava/Lava Gorillo Watermelondrillo" }, { id = "lava_nyanninicattalini", name = "Lava Nyannini Cattalini", model = "Lava/Lava Nyannini Cattalini" } },
			divine = { { id = "lava_ballerinolololo", name = "Lava Ballerino Lololo", model = "Lava/Lava Ballerino Lololo" }, { id = "lava_trictrac", name = "Lava Tric Trac Baraboom", model = "Lava/Lava Tric Trac Barabum" } },
			god = { { id = "lava_burbaloni", name = "Lava Burbaloni Luliloli", model = "Lava/Lava Burbaloni Luliloli" } },
			og = { { id = "lava_odin", name = "Lava Odin Din Din Dun", model = "Lava/Lava Odin Din Din Dun" } },
			celestial = { { id = "lava_lionelcactuseli", name = "Lava Lionel Cactuseli", model = "Lava/Lava Lioneo Cactuseli" } },
		},
	},
	{
		id = "volcano",
		order = 20,
		name = "Volcano Pack",
		price = 3.8e13,
		cash = 190000,
		color = Color3.fromRGB(180, 45, 20),
		odds = { secret = 42, divine = 38, god = 15.5, og = 4, celestial = 0.5 },
		cards = {
			secret = { { id = "lava_karkerkarkurkur", name = "Lava Karkerkar Kurkur", model = "Lava/Lava Karkerkar Kurkur" }, { id = "lava_chefcrabracadabra", name = "Lava Chef Crabracadabra", model = "Lava/Lava Chef Crabracadabra" } },
			divine = { { id = "lava_tralaledon", name = "Lava Tralaledon", model = "Lava/Lava Tralaledon" }, { id = "lava_girafa", name = "Lava Girafa Celestre", model = "Lava/Lava Girafa Celeste" } },
			god = { { id = "lava_bombardiro", name = "Lava Bombardiro Crocodilo", model = "Lava/Lava Bombardiro Crocodilo" } },
			og = { { id = "lava_noomyexamen", name = "Lava Noo My Examen", model = "Lava/Lava Noo My Examen" } },
			celestial = { { id = "lava_sixseven", name = "Lava Six Seven", model = "Lava/Lava Six Seven" } },
		},
	},
	{
		id = "lava",
		order = 21,
		name = "Lava Pack",
		price = 1.9e14,
		cash = 350000,
		color = Color3.fromRGB(255, 95, 0),
		odds = { secret = 32, divine = 40, god = 20, og = 6.5, celestial = 1.5 },
		cards = {
			secret = { { id = "lava_tatatatasahur", name = "Lava Ta Ta Ta Ta Sahur", model = "Lava/Lava Ta Ta Ta Ta Sahur" }, { id = "lava_madudung", name = "Lava Madudung", model = "Lava/Lava Madudung" } },
			divine = { { id = "lava_dragoncannelloni", name = "Lava Dragon Cannelloni", model = "Lava/Lava Dragon Cannelloni" }, { id = "lava_espresso", name = "Lava Espresso Signora", model = "Lava/Lava Espresso Signora" } },
			god = { { id = "lava_strawberry", name = "Lava Strawberry Elephant", model = "Lava/Lava Strawberry Elephant" } },
			og = { { id = "lava_illuminatotriangolo", name = "Lava Illuminato Triangolo", model = "Lava/Lava Illuminato Triangolo" } },
			celestial = { { id = "lava_pothotspot", name = "Lava Pot Hotspot", model = "Lava/Lava Pot Hotspot" } },
		},
	},
	{
		id = "nebula",
		order = 22,
		name = "Nebula Pack",
		price = 7e14,
		cash = 570000,
		color = Color3.fromRGB(200, 100, 255),
		odds = { divine = 55, god = 30, og = 12, celestial = 2.8, eternal = 0.2 },
		cards = {
			divine = { { id = "galaxy_pipikiwi", name = "Galaxy Pipi Kiwi", model = "Galaxia/Galaxy Pipi Kiwi" }, { id = "galaxy_pipipotato", name = "Galaxy Pipi Potato", model = "Galaxia/Galaxy Pipi Potato" } },
			god = { { id = "galaxy_avocadiniguffo", name = "Galaxy Avocadini Guffo", model = "Galaxia/Galaxy Avocadini Guffo" }, { id = "galaxy_bananinikittini", name = "Galaxy Bananini Kittini", model = "Galaxia/Galaxy Bananini Kittini" } },
			og = { { id = "galaxy_patapim", name = "Galaxy Brr Brr Patapim", model = "Galaxia/Galaxy Brr Brr Patapim" } },
			celestial = { { id = "galaxy_ballerina", name = "Galaxy Ballerina Cappuccina", model = "Galaxia/Galaxy Ballerina Cappuccina" } },
			eternal = { { id = "galaxy_pandaccinibananini", name = "Galaxy Pandaccini Bananini", model = "Galaxia/Galaxy Pandaccini Bananini" } },
		},
	},
	{
		id = "comet",
		order = 23,
		name = "Comet Pack",
		price = 1.5e15,
		cash = 1200000,
		color = Color3.fromRGB(120, 140, 255),
		odds = { divine = 42, god = 38, og = 15.5, celestial = 4, eternal = 0.5 },
		cards = {
			divine = { { id = "galaxy_gorillowatermelondrillo", name = "Galaxy Gorillo Watermelondrillo", model = "Galaxia/Galaxy Gorillo Watermelondrillo" }, { id = "galaxy_nyanninicattalini", name = "Galaxy Nyannini Cattalini", model = "Galaxia/Galaxy Nyannini Cattalini" } },
			god = { { id = "galaxy_tralalitatralala", name = "Galaxy Tralalita Tralala", model = "Galaxia/Galaxy Tralalita Tralala" }, { id = "galaxy_rhino", name = "Galaxy Rhino Toasterino", model = "Galaxia/Galaxy Rhino Toasterino" } },
			og = { { id = "galaxy_orangutini", name = "Galaxy Orangutini Ananassini", model = "Galaxia/Galaxy Orangutini Ananassini" } },
			celestial = { { id = "galaxy_matteo", name = "Galaxy Matteo", model = "Galaxia/Galaxy Matteo" } },
			eternal = { { id = "galaxy_quesadillacrocodila", name = "Galaxy Quesadilla Crocodila", model = "Galaxia/Galaxy Quesadilla Crocodila" } },
		},
	},
	{
		id = "supernova",
		order = 24,
		name = "Supernova Pack",
		price = 4.5e15,
		cash = 2300000,
		color = Color3.fromRGB(255, 120, 255),
		odds = { divine = 32, god = 40, og = 20, celestial = 6.5, eternal = 1.5 },
		cards = {
			divine = { { id = "galaxy_pakrahmatmatina", name = "Galaxy Pakrahmatmatina", model = "Galaxia/Galaxy Pakrahmatmatina" }, { id = "galaxy_torrtuginnidragonfrutini", name = "Galaxy Torrtuginni Dragonfrutini", model = "Galaxia/Galaxy Torrtuginni Dragonfrutini" } },
			god = { { id = "galaxy_tralaledon", name = "Galaxy Tralaledon", model = "Galaxia/Galaxy Tralaledon" }, { id = "galaxy_girafa", name = "Galaxy Girafa Celestre", model = "Galaxia/Galaxy Girafa Celeste" } },
			og = { { id = "galaxy_gangster", name = "Galaxy Gangster Footera", model = "Galaxia/Galaxy Gangster Footera" } },
			celestial = { { id = "galaxy_yessmyexamen", name = "Galaxy Yess My Examen", model = "Galaxia/Galaxy Yess My Examen" } },
			eternal = { { id = "galaxy_worl", name = "Galaxy W Or L", model = "Galaxia/Galaxy W Or L" } },
		},
	},
	{
		id = "cosmos",
		order = 25,
		name = "Cosmos Pack",
		price = 3.7e16,
		cash = 3700000,
		color = Color3.fromRGB(90, 50, 170),
		odds = { god = 55, og = 30, celestial = 12, eternal = 2.8, infinity = 0.2 },
		cards = {
			god = { { id = "galaxy_cavallovirtuoso", name = "Galaxy Cavallo Virtuoso", model = "Galaxia/Galaxy Cavallo Virtuoso" }, { id = "galaxy_triplitotralaleritos", name = "Galaxy Triplito Tralaleritos", model = "Galaxia/Galaxy Triplito Tralaleritos" } },
			og = { { id = "galaxy_glorbo", name = "Galaxy Glorbo Fruttodrillo", model = "Galaxia/Galaxy Glorbo Fruttodrillo" }, { id = "galaxy_chicleteira", name = "Galaxy Chicleteira Bicicleteira", model = "Galaxia/Galaxy Chicleteira Bicicleteira" } },
			celestial = { { id = "galaxy_strawberry", name = "Galaxy Strawberry Elephant", model = "Galaxia/Galaxy Strawberry Elephant" } },
			eternal = { { id = "galaxy_illuminatotriangolo", name = "Galaxy Illuminato Triangolo", model = "Galaxia/Galaxy Illuminato Triangolo" } },
			infinity = { { id = "galaxy_pothotspot", name = "Galaxy Pot Hotspot", model = "Galaxia/Galaxy Pot Hotspot" } },
		},
	},
	{
		id = "glitch",
		order = 26,
		name = "Glitch Pack",
		price = 1.1e17,
		cash = 8100000,
		color = Color3.fromRGB(0, 255, 130),
		odds = { god = 42, og = 38, celestial = 15.5, eternal = 4, infinity = 0.5 },
		cards = {
			god = { { id = "hacker_pipikiwi", name = "Hacker Pipi Kiwi", model = "Hacker/Hacker Pipi Kiwi" }, { id = "hacker_boneca", name = "Hacker Boneca Ambalabu", model = "Hacker/Hacker Boneca Ambalabu" } },
			og = { { id = "hacker_bambinicrostini", name = "Hacker Bambini Crostini", model = "Hacker/Hacker Bambini Crostini" }, { id = "hacker_swagsoda", name = "Hacker Swag Soda", model = "Hacker/Hacker Swag Soda" } },
			celestial = { { id = "hacker_talpa", name = "Hacker Talpa di Fero", model = "Hacker/Hacker Talpa Di Fero" } },
			eternal = { { id = "hacker_patapim", name = "Hacker Brr Brr Patapim", model = "Hacker/Hacker Brr Brr Patapim" } },
			infinity = { { id = "hacker_ballerina", name = "Hacker Ballerina Cappuccina", model = "Hacker/Hacker Ballerina Cappuccina" } },
		},
	},
	{
		id = "virus",
		order = 27,
		name = "Virus Pack",
		price = 2.4e17,
		cash = 1.5e7,
		color = Color3.fromRGB(130, 255, 0),
		odds = { god = 32, og = 40, celestial = 20, eternal = 6.5, infinity = 1.5 },
		cards = {
			god = { { id = "hacker_zibrazubrazibralini", name = "Hacker Zibra Zubra Zibralini", model = "Hacker/Hacker Zibra Zubra Zibralini" }, { id = "hacker_tigroligrefrutonni", name = "Hacker Tigroligre Frutonni", model = "Hacker/Hacker Tigroligre Frutonni" } },
			og = { { id = "hacker_bobritobandito", name = "Hacker Bobrito Bandito", model = "Hacker/Hacker Bobrito Bandito" }, { id = "hacker_nyanninicattalini", name = "Hacker Nyannini Cattalini", model = "Hacker/Hacker Nyannini Cattalini" } },
			celestial = { { id = "hacker_ballerinolololo", name = "Hacker Ballerino Lololo", model = "Hacker/Hacker Ballerino Lololo" } },
			eternal = { { id = "hacker_strawberrelliflamingelli", name = "Hacker Strawberrelli Flamingelli", model = "Hacker/Hacker Strawberrelli Flamingelli" } },
			infinity = { { id = "hacker_cappuccino", name = "Hacker Cappuccino Assassino", model = "Hacker/Hacker Cappuccino Assassino" } },
		},
	},
	{
		id = "firewall",
		order = 28,
		name = "Firewall Pack",
		price = 7.1e17,
		cash = 1.2e8,
		color = Color3.fromRGB(0, 200, 90),
		odds = { god = 55, og = 30, celestial = 12, eternal = 2.8, infinity = 0.2 },
		cards = {
			god = { { id = "hacker_orangutini", name = "Hacker Orangutini Ananassini", model = "Hacker/Hacker Orangutini Ananassini" }, { id = "hacker_matteo", name = "Hacker Matteo", model = "Hacker/Hacker Matteo" } },
			og = { { id = "hacker_lionelcactuseli", name = "Hacker Lionel Cactuseli", model = "Hacker/Hacker Lionel Cactuseli" }, { id = "hacker_karkerkarkurkur", name = "Hacker Karkerkar Kurkur", model = "Hacker/Hacker Karkerkar Kurkur" } },
			celestial = { { id = "hacker_pakrahmatmamat", name = "Hacker Pakrahmatmamat", model = "Hacker/Hacker Pakrahmatmamat" } },
			eternal = { { id = "hacker_orcaleroorcala", name = "Hacker Orcalero Orcala", model = "Hacker/Hacker Orcalero Orcala" } },
			infinity = { { id = "hacker_tralaledon", name = "Hacker Tralaledon", model = "Hacker/Hacker Tralaledon" } },
		},
	},
	{
		id = "matrix",
		order = 29,
		name = "Matrix Pack",
		price = 4.9e18,
		cash = 2.7e8,
		color = Color3.fromRGB(0, 255, 60),
		odds = { god = 42, og = 38, celestial = 15.5, eternal = 4, infinity = 0.5 },
		cards = {
			god = { { id = "hacker_girafa", name = "Hacker Girafa Celestre", model = "Hacker/Hacker Girafa Celeste" }, { id = "hacker_cocofanto", name = "Hacker Cocofanto Elefanto", model = "Hacker/Hacker Cocofanto Elefanto" } },
			og = { { id = "hacker_lavaca", name = "Hacker La Vaca Saturno Saturnita", model = "Hacker/Hacker La Vacca Saturno Saturnita" }, { id = "hacker_yessmyexamen", name = "Hacker Yess My Examen", model = "Hacker/Hacker Yess My Examen" } },
			celestial = { { id = "hacker_worl", name = "Hacker W Or L", model = "Hacker/Hacker W Or L" } },
			eternal = { { id = "hacker_tatatatasahur", name = "Hacker Ta Ta Ta Ta Sahur", model = "Hacker/Hacker Ta Ta Ta Ta Sahur" } },
			infinity = { { id = "hacker_madudung", name = "Hacker Madudung", model = "Hacker/Hacker Madudung" } },
		},
	},
	{
		id = "hacker",
		order = 30,
		name = "Hacker Pack",
		price = 1.3e19,
		cash = 4.9e8,
		color = Color3.fromRGB(40, 255, 170),
		odds = { god = 32, og = 40, celestial = 20, eternal = 6.5, infinity = 1.5 },
		cards = {
			god = { { id = "hacker_1x1x1x1", name = "Hacker 1x1x1x1", model = "Hacker/Hacker 1x1x1x1" }, { id = "hacker_blueberrinni", name = "Hacker Blueberrinni Octopussini", model = "Hacker/Hacker Blueberrinni Octopusini" } },
			og = { { id = "hacker_chicleteira", name = "Hacker Chicleteira Bicicleteira", model = "Hacker/Hacker Chicleteira Bicicleteira" }, { id = "hacker_strawberry", name = "Hacker Strawberry Elephant", model = "Hacker/Hacker Strawberry Elephant" } },
			celestial = { { id = "hacker_ganganzellitrulala", name = "Hacker Ganganzelli Trulala", model = "Hacker/Hacker Ganganzelli Trulala" } },
			eternal = { { id = "hacker_meowl", name = "Hacker Meowl", model = "Hacker/Hacker Meowl" } },
			infinity = { { id = "hacker_pothotspot", name = "Hacker Pot Hotspot", model = "Hacker/Hacker Pot Hotspot" } },
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
			Config.CARDS[entry.id] = { id = entry.id, name = entry.name, rarity = rarityId, pack = pack.id, model = entry.model }
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

-- Full art cards: the rarest cards of each pack. Their picture fills the whole card.
function Config.isFullArt(cardId: string): boolean
	local card = Config.CARDS[cardId]
	local best = 0
	for rarityId in Config.PACK[card.pack].cards do
		best = math.max(best, Config.RARITY[rarityId].order)
	end
	return Config.RARITY[card.rarity].order == best
end

-- 2D illustrations (uploaded image ids) for the cards that have one, mainly the full arts.
-- A card without one shows its 3D model.
Config.CARD_ART = {} :: { [string]: number }

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

-- Grading a card costs GRADE_COST_SECONDS of its Cash (variant included). A grade adds about
-- +34% on average, so it pays for itself after about 15 minutes on a stand.
Config.GRADE_COST_SECONDS = 300

function Config.gradeCost(cardId: string, variantId: string): number
	return math.max(1, math.floor(Config.cardIncome(cardId, variantId) * Config.GRADE_COST_SECONDS))
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
	{ slots = 25, price = 2500 },
	{ slots = 25, price = 100000 },
	{ slots = 50, price = 3000000 },
	{ slots = 50, price = 100000000 },
	{ slots = 100, price = 3000000000 },
} :: { { slots: number, price: number } }

function Config.backpackSize(level: number): number
	local size = Config.BACKPACK_SLOTS
	for index = 1, math.min(level, #Config.BACKPACK_UPGRADES) do
		size += Config.BACKPACK_UPGRADES[index].slots
	end
	return size
end

-- A card sells for SELL_RATIO of its share of the pack price (price / CARDS_PER_PACK), scaled by how
-- much more (or less) Cash it makes than an average card of its pack (variant, grade and trait
-- included). On average, selling the cards of a pack gives back 25% of its price, so opening packs
-- only to sell them loses money.
Config.SELL_RATIO = 0.25
-- An unopened pack sells back for this share of its price
Config.PACK_SELL_RATIO = 0.5

-- Average Cash per second of a normal-grade card pulled from a pack (variants included)
local averageIncome: { [string]: number } = {}

function Config.packAverageIncome(packId: string): number
	if averageIncome[packId] then
		return averageIncome[packId]
	end
	local pack = Config.PACK[packId]
	local variantAverage = Config.variantChance("normal") / 100
	for _, variant in Config.VARIANTS do
		variantAverage += variant.chance / 100 * variant.cash
	end
	local rarityAverage = 0
	for rarityId, odds in pack.odds do
		rarityAverage += odds / 100 * Config.RARITY[rarityId].cash
	end
	averageIncome[packId] = rarityAverage * pack.cash * variantAverage
	return averageIncome[packId]
end

function Config.sellPrice(key: string): number
	local cardId = Config.splitKey(key)
	local card = Config.CARDS[cardId]
	if not card then
		return 1
	end
	local share = Config.PACK[card.pack].price / Config.CARDS_PER_PACK * Config.SELL_RATIO
	return math.max(1, math.floor(share * Config.keyIncome(key) / Config.packAverageIncome(card.pack)))
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
-- Pity: after PITY_PACKS packs of the same kind without a card of the pack's second rarest
-- rarity or better, the next pack guarantees one
Config.PITY_PACKS = 20

function Config.pityRarity(packId: string): Rarity
	local orders = {}
	for rarityId in Config.PACK[packId].odds do
		table.insert(orders, Config.RARITY[rarityId].order)
	end
	table.sort(orders)
	return Config.RARITIES[orders[math.max(1, #orders - 1)]]
end
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
	tungtung = { id = 71630473252028 }, -- chosen by Estéban, better than the one of the Brainrot Pack
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

-- Every card with a model in the Brainrot Pack and no entry above: the model only exists in
-- ServerStorage > AssetLibrary
for cardId, card in Config.CARDS do
	if card.model and not Config.ASSETS[cardId] then
		Config.ASSETS[cardId] = { id = 0 }
	end
end

-- The giant statue in the middle of the plaza: one of the card models (Config.ASSETS)
Config.CENTER_STATUE = { card = "strawberry", height = 14 }

-- The brainrot standing behind the counter of each station of the plaza (a card id, so its
-- model comes from Config.ASSETS / the AssetLibrary) and how tall it is in studs
Config.SHOPKEEPERS = {
	shop = { card = "tralalero", title = "Shopkeeper", height = 6.5 },
	sell = { card = "bobritobandito", title = "Buyer", height = 6.5 },
	grade = { card = "odin", title = "Grader", height = 6.5 },
	towers = { card = "bombardiro", title = "Tower Master", height = 6.5 },
}

-- Free Creator Store models that decorate the plaza (same loading as the brainrots).
-- If one is missing, a simple shape built from parts takes its place.
-- `size` (instead of `height`) scales a flat model by its longest side.
Config.DECOR = {
	-- Keys are never reused for another model: the place keeps old ones in ServerStorage.AssetLibrary
	decor_cartoon_tree = { id = 13870570014, height = 20 },
	decor_bush = { id = 11209863116, height = 4 },
	decor_big_flowers = { id = 12209067059, height = 2.5 },
	decor_rocks = { id = 8647358410, height = 3.5 },
	decor_chest = { id = 7924041336, height = 1.8 },
	decor_stool = { id = 4456279344, height = 3 }, -- chosen by Estéban; scaled to the height needed
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
