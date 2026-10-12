-- Paste into SERVER Command Bar in fresh solo Studio Play; disposable profiles only.
-- Exercises actual pad polling, not direct claim/purchase calls. No saved data is changed.
local Server = game.ServerScriptService.Server
local Config = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local Shelter = require(Server.Shelter.ShelterService)
local Movement = require(Server.Players.MovementService)
local Builder = require(Server.World.PlotBuilder)
local players = game.Players:GetPlayers()
assert(game:GetService("RunService"):IsStudio() and not Config.StudioPersistence, "Disposable Studio test only")
assert(#players == 1, "Fresh solo Play required")
local player = players[1]
assert(player:GetAttribute("ProfileReady") and player.Character, "Wait for loading")
assert(not Shelter.GetPlot(player), "Restart Play before this test")
local world = Shelter.GetWorld()
local plot = world.Plots[1]
local function enter(zone)
 player.Character:PivotTo(world.Spawn.CFrame + Vector3.new(0, 4, 0))
 task.wait(Config.PurchaseCooldown + Config.PadInterval + 0.1)
 player.Character:PivotTo(zone.CFrame)
 task.wait(Config.PadInterval * 3)
end
enter(plot.ClaimZone)
assert(Shelter.GetPlot(player) == plot and player.RespawnLocation == plot.Spawn, "Walk-on claim and respawn assignment")
enter(plot.PurchaseZone)
assert(plot.Kennel and plot.Kennel.Parent == plot.Model and Shelter.GetCash(player) == 75, "Walk-on pad builds and charges once")
task.wait(1)
assert(Shelter.GetCash(player) == 75, "Standing on pad does not charge again")
local originalSlots = Builder.GetSlots(plot, 3)
Shelter.RestoreCash(player, 5000) -- server-only test fixture
local expectedCash = 5000
for _, branch in { "Beds", "Pantry", "Storage", "Care" } do
 for level, tier in Config.Upgrades[branch] do
  enter(plot.UpgradePads[branch].Zone)
  expectedCash -= tier.Cost
  assert(plot.Upgrades[branch] == level and Shelter.GetCash(player) == expectedCash, "Walk-on upgrade: " .. branch)
  assert(plot.Kennel.Parent == plot.Model, "Replacement kennel remains live")
 end
end
assert(Shelter.GetPetCapacity(player).maxPetCapacity == 8, "Eight-bed upgrade")
for i, frame in originalSlots do assert(plot.Slots[i] == frame, "Existing bed transforms remain stable") end
for _, frame in plot.Slots do
 local position = plot.Frame:PointToObjectSpace(frame.Position)
 assert(math.abs(position.X) < 52 and math.abs(position.Z) < 52, "Beds inside plot fence")
end
assert(plot.Model:GetAttribute("FoodCapacity") == 175 and plot.Model:GetAttribute("FoodBinCapacity") == 100, "Storage attributes")
assert(plot.Model:GetAttribute("FoodProductionInterval") == 1.75 and plot.Model:GetAttribute("FeedingXPReward") == 30, "Production/care attributes")
assert(not Movement.SetRunning(player, 999), "Client cannot supply speed")
assert(Movement.SetRunning(player, true), "Valid sprint")
assert(player.Character.Humanoid.WalkSpeed == Config.RunSpeed, "Configured run speed")
assert(Movement.SetRunning(player, false) and player.Character.Humanoid.WalkSpeed == Config.WalkSpeed, "Release immediately restores walking")
assert(#world.SpawnPoints == Config.AvailablePets, "Configured population positions")
print("PASS: M4 walk-on pads, all upgrade tiers, stable beds and server sprint checks. Run studio-economy separately in fresh Play for feeding/adoption.")
