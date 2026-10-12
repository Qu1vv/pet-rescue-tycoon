local Config = require("../src/shared/Config/GameConfig")
local Upgrades = require("../src/shared/Config/ShelterUpgrades")
local Rewards = require("../src/shared/Config/Rewards")
local Biomes = require("../src/shared/Config/Biomes")
local Audio = require("../src/shared/Config/Audio")
local Catalog = require("../src/shared/Pets/PetCatalog")
local Assets = require("../src/shared/Pets/PetAssets")
local Contract = require("../src/shared/Pets/PetModelContract")
local Movement = require("../src/shared/Pets/MovementProfiles")
local Animations = require("../src/shared/Pets/AnimationProfiles")
local Styles = require("../src/shared/Pets/RarityStyles")
local PetCare = require("../src/shared/Pets/PetCare")
local Requests = require("../src/shared/Pets/AdoptionRequests")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- Validates all stable catalog identifiers and their replaceable model-stage mappings.
local definitionIds, entryKeys, assetKeys = {}, {}, {}
for _, definition in Catalog.Definitions do
	check(type(definition.DefinitionId) == "string" and definition.DefinitionId ~= "", "Definition has stable ID")
	check(not definitionIds[definition.DefinitionId], "Duplicate definition ID: " .. definition.DefinitionId)
	definitionIds[definition.DefinitionId] = true
	check(Catalog.ById[definition.DefinitionId] == definition, "ById points to definition")
	check(type(definition.DisplayName) == "string" and definition.DisplayName ~= "", "Definition has display name")
	check(type(definition.BaseAdoptionValue) == "number" and definition.BaseAdoptionValue > 0, "Positive adoption base")
	check(type(definition.SpawnWeight) == "number" and definition.SpawnWeight > 0, "Positive definition weight")
	check(Movement.Get(definition.MovementProfile).Mode ~= nil, "Movement profile resolves")
	check(Animations.Validate(definition.AnimationProfile), "Animation profile validates")
	check(Contract.ValidateDefinition(definition, Assets, Movement, Animations), "Definition model contract validates")

	local variantIds, lastLevel = {}, 0
	for _, coat in definition.Variants do
		check(type(coat.Id) == "string" and coat.Id ~= "" and not variantIds[coat.Id], "Unique variant in " .. definition.DefinitionId)
		variantIds[coat.Id] = true
		check(Styles[coat.Rarity] ~= nil and Config.RarityMultipliers[coat.Rarity] ~= nil, "Variant rarity configured")
		check(type(coat.Weight) == "number" and coat.Weight > 0, "Positive variant weight")
		check(type(coat.AdoptionMultiplier) == "number" and coat.AdoptionMultiplier > 0, "Positive variant multiplier")
	end
	for _, stage in definition.ModelProgression do
		check(type(stage.MinLevel) == "number" and stage.MinLevel % 1 == 0 and stage.MinLevel > lastLevel, "Strict model level thresholds")
		check(stage.MinLevel >= 1 and stage.MinLevel <= Config.MaxPetLevel, "Model threshold inside level range")
		lastLevel = stage.MinLevel
		check(type(stage.ModelKey) == "string" and stage.ModelKey == stage.AssetKey, "Stable model and asset key")
		local asset = Assets.Get(stage.AssetKey)
		check(asset ~= nil and asset.DefinitionId == definition.DefinitionId, "Stage resolves correct asset")
		check(not assetKeys[stage.AssetKey], "Stage asset key used once")
		assetKeys[stage.AssetKey] = true
	end
end

for _, entry in Catalog.Entries do
	check(type(entry.Key) == "string" and not entryKeys[entry.Key], "Unique index key: " .. entry.Key)
	entryKeys[entry.Key] = true
	local definition, coat = Catalog.Get(entry.Definition.DefinitionId, entry.Variant.Id)
	check(definition == entry.Definition and coat == entry.Variant, "Catalog lookup round trip")
	check(entry.Rarity == entry.Variant.Rarity, "Entry rarity agrees with variant")
end

