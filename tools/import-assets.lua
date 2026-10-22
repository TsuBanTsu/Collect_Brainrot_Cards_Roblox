-- One-time import of the Creator Store models into the place, for when the game can't
-- load them by itself. In Roblox Studio (edit mode, not Play): paste this whole file into
-- the command bar (View > Command Bar) and press Enter, then save the place.
-- The brainrot models land in ServerStorage > AssetLibrary, where Assets.luau finds them.
-- Scripts inside the models are deleted. Running it again only adds the models still missing.

local Config = require(game.ReplicatedStorage.Shared.Config)
local library = game.ServerStorage:FindFirstChild("AssetLibrary")
if not library then
	library = Instance.new("Folder")
	library.Name = "AssetLibrary"
	library.Parent = game.ServerStorage
end
-- One model at a time, with a pause between them: downloading takes a while and the
-- command bar stops any code that runs too long without pausing.
task.spawn(function()
local added, failed = 0, 0
for key, info in Config.ASSETS do
	task.wait(0.2)
	if not library:FindFirstChild(key) then
		local ok, objects = pcall(function()
			return game:GetObjects("rbxassetid://" .. info.id)
		end)
		if ok and objects[1] then
			local model = Instance.new("Model")
			model.Name = key
			for _, object in objects do
				object.Parent = model
			end
			for _, inst in model:GetDescendants() do
				if inst:IsA("LuaSourceContainer") then
					inst:Destroy()
				end
			end
			model.Parent = library
			added += 1
		else
			failed += 1
			warn("[Import] " .. key .. " (" .. info.id .. ") failed: " .. tostring(objects))
		end
	end
end
print(string.format("[Import] %d models added, %d failed. Now save the place (Ctrl+S).", added, failed))
end)
print("[Import] Started, wait for the summary line...")
