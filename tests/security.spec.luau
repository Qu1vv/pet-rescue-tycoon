local Config = require("../src/shared/Config/GameConfig")
local ShelterState = require("../src/server/Shelter/ShelterState")
local FoodState = require("../src/server/Food/FoodState")
local ProfileData = require("../src/server/Persistence/ProfileData")
local Catalog = require("../src/shared/Pets/PetCatalog")
local Progression = require("../src/shared/Pets/PetProgression")
local PetCare = require("../src/shared/Pets/PetCare")
local Requests = require("../src/shared/Pets/AdoptionRequests")
local RewardState = require("../src/shared/Config/RewardState")
local Rewards = require("../src/shared/Config/Rewards")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end
local function rejected(callback, message)
	local ok = pcall(callback)
	check(not ok, message)
end

-- Interleaves repeated claim races; exactly one player can own a plot or pet reservation.
for round = 1, 100 do
	local state = ShelterState.new(2, 3)
	local first, second = { Id = round * 2 }, { Id = round * 2 + 1 }
	check(state:Claim(first, 1), "First claim wins")
	local claimed, reason = state:Claim(second, 1)
	check(not claimed and reason == "PlotTaken", "Second claim loses deterministically")
	check(not state:Claim(first, 2), "One player cannot own two plots")
	check(state:Claim(second, 2), "Second player can claim another plot")
	local slot = state:Reserve(first, "shared-" .. round)
	check(slot == 1, "Owner reserves unique pet")
	local duplicate, duplicateReason = state:Reserve(second, "shared-" .. round)
	check(duplicate == nil and duplicateReason == "PetUnavailable", "Pet ID cannot be reserved twice")
	check(not state:Commit(second, "shared-" .. round), "Foreign delivery commit rejected")
	check(not state:Free(second, "shared-" .. round), "Foreign slot free rejected")
	check(state:Commit(first, "shared-" .. round), "Owner delivery commits once")
	check(not state:Commit(first, "shared-" .. round), "Duplicate delivery commit rejected")
end

-- Stresses capacity filling, resize boundaries, release cleanup, and stale IDs.
do
	local state = ShelterState.new(1, 3)
	local owner, stranger = {}, {}
	check(state:Claim(owner, 1), "Capacity owner claimed")
	for index = 1, 3 do check(state:Reserve(owner, "pet-" .. index) == index, "Sequential slot reservation") end
	local full, reason = state:Reserve(owner, "overflow")
	check(full == nil and reason == "ShelterFull", "Capacity cannot overflow")
	check(not state:SetCapacity(owner, 2), "Occupied high slot prevents shrinking")
	check(not state:SetCapacity(stranger, 10), "Foreign capacity change rejected")
	check(not state:SetCapacity(owner, 0) and not state:SetCapacity(owner, 2.5), "Invalid capacities rejected")
	check(state:SetCapacity(owner, 6), "Validated upgrade capacity accepted")
	check(state:Reserve(owner, "pet-4") == 4, "Expanded capacity is usable")
	check(state:ReleasePlot(owner) == 1, "Release returns plot")
	check(next(state.Pets) == nil and state.Owners[owner] == nil, "Release removes all authoritative references")
	check(not state:Commit(owner, "pet-1") and not state:Free(owner, "pet-1"), "Stale pet IDs stay invalid")
end

-- Fuzzes food production and collection so client spam cannot bypass cooldowns or limits.
do
	local state = FoodState.new(Config, 0)
	check(state:Produce(0, true), "First manual drop accepted")
	for _ = 1, 1000 do check(not state:Produce(0, true), "Same-timestamp manual spam rejected") end
	local accepted = 1
	for index = 1, 100 do
		if state:Produce(index * Config.ManualGenerateCooldown, true) then accepted += 1 end
	end
	check(accepted <= Config.MaxVisibleFoodItems, "Visible food cap bounds pending drops")
	state:Step(10000)
	check(state.Ready <= Config.FoodBinCapacity, "Settled drops stay within bin")
	state.Amount = Config.FoodStorageCapacity - 1
	local beforeReady = state.Ready
	local moved = state:Collect()
	check(moved <= 1 and state.Amount <= Config.FoodStorageCapacity and state.Ready == beforeReady - moved, "Collection preserves overflow")
	for _, invalid in { -1, 0, 0.5, math.huge, 0 / 0 } do check(not state:TryConsume(invalid), "Invalid food spend rejected") end
end

