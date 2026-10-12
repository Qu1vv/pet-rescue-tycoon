-- Paste this entire file into Studio's SERVER Command Bar in a fresh solo Play.
-- It changes only the running test session, never source files or saved data.
-- Teleport-based service tests do NOT replace the manual walking/leash tests.
local Players = game:GetService("Players")
local Server = game.ServerScriptService.Server
local Shelter = require(Server.Shelter.ShelterService)
local Pets = require(Server.Pets.PetService)
local PlotBuilder = require(Server.World.PlotBuilder)
local Follow = require(Server.Pets.PetFollowService)
local Config = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local world = Shelter.GetWorld()
local player = Players:GetPlayers()[1]
assert(game:GetService("RunService"):IsStudio() and not require(game.ReplicatedStorage.Shared.Config.GameConfig).StudioPersistence, "Use disposable Studio data")
assert(player:GetAttribute("ProfileReady"), "Wait for profile loading")
assert(#Players:GetPlayers() == 1, "Use a fresh solo test")
assert(player and player.Character and player.Character:FindFirstChild("HumanoidRootPart"), "Wait for the character to spawn")
assert(not Shelter.GetPlot(player), "Restart Play: this test needs an unclaimed player")
assert(#world.Model.Plots:GetChildren() == Config.PlotCount and #world.Pets:GetChildren() == Config.AvailablePets, "World counts")
for _, item in world.Model:GetDescendants() do
	if item:IsA("SpawnLocation") then
		assert(item.Transparency == 1 and not item:FindFirstChildWhichIsA("Decal"), "Visible spawn marker")
	end
end
local cash = player.leaderstats.ShelterCash
local plot = world.Plots[1]
local function moveTo(frame) player.Character:PivotTo(frame) end
local function away() moveTo(world.Spawn.CFrame + Vector3.new(0, 4, 0)) end
local function assertResult(ok, reason, expected)
	assert(reason == expected, "Expected " .. expected .. ", got " .. tostring(reason))
	return ok
end
-- Calms a wild pet through the real server interaction before any leash test.
local function earnTrust(model)
	local id = model:GetAttribute("PetId")
	assert(Pets.TryBeginRescue(player, id), "Trust encounter opens")
	for _ = 1, 6 do
		if model:GetAttribute("Trust") >= Config.TrustRequired then break end
		assert(Pets.TryTrustAction(player, id, "Calm"), "Calming grants trust")
		if model:GetAttribute("Trust") < Config.TrustRequired then task.wait(Config.TrustActionCooldown + 0.1) end
	end
	assert(model:GetAttribute("Trust") >= Config.TrustRequired, "Trust target reached")
end

moveTo(plot.ClaimZone.CFrame)
local ok, reason = Shelter.TryClaim(player, 1)
assert(ok and reason == "Claimed" and cash.Value == 100, "Free plot claim")
away()
task.wait(0.6)
ok, reason = Shelter.TryClaim(player, 2)
assert(not ok, "Cannot claim a second plot from another location")
task.wait(0.6)
moveTo(plot.PurchaseZone.CFrame)
cash.Value = 24
ok, reason = Shelter.TryPurchase(player, 1)
assert(not assertResult(ok, reason, "InsufficientCash"))
assert(cash.Value == 24 and not plot.Kennel, "Rejected payment changes nothing")
away()
task.wait(0.6)
cash.Value = 100
local originalBuild = PlotBuilder.BuildKennel
PlotBuilder.BuildKennel = function(model, record)
	originalBuild(model, record)
	error("Intentional kennel rollback test")
end
moveTo(plot.PurchaseZone.CFrame)
local called, buyOK, buyReason = pcall(Shelter.TryPurchase, player, 1)
PlotBuilder.BuildKennel = originalBuild
away()
assert(called and not buyOK and buyReason == "BuildFailed", "Build failure is caught")
assert(cash.Value == 100 and not plot.Purchased and not plot.Model:FindFirstChild("BasicKennel"), "Build rollback refunds and destroys partial model")
task.wait(0.6)
moveTo(plot.PurchaseZone.CFrame)
ok, reason = Shelter.TryPurchase(player, 1)
assert(ok and reason == "Purchased" and cash.Value == 75, "Purchase succeeds once")
away()
task.wait(0.6)
ok, reason = Shelter.TryPurchase(player, 1)
assert(not ok and reason == "AlreadyPurchased" and cash.Value == 75, "Duplicate payment blocked")

local function available()
	for _, model in world.Pets:GetChildren() do
		if model:GetAttribute("State") == "Available" then return model end
	end
	error("No available pets")
end
local first = available()
local firstId = first:GetAttribute("PetId")
ok, reason = Pets.TryRescue(player, firstId)
assert(not ok and reason == "TooFar", "Far pickup blocked")
task.wait(0.6)
local originalAdd = Follow.Add
Follow.Add = function(owner, pet)
	originalAdd(owner, pet)
	error("Intentional pickup rollback test")
end
moveTo(first:GetPivot() + Vector3.new(0, 3, 0))
earnTrust(first)
local rescuedCall, rescueOK, rescueReason = pcall(Pets.TryRescue, player, firstId)
Follow.Add = originalAdd
assert(rescuedCall and not rescueOK and rescueReason == "RescueFailed", "Pickup failure is caught")
assert(first:GetAttribute("State") == "Available" and plot.Model:GetAttribute("ReservedCount") == 0, "Pickup failure frees slot")
assert(not first:FindFirstChild("PetLeash") and not player.Character:FindFirstChild("PetLeashHand", true), "Pickup failure cleans leash")
task.wait(0.6)
earnTrust(first)
ok, reason = Pets.TryRescue(player, firstId)
assert(ok and reason == "Rescued" and plot.Model:GetAttribute("ReservedCount") == 1, "Rescue reserves capacity")
moveTo(plot.Intake.CFrame)
assert(not Pets.TryDeliver(player, firstId), "Owner alone in intake cannot deliver")
first:PivotTo(plot.Frame * CFrame.new(0, 1, 5))
assert(Pets.TryDeliver(player, firstId), "Owner and pet together deliver")
assert(first:GetAttribute("State") == "Sheltered" and plot.Model:GetAttribute("PetCount") == 1, "Delivered state")
local firstSuite = plot.Kennel.HousingSpaces:FindFirstChild("Suite" .. first:GetAttribute("HousingSlotId"))
assert(firstSuite and firstSuite:GetAttribute("PetUniqueId") == firstId and firstSuite:GetAttribute("Occupied"), "Delivery assigns one housing suite")
assert(not Pets.TryDeliver(player, firstId), "Delivery is not repeatable")

for expected = 2, 3 do
	task.wait(0.6)
	local model = available()
	local id = model:GetAttribute("PetId")
	moveTo(model:GetPivot() + Vector3.new(0, 3, 0))
	earnTrust(model)
	assert(Pets.TryRescue(player, id), "Rescue next pet")
	moveTo(plot.Intake.CFrame)
	model:PivotTo(plot.Frame * CFrame.new(0, 1, 5))
	assert(Pets.TryDeliver(player, id), "Deliver next pet")
	assert(plot.Model:GetAttribute("PetCount") == expected, "Independent kennel spaces")
end
task.wait(0.6)
local fourth = available()
moveTo(fourth:GetPivot() + Vector3.new(0, 3, 0))
ok, reason = Pets.TryBeginRescue(player, fourth:GetAttribute("PetId"))
assert(not ok and reason == "ShelterFull", "Fourth pet rejected")
moveTo(first:GetPivot() + Vector3.new(0, 3, 0))
local reward = first:GetAttribute("AdoptionValue")
assert(Pets.TryAdopt(player, firstId), "Adopt owned nearby pet")
local deadline = os.clock() + 65
while first.Parent and os.clock() < deadline do task.wait(0.2) end
assert(plot.Model:GetAttribute("PetCount") == 2 and not first.Parent, "Release frees bed and model")
assert(not firstSuite:GetAttribute("Occupied"), "Adoption frees housing suite")
task.wait(0.6)
moveTo(fourth:GetPivot() + Vector3.new(0, 3, 0))
earnTrust(fourth)
assert(Pets.TryRescue(player, fourth:GetAttribute("PetId")), "Released space reusable")
Pets.CancelFollowing(player)
assert(plot.Model:GetAttribute("ReservedCount") == 0 and plot.Model:GetAttribute("PetCount") == 2, "Cancel transport keeps sheltered pets")
away()
task.wait(5.5)
assert(world.Model:GetAttribute("AvailablePetCount") == Config.AvailablePets, "Habitat pets replenish")
assert(world.Model:GetAttribute("TotalPetCount") <= Config.MaxPets, "Population is bounded")
assert(cash.Value == 75 + reward, "Adoption credits the server-calculated reward once")
print("PASS: Studio solo service smoke tests. Two intentional rollback warnings are expected.")
