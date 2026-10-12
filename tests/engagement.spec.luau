local Config = require("../src/shared/Config/GameConfig")
local Upgrades = require("../src/shared/Config/ShelterUpgrades")
local PetCare = require("../src/shared/Pets/PetCare")
local Requests = require("../src/shared/Pets/AdoptionRequests")
local Catalog = require("../src/shared/Pets/PetCatalog")
local ProfileData = require("../src/server/Persistence/ProfileData")

local checks = 0
local function check(value, message) checks += 1; assert(value, message) end

check(#PetCare.Personalities == 8, "Configured personality pool")
for _, name in PetCare.Personalities do check(PetCare.IsPersonality(name), "Valid personality " .. name) end
check(not PetCare.IsPersonality("ClientMadeUp"), "Unknown personality rejected")
for id, action in PetCare.Actions do
	check(action.XP > 0 and action.Cooldown >= 45, id .. " is bounded")
end

local pet = { CareCooldowns = {} }
local reward = PetCare.Commit(pet, "Brush", 1000, 1.35)
check(reward == 11, "Care multiplier rounds centrally")
local ready, reason, remaining = PetCare.CanPerform(pet, "Brush", 1001)
check(not ready and reason == "CareCooldown" and remaining == 179, "Per-pet care deadline")
check(PetCare.CanPerform({ CareCooldowns = {} }, "Brush", 1001), "Another pet remains eligible")
check(not PetCare.CanPerform(pet, "Unknown", 1001), "Unknown care rejected")

local values = { 0.1, 0.123, 0 }
local index = 0
local request = Requests.Roll(function() index += 1; return values[index] end, 2000)
check(request.Kind == "Species" and request.Value == "Dog", "Species request roll")
check(request.ExpiresAt == 2000 + Requests.Duration, "Request expiry")
local dog = { Definition = { Species = "Dog" }, Rarity = "Common", Level = 1 }
local cat = { Definition = { Species = "Cat" }, Rarity = "Rare", Level = 9 }
check(Requests.Matches(request, dog) and not Requests.Matches(request, cat), "Species matching")
local offer, bonus, matched = Requests.GetOffer(request, dog, 100)
check(offer == 135 and bonus == 35 and matched, "Matching request bonus")
check(Requests.GetOffer(request, cat, 100) == 100, "Normal adoption remains available")

local baseStats = Upgrades.Stats(Upgrades.New(), Config)
local careStats = Upgrades.Stats({ Beds = 0, Pantry = 0, Storage = 0, Care = 2 }, Config)
check(baseStats.CareMultiplier == 1 and careStats.CareMultiplier == 1.35, "Care upgrade multiplier")
check(careStats.FeedingXPReward == 30, "Care upgrade feeding benefit")

local profile = ProfileData.New(Config)
check(profile.Version == 5, "Current profile schema")
profile.Purchased = true
profile.Pets = {{
	Id = "stable-pet", DefinitionId = "GoldenRetriever", Variant = "Golden", Rarity = "Common",
	Level = 2, XP = 1, NextFeedAt = 1234, CustomName = "Buddy", Personality = "Playful",
	Locked = true, CareCooldowns = { Pet = 10, Brush = 20, Play = 30, Walk = 40 },
}}
local validated = ProfileData.Validate(profile, Config, Catalog)
local saved = validated.Pets[1]
check(saved.CustomName == "Buddy" and saved.Personality == "Playful" and saved.Locked, "Pet identity persists")
check(saved.CareCooldowns.Walk == 40, "Care deadlines persist")

local legacy = ProfileData.New(Config)
legacy.Version = 3
legacy.Purchased = true
legacy.Pets = {{
	Id = "old-pet", DefinitionId = "HouseCat", Variant = "Orange", Rarity = "Common",
	Level = 1, XP = 0, NextFeedAt = 0,
}}
local migrated = ProfileData.Validate(legacy, Config, Catalog)
check(migrated.Version == 5 and migrated.Pets[1].Personality == "Gentle", "Version 3 identity migration")
check(not migrated.Pets[1].Locked and migrated.Pets[1].CareCooldowns.Pet == 0, "Legacy defaults are safe")

local corrupt = table.clone(profile)
corrupt.Pets = { table.clone(profile.Pets[1]) }
corrupt.Pets[1].Personality = "Injected"
check(not pcall(ProfileData.Validate, corrupt, Config, Catalog), "Corrupt personality fails closed")

local hourlyFood = math.floor(3600 / Config.FoodProductionInterval) * Config.FoodPerDrop
check(hourlyFood > 0 and Config.FoodStorageCapacity < hourlyFood, "Collection remains relevant")
check(Config.StartingCash >= Config.KennelCost, "New players can enter the rescue loop")
check(Config.MaxPetCapacity > Config.PetCapacity, "Capacity upgrades remain meaningful")

print("PASS: " .. checks .. " engagement, care, requests and persistence checks")
