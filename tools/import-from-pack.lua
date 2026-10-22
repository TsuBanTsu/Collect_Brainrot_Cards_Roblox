-- Replaces the brainrot models with the blocky ones of the free "Brainrot Pack [150+]"
-- (Creator Store 137461628889541). In Roblox Studio (edit mode, not Play):
--   1. insert the pack from the Toolbox (it lands in Workspace as "BrainrotPack"),
--   2. paste this whole file into the command bar (View > Command Bar) and press Enter,
--   3. save the place (Ctrl+S).
-- The models of the pack's "Normal" folder are copied into ServerStorage > AssetLibrary under
-- the card ids, without scripts, particles or animations. The pack is then deleted from Workspace.

local PACK_TO_CARD = {
	-- [card id] = exact model name in BrainrotPack > Normal (Noobini Pizzanini isn't in the pack)
	lirili = "Lirili Larila",
	timcheese = "Tim Cheese",
	fluriflura = "Fluri Flura",
	pipikiwi = "Pipi Kiwi",
	trippi = "Trippi Troppi",
	boneca = "Boneca Ambalabu",
	talpa = "Talpa Di Fero",
	svinino = "Svinina Bombardino",
	patapim = "Brr Brr Patapim",
	bananita = "Bananita Dolphinita",
	chimpanzini = "Chimpanzini Bananini",
	ballerina = "Ballerina Cappuccina",
	tralalero = "Tralalero Tralala",
	trictrac = "Tric Trac Barabum",
	rhino = "Rhino Toasterino",
	cappuccino = "Cappuccino Assassino",
	burbaloni = "Burbaloni Luliloli",
	orangutini = "Orangutini Ananassini",
	tungtung = "Tung Sahur",
	odin = "Odin Din Din Dun",
	matteo = "Matteo",
	bombombini = "Bombombini Gusini",
	girafa = "Girafa Celeste",
	frigo = "Frigo Camelo",
	cocofanto = "Cocofanto Elefanto",
	bombardiro = "Bombardiro Crocodilo",
	gangster = "Gangster Footera",
	lavaca = "La Vacca Saturno Saturnita",
	glorbo = "Glorbo Fruttodrillo",
	blueberrinni = "Blueberrinni Octopusini",
	espresso = "Espresso Signora",
	chicleteira = "Chicleteira Bicicleteira",
	tralaleritos = "Los Tralaleritos",
	garama = "Garamararam",
	strawberry = "Strawberry Elephant",
}

local library = game.ServerStorage:FindFirstChild("AssetLibrary")
if not library then
	library = Instance.new("Folder")
	library.Name = "AssetLibrary"
	library.Parent = game.ServerStorage
end

-- Anything that moves, glows or runs code: the cards only need the still model
local REMOVED_CLASSES = {
	"LuaSourceContainer",
	"ParticleEmitter",
	"Trail",
	"Beam",
	"Fire",
	"Smoke",
	"Sparkles",
	"Light",
	"Animation",
	"AnimationController",
	"Animator",
	"KeyframeSequence",
	"Sound",
}

local function clean(model: Instance)
	for _, inst in model:GetDescendants() do
		for _, className in REMOVED_CLASSES do
			if inst:IsA(className) then
				inst:Destroy()
				break
			end
		end
	end
end

local packs = {}
for _, child in workspace:GetChildren() do
	if child.Name == "BrainrotPack" then
		table.insert(packs, child)
	end
end
local normal
for _, pack in packs do
	-- A pack inserted twice and emptied by hand leaves an empty "Normal": take one with models
	local folder = pack:FindFirstChild("Normal")
	if folder and #folder:GetChildren() > 0 then
		normal = folder
	end
end
if not normal then
	warn("[Pack] No BrainrotPack > Normal in Workspace: insert the pack from the Toolbox first.")
	return
end

local replaced, missing = 0, {}
for cardId, modelName in PACK_TO_CARD do
	local source = normal:FindFirstChild(modelName)
	if source then
		local copy = source:Clone()
		if not copy:IsA("Model") then
			local wrapper = Instance.new("Model")
			copy.Parent = wrapper
			copy = wrapper
		end
		clean(copy)
		copy.Name = cardId
		local old = library:FindFirstChild(cardId)
		if old then
			old:Destroy()
		end
		copy.Parent = library
		replaced += 1
	else
		table.insert(missing, cardId .. " (" .. modelName .. ")")
	end
end
for _, pack in packs do
	pack:Destroy()
end
print(string.format("[Pack] %d brainrots replaced. Now save the place (Ctrl+S).", replaced))
if #missing > 0 then
	warn("[Pack] Not found in the pack: " .. table.concat(missing, ", "))
end
