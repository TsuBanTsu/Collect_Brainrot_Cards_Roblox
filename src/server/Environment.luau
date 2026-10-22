-- The look of the world, in the bright style of the big Roblox simulators (Steal a Brainrot,
-- Grow a Garden...): clear lighting, a cyan cartoon sky, saturated colors, a studded green
-- baseplate, and bright terrain hills with a river around the map.

local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Environment = {}

local MAP_SIZE = 280 -- the studded baseplate in the middle, where the plaza and the plots are
local HILLS_RADIUS = 300 -- the ring of hills around the map
local WATER_RADIUS = 380 -- a lake ring behind the hills

local function replace(className: string, props, parent: Instance?)
	local target = parent or Lighting
	local old = target:FindFirstChildOfClass(className)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = target
	return inst
end

local function setupLighting()
	Lighting.ClockTime = 13.5
	Lighting.GeographicLatitude = 25
	Lighting.Brightness = 2.6
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.3
	-- Bright ambient light: shadows stay soft and colors stay vivid, like a cartoon
	Lighting.OutdoorAmbient = Color3.fromRGB(165, 165, 175)
	Lighting.Ambient = Color3.fromRGB(110, 110, 120)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.4
	Lighting.ExposureCompensation = 0.15

	local sky = Config.SKY
	replace("Sky", {
		SkyboxBk = sky.SkyboxBk,
		SkyboxDn = sky.SkyboxDn,
		SkyboxFt = sky.SkyboxFt,
		SkyboxLf = sky.SkyboxLf,
		SkyboxRt = sky.SkyboxRt,
		SkyboxUp = sky.SkyboxUp,
		SunAngularSize = 14,
		CelestialBodiesShown = false,
	})
	-- Very light haze, only far away: no grey veil over the map
	replace("Atmosphere", {
		Density = 0.22,
		Offset = 0,
		Color = Color3.fromRGB(200, 235, 255),
		Decay = Color3.fromRGB(150, 200, 240),
		Glare = 0,
		Haze = 0,
	})
	replace("BloomEffect", { Intensity = 0.25, Size = 20, Threshold = 2.4 })
	replace("ColorCorrectionEffect", { Saturation = 0.22, Contrast = 0.06, Brightness = 0.03, TintColor = Color3.new(1, 1, 1) })
	for _, className in { "SunRaysEffect", "DepthOfFieldEffect" } do
		local old = Lighting:FindFirstChildOfClass(className)
		if old then
			old:Destroy()
		end
	end
	-- No texture overrides: the simulator look is plain, bright plastic
	for _, variant in MaterialService:GetDescendants() do
		if variant:IsA("MaterialVariant") then
			MaterialService:SetBaseMaterialOverride(variant.BaseMaterial, "")
		end
	end
end

-- The flat ground in the middle: bright green plastic with studs, like a classic baseplate
local function setupBaseplate()
	local old = Workspace:FindFirstChild("Baseplate")
	if old then
		old:Destroy()
	end
	local baseplate = Instance.new("Part")
	baseplate.Name = "Baseplate"
	baseplate.Anchored = true
	baseplate.Size = Vector3.new(MAP_SIZE, 4, MAP_SIZE)
	baseplate.Position = Vector3.new(0, -1.9, 0) -- top at y = 0.1, just above the terrain
	baseplate.Color = Color3.fromRGB(75, 200, 75)
	baseplate.Material = Enum.Material.Plastic
	baseplate.TopSurface = Enum.SurfaceType.Studs
	baseplate.BottomSurface = Enum.SurfaceType.Smooth
	baseplate.Parent = Workspace
end

local function setupTerrain()
	local terrain = Workspace.Terrain
	terrain:Clear()

	-- Bright cartoon colors for the terrain materials
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(80, 200, 80))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(60, 180, 70))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(170, 120, 70))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(150, 150, 165))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(250, 225, 150))
	terrain.WaterColor = Color3.fromRGB(40, 170, 255)
	terrain.WaterTransparency = 0.3
	terrain.WaterReflectance = 0.3
	terrain.WaterWaveSize = 0.08
	terrain.WaterWaveSpeed = 6
	pcall(function()
		(terrain :: any).Decoration = false -- no grass blades: they would poke through the baseplate
	end)

	-- The ground: its surface shows up at y = 0 (terrain is drawn about 2 studs above the
	-- block it fills, so the block stops at y = -2)
	local size = WATER_RADIUS * 2 + 120
	terrain:FillBlock(CFrame.new(0, -8, 0), Vector3.new(size, 12, size), Enum.Material.Grass)
	-- Soft hills all around, two rows, with rock on the biggest ones
	local rng = Random.new(42) -- same hills every time
	for row = 0, 1 do
		local count = 30 + row * 8
		for i = 0, count - 1 do
			local angle = (i + rng:NextNumber() * 0.6) / count * math.pi * 2
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local radius = rng:NextNumber(22, 42) + row * 14
			local distance = HILLS_RADIUS + row * 30 + rng:NextNumber(-10, 10)
			local center = direction * distance + Vector3.new(0, -radius * 0.45, 0)
			terrain:FillBall(center, radius, if radius > 46 then Enum.Material.Rock else Enum.Material.LeafyGrass)
			terrain:FillBall(center + Vector3.new(0, radius * 0.25, 0), radius * 0.8, Enum.Material.Grass)
		end
	end
	-- A river ring behind the hills: sand banks, then the bed dug out and filled with water
	for i = 0, 47 do
		local angle = i / 48 * math.pi * 2
		local position = Vector3.new(math.cos(angle), 0, math.sin(angle)) * WATER_RADIUS
		local facing = CFrame.lookAt(position, Vector3.zero)
		terrain:FillBlock(facing * CFrame.new(0, -1, 0), Vector3.new(58, 4, 76), Enum.Material.Sand)
		terrain:FillBlock(facing * CFrame.new(0, 37, 0), Vector3.new(58, 90, 60), Enum.Material.Air)
		terrain:FillBlock(facing * CFrame.new(0, -6, 0), Vector3.new(58, 8, 52), Enum.Material.Water)
	end
	-- A few gentle bumps between the plots and the hills, so the ground isn't perfectly flat
	for i = 0, 17 do
		local angle = (i + 0.5) / 18 * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		terrain:FillBall(direction * rng:NextNumber(150, 230) + Vector3.new(0, -9, 0), rng:NextNumber(12, 18), Enum.Material.Grass)
	end
	-- Keep the middle flat (plaza and plots): clear anything above the ground there
	terrain:FillBlock(CFrame.new(0, 30, 0), Vector3.new(MAP_SIZE, 60, MAP_SIZE), Enum.Material.Air)
end

function Environment.setup()
	setupLighting()
	setupTerrain()
	setupBaseplate()
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy() -- the cartoon skybox has its own clouds
	end
end

return Environment
