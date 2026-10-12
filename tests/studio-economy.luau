-- SERVER Command Bar, fresh SOLO Studio Play with StudioPersistence=false.
-- About 35 seconds. Uses server-only setup; never paste into a published server.
local Players = game:GetService("Players")
local Server = game.ServerScriptService.Server
local Shelter, Pets, Food = require(Server.Shelter.ShelterService), require(Server.Pets.PetService), require(Server.Food.FoodService)
local Config = require(game.ReplicatedStorage.Shared.Config.GameConfig)
local player = Players:GetPlayers()[1]
assert(game:GetService("RunService"):IsStudio() and not Config.StudioPersistence, "Use disposable Studio data")
assert(#Players:GetPlayers() == 1 and player.Character and player:GetAttribute("ProfileReady"), "Wait for solo loading")
assert(not Shelter.GetPlot(player), "Restart Play for an unclaimed shelter")
local world, plot = Shelter.GetWorld(), Shelter.GetWorld().Plots[1]
local function move(frame) player.Character:PivotTo(frame) end
local function away() move(world.Spawn.CFrame + Vector3.new(0, 4, 0)) end
local function earnTrust(model)
	local id = model:GetAttribute("PetId")
	assert(Pets.TryBeginRescue(player, id), "Trust encounter opens")
	for _ = 1, 6 do
		if model:GetAttribute("Trust") >= Config.TrustRequired then break end
		assert(Pets.TryTrustAction(player, id, "Calm"), "Calm increases trust")
		if model:GetAttribute("Trust") < Config.TrustRequired then task.wait(Config.TrustActionCooldown + 0.1) end
	end
	assert(model:GetAttribute("Trust") >= Config.TrustRequired, "Pet is ready for leash")
end
move(plot.ClaimZone.CFrame); assert(Shelter.TryClaim(player, 1)); away(); task.wait(0.6)
move(plot.PurchaseZone.CFrame); assert(Shelter.TryPurchase(player, 1)); away()
assert(player.leaderstats.ShelterCash.Value == 75)
local button, bin = plot.Kennel.GenerateButton, plot.Kennel.FoodCollection
move(button.CFrame + Vector3.new(0, 3, 0))
assert(Food.Interact(player, button), "Manual food drop")
local sequence = plot.Model:GetAttribute("FoodDropSequence")
for _ = 1, 100 do Food.Interact(player, button) end
assert(plot.Model:GetAttribute("FoodDropSequence") == sequence, "Spam cannot create extra drops")
task.wait(Config.FoodTravelSeconds + 0.4)
assert(Food.GetStoredFood(player) == 0 and plot.Model:GetAttribute("PendingFood") >= 1, "Arrivals wait in bin")
move(bin.CFrame + Vector3.new(0, 3, 0))
assert(Food.Interact(player, bin) and Food.GetStoredFood(player) >= 1, "Manual collection")
Food.Restore(player, { Stored = 49, Pending = 5 }) -- controlled test fixture
task.wait(0.3)
assert(Food.Interact(player, bin))
assert(Food.GetStoredFood(player) == 50 and plot.Model:GetAttribute("PendingFood") == 4, "Excess preserved")

local function rescue()
	task.wait(0.6)
	local model
	for _, candidate in world.Pets:GetChildren() do if candidate:GetAttribute("State") == "Available" then model = candidate; break end end
	local id = model:GetAttribute("PetId")
	move(model:GetPivot() + Vector3.new(0, 3, 0)); earnTrust(model); assert(Pets.TryRescue(player, id))
	move(plot.Intake.CFrame); model:PivotTo(plot.Frame * CFrame.new(0, 1, 5)); assert(Pets.TryDeliver(player, id))
	return model, id
end
local pet, id = rescue()
local suite = plot.Kennel.HousingSpaces:FindFirstChild("Suite" .. pet:GetAttribute("HousingSlotId"))
assert(suite and suite:GetAttribute("Occupied") and suite:GetAttribute("PetUniqueId") == id, "Delivered pet occupies a named suite")
local other, otherId = rescue()
local key = pet:GetAttribute("DefinitionId") .. ":" .. pet:GetAttribute("Variant")
local index = player.PetIndex:FindFirstChild(key)
assert(index and not Pets.TryDeliver(player, id), "Discovery exists; repeated delivery rejected")
local discoveries = index:GetAttribute("TotalDiscovered")
local root, art = pet.PrimaryPart, pet:FindFirstChild("Visuals")
move(pet:GetPivot() + Vector3.new(0, 3, 0))
local before = Food.GetStoredFood(player)
assert(Pets.TryFeed(player, id))
assert(Food.GetStoredFood(player) == before - 1 and pet:GetAttribute("Level") == 2, "Food consumed; level-up")
local nextFeed = pet:GetAttribute("NextFeedAt")
assert(math.abs(nextFeed - os.time() - 180) <= 1)
task.wait(0.6)
local ok, reason = Pets.TryFeed(player, id)
assert(not ok and reason == "FeedingCooldown" and Food.GetStoredFood(player) == before - 1, "Cooldown spends no food")
move(other:GetPivot() + Vector3.new(0, 3, 0)); task.wait(0.6)
assert(Pets.TryFeed(player, otherId), "Per-pet independent cooldown")
assert(Pets.AddPetXP(id, 90)) -- level 2 to 5, preserving logical identity
assert(pet:GetAttribute("Level") == 5 and pet:GetAttribute("ModelStage") == 2)
assert(pet.PrimaryPart == root and pet:GetAttribute("PetId") == id and pet:GetAttribute("NextFeedAt") == nextFeed)
assert(pet:FindFirstChild("Visuals") ~= art and index:GetAttribute("BestLevel") == 5)
assert(index:GetAttribute("TotalDiscovered") == discoveries, "XP does not rediscover pets")
local payout, cash = pet:GetAttribute("AdoptionValue"), player.leaderstats.ShelterCash.Value
move(pet:GetPivot() + Vector3.new(0, 3, 0))
assert(Pets.TryAdopt(player, id))
assert(pet:GetAttribute("State") == "Adopting" and player.leaderstats.ShelterCash.Value == cash and plot.Model:GetAttribute("PetCount") == 2, "No early reward/capacity")
task.wait(0.6)
assert(not Pets.TryAdopt(player, id) and not Pets.TryFeed(player, id), "Adopting pet locked")
local deadline, sawLeash = os.clock() + Config.AdoptionTimeout + 1, false
while pet.Parent and os.clock() < deadline do
	local npc = plot.Model:FindFirstChild("Adopter")
	if npc and npc:FindFirstChild("AdoptionLeash") then sawLeash = true end
	task.wait(0.1)
end
assert(sawLeash and not pet.Parent and not plot.Model:FindFirstChild("Adopter"), "NPC/leash/pet cleaned after departure")
assert(player.leaderstats.ShelterCash.Value == cash + payout and plot.Model:GetAttribute("PetCount") == 1, "Exactly one payout and free slot")
assert(not suite:GetAttribute("Occupied") and suite:GetAttribute("PetUniqueId") == "", "Adoption clears housing")
assert(player.PetIndex:FindFirstChild(key) and index:GetAttribute("TotalDiscovered") == discoveries, "Discovery survives adoption")
assert(not Pets.TryAdopt(player, id), "Removed pet cannot sell twice")
assert(not Pets.TryFeed(player, {}) and not Pets.TryAdopt(player, {}), "Malformed IDs rejected")
print("PASS: food/manual feeding/progression/index/NPC adoption Studio smoke checks")
