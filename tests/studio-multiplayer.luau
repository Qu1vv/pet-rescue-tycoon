-- SERVER Command Bar in a fresh Studio local server with 2–6 loaded players.
-- Disposable data only. Tests service ownership boundaries; manual walking/lag tests still required.
local Players = game:GetService("Players")
local Server = game.ServerScriptService.Server
local Shelter, Pets, Food = require(Server.Shelter.ShelterService), require(Server.Pets.PetService), require(Server.Food.FoodService)
local Config = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local RewardConfig = require(game.ReplicatedStorage.Shared.Config.Rewards)
local Rewards = require(Server.Players.RewardService)
local Events = require(Server.Common.GameplayEvents)
assert(game:GetService("RunService"):IsStudio() and not Config.StudioPersistence)
local players = Players:GetPlayers()
assert(#players >= 2 and #players <= 6)
local world, owned = Shelter.GetWorld(), {}
local function earnTrust(player, model)
	local id = model:GetAttribute("PetId")
	assert(Pets.TryBeginRescue(player, id))
	for _ = 1, 6 do
		if model:GetAttribute("Trust") >= Config.TrustRequired then break end
		assert(Pets.TryTrustAction(player, id, "Calm"))
		if model:GetAttribute("Trust") < Config.TrustRequired then task.wait(Config.TrustActionCooldown + 0.1) end
	end
end
for i, player in players do
	assert(player:GetAttribute("ProfileReady") and player.Character and not Shelter.GetPlot(player))
	local plot = world.Plots[i]
	player.Character:PivotTo(plot.ClaimZone.CFrame)
	assert(Shelter.TryClaim(player, i))
	player.Character:PivotTo(world.Spawn.CFrame + Vector3.new(0, 4, 0))
end
task.wait(0.6)
for i, player in players do
	local plot = world.Plots[i]
	player.Character:PivotTo(plot.PurchaseZone.CFrame)
	assert(Shelter.TryPurchase(player, i))
	local pet
	for _, model in world.Pets:GetChildren() do if model:GetAttribute("State") == "Available" then pet = model; break end end
	player.Character:PivotTo(pet:GetPivot() + Vector3.new(0, 3, 0))
	earnTrust(player, pet)
	assert(Pets.TryRescue(player, pet:GetAttribute("PetId")))
	player.Character:PivotTo(plot.Intake.CFrame)
	pet:PivotTo(plot.Frame * CFrame.new(0, 1, 5))
	assert(Pets.TryDeliver(player, pet:GetAttribute("PetId")))
	Food.Restore(player, { Stored = 10, Pending = 3 })
	owned[player] = pet
end
local intruder, owner = players[1], players[2]
local pet, plot = owned[owner], Shelter.GetPlot(owner)
intruder.Character:PivotTo(pet:GetPivot() + Vector3.new(0, 3, 0))
local id = pet:GetAttribute("PetId")
assert(not Pets.TryFeed(intruder, id) and not Pets.TryAdopt(intruder, id), "Foreign pet protected")
assert(not Pets.TryCare(intruder, id, "Pet") and not Pets.TryFavorite(intruder, id) and not Pets.TryRename(intruder, id, "Stolen"), "Foreign identity and care protected")
assert(Food.GetStoredFood(owner) == 10 and pet:GetAttribute("Level") == 1)
intruder.Character:PivotTo(plot.Kennel.FoodCollection.CFrame + Vector3.new(0, 3, 0))
assert(not Food.Interact(intruder, plot.Kennel.FoodCollection), "Foreign bin protected")
task.wait(0.3)
intruder.Character:PivotTo(plot.Kennel.GenerateButton.CFrame + Vector3.new(0, 3, 0))
assert(not Food.Interact(intruder, plot.Kennel.GenerateButton), "Foreign generator protected")
owner.Character:PivotTo(pet:GetPivot() + Vector3.new(0, 3, 0))
assert(Pets.TryFeed(owner, id), "Owner can feed")
local cash = owner.leaderstats.ShelterCash.Value
assert(Pets.TryAdopt(owner, id))
task.wait(1)
require(Server.Pets.AdoptionService).Cancel(owner)
assert(pet:GetAttribute("State") == "Sheltered" and plot.Model:GetAttribute("PetCount") == 1)
assert(owner.leaderstats.ShelterCash.Value == cash and not plot.Model:FindFirstChild("Adopter"), "Cancelled adopter leaves pet and cash intact")
for _, player in players do assert(Shelter.GetPetCapacity(player).currentPetCount == 1 and player.leaderstats.ShelterCash.Value == 75) end

-- Drive one active daily through the server event bus and verify another player's row cannot change.
local questOwner, otherPlayer = players[1], players[2]
local dailyRow
for _, row in questOwner.RescueGoals:GetChildren() do
	if row:GetAttribute("Kind") == "Daily" then dailyRow = row; break end
end
assert(dailyRow, "Expected one active daily goal")
local definition
for _, quest in RewardConfig.Dailies do if quest.Id == dailyRow.Name then definition = quest; break end end
assert(definition, "Active daily must exist in shared configuration")
local otherRow = otherPlayer.RescueGoals:FindFirstChild(dailyRow.Name)
local otherProgress = otherRow and otherRow:GetAttribute("Progress") or 0
Events.Emit(questOwner, definition.Event, definition.Target, definition.Detail)
assert(dailyRow:GetAttribute("Progress") == definition.Target, "Owner daily reaches its target")
assert((otherRow and otherRow:GetAttribute("Progress") or 0) == otherProgress, "Quest progress is player-isolated")
local ownerCash, otherCash = questOwner.leaderstats.ShelterCash.Value, otherPlayer.leaderstats.ShelterCash.Value
assert(Rewards.Claim(questOwner, "Daily", dailyRow.Name), "Completed owner daily pays once")
assert(questOwner.leaderstats.ShelterCash.Value == ownerCash + definition.Cash and otherPlayer.leaderstats.ShelterCash.Value == otherCash)
task.wait(0.6)
assert(not Rewards.Claim(questOwner, "Daily", dailyRow.Name), "Claimed daily cannot pay twice")
print("PASS: " .. #players .. " isolated shelters, protected actions, adopter cancellation, quest isolation")
