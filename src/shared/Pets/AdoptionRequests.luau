-- Server-readable adopter preferences. Normal adoption remains available when a pet does not match.
local Requests = {}

Requests.Duration = 600
Requests.BonusMultiplier = 1.35
Requests.Species = table.freeze({ "Dog", "Cat", "Bunny", "Hamster", "GuineaPig" })
Requests.Rarities = table.freeze({ "Uncommon", "Rare", "Epic", "Legendary", "Mythic" })
Requests.Levels = table.freeze({ 3, 5, 8 })

-- Produces one bounded request from a server random source and timestamp.
function Requests.Roll(randomNumber, now)
	local kindRoll = randomNumber()
	local request = {
		Id = tostring(now) .. ":" .. tostring(math.floor(randomNumber() * 1000000)),
		BonusMultiplier = Requests.BonusMultiplier,
		ExpiresAt = now + Requests.Duration,
	}
	if kindRoll < 0.45 then
		request.Kind = "Species"
		request.Value = Requests.Species[math.floor(randomNumber() * #Requests.Species) + 1]
		request.Text = "Looking for any " .. request.Value
	elseif kindRoll < 0.75 then
		request.Kind = "Rarity"
		request.Value = Requests.Rarities[math.floor(randomNumber() * #Requests.Rarities) + 1]
		request.Text = "Looking for a " .. request.Value .. " pet"
	else
		request.Kind = "Level"
		request.Value = Requests.Levels[math.floor(randomNumber() * #Requests.Levels) + 1]
		request.Text = "Looking for Level " .. request.Value .. "+"
	end
	return request
end

-- Checks a request against private server pet data.
function Requests.Matches(request, pet)
	if not request or not pet then return false end
	if request.Kind == "Species" then return pet.Definition.Species == request.Value end
	if request.Kind == "Rarity" then return pet.Rarity == request.Value end
	if request.Kind == "Level" then return pet.Level >= request.Value end
	return false
end

-- Applies the request bonus only to matching pets and returns value, bonus and match state.
function Requests.GetOffer(request, pet, baseValue)
	local matched = Requests.Matches(request, pet)
	local value = if matched then math.floor(baseValue * request.BonusMultiplier) else baseValue
	return value, value - baseValue, matched
end

return table.freeze(Requests)
