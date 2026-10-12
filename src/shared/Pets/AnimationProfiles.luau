-- Central animation data. AssetId stays absent until an owned/approved Roblox animation is supplied.
local Profiles = {}

-- Creates one animation state with a procedural fallback used by the current placeholder models.
local function state(rate, bob, pitch)
	return table.freeze({ Rate = rate, Bob = bob, Pitch = pitch or 0 })
end

local dog = table.freeze({
	Controller = "Procedural",
	States = table.freeze({
		Idle = state(1.8, 0.035), Walk = state(8, 0.08, 1.5), Run = state(12, 0.13, 2.5),
		Eat = state(9, 0.09, 5), Happy = state(6, 0.2, -3), Adoption = state(8, 0.08, 1.5),
	}),
})

Profiles.Dog = dog
Profiles.Cat = table.freeze({ Controller = "Procedural", States = table.freeze({
	Idle = state(1.5, 0.03), Walk = state(8.5, 0.07, 1), Run = state(12, 0.11, 2),
	Eat = state(8, 0.075, 4), Happy = state(5.5, 0.14, -2), Adoption = state(8.5, 0.07, 1),
}) })
Profiles.Bunny = table.freeze({ Controller = "Procedural", States = table.freeze({
	Idle = state(1.5, 0.045), Walk = state(9, 0.24, -2), Run = state(13, 0.34, -4),
	Eat = state(10, 0.1, 5), Happy = state(7, 0.3, -5), Adoption = state(9, 0.24, -2),
}) })
Profiles.Hamster = table.freeze({ Controller = "Procedural", States = table.freeze({
	Idle = state(2.1, 0.025), Walk = state(10, 0.065), Run = state(14, 0.1),
	Eat = state(11, 0.07, 4), Happy = state(8, 0.13, -2), Adoption = state(10, 0.065),
}) })
Profiles.GuineaPig = table.freeze({ Controller = "Procedural", States = table.freeze({
	Idle = state(1.7, 0.025), Walk = state(8, 0.06), Run = state(11, 0.09),
	Eat = state(9, 0.065, 3), Happy = state(6, 0.12, -2), Adoption = state(8, 0.06),
}) })

-- Resolves a configured profile, falling back to the dog profile for unknown future definitions.
function Profiles.Get(profileId)
	return Profiles[profileId] or dog
end

-- Verifies that every required gameplay state has usable fallback data or an approved animation slot.
function Profiles.Validate(profileId)
	local profile = Profiles[profileId]
	if not profile or type(profile.States) ~= "table" then return false end
	for _, name in { "Idle", "Walk", "Run", "Eat", "Happy", "Adoption" } do
		local value = profile.States[name]
		if type(value) ~= "table" or type(value.Rate) ~= "number" or type(value.Bob) ~= "number" then return false end
		if value.AssetId ~= nil and (type(value.AssetId) ~= "string" or not string.match(value.AssetId, "^rbxassetid://%d+$")) then return false end
	end
	return true
end

return Profiles
