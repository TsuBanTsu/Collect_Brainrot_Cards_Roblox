-- Weather: every Config.WEATHER_INTERVAL seconds a random weather gives the whole
-- server a temporary buff (luck, shiny chances or cash). The current weather is shared
-- with the clients through attributes on ReplicatedStorage.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

local Weather = {}

local NO_WEATHER = { luck = 1, shiny = 1, cash = 1 }

local current: Config.Weather? = nil
local tint: ColorCorrectionEffect

local function pick(): Config.Weather
	local total = 0
	for _, weather in Config.WEATHERS do
		total += weather.weight
	end
	local roll = math.random() * total
	for _, weather in Config.WEATHERS do
		roll -= weather.weight
		if roll <= 0 then
			return weather
		end
	end
	return Config.WEATHERS[1]
end

local function setTint(color: Color3)
	TweenService:Create(tint, TweenInfo.new(4), { TintColor = color }):Play()
end

-- Multipliers to apply right now
function Weather.buffs(): { luck: number, shiny: number, cash: number }
	return current or NO_WEATHER
end

function Weather.start(weather: Config.Weather, announce: (string, Color3) -> ())
	current = weather
	ReplicatedStorage:SetAttribute("Weather", weather.id)
	ReplicatedStorage:SetAttribute("WeatherEnds", os.time() + Config.WEATHER_DURATION)
	setTint(weather.color:Lerp(Color3.new(1, 1, 1), 0.7))
	announce(weather.name .. "! " .. weather.description .. " for " .. math.floor(Config.WEATHER_DURATION / 60) .. " minutes", weather.color)
end

function Weather.stop()
	current = nil
	ReplicatedStorage:SetAttribute("Weather", "")
	setTint(Color3.new(1, 1, 1))
end

function Weather.init(announce: (string, Color3) -> ())
	tint = Instance.new("ColorCorrectionEffect")
	tint.Name = "WeatherTint"
	tint.Parent = Lighting
	ReplicatedStorage:SetAttribute("Weather", "")

	task.spawn(function()
		while true do
			-- A weather starts every WEATHER_INTERVAL seconds, its duration included
			local calm = Config.WEATHER_INTERVAL - Config.WEATHER_DURATION
			ReplicatedStorage:SetAttribute("NextWeather", os.time() + calm)
			task.wait(calm)
			Weather.start(pick(), announce)
			task.wait(Config.WEATHER_DURATION)
			Weather.stop()
		end
	end)
end

return Weather
