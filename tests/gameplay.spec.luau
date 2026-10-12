local Config = require("../src/shared/Config/GameConfig")
local Catalog = require("../src/shared/Pets/PetCatalog")
local Assets = require("../src/shared/Pets/PetAssets")
local Progression = require("../src/shared/Pets/PetProgression")
local Food = require("../src/server/Food/FoodState")
local Data = require("../src/server/Persistence/ProfileData")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end

local food = Food.new(Config, 0)
check(food:Produce(0, true), "Immediate active drop")
for i = 1, 1000 do assert(not food:Produce(0.001, true), "Spam bypassed cooldown") end
check(#food.Pending == 1, "1000 spam requests produce one item")
check(not food:Produce(0.749, true) and food:Produce(0.75, true), "Manual cooldown exact boundary")
for tick = 1, 10000 do
	local now = tick / 20
	food:Step(now); food:Produce(now, true)
	assert(#food.Pending <= Config.MaxVisibleFoodItems)
	local pending = food.Ready
	for _, drop in food.Pending do pending += drop.Amount end
	assert(pending <= Config.FoodBinCapacity)
end
check(food.Ready == Config.FoodBinCapacity and #food.Pending == 0, "Long spam run bounded")
check(food.Amount == 0, "No automatic storage credit")

local petA, petB = { Level = 1, XP = 0, NextFeedAt = 1000 }, { Level = 1, XP = 0, NextFeedAt = 0 }
local ok, reason, remaining = Progression.CanGainFeedingXP(petA, 820, Config)
check(not ok and reason == "FeedingCooldown" and remaining == 180, "Three minute pet cooldown")
check(not Progression.CanGainFeedingXP(petA, 999, Config), "No XP early")
check(Progression.CanGainFeedingXP(petA, 1000, Config), "Exact expiry eligible")
check(Progression.CanGainFeedingXP(petB, 820, Config), "Another pet is independent")
petB.Level = Config.MaxPetLevel
check(not Progression.CanGainFeedingXP(petB, 820, Config), "Max level consumes no meal")

local counts = {}
math.randomseed(771)
for _ = 1, 100000 do
	local def, variant = Catalog.Roll(math.random, Config.RarityWeights, "RescuePark")
	assert(Catalog.Get(def.DefinitionId, variant.Id) == def)
	counts[variant.Rarity] = (counts[variant.Rarity] or 0) + 1
end
for rarity, weight in Config.RarityWeights do check(math.abs(counts[rarity] / 1000 - weight) < 0.6, "Weighted rarity distribution: " .. rarity) end
check(#Catalog.Entries == 24 and #Catalog.Definitions == 13, "Expanded manageable catalog")
for _, def in Catalog.Definitions do
	for _, level in { 1, 5, 10, 20 } do
		local stage = Progression.GetModelStage(def, level)
		check(stage.MinLevel == level and Assets[stage.ModelKey] ~= nil, "Every tier has a registry key")
	end
end
local def, variant = Catalog.Get("GoldenRetriever", "Golden")
local alternate = { ModelOverrides = { ["GoldenRetriever.Puppy"] = "Custom.Puppy" } }
check(Progression.GetModelStage(def, 1, alternate).ModelKey == "Custom.Puppy" and Progression.GetModelStage(def, 1).ModelKey == "GoldenRetriever.Puppy", "Variant model override preserves definition")
check(Progression.GetAdoptionValue(def, "Common", 5, Config, variant) > Progression.GetAdoptionValue(def, "Common", 1, Config, variant), "Raising a pet increases value")

local data = Data.New(Config)
data.Purchased = true
data.Food.Stored, data.Food.Pending = 12, 5
data.Pets = { { Id = "stable-identity", DefinitionId = def.DefinitionId, Variant = variant.Id, Rarity = variant.Rarity, Level = 5, XP = 3, NextFeedAt = 1000 } }
data.Index["GoldenRetriever:Golden"] = { BestLevel = 5, TotalDiscovered = 1 }
local copy = Data.Validate(data, Config, Catalog)
check(copy.Pets[1].Id == "stable-identity" and copy.Pets[1].NextFeedAt == 1000 and copy.Food.Stored == 12, "Progression/cooldown/storage round trip")
data.Pets = {} -- completed adoption
copy = Data.Validate(data, Config, Catalog)
check(copy.Index["GoldenRetriever:Golden"].BestLevel == 5, "Adoption retains discovery")
copy.Index["GoldenRetriever:Golden"].BestLevel = 10
check(data.Index["GoldenRetriever:Golden"].BestLevel == 5, "Save snapshot is independent")
for _, value in { -1, math.huge, 0/0, "100", 1000000001 } do
	local invalid = table.clone(data); invalid.Cash = value
	check(not pcall(Data.Validate, invalid, Config, Catalog), "Invalid saved cash fails closed")
end
local invalid = table.clone(data); invalid.Version = 999
check(not pcall(Data.Validate, invalid, Config, Catalog), "Future schema is never reset")
invalid = table.clone(data); invalid.Pets = { { Id = "x", DefinitionId = "Unknown", Variant = "Unknown" } }
check(not pcall(Data.Validate, invalid, Config, Catalog), "Unknown assets cannot silently erase pets")
check(Data.CanAcquire(nil, "A", 1), "New session")
check(not Data.CanAcquire({ Token = "A", Expires = 100 }, "B", 99), "Concurrent server blocked")
check(Data.CanAcquire({ Token = "A", Expires = 100 }, "B", 100), "Expired session recoverable")
check(not Data.Owns({ Token = "B", Expires = 200 }, "A"), "Stale writer cannot save")
print("PASS: " .. checks .. " gameplay checks, 100,000 rarity rolls and 10,000 bounded production steps")
