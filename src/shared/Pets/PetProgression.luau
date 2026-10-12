-- Pure calculations; server owns the pet records passed to AddPetXP.
local Progression = {}

-- Returns the XP needed to advance from this level using the configured growth curve.
function Progression.GetXPRequired(level, config)
	return config.XPBase + (level - 1) * config.XPPerLevel
end

-- Returns the level stored on the authoritative pet record.
function Progression.GetPetLevel(pet)
	return pet.Level
end

-- Adds valid XP, applies all earned levels, and caps progress; returns whether a level was gained.
function Progression.AddPetXP(pet, amount, config)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then return false end
	local previous = pet.Level
	if pet.Level >= config.MaxPetLevel then return false end
	pet.XP += math.floor(amount)
	while pet.Level < config.MaxPetLevel do
		local required = Progression.GetXPRequired(pet.Level, config)
		if pet.XP < required then break end
		pet.XP -= required
		pet.Level += 1
	end
	if pet.Level == config.MaxPetLevel then pet.XP = 0 end
	return pet.Level > previous
end

-- Calculates the rounded payout from base value, rarity, level and optional variant multiplier.
function Progression.GetAdoptionValue(definition, rarity, level, config, variant, happiness)
	local multiplier = config.RarityMultipliers[rarity]
	assert(multiplier, "Unknown rarity in pet definition")
	local careBonus = 1 + math.clamp(((happiness or config.StartingPetHappiness) - config.StartingPetHappiness) / (100 - config.StartingPetHappiness), 0, 1) * config.AdoptionHappinessBonus
	return math.floor(definition.BaseAdoptionValue * multiplier * (1 + (level - 1) * config.AdoptionLevelBonus) * (if variant then variant.AdoptionMultiplier or 1 else 1) * careBonus)
end

-- Checks the level cap and per-pet deadline; returns eligibility, a reason and seconds remaining.
function Progression.CanGainFeedingXP(pet, now, config)
	if pet.Level >= config.MaxPetLevel then return false, "MaxLevel", 0 end
	local remaining = math.max(0, (pet.NextFeedAt or 0) - now)
	return remaining == 0, if remaining == 0 then "Ready" else "FeedingCooldown", math.ceil(remaining)
end

-- Selects the visual tier for a level and applies optional variant model overrides without changing pet data.
function Progression.GetModelStage(definition, level, variant)
	local selected = { ModelKey = definition.ModelKey, AssetKey = definition.AssetKey or definition.ModelKey, Stage = 1, MinLevel = 1 }
	local stages = (variant and variant.ModelProgression) or definition.ModelProgression or {}
	for _, stage in stages do
		if stage.MinLevel <= level and stage.MinLevel >= selected.MinLevel then selected = stage end
	end
	if variant and variant.ModelOverrides and variant.ModelOverrides[selected.ModelKey] then
		selected = table.clone(selected)
		selected.ModelKey = variant.ModelOverrides[selected.ModelKey]
		selected.AssetKey = selected.ModelKey
	end
	return selected
end

return table.freeze(Progression)
