-- Animates the plaza on the player's side, so it moves smoothly (the server places everything
-- once and tags it, see Plaza.luau):
--   AmbientSpin   turns slowly on itself (attribute Speed, radians per second)
--   AmbientOrbit  floats around the middle of the map (attributes Radius, Height, Phase, Speed)
--   AmbientKeeper a shopkeeper: bounces gently and turns to look at the player when close

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LOOK_DISTANCE = 30 -- the shopkeepers look at the player closer than this
local LOOK_LIMIT = math.rad(70) -- and turn at most this much from facing the plaza

type Entry = { instance: PVInstance, pivot: CFrame, yaw: number, phase: number }
local entries: { [string]: { [PVInstance]: Entry } } = { AmbientSpin = {}, AmbientOrbit = {}, AmbientKeeper = {} }

for tag, list in entries do
	local function add(instance: Instance)
		if instance:IsA("PVInstance") then
			list[instance] = { instance = instance, pivot = instance:GetPivot(), yaw = 0, phase = math.random() * math.pi * 2 }
		end
	end
	for _, instance in CollectionService:GetTagged(tag) do
		add(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(add)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
		list[instance :: PVInstance] = nil
	end)
end

local player = Players.LocalPlayer

RunService.RenderStepped:Connect(function(dt)
	local t = os.clock()

	for _, entry in entries.AmbientSpin do
		local speed = entry.instance:GetAttribute("Speed") or 0.4
		entry.instance:PivotTo(entry.pivot * CFrame.Angles(0, t * speed, 0))
	end

	for _, entry in entries.AmbientOrbit do
		local instance = entry.instance
		local radius = instance:GetAttribute("Radius") or 10
		local height = instance:GetAttribute("Height") or 10
		local angle = (instance:GetAttribute("Phase") or 0) + t * (instance:GetAttribute("Speed") or 0.3)
		local position = Vector3.new(math.cos(angle) * radius, height + math.sin(t * 1.5 + angle * 2) * 0.6, math.sin(angle) * radius)
		-- Faces outward and rocks a little, like a card floating in the air
		instance:PivotTo(CFrame.lookAt(position, position * 2 - Vector3.new(0, position.Y, 0)) * CFrame.Angles(0, math.sin(t + angle) * 0.25, math.sin(t * 0.8 + angle) * 0.08))
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, entry in entries.AmbientKeeper do
		local target = 0
		if root then
			local offset = entry.pivot:PointToObjectSpace(root.Position)
			if Vector3.new(offset.X, 0, offset.Z).Magnitude < LOOK_DISTANCE then
				-- Models face -Z: the angle to the player around the vertical axis
				target = math.clamp(math.atan2(-offset.X, -offset.Z), -LOOK_LIMIT, LOOK_LIMIT)
			end
		end
		entry.yaw += (target - entry.yaw) * math.min(1, dt * 5)
		local bounce = math.abs(math.sin(t * 2.2 + entry.phase)) * 0.25
		entry.instance:PivotTo(entry.pivot * CFrame.new(0, bounce, 0) * CFrame.Angles(0, entry.yaw, 0))
	end
end)
