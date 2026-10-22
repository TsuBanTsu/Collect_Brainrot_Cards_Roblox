-- Loads the free Creator Store models listed in Config.ASSETS (the brainrot characters) and
-- Config.DECOR (the plaza decoration) when the server starts.
-- Each model is cleaned up (no scripts, no collisions) and kept as a template to clone.
-- Loading other creators' models needs "Allow Loading Third Party Assets" turned on
-- (Game Settings > Security). If a model can't load, get() returns nil and the caller
-- shows only the card, so the game always works.

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Assets = {}

local LOAD_TIMEOUT = 20 -- seconds to wait for all the models before building the map

type Template = { model: Model, height: number, longest: number }
local templates: { [string]: Template } = {}
local folder: Folder

-- Anything that could run code, hurt players or get in the way is removed
local REMOVED_CLASSES = {
	"LuaSourceContainer", -- Script, LocalScript, ModuleScript
	"Humanoid",
	"Tool",
	"Seat",
	"VehicleSeat",
	"SpawnLocation",
	"ClickDetector",
	"ProximityPrompt",
	"Sound",
	"ForceField",
	"Explosion",
	"BodyMover",
	"Constraint",
	"JointInstance",
}

local function clean(model: Model)
	for _, inst in model:GetDescendants() do
		for _, className in REMOVED_CLASSES do
			if inst:IsA(className) then
				inst:Destroy()
				break
			end
		end
	end
	for _, inst in model:GetDescendants() do
		if inst:IsA("BasePart") then
			inst.Anchored = true
			inst.CanCollide = false
			inst.CanTouch = false
			inst.CanQuery = false
			inst.Massless = true
			inst.CastShadow = false
		end
	end
end

-- Models saved in the place by tools/import-assets.lua (ServerStorage.AssetLibrary) are used
-- first: they need no download. Otherwise the model is loaded from the Creator Store.
local function fetch(key: string, info): Model?
	local library = ServerStorage:FindFirstChild("AssetLibrary")
	local saved = library and library:FindFirstChild(key)
	if saved and saved:IsA("Model") then
		return saved:Clone()
	end
	if info.id == 0 then
		warn(string.format("[Assets] '%s' is missing from ServerStorage.AssetLibrary: run tools/import-from-pack.lua", key))
		return nil
	end
	local ok, result = pcall(AssetService.LoadAssetAsync, AssetService, info.id)
	if not ok or not result then
		warn(string.format("[Assets] Could not load '%s' (%d): %s", key, info.id, tostring(result)))
		return nil
	end
	return result :: Model
end

local function load(key: string, info)
	local model = fetch(key, info)
	if not model then
		return
	end
	clean(model)
	if not model:FindFirstChildWhichIsA("BasePart", true) then
		warn(string.format("[Assets] '%s' (%d) has no visible part", key, info.id))
		model:Destroy()
		return
	end
	-- Pivot at the bottom center of the model, facing -Z (turned by `yaw` if needed)
	model.WorldPivot = CFrame.new(model:GetPivot().Position) * CFrame.Angles(0, math.rad(info.yaw or 0), 0)
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0)) * model.WorldPivot.Rotation
	model.Name = key
	model.Parent = folder
	templates[key] = { model = model, height = size.Y, longest = math.max(size.X, size.Y, size.Z) }
end

function Assets.loadAll()
	folder = Instance.new("Folder")
	folder.Name = "AssetTemplates"
	-- Replicated so that the cards can show the 3D model (CardArt.luau); the models carry no scripts
	folder.Parent = ReplicatedStorage

	local pending = 0
	for _, list in { Config.ASSETS, Config.DECOR } do
		for key, info in list do
			pending += 1
			task.spawn(function()
				load(key, info)
				pending -= 1
			end)
		end
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < LOAD_TIMEOUT do
		task.wait(0.1)
	end
	local loaded = 0
	for _ in templates do
		loaded += 1
	end
	print(string.format("[Assets] %d models loaded", loaded))
end

-- Returns a fresh copy of the model, `height` studs tall (default: the size in Config),
-- with its pivot at its bottom center. Returns nil if the model isn't loaded.
function Assets.get(key: string, height: number?): Model?
	local template = templates[key]
	if not template then
		return nil
	end
	local model = template.model:Clone()
	local info = Config.ASSETS[key] or Config.DECOR[key]
	if not height and info.size then
		-- Flat models: scaled by their longest side instead of their height
		model:ScaleTo(model:GetScale() * info.size / template.longest)
		return model
	end
	local wanted = height or info.height or Config.MODEL_HEIGHT
	model:ScaleTo(model:GetScale() * wanted / template.height)
	return model
end

-- Clones a model and puts its bottom center at `position`, turned by `yaw` radians
function Assets.place(key: string, parent: Instance, position: Vector3, yaw: number?, height: number?): Model?
	local model = Assets.get(key, height)
	if model then
		model:PivotTo(CFrame.new(position) * CFrame.Angles(0, yaw or 0, 0))
		model.Parent = parent
	end
	return model
end

function Assets.has(key: string): boolean
	return templates[key] ~= nil
end

return Assets
