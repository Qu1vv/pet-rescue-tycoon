local Config = require("../src/shared/Config/GameConfig")
local Upgrades = require("../src/shared/Config/ShelterUpgrades")
local Data = require("../src/server/Persistence/ProfileData")
local Catalog = require("../src/shared/Pets/PetCatalog")
local Geometry = require("../src/shared/Pets/PetGeometry")
local Progression = require("../src/shared/Pets/PetProgression")
local Styles = require("../src/shared/Pets/RarityStyles")
local checks = 0
local function check(value, message) checks += 1; assert(value, message) end

local levels, other = Upgrades.New(), Upgrades.New()
levels.Beds = 2
check(other.Beds == 0 and Upgrades.Next(levels, "Beds", Config) == nil, "Independent levels and completed branch")
check(Upgrades.Next(levels, "Unknown", Config) == nil, "Unknown branch has no purchase")
levels.Pantry, levels.Storage, levels.Care = 2, 2, 2
local stats = Upgrades.Stats(levels, Config)
check(stats.FoodProductionInterval == 1.75 and stats.FoodStorageCapacity == 175 and stats.FoodBinCapacity == 100, "Maximum food upgrades")
check(stats.FeedingXPReward == 30 and stats.FeedingXPCooldown == 180, "Care increases reward without bypassing cooldown")
check(Config.FoodStorageCapacity == 50 and Config.FeedingXPReward == 20, "Derived stats do not alter defaults")

local legacy = { Version = 1, Cash = 321, Purchased = true, Capacity = 6, Food = { Stored = 40, Pending = 30 },
 Pets = { { Id = "keep-this-id", DefinitionId = "GoldenRetriever", Variant = "Golden", Rarity = "Common", Level = 5, XP = 3, NextFeedAt = 1234 } },
 Index = { ["GoldenRetriever:Golden"] = { BestLevel = 5, TotalDiscovered = 2 } } }
local migrated = Data.Validate(legacy, Config, Catalog)
check(migrated.Version == 5 and migrated.Upgrades.Beds == 1 and migrated.Upgrades.Care == 0, "Legacy six-bed profile migrates")
check(migrated.Cash == 321 and migrated.Pets[1].Id == "keep-this-id" and migrated.Pets[1].XP == 3 and migrated.Pets[1].NextFeedAt == 1234, "Migration preserves economy and pet identity/progression")
check(migrated.Index["GoldenRetriever:Golden"].TotalDiscovered == 2 and migrated.Food.Pending == 30, "Migration preserves discoveries and food")
local modern = Data.New(Config)
modern.Purchased, modern.Upgrades, modern.Capacity = true, levels, 8
modern.Food = { Stored = 175, Pending = 100 }
check(Data.Validate(modern, Config, Catalog).Capacity == 8, "Expanded shelter and food round-trip")
modern.Food.Stored = 176
check(not pcall(Data.Validate, modern, Config, Catalog), "Storage overflow rejected")
modern.Food.Stored, modern.Capacity = 175, 6
check(not pcall(Data.Validate, modern, Config, Catalog), "Capacity must match bed tier")
modern.Capacity, levels.Care = 8, 3
check(not pcall(Data.Validate, modern, Config, Catalog), "Unknown upgrade tier rejected")
levels.Care = 2

math.randomseed(481)
for _, zone in { "DogPark", "Orchard", "Forest" } do
 for _ = 1, 5000 do
  local def, variant = Catalog.Roll(math.random, Config.RarityWeights, zone)
  assert(def.Habitat == zone and table.find(def.Variants, variant), "Cross-habitat spawn")
 end
 check(true, "Habitat roll eligibility: " .. zone)
end
check(not pcall(Catalog.Roll, math.random, Config.RarityWeights, "Unknown"), "Unknown zone fails explicitly")
for _, entry in Catalog.Entries do
 for _, level in { 1, 5, 10, 20 } do
  local stage = Progression.GetModelStage(entry.Definition, level, entry.Variant)
  local parts, names = Geometry.Build(entry.Definition, entry.Variant, stage), {}
  assert(#parts > 15 and #parts < 70, "Visual complexity bounded")
  for _, part in parts do
   names[part.Name] = true
   for _, n in part.Size do assert(n > 0 and n < 20) end
   for _, n in part.Position do assert(n == n and math.abs(n) < 20) end
   for _, n in part.Color do assert(n >= 0 and n <= 255 and n % 1 == 0) end
  end
  check(names.Head and names.Collar, "Every variant/stage has a readable head and leash collar")
 end
end
for rank, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
 check(Styles[rarity].Rank == rank, "Consistent rarity display order")
end
check(Config.RunSpeed > Config.WalkSpeed and Config.FollowSpeed > Config.RunSpeed, "Rescue pets can follow sprinting owners")
print("PASS: " .. checks .. " M4 migration, upgrade, habitat, geometry and rarity checks")