-- Validates habitat pools, spawn points, rarity weights, and audio ambience references.
local totalActive = 0
for biomeId, biome in Biomes do
	check(biome.Id == biomeId and biome.Name ~= "", "Biome identity")
	check(type(biome.Center) == "table" and #biome.Center == 3, "Biome center")
	check(type(biome.Points) == "table" and #biome.Points == biome.MaxActive, "Biome points equal active cap")
	check(type(biome.Route) == "table" and #biome.Route >= 2, "Biome route")
	check(type(Audio.Cues[biome.Ambience]) == "table" and Audio.Cues[biome.Ambience].Category == "World", "Biome ambience cue")
	local weight, eligible = 0, 0
	for rarity, value in biome.RarityWeights do
		check(Styles[rarity] ~= nil and value > 0, "Biome rarity configured")
		weight += value
	end
	for _, entry in Catalog.Entries do
		if biome.Species[entry.Definition.Species] and table.find(entry.Definition.SpawnZones, biomeId) then eligible += 1 end
	end
	check(weight > 0 and eligible > 0, "Biome has eligible weighted pets")
	totalActive += biome.MaxActive
end
check(totalActive == Config.AvailablePets, "Configured available population equals biome caps")

-- Validates monotonic upgrade branches and their centrally derived final values.
local previousCapacity = Config.PetCapacity
for branch, tiers in Config.Upgrades do
	check(#tiers > 0, "Upgrade branch is not empty: " .. branch)
	local previousCost = 0
	for index, tier in tiers do
		check(type(tier.Title) == "string" and tier.Title ~= "", "Upgrade title")
		check(type(tier.Cost) == "number" and tier.Cost % 1 == 0 and tier.Cost > previousCost, "Upgrade costs increase")
		previousCost = tier.Cost
		if branch == "Beds" then
			check(tier.Capacity > previousCapacity, "Bed capacity increases")
			previousCapacity = tier.Capacity
		elseif branch == "Pantry" then
			check(tier.Interval > 0 and tier.Interval < Config.FoodProductionInterval, "Pantry improves production")
		elseif branch == "Storage" then
			check(tier.Capacity > Config.FoodStorageCapacity and tier.BinCapacity > Config.FoodBinCapacity, "Storage improves both capacities")
		elseif branch == "Care" then
			check(tier.FeedingXP > Config.FeedingXPReward and tier.CareMultiplier > 1, "Care tier improves XP")
		end
	end
end
local finalLevels = {}
for branch, tiers in Config.Upgrades do finalLevels[branch] = #tiers end
local finalStats = Upgrades.Stats(finalLevels, Config)
check(finalStats.FoodStorageCapacity >= Config.FoodStorageCapacity, "Final storage stats resolve")
check(finalStats.FeedingXPReward >= Config.FeedingXPReward, "Final care stats resolve")
check(Config.MaxPetCapacity == Config.Upgrades.Beds[#Config.Upgrades.Beds].Capacity, "Maximum capacity derives from final tier")

-- Validates reward identifiers and event references used by the server event bus.
local validEvents = { Rescue = true, Feed = true, CollectFood = true, Care = true, Upgrade = true, Adopt = true, Discover = true, Visit = true, Deliver = true, Generate = true }
local rewardIds = {}
for _, quest in Rewards.Dailies do
	check(not rewardIds[quest.Id], "Unique daily ID")
	rewardIds[quest.Id] = true
	check(validEvents[quest.Event] and quest.Target > 0 and quest.Cash >= 0, "Valid daily event and values")
end
for _, milestone in Rewards.Milestones do
	check(not rewardIds[milestone.Id], "Unique milestone ID")
	rewardIds[milestone.Id] = true
	check(milestone.Target > 0 and milestone.Cash >= 0, "Valid milestone values")
end
for _, step in Rewards.Guided do
	check(validEvents[step.Event] and type(step.Title) == "string" and step.Title ~= "", "Valid guided objective")
end

-- Validates all care, adopter request, rarity, and audio configuration references.
for actionId, action in PetCare.Actions do
	check(type(actionId) == "string" and action.Title ~= "", "Care action identity")
	check(action.XP > 0 and action.Cooldown >= Config.PurchaseCooldown, "Care reward and cooldown")
end
for _, personality in PetCare.Personalities do check(PetCare.IsPersonality(personality), "Personality lookup") end
for _, species in Requests.Species do
	local found = false
	for _, definition in Catalog.Definitions do if definition.Species == species then found = true end end
	check(found, "Adopter species exists in catalog")
end
for _, rarity in Requests.Rarities do check(Styles[rarity] ~= nil, "Adopter rarity exists") end
for _, level in Requests.Levels do check(level >= 1 and level <= Config.MaxPetLevel, "Adopter level is reachable") end
for cueId, cue in Audio.Cues do
	check(Audio.Categories[cue.Category] ~= nil, "Audio cue category: " .. cueId)
	check(cue.Cooldown == nil or cue.Cooldown >= 0, "Audio cue cooldown")
	check(cue.SoundId == nil or string.match(cue.SoundId, "^rbxassetid://%d+$") ~= nil, "Approved audio ID format")
end

print("PASS: " .. checks .. " content configuration and reference checks")
