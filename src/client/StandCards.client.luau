-- The cards standing on the plots, drawn on this client: the same card as in the UI and the
-- pack opening, with the brainrot's 3D model in it. The server only places an invisible part
-- tagged "StandCard" with the card's key (Plots.luau); a ViewportFrame it built would stay blank.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CardArt = require(ReplicatedStorage.Shared.CardArt)
local Config = require(ReplicatedStorage.Shared.Config)

local PIXELS_PER_STUD = 50
local MAX_DISTANCE = 90 -- farther stands aren't drawn (up to 48 stands on the map)

local folder = Instance.new("Folder")
folder.Name = "StandCards"
folder.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local drawn: { [Instance]: { SurfaceGui } } = {}

local function draw(cardPart: Instance)
	local key = cardPart:GetAttribute("CardKey")
	if not cardPart:IsA("BasePart") or type(key) ~= "string" or drawn[cardPart] then
		return
	end
	local cardId, variantId = Config.splitKey(key)
	if not Config.CARDS[cardId] then
		return
	end
	local guis = {}
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Name = cardPart:GetFullName()
		gui.Adornee = cardPart
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PIXELS_PER_STUD
		gui.LightInfluence = 0
		gui.MaxDistance = MAX_DISTANCE
		gui.ResetOnSpawn = false
		gui.Parent = folder
		CardArt.build(gui, cardId, variantId, Config.keyGrade(key), nil, (Config.keyTrait(key) or {} :: any).id)
		table.insert(guis, gui)
	end
	drawn[cardPart] = guis
end

local function erase(cardPart: Instance)
	local guis = drawn[cardPart]
	if guis then
		for _, gui in guis do
			gui:Destroy()
		end
	end
	drawn[cardPart] = nil
end

for _, cardPart in CollectionService:GetTagged("StandCard") do
	draw(cardPart)
end
CollectionService:GetInstanceAddedSignal("StandCard"):Connect(draw)
CollectionService:GetInstanceRemovedSignal("StandCard"):Connect(erase)
