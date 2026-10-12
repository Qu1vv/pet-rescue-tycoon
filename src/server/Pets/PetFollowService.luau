local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Validation = require(script.Parent.Parent.Common.Validation)
local FollowTrail = require(script.Parent.FollowTrail)
local Profiles = require(game:GetService("ReplicatedStorage").Shared.Pets.MovementProfiles)
local Motion = require(game:GetService("ReplicatedStorage").Shared.Pets.AnimalMotion)
local PetFollowService = {}
local followers = {}
local started = false
local world, onStep, onLost
local movementModes = {}

-- Samples walkable ground beneath a grounded living character, excluding airborne positions.
local function groundPosition(root, params)
	local humanoid = root.Parent:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.FloorMaterial == Enum.Material.Air then return nil end
	local hit = workspace:Raycast(root.Position + Vector3.new(0, 1, 0), Vector3.new(0, -12, 0), params)
	if not hit or hit.Normal.Y < 0.7 then return nil end
	return hit.Position
end
movementModes.Ground = groundPosition

-- Registers a server-only locomotion target resolver for a future profile mode such as Hover or Fly.
function PetFollowService.RegisterMovementMode(name, resolver)
	assert(not started, "Movement modes must be registered before follow updates start")
	assert(type(name) == "string" and name ~= "" and type(resolver) == "function", "Invalid movement mode")
	movementModes[name] = resolver
end

-- Destroys the player's rescue leash and hand attachment and releases the follower record.
function PetFollowService.Remove(player)
	local entry = followers[player]
	if not entry then return end
	if entry.Beam then entry.Beam:Destroy() end
	if entry.Hand then entry.Hand:Destroy() end
	followers[player] = nil
end

-- Registers one following pet and creates its visual hand-to-collar leash; asserts required character parts.
function PetFollowService.Add(player, pet)
	assert(not followers[player], "Player already has a follower")
	local root = assert(Validation.Root(player), "No living character")
	local collar = assert(pet.Model:FindFirstChild("LeashAttachment", true), "Missing leash attachment")
	local handPart = player.Character:FindFirstChild("RightHand") or player.Character:FindFirstChild("Right Arm") or root
	local entry = { Pet = pet, Trail = FollowTrail.new(pet.Model:GetPivot().Position), Character = player.Character,
		Profile = Profiles.Get(pet.Definition.MovementProfile or pet.Definition.Species), Speed = 0, FarTime = 0 }
	followers[player] = entry -- registered first so failure cleanup owns partial attachments
	local hand = Instance.new("Attachment")
	entry.Hand = hand
	hand.Name = "PetLeashHand"
	hand.Position = Vector3.new(0, -handPart.Size.Y * 0.4, 0)
	hand.Parent = handPart
	local beam = Instance.new("Beam")
	entry.Beam = beam
	beam.Name = "PetLeash"
	beam.Attachment0 = hand
	beam.Attachment1 = collar
	beam.Width0 = 0.07
	beam.Width1 = 0.07
	beam.Color = ColorSequence.new(Color3.fromRGB(84, 64, 45))
	beam.FaceCamera = true
	beam.Segments = 10
	beam.CurveSize0 = 0.5
	beam.CurveSize1 = -0.5
	beam.Parent = pet.Model
end

-- Advances one pet along its bounded trail and invokes delivery or lost-character callbacks.
local function step(player, entry, dt, params)
	local root = Validation.Root(player)
	if not root or player.Character ~= entry.Character or not entry.Pet.Model:IsDescendantOf(workspace) then
		onLost(player)
		return
	end
	local trail = entry.Trail
	local resolver = movementModes[entry.Profile.Mode]
	assert(resolver, "Unsupported pet movement mode: " .. tostring(entry.Profile.Mode))
	local target = resolver(root, params, entry)
	if target then trail:Add(target) end
	local model = entry.Pet.Model
	local current = model:GetPivot()
	local profile = entry.Profile
	local gap = math.max(0, trail.Length - profile.Spacing - trail.Progress)
	local recover, animation
	entry.Speed, entry.FarTime, recover, animation = Motion.Step(entry.Speed, gap,
		(root.Position-current.Position).Magnitude, entry.FarTime, dt, profile)
	local position = trail:Advance(profile.Spacing, entry.Speed, dt, recover)
	local facing = Vector3.new(position.X - current.X, 0, position.Z - current.Z)
	local rotation = current.Rotation
	if facing.Magnitude > 0.02 then rotation = rotation:Lerp(CFrame.lookAt(Vector3.zero, facing).Rotation, 1-math.exp(-profile.TurnRate*dt)) end
	model:PivotTo(CFrame.new(position) * rotation)
	model:SetAttribute("MovementState", animation)
	model:SetAttribute("MoveSpeed", entry.Speed)
	onStep(player, entry.Pet)
end

-- Starts one bounded follow loop with grounded trails, delivery checks and failed-follow cleanup.
function PetFollowService.Start(shelterWorld, deliveryCallback, lostCallback)
	if started then return end
	started = true
	world, onStep, onLost = shelterWorld, deliveryCallback, lostCallback
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.FollowInterval then return end
		local stepTime = math.min(elapsed, 0.15)
		elapsed = 0
		local excluded = { world.Pets }
		for _, player in Players:GetPlayers() do
			if player.Character then table.insert(excluded, player.Character) end
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = excluded
		for player, entry in followers do
			local ok, err = pcall(step, player, entry, stepTime, params)
			if not ok then
				warn("Pet follow cancelled: " .. tostring(err))
				onLost(player)
			end
		end
	end)
end

return PetFollowService
