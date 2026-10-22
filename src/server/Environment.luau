-- Lighting and post-processing: atmosphere, bloom, colors, sun rays.

local Lighting = game:GetService("Lighting")

local Environment = {}

local function replace(className: string, props)
	local old = Lighting:FindFirstChildOfClass(className)
	if old then
		old:Destroy()
	end
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = Lighting
	return inst
end

function Environment.setup()
	Lighting.ClockTime = 16.8
	Lighting.Brightness = 2.2
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.OutdoorAmbient = Color3.fromRGB(120, 115, 140)
	Lighting.Ambient = Color3.fromRGB(40, 40, 55)
	Lighting.GlobalShadows = true

	replace("Sky", { SunAngularSize = 14, MoonAngularSize = 8, StarCount = 3000 })
	replace("Atmosphere", {
		Density = 0.32,
		Offset = 0.2,
		Color = Color3.fromRGB(200, 170, 220),
		Decay = Color3.fromRGB(110, 80, 140),
		Glare = 0.4,
		Haze = 1.6,
	})
	replace("BloomEffect", { Intensity = 0.6, Size = 28, Threshold = 1.6 })
	replace("ColorCorrectionEffect", { Saturation = 0.18, Contrast = 0.08, Brightness = 0.02 })
	replace("SunRaysEffect", { Intensity = 0.06, Spread = 0.8 })
end

return Environment
