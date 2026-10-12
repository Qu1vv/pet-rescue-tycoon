local Config = require("../src/shared/Config/GameConfig")
local Trust = require("../src/shared/Pets/RescueTrust")
local Progression = require("../src/shared/Pets/PetProgression")
local Catalog = require("../src/shared/Pets/PetCatalog")
local Profiles = require("../src/server/Persistence/ProfileData")

local checks = 0
local function check(value, message) checks += 1; assert(value, message) end

-- A player can always earn trust without food, while treats shorten the encounter.
for rarity in Config.RarityWeights do
	local initial = Trust.Initial(rarity, "Gentle", Config)
	check(initial < Config.TrustRequired and initial > 0, rarity .. " starts below ready")
	local calm = initial
	for _ = 1, 6 do calm = math.min(Config.TrustRequired, calm + Trust.Gain("Calm", "Gentle", false, Config)) end
	check(calm == Config.TrustRequired, rarity .. " can be rescued without food")
end
check(Trust.Initial("Common", "Gentle", Config) > Trust.Initial("Mythic", "Gentle", Config), "Rarity affects difficulty")
check(Trust.Initial("Common", "Gentle", Config) > Trust.Initial("Common", "Sleepy", Config), "Personality affects start")
check(Trust.Gain("Treat", "Sleepy", false, Config) > Trust.Gain("Calm", "Sleepy", false, Config), "Treats accelerate trust")
check(Trust.Gain("Calm", "Gentle", true, Config) < Trust.Gain("Calm", "Gentle", false, Config), "Rushing reduces gain")
check(Trust.Initial("Rare", "Shy", Config) < Trust.Initial("Rare", "Gentle", Config), "Shy pets need more patience")
check(Trust.RetreatDistance("Skittish", Config) > Trust.RetreatDistance("Gentle", Config), "Skittish pets retreat farther")
check(Trust.Mood(20, Config) == "Nervous" and Trust.Mood(70, Config) == "Cautious"
	and Trust.Mood(100, Config) == "Ready", "Readable rescue states")

local definition, variant = Catalog.Get("GoldenRetriever", "Golden")
local baseline = Progression.GetAdoptionValue(definition, "Common", 3, Config, variant, 60)
local cared = Progression.GetAdoptionValue(definition, "Common", 3, Config, variant, 100)
check(cared > baseline and cared <= math.floor(baseline * 1.16), "Care adds a modest payout")
check(Trust.Happiness(98, 10, Config) == 100 and Trust.Happiness(5, -10, Config) == 0, "Happiness remains bounded")

local profile = Profiles.New(Config)
profile.Purchased = true
profile.Pets = {{ Id = "m9-pet", DefinitionId = "GoldenRetriever", Variant = "Golden", Rarity = "Common",
	Level = 3, XP = 1, NextFeedAt = 0, Happiness = 91 }}
local saved = Profiles.Validate(profile, Config, Catalog)
check(saved.Pets[1].Happiness == 91 and saved.Pets[1].Id == "m9-pet", "Happiness persists with identity")
local legacy = table.clone(profile)
legacy.Version = 4
legacy.Pets = { table.clone(profile.Pets[1]) }
legacy.Pets[1].Happiness = nil
check(Profiles.Validate(legacy, Config, Catalog).Pets[1].Happiness == Config.StartingPetHappiness, "Legacy pets receive a safe default")
local invalid = table.clone(profile)
invalid.Pets = { table.clone(profile.Pets[1]) }
invalid.Pets[1].Happiness = 101
check(not pcall(Profiles.Validate, invalid, Config, Catalog), "Invalid happiness is rejected")

print("PASS: " .. checks .. " M9 trust, care value and save migration checks")
