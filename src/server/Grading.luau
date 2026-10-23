-- Grading: a card gets 4 scores from 1 to 10 (Config.GRADE_CRITERIA). The grade is rolled
-- first with the odds of Config.GRADES, then 4 scores whose average fits it are made up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Grading = {}

local rng = Random.new()

export type Result = { key: string, scores: { number }, grade: number }

local function rollGrade(): Config.Grade
	local total = 0
	for _, grade in Config.GRADES do
		total += grade.chance
	end
	local roll = rng:NextNumber() * total
	for _, grade in Config.GRADES do
		roll -= grade.chance
		if roll <= 0 then
			return grade
		end
	end
	return Config.GRADES[#Config.GRADES]
end

-- 4 scores from 1 to 10 whose average is in [grade.min, the next grade's min)
local function rollScores(index: number): { number }
	local grade = Config.GRADES[index]
	local count = #Config.GRADE_CRITERIA
	local lowest = math.ceil(grade.min * count)
	local highest = if index > 1 then math.ceil(Config.GRADES[index - 1].min * count) - 1 else 10 * count
	local total = rng:NextInteger(lowest, math.min(highest, 10 * count))

	-- Spread the total evenly, then shuffle points around so the scores look natural
	local scores = {}
	for i = 1, count do
		scores[i] = math.floor(total / count) + (if i <= total % count then 1 else 0)
	end
	for _ = 1, 6 do
		local from, to = rng:NextInteger(1, count), rng:NextInteger(1, count)
		if from ~= to and scores[from] > 1 and scores[to] < 10 then
			scores[from] -= 1
			scores[to] += 1
		end
	end
	return scores
end

-- Grades one card of the backpack. Returns the result, or nil and a reason
function Grading.grade(player: Player, key: string): (Result?, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return nil, "Not ready"
	end
	local cardId, variantId, scores, traitId = Config.splitKey(key)
	if not Config.CARDS[cardId] or not Config.VARIANT[variantId] then
		return nil, "Unknown card"
	end
	if scores then
		return nil, "This card is already graded"
	end
	if (profile.Cards[key] or 0) < 1 then
		return nil, "This card isn't in your backpack"
	end
	local cost = Config.gradeCost(cardId, variantId)
	if profile.Cash < cost then
		return nil, "Not enough Cash"
	end

	local grade = rollGrade()
	local newScores = rollScores(table.find(Config.GRADES, grade) :: number)
	profile.Cash -= cost
	PlayerData.removeCard(profile, key, 1)
	PlayerData.addCard(profile, cardId, variantId, newScores, traitId)
	PlayerData.sync(player)
	return { key = Config.cardKey(cardId, variantId, newScores, traitId), scores = newScores, grade = grade.grade }
end

return Grading
