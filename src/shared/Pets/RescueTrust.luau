-- Pure balancing rules for a short, gentle wild-pet trust interaction.
local RescueTrust = {}

RescueTrust.RarityStart = table.freeze({ Common = 64, Uncommon = 58, Rare = 50, Epic = 44, Legendary = 38, Mythic = 34 })
RescueTrust.Personality = table.freeze({
	Gentle = table.freeze({ Start = 8, Calm = 4, Treat = 0, Retreat = 0 }),
	Affectionate = table.freeze({ Start = 7, Calm = 5, Treat = 0, Retreat = 0 }),
	Playful = table.freeze({ Start = 4, Calm = 3, Treat = 0, Retreat = 1 }),
	Curious = table.freeze({ Start = 1, Calm = 2, Treat = 3, Retreat = 1 }),
	Sleepy = table.freeze({ Start = -4, Calm = 0, Treat = 4, Retreat = 1 }),
	Brave = table.freeze({ Start = -2, Calm = 1, Treat = 2, Retreat = 0 }),
	Shy = table.freeze({ Start = -8, Calm = -1, Treat = 8, Retreat = 2 }),
	Skittish = table.freeze({ Start = -14, Calm = -3, Treat = 12, Retreat = 3 }),
})

-- Returns initial trust from rarity and personality; no client-supplied value is involved.
function RescueTrust.Initial(rarity, personality, config)
	local traits = RescueTrust.Personality[personality] or RescueTrust.Personality.Gentle
	return math.clamp((RescueTrust.RarityStart[rarity] or 50) + traits.Start, 0, config.TrustRequired)
end

-- Computes one calm or treat gain, with a small penalty for rushing while interacting.
function RescueTrust.Gain(action, personality, rushed, config)
	local traits = RescueTrust.Personality[personality] or RescueTrust.Personality.Gentle
	local base = if action == "Treat" then config.TrustTreatGain + traits.Treat else config.TrustCalmGain + traits.Calm
	return math.max(1, math.floor(base * (if rushed then config.TrustRushedGainMultiplier else 1)))
end

-- Converts trust to a readable state for the pet and encounter UI.
function RescueTrust.Mood(trust, config)
	if trust >= config.TrustRequired then return "Ready" end
	if trust >= config.TrustCautiousThreshold then return "Cautious" end
	return "Nervous"
end

-- Lets nervous personalities back away slightly farther without escaping their spawn clearing.
function RescueTrust.RetreatDistance(personality, config)
	local traits = RescueTrust.Personality[personality] or RescueTrust.Personality.Gentle
	return config.TrustRetreatDistance * (0.6 + traits.Retreat * 0.4)
end

-- Adds bounded happiness for care; an uninitialized legacy pet starts content.
function RescueTrust.Happiness(current, gain, config)
	return math.clamp((current or config.StartingPetHappiness) + gain, 0, 100)
end

return table.freeze(RescueTrust)
