-- Central definitions for repeatable non-feeding care activities and pet personalities.
local PetCare = {}

PetCare.Personalities = table.freeze({
	"Playful", "Gentle", "Curious", "Brave", "Sleepy", "Affectionate", "Shy", "Skittish",
})

PetCare.Actions = table.freeze({
	Pet = table.freeze({ Title = "Pet", XP = 4, Cooldown = 45 }),
	Brush = table.freeze({ Title = "Brush", XP = 8, Cooldown = 180 }),
	Play = table.freeze({ Title = "Play", XP = 12, Cooldown = 300 }),
	Walk = table.freeze({ Title = "Practice walk", XP = 15, Cooldown = 420 }),
})

-- Selects a valid personality from a server-generated integer.
function PetCare.PersonalityAt(index)
	return PetCare.Personalities[(math.abs(math.floor(index)) % #PetCare.Personalities) + 1]
end

-- Returns whether a persisted personality belongs to the configured set.
function PetCare.IsPersonality(value)
	return type(value) == "string" and table.find(PetCare.Personalities, value) ~= nil
end

-- Returns the configured care action, or nil for an unknown client identifier.
function PetCare.Get(actionId)
	return PetCare.Actions[actionId]
end

-- Checks one authoritative per-pet cooldown without changing it.
function PetCare.CanPerform(pet, actionId, now)
	local action = PetCare.Get(actionId)
	if not action then return false, "UnknownCare", 0 end
	local deadline = (pet.CareCooldowns and pet.CareCooldowns[actionId]) or 0
	local remaining = math.max(0, deadline - now)
	return remaining == 0, if remaining == 0 then "Ready" else "CareCooldown", math.ceil(remaining)
end

-- Commits one care cooldown and returns the centrally calculated whole XP reward.
function PetCare.Commit(pet, actionId, now, multiplier)
	local allowed, reason, remaining = PetCare.CanPerform(pet, actionId, now)
	if not allowed then return nil, reason, remaining end
	local action = PetCare.Actions[actionId]
	pet.CareCooldowns = pet.CareCooldowns or {}
	pet.CareCooldowns[actionId] = now + action.Cooldown
	return math.max(1, math.floor(action.XP * (multiplier or 1) + 0.5)), "Ready", 0
end

return table.freeze(PetCare)
