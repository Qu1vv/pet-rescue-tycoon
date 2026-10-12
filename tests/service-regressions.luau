-- Executed by tools/run_service_tests.py, which injects current source strings.
-- The test runs real service/ledger/profile code; only Roblox APIs/geometry are doubled.
local now, checks = 10, 0
local function check(value, message) checks += 1; assert(value, message) end
local function event()
	local signal = { Listeners = {} }
	function signal:Connect(callback)
		table.insert(self.Listeners, callback)
		return { Disconnect = function() end }
	end
	function signal:Fire(...) for _, callback in self.Listeners do callback(...) end end
	return signal
end
local function instance(class)
	local object = { ClassName = class, Attributes = {}, Children = {} }
	function object:SetAttribute(key, value) self.Attributes[key] = value end
	function object:GetAttribute(key) return self.Attributes[key] end
	function object:FindFirstChild(name)
		for _, child in self.Children do if child.Name == name then return child end end
	end
	function object:IsA(name) return self.ClassName == name end
	function object:IsDescendantOf(_) return self.Parent ~= nil end
	function object:Destroy() self.Parent = nil end
	function object:Kick(reason) error("Unexpected kick: " .. reason) end
	return setmetatable(object, { __newindex = function(self, key, value)
		rawset(self, key, value)
		if key == "Parent" and value and value.Children then table.insert(value.Children, self) end
	end })
end
local Players = { PlayerAdded = event(), PlayerRemoving = event(), Children = {}, List = {} }
function Players:GetPlayers() return self.List end
local Run = { Heartbeat = event(), IsStudio = function() return true end }
local world = { Model = instance("Model"), Plots = {}, Spawn = {} }
for id = 1, 2 do
	local model = instance("Model"); model.Parent = world.Model
	world.Plots[id] = { Id = id, Model = model, Spawn = {}, Title = {}, ClaimZone = {}, PurchaseZone = {},
		Upgrades = { Beds = 0, Pantry = 0, Storage = 0, Care = 0 }, UpgradePads = {}, Capacity = 3, Purchased = false }
	for _, branch in { "Beds", "Pantry", "Storage", "Care" } do world.Plots[id].UpgradePads[branch] = { Zone = {} } end
end
local restoreCalls, snapshots = 0, 0
local failBuild = false
local mocks = {
	Validation = {
		Player = function(player) return player.Parent == Players end,
		Root = function(player) return player.Root end,
		InZone = function(position, zone) return position == zone end,
		Finite = function(n) return n == n and math.abs(n) < math.huge end,
	},
	Builder = {
		BuildKennel = function(model) if failBuild then error("Injected build failure") end; model.Name = "Kennel" end,
		SetPurchased = function() end,
		GetSlots = function(_, count) return table.create(count, "bed") end,
		Reset = function(plot) plot.Owner = nil; plot.Purchased = false end,
	},
	World = { Build = function() return world end },
	Collection = { Load = function() end, Export = function() return {} end, Cleanup = function() end },
	Rewards = { Load = function() end, Export = function() return {Day=0,Progress={},Claimed={},Milestones={},GuidedStep=1} end, Cleanup = function() end },
	Events = { Emit = function() end },
}
local root = {
	Common = { Validation = "Validation", GameplayEvents = "Events" }, World = { PlotBuilder = "Builder", WorldBuilder = "World" },
	Shelter = { ShelterState = "State" }, Persistence = { ProfileData = "Data" }, Pets = { CollectionService = "Collection" },
	Players = { RewardService = "Rewards" },
}
for _, folder in root do folder.Parent = root end
local replicated = { Shared = { Config = { GameConfig = "Config", ShelterUpgrades = "Upgrades", Rewards="RewardConfig",RewardState="RewardState" }, Pets = { PetCatalog = "Catalog", PetCare = "PetCare" } } }
local services = { Players = Players, RunService = Run, ReplicatedStorage = replicated, HttpService = { GenerateGUID = function() return "test-session" end } }
local game = { JobId = "test", GetService = function(_, name) return assert(services[name], name) end, BindToClose = function() end }
local cache = {}
local function loadModule(name)
	if mocks[name] then return mocks[name] end
	if cache[name] then return cache[name] end
	local env = setmetatable({ game = game, workspace = world.Model, Instance = { new = instance },
		warn = print, -- Roblox's warning function is absent from the standalone Luau runtime.
		script = { Parent = if name == "Profiles" then root.Persistence else root.Shelter },
		os = { clock = function() return now end, time = function() return 100000 end },
		task = { spawn = function(fn, ...) fn(...) end, wait = function() end },
	}, { __index = getfenv() })
	env.require = loadModule
	local chunk = assert(loadstring(assert(sources[name]), name))
	setfenv(chunk, env)
	cache[name] = chunk()
	return cache[name]
end
local Shelter, Profiles, Pads = loadModule("Shelter"), loadModule("Profiles"), loadModule("Pads")
local feedback = { FireClient = function() end }
Shelter.Start(feedback)
local player = instance("Player")
player.Parent, player.UserId, player.DisplayName, player.Root = Players, 1, "First", {}
Players.List = { player }
-- Deliberately skip Shelter's PlayerAdded listener: profile loading must initialize cash itself.
Profiles.Start(Shelter, { Restore = function() restoreCalls += 1 end, Export = function() snapshots += 1; return {} end },
	{ Restore = function() end, Export = function() return { Stored = 0, Pending = 0 } end })
