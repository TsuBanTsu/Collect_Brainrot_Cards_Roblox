-- Grading: a card gets 4 scores from 1 to 10 (Config.GRADE_CRITERIA). The grade is rolled
-- first with the odds of Config.GRADES, then 4 scores whose average fits it are made up.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)

local Grading = {}

local rng = Random.new()

-- `kept`: a regraded card that rolled worse than its old grade keeps the old one (`key`, `grade`);
-- `scores` are always the ones just rolled, for the screen
export type Result = { key: string, scores: { number }, grade: number, regrade: boolean, kept: boolean }

local function average(scores: { number }): number
	local total = 0
	for _, score in scores do
		total += score
	end
	return total / #scores
end

-- `bonus` (upgrades) multiplies the chances of the grades 8 to 10
local function rollGrade(bonus: number): Config.Grade
	local function chance(grade: Config.Grade): number
		return if grade.grade >= 8 then grade.chance * (1 + bonus) else grade.chance
	end
	local total = 0
	for _, grade in Config.GRADES do
		total += chance(grade)
	end
	local roll = rng:NextNumber() * total
	for _, grade in Config.GRADES do
		roll -= chance(grade)
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

-- Grades one card of the backpack. A graded card is graded again (cheaper) and keeps the
-- better of its two grades. Returns the result, or nil and a reason
function Grading.grade(player: Player, key: string): (Result?, string?)
	local profile = PlayerData.get(player)
	if not profile then
		return nil, "Not ready"
	end
	local cardId, variantId, oldScores, traitId = Config.splitKey(key)
	if not Config.CARDS[cardId] or not Config.VARIANT[variantId] then
		return nil, "Unknown card"
	end
	if (profile.Cards[key] or 0) < 1 then
		return nil, "This card isn't in your backpack"
	end
	local cost = if oldScores then Config.regradeCost(cardId, variantId) else Config.gradeCost(cardId, variantId)
	if profile.Cash < cost then
		return nil, "Not enough Cash"
	end

	local grade = rollGrade(PlayerData.bonus(profile, "grade"))
	local newScores = rollScores(table.find(Config.GRADES, grade) :: number)
	profile.Cash -= cost
	local kept = oldScores ~= nil and average(newScores) <= average(oldScores)
	if kept then
		PlayerData.sync(player)
		return { key = key, scores = newScores, grade = (Config.keyGrade(key) :: Config.Grade).grade, regrade = true, kept = true }
	end
	PlayerData.removeCard(profile, key, 1)
	PlayerData.addCard(profile, cardId, variantId, newScores, traitId)
	PlayerData.sync(player)
	return { key = Config.cardKey(cardId, variantId, newScores, traitId), scores = newScores, grade = grade.grade, regrade = oldScores ~= nil, kept = false }
end

return Grading