-- Exercises progression boundaries and confirms payout data never comes from a client.
do
	local definition, coat = Catalog.Get("GoldenRetriever", "Golden")
	local pet = { Level = 1, XP = 0, NextFeedAt = 0, CareCooldowns = {} }
	for _, invalid in { -10, 0, math.huge, 0 / 0 } do
		local level, xp = pet.Level, pet.XP
		check(not Progression.AddPetXP(pet, invalid, Config) and pet.Level == level and pet.XP == xp, "Invalid XP is ignored")
	end
	local common = Progression.GetAdoptionValue(definition, "Common", 1, Config, coat)
	local rare = Progression.GetAdoptionValue(definition, "Rare", 1, Config, coat)
	local leveled = Progression.GetAdoptionValue(definition, "Common", 10, Config, coat)
	check(common > 0 and rare > common and leveled > common, "Server formula rewards rarity and level")
	check(Progression.AddPetXP(pet, 100000, Config) and pet.Level == Config.MaxPetLevel and pet.XP == 0, "XP caps safely")
	check(not Progression.AddPetXP(pet, 10, Config), "Max-level XP cannot overflow")
	local reward = PetCare.Commit({ CareCooldowns = {} }, "Play", 100, 1)
	check(reward == PetCare.Actions.Play.XP, "Care reward comes from central definition")
	check(PetCare.Commit({ CareCooldowns = {} }, "Injected", 100, 1000) == nil, "Unknown care action has no reward")
	local request = Requests.Roll(function() return 0 end, 100)
	local offer = Requests.GetOffer(request, { Definition = definition, Rarity = "Common", Level = 1 }, common)
	check(offer >= common, "Adopter offer never reduces central payout")
end

-- Mutates valid profiles to ensure incompatible, duplicated, or inflated saves fail closed.
do
	local valid = ProfileData.New(Config)
	valid.Purchased = true
	valid.Pets = {{
		Id = "secure-pet", DefinitionId = "GoldenRetriever", Variant = "Golden", Rarity = "Common",
		Level = 1, XP = 0, NextFeedAt = 0, Personality = "Gentle", Locked = false,
		CareCooldowns = { Pet = 0, Brush = 0, Play = 0, Walk = 0 },
	}}
	check(ProfileData.Validate(valid, Config, Catalog).Pets[1].Id == "secure-pet", "Valid profile accepted")

	local function corrupt(mutator)
		local profile = ProfileData.New(Config)
		profile.Purchased = true
		profile.Pets = {{
			Id = "secure-pet", DefinitionId = "GoldenRetriever", Variant = "Golden", Rarity = "Common",
			Level = 1, XP = 0, NextFeedAt = 0, Personality = "Gentle", Locked = false,
			CareCooldowns = { Pet = 0, Brush = 0, Play = 0, Walk = 0 },
		}}
		mutator(profile)
		return profile
	end
	rejected(function() ProfileData.Validate(corrupt(function(profile) profile.Version = 999 end), Config, Catalog) end, "Future schema rejected")
	rejected(function() ProfileData.Validate(corrupt(function(profile) profile.Cash = math.huge end), Config, Catalog) end, "Infinite cash rejected")
	rejected(function() ProfileData.Validate(corrupt(function(profile) profile.Pets[1].Rarity = "ClientLegend" end), Config, Catalog) end, "Injected rarity rejected")
	rejected(function() ProfileData.Validate(corrupt(function(profile) table.insert(profile.Pets, table.clone(profile.Pets[1])) end), Config, Catalog) end, "Duplicate identity rejected")
	rejected(function() ProfileData.Validate(corrupt(function(profile) profile.Pets[1].CustomName = string.rep("x", 1000) end), Config, Catalog) end, "Oversized name rejected")
	rejected(function() ProfileData.Validate(corrupt(function(profile) profile.Pets[1].Level = Config.MaxPetLevel + 1 end), Config, Catalog) end, "Inflated level rejected")
	rejected(function() ProfileData.Validate(corrupt(function(profile) profile.Pets[1].CareCooldowns.Play = -1 end), Config, Catalog) end, "Negative deadline rejected")
	rejected(function() ProfileData.Validate(corrupt(function(profile) profile.Capacity = 999 end), Config, Catalog) end, "Invented capacity rejected")
end

-- Verifies one-time reward eligibility under duplicate and malformed client identifiers.
do
	local state = RewardState.New(1)
	local quest = RewardState.Active(1, Rewards)[1]
	RewardState.Record(state, quest.Event, quest.Target, quest.Detail, Rewards)
	check(RewardState.Eligible(state, "Daily", quest.Id, 0, Rewards) == quest, "Completed reward eligible")
	state.Claimed[quest.Id] = true
	check(RewardState.Eligible(state, "Daily", quest.Id, 0, Rewards) == nil, "Claimed reward cannot repeat")
	check(RewardState.Eligible(state, "Daily", "Injected", 1000000, Rewards) == nil, "Unknown reward rejected")
	check(RewardState.Eligible(state, "Collection", "Injected", 1000000, Rewards) == nil, "Unknown collection reward rejected")
end

print("PASS: " .. checks .. " security, race, and malformed-data checks")