check(player:GetAttribute("ProfileReady") and Shelter.GetCash(player) == 100, "Profile-first join initializes authoritative cash")
player.Root.Position = world.Plots[1].ClaimZone
check(Shelter.TryClaim(player, 1), "Claim succeeds without calling a boolean")
check(restoreCalls == 1, "Claim invokes saved-shelter restoration exactly once")
now += 1
check(not Shelter.TryClaim(player, 1) and restoreCalls == 1, "Duplicate claim cannot restore twice")
now += 1
player.Root.Position = world.Plots[1].PurchaseZone
check(Shelter.TryPurchase(player, 1), "Purchase works after restored claim")
check(world.Plots[1].Purchased and Shelter.GetCash(player) == 75, "One kennel and exactly one debit")
Shelter.InitializePlayer(player)
check(Shelter.GetCash(player) == 75 and #player.Children == 1, "Late initialization cannot reset cash or duplicate leaderstats")
now += 1
check(not Shelter.TryPurchase(player, 1) and Shelter.GetCash(player) == 75, "Repeated purchase cannot charge")
Shelter.RestoreCash(player, 1000)
now += 1
player.Root.Position = world.Plots[1].UpgradePads.Beds.Zone
check(Shelter.TryUpgrade(player, 1, "Beds") and Shelter.GetPetCapacity(player).maxPetCapacity == 6, "First bed expansion")
now += 1
check(Shelter.TryUpgrade(player, 1, "Beds") and Shelter.GetPetCapacity(player).maxPetCapacity == 8, "Sunroom expansion")
now += 1
player.Root.Position = world.Plots[1].UpgradePads.Pantry.Zone
local balance = Shelter.GetCash(player)
failBuild = true
check(not Shelter.TryUpgrade(player, 1, "Pantry"), "Failed upgrade returns failure")
check(Shelter.GetCash(player) == balance and world.Plots[1].Upgrades.Pantry == 0, "Failed upgrade restores level and cash")
failBuild = false
now += 1
check(Shelter.TryUpgrade(player, 1, "Pantry") and world.Plots[1].Upgrades.Pantry == 1, "Pantry branch works independently")
local second = instance("Player")
second.Parent, second.UserId, second.DisplayName, second.Root = Players, 2, "Second", { Position = world.Plots[2].ClaimZone }
Players.List = { player, second }
Shelter.InitializePlayer(second)
Pads.Start(Shelter)
Run.Heartbeat:Fire(0.21)
check(world.Plots[2].Owner == nil, "Loading player cannot claim")
second:SetAttribute("ProfileReady", true)
now += 1
Run.Heartbeat:Fire(0.21)
check(world.Plots[2].Owner == second, "Standing on pad activates after loading without re-entry")
now += 61
Run.Heartbeat:Fire(61)
check(snapshots == 1, "Restored claim enters the live snapshot path")
local Movement = loadModule("Movement")
local humanoid = { WalkSpeed = 16 }
player.Root.Parent = { FindFirstChildOfClass = function(_, class) assert(class == "Humanoid"); return humanoid end }
check(not Movement.SetRunning(player, 999), "Sprint rejects a client-supplied speed")
check(Movement.SetRunning(player, true) and humanoid.WalkSpeed == 26, "Sprint uses server speed")
check(not Movement.SetRunning(player, true), "Sprint start spam is throttled")
check(Movement.SetRunning(player, false) and humanoid.WalkSpeed == 16, "Release bypasses cooldown to prevent stuck sprint")
now += 1
player:SetAttribute("ProfileReady", false)
check(not Movement.SetRunning(player, true) and humanoid.WalkSpeed == 16, "Loading player cannot start sprint")
player:SetAttribute("ProfileReady", true)
now += 1
local liveRoot = player.Root
player.Root = nil
check(not Movement.SetRunning(player, true), "Missing living character rejects sprint")
player.Root = liveRoot
-- Run the real client binding with a fake input surface to cover Shift/chat ordering.
local focused, sprintAction, sent = false, nil, {}
local input = { WindowFocusReleased = event(), GetFocusedTextBox = function() return focused end }
local actions = { BindAction = function(_, _, callback) sprintAction = callback end,
 SetTitle = function() end, SetPosition = function() end }
local remote = { FireServer = function(_, value) table.insert(sent, value) end }
local folder = { WaitForChild = function() return remote end }
local replica = { WaitForChild = function() return folder end }
Players.LocalPlayer = player
player.CharacterRemoving = event()
local clientServices = { Players = Players, UserInputService = input, ContextActionService = actions, ReplicatedStorage = replica }
local clientEnv = setmetatable({ game = { GetService = function(_, name) return clientServices[name] end },
 Enum = { KeyCode = { LeftShift = "L", RightShift = "R", ButtonL3 = "G" },
  UserInputState = { Begin = "Begin", End = "End", Cancel = "Cancel" }, ContextActionResult = { Pass = "Pass", Sink = "Sink" } },
 UDim2 = { new = function() return {} end },
}, { __index = getfenv() })
local clientChunk = assert(loadstring(sources.MovementClient, "MovementClient"))
setfenv(clientChunk, clientEnv)
clientChunk().Start()
sprintAction(nil, "Begin", { KeyCode = "L" })
focused = true
sprintAction(nil, "End", { KeyCode = "L" })
check(#sent == 2 and sent[1] == true and sent[2] == false, "Shift release while chat focused still stops sprint")
sprintAction(nil, "Begin", { KeyCode = "L" })
check(#sent == 2, "Typing in chat cannot start sprint")
focused = false
sprintAction(nil, "Begin", { KeyCode = "G" })
input.WindowFocusReleased:Fire()
check(sent[3] == true and sent[4] == false, "Gamepad toggle and lost focus release")
print("PASS: " .. checks .. " actual service regressions (one injected rollback warning expected)")
