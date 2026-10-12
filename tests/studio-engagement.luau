-- Paste into the SERVER Command Bar during a fresh solo Studio Play session.
local Players = game:GetService("Players")
local player = Players:GetPlayers()[1]
assert(player and player.Character and player:GetAttribute("ProfileReady"), "Wait for the player profile")
local Server = game.ServerScriptService.Server
local Shelter = require(Server.Shelter.ShelterService)
local Pets = require(Server.Pets.PetService)
local Food = require(Server.Food.FoodService)
local Requests = require(Server.Pets.AdopterRequestService)
local Rewards = require(Server.Players.RewardService)
local world = Shelter.GetWorld()
local Config = require(game.ReplicatedStorage.Shared.Config.GameConfig)

-- Exercises the same server trust gates as the player-facing rescue dialog.
local function earnTrust(model)
	local id = model:GetAttribute("PetId")
	assert(Pets.TryBeginRescue(player, id))
	for _ = 1, 6 do
		if model:GetAttribute("Trust") >= Config.TrustRequired then break end
		assert(Pets.TryTrustAction(player, id, "Calm"))
		if model:GetAttribute("Trust") < Config.TrustRequired then task.wait(Config.TrustActionCooldown + 0.1) end
	end
end

-- Claim and build through the same server methods used by walk-on pads.
local plot = world.Plots[1]
player.Character:PivotTo(plot.ClaimZone.CFrame)
assert(Shelter.TryClaim(player, 1))
task.wait(0.6)
player.Character:PivotTo(plot.PurchaseZone.CFrame)
assert(Shelter.TryPurchase(player, 1))
assert(Requests.Ensure(player) and plot.Model:GetAttribute("AdopterRequestText") ~= "", "Adopter request appears")

-- Rescue and deliver one pet so identity and care actions have a valid owned target.
local pet
for _, candidate in world.Pets:GetChildren() do
	if candidate:GetAttribute("State") == "Available" then pet = candidate; break end
end
assert(pet, "Expected an available pet")
player.Character:PivotTo(pet:GetPivot() + Vector3.new(0, 3, 0))
earnTrust(pet)
assert(Pets.TryRescue(player, pet:GetAttribute("PetId")))
player.Character:PivotTo(plot.Intake.CFrame)
pet:PivotTo(plot.Frame * CFrame.new(0, 1, 5))
assert(Pets.TryDeliver(player, pet:GetAttribute("PetId")))
local id = pet:GetAttribute("PetId")
player.Character:PivotTo(pet:GetPivot() + Vector3.new(0, 3, 0))

-- Care is server-owned, independently cooled down, and changes progression without consuming food.
Food.Restore(player, { Stored = 5, Pending = 0 })
local foodBefore = Food.GetStoredFood(player)
local happinessBefore = pet:GetAttribute("Happiness")
assert(Pets.TryCare(player, id, "Pet"), "Petting succeeds")
assert(Food.GetStoredFood(player) == foodBefore, "Care does not consume food")
assert(pet:GetAttribute("Happiness") > happinessBefore, "Care increases happiness")
assert(not Pets.TryCare(player, id, "Pet"), "Same care action cannot be spammed")
assert(Pets.TryCare(player, id, "Brush"), "Different care action remains available")

-- Favorite protection blocks adoption; custom names retain the same logical identity.
task.wait(0.6)
assert(Pets.TryFavorite(player, id))
assert(pet:GetAttribute("Favorite") and not Pets.TryAdopt(player, id), "Favorite blocks adoption")
task.wait(0.6)
assert(Pets.TryFavorite(player, id))
task.wait(0.6)
assert(Pets.TryRename(player, id, "Buddy"))
assert(pet:GetAttribute("PetName") == "Buddy" and pet:GetAttribute("PetId") == id, "Rename preserves identity")

-- Exports include new persistent identity/care fields, and tutorial skipping grants no cash.
local exported = Pets.Export(player)[1]
assert(exported.CustomName == "Buddy" and exported.Personality and exported.CareCooldowns.Pet > 0 and exported.Happiness > happinessBefore)
local cash = player.leaderstats.ShelterCash.Value
assert(Rewards.SkipGuide(player) and player:GetAttribute("GuidedObjective") == "")
assert(player.leaderstats.ShelterCash.Value == cash, "Skipping tutorial never awards currency")

-- One upgrade rebuild visibly increments the centralized shelter tier.
Shelter.RestoreCash(player, 1000)
task.wait(0.6)
player.Character:PivotTo(plot.UpgradePads.Beds.Zone.CFrame)
assert(Shelter.TryUpgrade(player, plot.Id, "Beds"))
assert(plot.Model:GetAttribute("ShelterTier") == 1 and plot.Kennel:FindFirstChild("UpgradeBoard"), "Upgrade presentation")

print("PASS: onboarding skip, adopter request, care, favorite, rename, persistence export and upgrade presentation")
