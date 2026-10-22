-- Lighting, sky, clouds, hand-painted textures and the terrain around the map: soft hills,
-- a lake ring and stylized colors. Lighting.Technology can't be set by a script: choose it
-- in Studio (Lighting > Technology > Future) and save the place.

local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local MaterialService = game:GetService("MaterialService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Environment = {}

local MAP_SIZE = 560 -- flat grass in the middle, where the plaza and the plots are
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
	Lighting.ClockTime = 14.6
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 3
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 160)
	Lighting.Ambient = Color3.fromRGB(60, 60, 75)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.1

	local sky = Config.SKY
	replace("Sky", {
		SkyboxBk = sky.SkyboxBk,
		SkyboxDn = sky.SkyboxDn,
		SkyboxFt = sky.SkyboxFt,
		SkyboxLf = sky.SkyboxLf,
		SkyboxRt = sky.SkyboxRt,
		SkyboxUp = sky.SkyboxUp,
		SunAngularSize = 11,
		MoonAngularSize = 8,
		StarCount = 3000,
		CelestialBodiesShown = true,
	})
	replace("Atmosphere", {
		Density = 0.28,
		Offset = 0.1,
		Color = Color3.fromRGB(205, 225, 255),
		Decay = Color3.fromRGB(120, 140, 190),
		Glare = 0.2,
		Haze = 1.2,
	})
	-- Soft bloom: only really bright things glow, the neon and the water don't burn out
	replace("BloomEffect", { Intensity = 0.35, Size = 22, Threshold = 2.2 })
	replace("ColorCorrectionEffect", { Saturation = 0.15, Contrast = 0.1, Brightness = 0.02, TintColor = Color3.fromRGB(255, 250, 245) })
	replace("SunRaysEffect", { Intensity = 0.04, Spread = 0.6 })
	replace("DepthOfFieldEffect", { FarIntensity = 0.12, FocusDistance = 120, InFocusRadius = 140, NearIntensity = 0 })
end

local function setupTerrain()
	local terrain = Workspace.Terrain
	terrain:Clear()

	-- Stylized colors for the terrain materials
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(110, 190, 85))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(90, 170, 75))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(140, 110, 80))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(130, 130, 140))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(235, 215, 165))
	terrain.WaterColor = Color3.fromRGB(60, 170, 220)
	terrain.WaterTransparency = 0.6
	terrain.WaterReflectance = 0.6
	terrain.WaterWaveSize = 0.1
	terrain.WaterWaveSpeed = 8
	pcall(function()
		(terrain :: any).Decoration = true -- grass blades on the Grass material
	end)

	-- The ground: its top is at y = 0, like the old ground part
	local size = WATER_RADIUS * 2 + 120
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(size, 12, size), Enum.Material.Grass)
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
	terrain:FillBlock(CFrame.new(0, 30, 0), Vector3.new(MAP_SIZE * 0.5, 60, MAP_SIZE * 0.5), Enum.Material.Air)
end

local function setupClouds()
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
	clouds.Parent = Workspace.Terrain
end

-- The textures are saved in the place by tools/import-assets.lua (MaterialService);
-- otherwise they are loaded from the Creator Store (works once the place is published)
local function setupMaterials()
	if not MaterialService:FindFirstChildWhichIsA("MaterialVariant", true) then
		local ok, pack = pcall(AssetService.LoadAssetAsync, AssetService, Config.MATERIAL_PACK)
		if ok and pack then
			for _, variant in pack:GetDescendants() do
				if variant:IsA("MaterialVariant") then
					variant.Parent = MaterialService
				end
			end
			pack:Destroy()
		else
			warn("[Environment] Could not load the texture pack:", pack)
		end
	end
	local applied = 0
	for materialName, info in Config.MATERIAL_OVERRIDES do
		local material = (Enum.Material :: any)[materialName] :: Enum.Material
		local variant = MaterialService:FindFirstChild(info.variant, true)
		if variant and variant:IsA("MaterialVariant") and variant.BaseMaterial == material then
			variant.StudsPerTile = info.tile
			MaterialService:SetBaseMaterialOverride(material, info.variant)
			applied += 1
		end
	end
	print(string.format("[Environment] %d textures applied", applied))
end

function Environment.setup()
	setupMaterials()
	setupLighting()
	setupTerrain()
	setupClouds()
end

return Environment
