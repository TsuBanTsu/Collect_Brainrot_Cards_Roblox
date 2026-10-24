-- Admin panel (Admin.client.luau): gives Cash, packs, cards, Trait Rerolls and upgrades, sets the
-- weather and the towers' best floors, and resets data. Admins: the place's owner, anyone
-- testing in Studio and the user ids in Config.ADMINS. Everything is checked here, on the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local PlayerData = require(script.Parent.PlayerData)
local Weather = require(script.Parent.Weather)

local Admin = {}

local MAX_PACKS = 100 -- per action: each pack is a Tool in the backpack
local MAX_CARDS = 100

function Admin.isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(Config.ADMINS, player.UserId) then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

-- "Tralalero" or "tralalero" -> the card id: exact id first, then the start of a card name
local function findCard(text: string): string?
	local wanted = string.lower(text)
	if Config.CARDS[wanted] then
		return wanted
	end
	for id, card in Config.CARDS do
		if string.sub(string.lower(card.name), 1, #wanted) == wanted then
			return id
		end
	end
	return nil
end

local function wholeNumber(value: any, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), min, max)
end

-- Runs one action. Returns the message to show the admin
local function run(admin: Player, target: Player, action: string, args: { [string]: any }, hooks): string
	local profile = PlayerData.get(target)
	if not profile then
		return "No data for " .. target.Name
	end
	if action == "cash" then
		local amount = type(args.amount) == "number" and args.amount == args.amount and math.clamp(args.amount, -1e30, 1e30)
		if not amount then
			return "Type an amount"
		end
		PlayerData.addCash(target, amount)
		PlayerData.sync(target)
		return "Gave $" .. Format.number(amount) .. " to " .. target.Name
	elseif action == "packs" then
		local pack = type(args.pack) == "string" and Config.PACK[args.pack]
		local count = wholeNumber(args.count, 1, MAX_PACKS)
		if not pack or not count then
			return "Choose a pack and a count"
		end
		profile.Packs[pack.id] = (profile.Packs[pack.id] or 0) + count
		PlayerData.sync(target)
		return "Gave " .. count .. "x " .. pack.name .. " to " .. target.Name
	elseif action == "card" then
		local cardId = type(args.card) == "string" and findCard(args.card)
		local variantId = if type(args.variant) == "string" and Config.VARIANT[args.variant] then args.variant else "normal"
		local count = wholeNumber(args.count, 1, MAX_CARDS) or 1
		if not cardId then
			return "Unknown card: type its name"
		end
		for _ = 1, count do
			PlayerData.addCard(profile, cardId, variantId)
		end
		PlayerData.sync(target)
		return "Gave " .. count .. "x " .. Config.VARIANT[variantId].name .. " " .. Config.CARDS[cardId].name .. " to " .. target.Name
	elseif action == "weather" then
		if args.weather == "stop" then
			Weather.stop()
			return "Weather stopped"
		end
		local weather = type(args.weather) == "string" and Config.WEATHER[args.weather]
		if not weather then
			return "Unknown weather"
		end
		Weather.start(weather, hooks.announce)
		return weather.name .. " started"
	elseif action == "tower" then
		local tower = type(args.tower) == "string" and Config.TOWER[args.tower]
		local floor = wholeNumber(args.floor, 0, tower and tower.floors or 100000)
		if not tower or not floor then
			return "Choose a tower and a floor"
		end
		profile.Towers[tower.id] = floor
		PlayerData.sync(target)
		return tower.name .. ": best floor set to " .. floor
	elseif action == "rerolls" then
		local count = wholeNumber(args.count, 1, 1000) or 10
		profile.TraitRerolls += count
		PlayerData.sync(target)
		return "Gave " .. count .. " Trait Rerolls to " .. target.Name
	elseif action == "upgrades" then
		if args.all then
			for id in Config.UPGRADES do
				profile.Upgrades[id] = true
			end
		else
			-- Cards on the stands that are now locked go back to the backpack
			table.clear(profile.Upgrades)
			for slot, key in profile.Stands do
				if (tonumber(slot) or 0) > Config.BASE_STANDS then
					profile.Cards[key] = (profile.Cards[key] or 0) + 1
					profile.Stands[slot] = nil
				end
			end
		end
		hooks.afterUpgrades(target)
		return if args.all then "All upgrades given to " .. target.Name else "Upgrades removed from " .. target.Name
	elseif action == "reset" then
		PlayerData.reset(target)
		hooks.afterUpgrades(target)
		return target.Name .. "'s data was reset"
	end
	return "Unknown action"
end

-- `hooks.afterUpgrades(player)` refreshes walk speed, plot and UI; `hooks.announce` is the server message
function Admin.init(remotes: Folder, notify: (Player, string) -> (), hooks)
	local function setAttribute(player: Player)
		player:SetAttribute("Admin", Admin.isAdmin(player) or nil)
	end
	Players.PlayerAdded:Connect(setAttribute)
	for _, player in Players:GetPlayers() do
		setAttribute(player)
	end

	(remotes:WaitForChild("AdminAction") :: RemoteEvent).OnServerEvent:Connect(function(player, action: any, args: any)
		if not Admin.isAdmin(player) or type(action) ~= "string" or type(args) ~= "table" then
			return
		end
		local target = player
		if type(args.target) == "string" and args.target ~= "" then
			local wanted = string.lower(args.target)
			local found = nil
			for _, other in Players:GetPlayers() do
				if string.lower(other.Name) == wanted or string.lower(other.DisplayName) == wanted then
					found = other
				end
			end
			if not found then
				notify(player, "No player called " .. args.target .. " on this server")
				return
			end
			target = found
		end
		notify(player, "[Admin] " .. run(player, target, action, args, hooks))
	end)
end

return Admin
