local Upgrades = {}

-- Creates independent branch levels; never share mutable upgrade state between owners.
function Upgrades.New()
	return { Beds = 0, Pantry = 0, Storage = 0, Care = 0 }
end

-- Returns the next affordable target's definition; nil means an unknown or completed branch.
function Upgrades.Next(levels, branch, config)
	local definitions = config.Upgrades[branch]
	return definitions and definitions[(levels[branch] or 0) + 1]
end

-- Resolves food/feeding stats centrally without mutating the global defaults.
function Upgrades.Stats(levels, config)
	local result = table.clone(config)
	result.CareMultiplier = 1
	local pantry = config.Upgrades.Pantry[levels.Pantry or 0]
	local storage = config.Upgrades.Storage[levels.Storage or 0]
	local care = config.Upgrades.Care[levels.Care or 0]
	if pantry then result.FoodProductionInterval = pantry.Interval end
	if storage then result.FoodStorageCapacity, result.FoodBinCapacity = storage.Capacity, storage.BinCapacity end
	if care then
		result.FeedingXPReward = care.FeedingXP
		result.CareMultiplier = care.CareMultiplier or 1
	end
	return result
end
return Upgrades
