-- Unopened packs as Roblox tools: one tool per kind of pack in the player's backpack (the hotbar
-- at the bottom of the screen), named with how many are left. Equipping it puts the pack in the
-- character's hand; clicking or tapping opens one (Hud.client.luau listens to Tool.Activated).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PackArt = require(ReplicatedStorage.Shared.PackArt)

local PackTools = {}

local function toolName(pack: Config.Pack, count: number): string
	return if count > 1 then pack.name .. " x" .. count else pack.name
end

local function makeTool(pack: Config.Pack): Tool
	local tool = Instance.new("Tool")
	tool.CanBeDropped = false
	tool.ToolTip = "Click to open"
	tool:SetAttribute("PackId", pack.id)
	tool.GripPos = Vector3.new(0, -0.6, 0.2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.6, 2.24, 0.15)
	handle.Color = pack.color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 100
		gui.LightInfluence = 0
		gui.Parent = handle
		PackArt.build(gui, pack)
	end
	return tool
end

-- The pack tools the player holds now, by pack id (in the backpack or in hand)
local function currentTools(player: Player): { [string]: Tool }
	local tools = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				local packId = child:IsA("Tool") and child:GetAttribute("PackId")
				if packId then
					tools[packId] = child
				end
			end
		end
	end
	return tools
end

-- Makes the tools match the packs of the profile: adds, renames and removes them
function PackTools.sync(player: Player, packs: { [string]: number })
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local tools = currentTools(player)
	for _, pack in Config.PACKS do
		local count = packs[pack.id] or 0
		local tool = tools[pack.id]
		if count > 0 then
			if not tool then
				tool = makeTool(pack)
				tool.Parent = backpack
			end
			tool.Name = toolName(pack, count)
		elseif tool then
			tool:Destroy()
		end
	end
end

return PackTools
