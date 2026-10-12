-- Reject incompatible/corrupt saves instead of silently replacing valuable data.
local ProfileData = {}
local RewardConfig = require(if game then game:GetService("ReplicatedStorage").Shared.Config.Rewards else "../../shared/Config/Rewards")
local RewardState = require(if game then game:GetService("ReplicatedStorage").Shared.Config.RewardState else "../../shared/Config/RewardState")
local PetCare = require(if game then game:GetService("ReplicatedStorage").Shared.Pets.PetCare else "../../shared/Pets/PetCare")
-- Validates a bounded whole number before it is accepted into a save snapshot.
local function integer(value, minimum, maximum)
	assert(type(value) == "number" and value == value and value % 1 == 0 and value >= minimum and value <= maximum, "Invalid saved number")
	return value
end
-- Checks a previously filtered UTF-8 pet name against the same gameplay length bound.
local function validName(value, config)
	if value == nil then return true end
	if type(value) ~= "string" or #value > config.CustomPetNameMaxLength * 4 then return false end
	local ok, length = pcall(utf8.len, value)
	return ok and length ~= nil and length >= 2 and length <= config.CustomPetNameMaxLength
end
-- Creates a versioned starting profile from configuration without accessing Roblox services.
function ProfileData.New(config)
	return { Version = 5, Cash = config.StartingCash, Purchased = false, Capacity = config.PetCapacity, Rewards = RewardState.New(),
		Upgrades = { Beds = 0, Pantry = 0, Storage = 0, Care = 0 },
		Food = { Stored = 0, Pending = 0 }, Pets = {}, Index = {} }
end
-- Copies and validates saved fields; rejects corrupt or incompatible profiles instead of silently deleting progress.
function ProfileData.Validate(source, config, catalog)
	assert(type(source) == "table" and (source.Version == 1 or source.Version == 2 or source.Version == 3 or source.Version == 4 or source.Version == 5), "Unsupported profile version")
	local result = ProfileData.New(config)
	if source.Version >= 3 then result.Rewards = RewardState.Validate(source.Rewards, RewardConfig) end
	result.Cash = integer(source.Cash, 0, 1000000000)
	assert(type(source.Purchased) == "boolean", "Invalid kennel state")
	result.Purchased = source.Purchased
	if source.Version == 1 then
		assert(source.Capacity == config.PetCapacity or source.Capacity == config.CapacityUpgrade.Capacity, "Unknown legacy capacity")
		result.Upgrades.Beds = if source.Capacity == config.CapacityUpgrade.Capacity then 1 else 0
	else
		assert(type(source.Upgrades) == "table", "Missing upgrade data")
		for branch, tiers in config.Upgrades do result.Upgrades[branch] = integer(source.Upgrades[branch], 0, #tiers) end
	end
	local beds = config.Upgrades.Beds[result.Upgrades.Beds]
	assert(source.Capacity == (if beds then beds.Capacity else config.PetCapacity), "Capacity does not match upgrades")
	if not result.Purchased then
		for _, level in result.Upgrades do assert(level == 0, "Unpurchased shelter has upgrades") end
	end
	result.Capacity = source.Capacity
	assert(type(source.Food) == "table" and type(source.Pets) == "table" and type(source.Index) == "table", "Incomplete profile")
	local storage = config.Upgrades.Storage[result.Upgrades.Storage]
	result.Food.Stored = integer(source.Food.Stored, 0, if storage then storage.Capacity else config.FoodStorageCapacity)
	result.Food.Pending = integer(source.Food.Pending, 0, if storage then storage.BinCapacity else config.FoodBinCapacity)
	local identities = {}
	for _, pet in source.Pets do
		assert(type(pet) == "table" and type(pet.Id) == "string" and #pet.Id > 0 and #pet.Id <= 64 and not identities[pet.Id], "Invalid pet identity")
		local def, variant = catalog.Get(pet.DefinitionId, pet.Variant)
		assert(def and variant and config.RarityMultipliers[pet.Rarity], "Unknown saved pet definition/variant/rarity")
		identities[pet.Id] = true
		local level = integer(pet.Level, 1, config.MaxPetLevel)
		local required = config.XPBase + (level - 1) * config.XPPerLevel
		local customName = pet.CustomName
		assert(validName(customName, config), "Invalid custom pet name")
		local personality = pet.Personality or "Gentle"
		assert(PetCare.IsPersonality(personality), "Invalid pet personality")
		local happiness = integer(pet.Happiness or config.StartingPetHappiness, 0, 100)
		assert(pet.Locked == nil or type(pet.Locked) == "boolean", "Invalid favorite state")
		local careCooldowns = {}
		assert(pet.CareCooldowns == nil or type(pet.CareCooldowns) == "table", "Invalid care cooldowns")
		for actionId in PetCare.Actions do
			careCooldowns[actionId] = integer((pet.CareCooldowns and pet.CareCooldowns[actionId]) or 0, 0, 100000000000)
		end
		table.insert(result.Pets, { Id = pet.Id, DefinitionId = pet.DefinitionId, Variant = pet.Variant, Rarity = pet.Rarity,
			Level = level, XP = integer(pet.XP, 0, if level == config.MaxPetLevel then 0 else required - 1),
			NextFeedAt = integer(pet.NextFeedAt or 0, 0, 100000000000), CustomName = customName,
			Personality = personality, Happiness = happiness, Locked = pet.Locked == true, CareCooldowns = careCooldowns })
	end
	assert(#result.Pets <= result.Capacity and (result.Purchased or #result.Pets == 0), "Pets exceed shelter capacity")
	local keys = {}
	for _, entry in catalog.Entries do keys[entry.Key] = true end
	for key, entry in source.Index do
		assert(keys[key] and type(entry) == "table", "Unknown index entry")
		result.Index[key] = { BestLevel = integer(entry.BestLevel, 1, config.MaxPetLevel), TotalDiscovered = integer(entry.TotalDiscovered, 0, 1000000000) }
	end
	return result
end
-- UpdateAsync may retry its callback. These functions have no side effects.
-- Checks whether a session lease is absent, already ours or expired.
function ProfileData.CanAcquire(lock, token, now)
	return lock == nil or lock.Token == token or (type(lock.Expires) == "number" and lock.Expires <= now)
end
-- Checks the lease token before a writer may save or release a profile.
function ProfileData.Owns(lock, token) return type(lock) == "table" and lock.Token == token end
return ProfileData
