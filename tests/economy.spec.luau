local Config = require("../src/shared/Config/GameConfig")
local Progression = require("../src/shared/Pets/PetProgression")
local Food = require("../src/server/Food/FoodState")
local State = require("../src/server/Shelter/ShelterState")
local count = 0
local function check(value, message) count += 1; assert(value, message) end

local pet = { Level = 1, XP = 0 }
check(Progression.GetXPRequired(1, Config) == 20, "Starting threshold")
check(Progression.GetXPRequired(2, Config) == 25, "Scaling threshold")
check(not Progression.AddPetXP(pet, 10, Config) and pet.XP == 10, "Partial feed XP")
check(Progression.AddPetXP(pet, 10, Config) and pet.Level == 2 and pet.XP == 0, "Exact threshold levels up")
check(Progression.AddPetXP(pet, 75, Config) and pet.Level == 4 and pet.XP == 20, "Multiple levels and remainder")
for _, amount in { -10, 0, math.huge, 0/0, "10" } do
	local level, xp = pet.Level, pet.XP
	check(not Progression.AddPetXP(pet, amount, Config) and pet.Level == level and pet.XP == xp, "Invalid XP rejected")
end
Progression.AddPetXP(pet, 1e9, Config)
check(pet.Level == Config.MaxPetLevel and pet.XP == 0, "Level cap bounded for huge awards")
check(not Progression.AddPetXP(pet, 10, Config), "Max-level pet does not grow")
local def = { BaseAdoptionValue = 25, ModelKey = "Dog", ModelProgression = {
	{ MinLevel = 1, Stage = 1, ModelKey = "Dog" },
	{ MinLevel = 5, Stage = 2, ModelKey = "DogCute" },
	{ MinLevel = 10, Stage = 3, ModelKey = "DogBest" },
} }
check(Progression.GetAdoptionValue(def, "Common", 1, Config) == 25, "Base value")
check(Progression.GetAdoptionValue(def, "Common", 2, Config) == 35, "Level premium rounds down")
check(Progression.GetAdoptionValue(def, "Rare", 2, Config) == 47, "Rarity premium")
check(Progression.GetModelStage(def, 4).ModelKey == "Dog", "Before threshold")
check(Progression.GetModelStage(def, 5).ModelKey == "DogCute", "First visual threshold")
check(Progression.GetModelStage(def, 10).ModelKey == "DogBest", "Second visual threshold")
check(Progression.GetModelStage(def, 20).Stage == 3, "Last stage retained")

local food = Food.new(Config, 0)
check(not food:Step(4) and food.Amount == 0, "No early food")
check(food:Step(5) and food.Amount == 0 and #food.Pending == 1, "Drop creation grants no food")
check(not food:Step(7.9) and food.Amount == 0, "Conveyor travel must finish")
food:Step(5 + Config.FoodTravelSeconds)
check(food.Ready == 1 and food.Amount == 0 and #food.Pending == 0, "Arrival credits bin only")
food:Step(5 + Config.FoodTravelSeconds)
check(food.Ready == 1, "Duplicate step cannot double-credit")
check(food:Collect() == 1 and food.Amount == 1 and food.Ready == 0, "Collection transfers to storage")
check(food:TryConsume(1) and food.Amount == 0, "Feeding consumes one")
check(not food:TryConsume(1) and food.Amount == 0, "No negative food")
for _, amount in { -1, 0, 0.5, math.huge, 0/0, "1" } do
	check(not food:TryConsume(amount), "Invalid food consumption rejected")
end
for time = 9, 1000 do food:Step(time) end
check(food.Ready == Config.FoodBinCapacity and food.Amount == 0 and #food.Pending == 0, "Bin caps and generator pauses")
food:Collect()
check(food:TryConsume(1), "Full storage can be consumed")
for time = 1001, 1010 do food:Step(time) end
check(food.Ready > 0, "Production resumes after collection")
food.Amount = Config.FoodStorageCapacity - 1
food.Ready = 5
check(food:Collect() == 1 and food.Ready == 4 and food.Amount == Config.FoodStorageCapacity, "Excess stays in bin")
check(food:Collect() == 0 and food.Ready == 4, "Full storage never deletes food")
local lagged = Food.new(Config, 0)
lagged:Step(100000)
check(#lagged.Pending == 1 and lagged.Amount == 0, "No catch-up burst after lag")
local reset = Food.new(Config, 100000)
check(reset.Amount == 0 and #reset.Pending == 0, "New owner starts empty")

local session = State.new(6, Config.PetCapacity)
assert(session:Claim("A", 1))
assert(session:Claim("B", 2))
for slot = 1, 3 do assert(session:Reserve("A", "pet" .. slot)); assert(session:Commit("A", "pet" .. slot)) end
local used, maximum, free = session:GetCapacity("A")
check(used == 3 and maximum == 3 and not free, "Full shelter API")
check(session:SetCapacity("A", 6), "Upgrade existing ledger")
used, maximum, free = session:GetCapacity("A")
check(used == 3 and maximum == 6 and free, "Upgrade preserves pets and creates capacity")
local _, otherMax = session:GetCapacity("B")
check(otherMax == 3, "Other plots unaffected")
check(session:Reserve("A", "pet4") == 4, "Fourth reserved bed is usable")
check(not session:SetCapacity("A", 3), "Cannot shrink below occupied slot")
check(session:Free("A", "pet1"), "Adoption frees capacity")
check(not session:Free("A", "pet1"), "Duplicate adoption cannot free another slot")
check(session:Reserve("A", "newPet") == 1, "Collection resumes after adoption")
session:ReleasePlot("A")
session:Claim("C", 1)
used, maximum = session:GetCapacity("C")
check(used == 0 and maximum == 3, "Owner departure resets upgrades")

-- A hungry pet remains unchanged; only a successful food debit grants XP.
local hungry = { Level = 1, XP = 0 }
local empty = Food.new(Config, 0)
if empty:TryConsume(Config.FoodCostPerFeed) then Progression.AddPetXP(hungry, Config.FeedingXPReward, Config) end
check(hungry.Level == 1 and hungry.XP == 0, "No harm or XP when food is absent")
empty:Step(5); empty:Step(5 + Config.FoodTravelSeconds); empty:Collect()
if empty:TryConsume(Config.FoodCostPerFeed) then Progression.AddPetXP(hungry, Config.FeedingXPReward, Config) end
check(hungry.Level == 2 and hungry.XP == 0 and empty.Amount == 0, "Successful meal consumes food and grants XP")
print("PASS: " .. count .. " economy, progression, food and capacity checks")
