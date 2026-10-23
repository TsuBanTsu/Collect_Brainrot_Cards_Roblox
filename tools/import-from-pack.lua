-- Replaces the brainrot models with the blocky ones of the free "Brainrot Pack [150+]"
-- (Creator Store 137461628889541). In Roblox Studio (edit mode, not Play):
--   1. insert the pack from the Toolbox (it lands in Workspace as "BrainrotPack"),
--   2. paste this whole file into the command bar (View > Command Bar) and press Enter,
--   3. save the place (Ctrl+S).
-- (If the pack isn't in Workspace, the script tries to load it by itself.)
-- The model of every card (Config: card `model`, e.g. "Lava/Lava Tung Sahur") is copied into
-- ServerStorage > AssetLibrary under the card id, without scripts, particles or animations.
-- The pack is then deleted from Workspace.

-- The model of each card is listed in Config (card `model` = "Folder/Model name")
local Config = require(game.ReplicatedStorage.Shared.Config)
local PACK_ASSET_ID = 137461628889541

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
-- Not inserted by hand: load it straight from the Creator Store
if #packs == 0 then
	local ok, loaded = pcall(function()
		return game:GetService("InsertService"):LoadAsset(PACK_ASSET_ID)
	end)
	if ok and loaded then
		for _, child in loaded:GetChildren() do
			if child.Name == "BrainrotPack" or child:FindFirstChild("Normal") then
				table.insert(packs, child)
			end
		end
		table.insert(packs, loaded)
	end
end
local function findModel(path: string): Instance?
	local folderName, modelName = string.match(path, "^([^/]+)/(.+)$")
	for _, pack in packs do
		-- A pack inserted twice and emptied by hand leaves empty folders: take one with models
		local folder = pack:FindFirstChild(folderName :: string)
		local model = folder and folder:FindFirstChild(modelName :: string)
		if model then
			return model
		end
	end
	return nil
end
if #packs == 0 then
	warn("[Pack] No BrainrotPack: insert it from the Toolbox (" .. PACK_ASSET_ID .. ") and run this again.")
	return
end

local replaced, missing = 0, {}
for cardId, card in Config.CARDS do
	local source = if card.model then findModel(card.model) else nil
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
	elseif card.model then
		table.insert(missing, cardId .. " (" .. card.model .. ")")
	end
end
for _, pack in packs do
	pack:Destroy()
end
print(string.format("[Pack] %d brainrots replaced. Now save the place (Ctrl+S).", replaced))
if #missing > 0 then
	warn("[Pack] Not found in the pack: " .. table.concat(missing, ", "))
end
