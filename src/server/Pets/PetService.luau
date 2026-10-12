local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TextService = game:GetService("TextService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.ShelterUpgrades)
local Catalog = require(Shared.Pets.PetCatalog)
local Progression = require(Shared.Pets.PetProgression)
local PetCare = require(Shared.Pets.PetCare)
local RescueTrust = require(Shared.Pets.RescueTrust)
local Builder = require(script.Parent.PetBuilder)
local PlotBuilder = require(script.Parent.Parent.World.PlotBuilder)
local Follow = require(script.Parent.PetFollowService)
local Validation = require(script.Parent.Parent.Common.Validation)
local Collection = require(script.Parent.CollectionService)
local Adoption = require(script.Parent.AdoptionService)
local Biomes = require(Shared.Config.Biomes)
local Events = require(script.Parent.Parent.Common.GameplayEvents)

local PetService = {}
local shelter, world, remotes, food, requestService
local records, following, attempts, characters = {}, {}, {}, {}
local spawnSlots = {}
local total = 0
local random = Random.new()

-- Returns the current server-calculated adoption offer and any matching-request bonus.
local function adoptionOffer(pet)
	local baseValue = Progression.GetAdoptionValue(pet.Definition, pet.Rarity, pet.Level, Config, pet.Coat, pet.Happiness)
	if pet.Owner and requestService then return requestService.GetOffer(pet.Owner, pet, baseValue) end
	return baseValue, 0, false
end

-- Copies authoritative pet fields to attributes and updates prompt availability for the current state.
local function publish(pet)
	pet.Model:SetAttribute("State", pet.State)
	pet.Model:SetAttribute("OwnerUserId", if pet.Owner then pet.Owner.UserId else 0)
	pet.Model:SetAttribute("DefinitionId", pet.Definition.DefinitionId)
	pet.Model:SetAttribute("Level", pet.Level)
	pet.Model:SetAttribute("XP", pet.XP)
	pet.Model:SetAttribute("XPRequired", if pet.Level >= Config.MaxPetLevel then 0 else Progression.GetXPRequired(pet.Level, Config))
	pet.Model:SetAttribute("Rarity", pet.Rarity)
	local adoptionValue, adoptionBonus, requestMatched = adoptionOffer(pet)
	pet.Model:SetAttribute("AdoptionValue", adoptionValue)
	pet.Model:SetAttribute("AdoptionBonus", adoptionBonus)
	pet.Model:SetAttribute("RequestMatched", requestMatched)
	pet.Model:SetAttribute("PetUniqueId", pet.Id)
	pet.Model:SetAttribute("PetDefinitionId", pet.Definition.DefinitionId)
	pet.Model:SetAttribute("DisplayName", pet.Name)
	pet.Model:SetAttribute("PetName", pet.Name)
	pet.Model:SetAttribute("Personality", pet.Personality)
	pet.Model:SetAttribute("Happiness", pet.Happiness)
	pet.Model:SetAttribute("HousingSlotId", pet.Slot or 0)
	pet.Model:SetAttribute("Trust", pet.Trust or 0)
	pet.Model:SetAttribute("TrustRequired", Config.TrustRequired)
	pet.Model:SetAttribute("RescueMood", RescueTrust.Mood(pet.Trust or 0, Config))
	pet.Model:SetAttribute("EngagedUserId", if pet.EngagedBy then pet.EngagedBy.UserId else 0)
	pet.Model:SetAttribute("Favorite", pet.Locked == true)
	pet.Model:SetAttribute("Variant", pet.Coat.Id)
	pet.Model:SetAttribute("NextFeedAt", pet.NextFeedAt or 0)
	for actionId in PetCare.Actions do
		pet.Model:SetAttribute("Care" .. actionId .. "At", (pet.CareCooldowns and pet.CareCooldowns[actionId]) or 0)
	end
	pet.Model:SetAttribute("ModelStage", pet.VisualStage)
	pet.Model:SetAttribute("ModelKey", pet.VisualKey)
	pet.Model:SetAttribute("VisualStage", pet.VisualStage)
	pet.Model:SetAttribute("BiomeId", pet.BiomeId or "")
	pet.Model:SetAttribute("MovementProfile", pet.Definition.MovementProfile or pet.Definition.Species)
	pet.Model:SetAttribute("AnimationProfile", pet.Definition.AnimationProfile or pet.Definition.Species)
	pet.Prompt.Enabled = pet.State == "Available" or pet.State == "Sheltered"
	pet.Prompt.ActionText = if pet.State == "Sheltered" then "View pet" else "Meet pet"
	pet.Prompt.ObjectText = pet.Name .. " • " .. pet.Rarity
end

-- Requires a loaded connected player and applies a separate request cooldown per action.
local function permitted(player, action)
	if not Validation.Player(player) or player:GetAttribute("ProfileReady") ~= true then return false end
	action = action or "Rescue"
	local now = os.clock()
	local buckets = attempts[player] or {}
	attempts[player] = buckets
	if buckets[action] and now - buckets[action] < Config.PurchaseCooldown then return false end
	buckets[action] = now
	return true
end

-- Disconnects and removes one pet, frees its slot and schedules replacement if it occupied a park spawn.
local function destroyPet(pet)
	if not records[pet.Id] then return end
	if pet.Connection then pet.Connection:Disconnect() end
	if pet.Owner then
		if pet.Slot and pet.State ~= "Following" then
			local plot = shelter.GetPlot(pet.Owner)
			if plot then PlotBuilder.SetHousingOccupant(plot, pet.Slot, nil) end
		end
		if following[pet.Owner] == pet then
			Follow.Remove(pet.Owner)
			following[pet.Owner] = nil
			pet.Owner:SetAttribute("FollowingPetId", "")
		end
		shelter.FreeSlot(pet.Owner, pet.Id)
	end
	if pet.SpawnIndex and spawnSlots[pet.SpawnIndex].Pet == pet then
		spawnSlots[pet.SpawnIndex].Pet = nil
		spawnSlots[pet.SpawnIndex].ReadyAt = os.clock() + world.SpawnDefinitions[pet.SpawnIndex].RespawnSeconds
	end
	pet.Model:Destroy()
	records[pet.Id] = nil
	total -= 1
end

-- Gives a nearby rushing player one bounded, non-physical pet retreat on the shared update loop.
local function reactToRush(pet, root, now)
	if not root or (pet.Trust or 0) >= Config.TrustRequired or now - (pet.LastRetreatAt or -math.huge) < Config.TrustRetreatCooldown then return false end
	local velocity = root.AssemblyLinearVelocity
	if not Validation.Position(velocity) then return false end
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local current = pet.Model:GetPivot()
	local away = Vector3.new(current.X - root.Position.X, 0, current.Z - root.Position.Z)
	if speed <= Config.TrustRushSpeed or away.Magnitude < 0.1 or away.Magnitude > 6 then return false end
	pet.LastRetreatAt = now
	local candidate = current.Position + away.Unit * RescueTrust.RetreatDistance(pet.Personality, Config)
	if (candidate - pet.SpawnPosition).Magnitude <= 5 then pet.Model:PivotTo(CFrame.new(candidate) * current.Rotation) end
	pet.Trust = math.max(0, pet.Trust - Config.TrustRushPenalty)
	publish(pet)
	pet.Model:SetAttribute("LastStartleAt", workspace:GetServerTimeNow())
	return true
end

-- Opens an exclusive short trust encounter after checking plot, capacity, character and pet proximity.
function PetService.TryBeginRescue(player, petId)
	if not permitted(player, "Encounter") then return false, "Cooldown" end
	if type(petId) ~= "string" or #petId > 64 then return false, "PetUnavailable" end
	local pet = records[petId]
	if not pet or pet.State ~= "Available" or pet.Busy or not pet.Prompt.Enabled or not pet.Model:IsDescendantOf(workspace) then return false, "PetUnavailable" end
	if not Validation.Near(player, pet.Model:GetPivot().Position + Vector3.new(0, 2, 0), Config.InteractionDistance) then return false, "TooFar" end
	local capacity = shelter.GetPetCapacity(player)
	if not shelter.GetPlot(player) then return false, "NeedPlot" end
	if not shelter.GetPlot(player).Purchased then return false, "NeedKennel" end
	if not capacity.hasAvailablePetSlot then return false, "ShelterFull" end
	if following[player] then return false, "AlreadyFollowing" end
	local now = os.clock()
	if pet.EngagedBy and pet.EngagedBy ~= player and (pet.EngagementExpiresAt or 0) > now then return false, "PetBusy" end
	for _, other in records do
		if other ~= pet and other.EngagedBy == player then
			other.EngagedBy = nil
			other.Trust = RescueTrust.Initial(other.Rarity, other.Personality, Config)
			publish(other)
		end
	end
	if pet.EngagedBy ~= player or (pet.EngagementExpiresAt or 0) <= now then
		pet.Trust = RescueTrust.Initial(pet.Rarity, pet.Personality, Config)
		pet.NextTrustActionAt = 0
	end
	pet.EngagedBy = player
	pet.EngagementExpiresAt = now + Config.TrustSessionSeconds
	publish(pet)
	reactToRush(pet, Validation.Root(player), now)
	remotes.PetEncounter:FireClient(player, pet.Id)
	return true, "EncounterStarted"
end

-- Awards server-calculated trust for calming or a paid treat; rushing causes a bounded retreat.
function PetService.TryTrustAction(player, petId, action)
	if action ~= "Calm" and action ~= "Treat" then return false, "UnknownCare" end
	if not permitted(player, "Trust:" .. action) then return false, "Cooldown" end
	if type(petId) ~= "string" or #petId > 64 then return false, "PetUnavailable" end
	local pet = records[petId]
	local now = os.clock()
	if not pet or pet.State ~= "Available" or pet.Busy or not pet.Model:IsDescendantOf(workspace)
		or pet.EngagedBy ~= player or (pet.EngagementExpiresAt or 0) <= now then
		return false, "EncounterExpired"
	end
	local root = Validation.Root(player)
	if not root or not Validation.Near(player, pet.Model:GetPivot().Position + Vector3.new(0, 2, 0), Config.InteractionDistance) then return false, "TooFar" end
	if now < (pet.NextTrustActionAt or 0) then return false, "TrustCooldown" end
	if pet.Trust >= Config.TrustRequired then return false, "TrustReady" end
	local velocity = root.AssemblyLinearVelocity
	if not Validation.Position(velocity) then return false, "TooFar" end
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local rushed = horizontalSpeed > Config.TrustRushSpeed
	if action == "Treat" and not food.TryConsume(player, Config.TrustTreatFoodCost) then return false, "NoFood" end
	reactToRush(pet, root, now)
	pet.NextTrustActionAt = now + Config.TrustActionCooldown
	pet.EngagementExpiresAt = now + Config.TrustSessionSeconds
	pet.Trust = math.min(Config.TrustRequired, pet.Trust + RescueTrust.Gain(action, pet.Personality, rushed, Config))
	publish(pet)
	pet.Model:SetAttribute("LastTrustAction", action)
	pet.Model:SetAttribute("LastTrustAt", workspace:GetServerTimeNow())
	return true, if pet.Trust >= Config.TrustRequired then "TrustReady" else "TrustGained", { Trust = pet.Trust, Gain = action, Name = pet.Name }
end

-- Cancels a rescue in transit, destroys its pet and frees the reserved shelter slot.
function PetService.CancelFollowing(player)
	local pet = following[player]
	if pet then destroyPet(pet) end
end

-- Cancels adoption/following, removes owned pets, and disconnects per-player listeners on departure.
function PetService.CleanupPlayer(player)
	Adoption.Cancel(player)
	PetService.CancelFollowing(player)
	for _, pet in records do
		if pet.State == "Available" and pet.EngagedBy == player then
			pet.EngagedBy = nil
			pet.Trust = RescueTrust.Initial(pet.Rarity, pet.Personality, Config)
			publish(pet)
		end
	end
	local owned = {}
	for _, pet in records do if pet.Owner == player then table.insert(owned, pet) end end
	for _, pet in owned do destroyPet(pet) end
	if characters[player] then characters[player]:Disconnect() end
	characters[player], attempts[player] = nil, nil
end

-- Validates pickup and reserves a bed before leashing; rolls back the reservation and visuals on failure.
function PetService.TryRescue(player, petId)
	if not permitted(player) then return false, "Cooldown" end
	if type(petId) ~= "string" or #petId > 64 then return false, "PetUnavailable" end
	local pet = records[petId]
	if not pet or pet.State ~= "Available" or pet.Busy or not pet.Model:IsDescendantOf(workspace) then
		return false, "PetUnavailable"
	end
	if not pet.Prompt.Enabled or not Validation.Near(player, pet.Model:GetPivot().Position + Vector3.new(0, 2, 0), Config.InteractionDistance) then
		return false, "TooFar"
	end
	if pet.EngagedBy ~= player or (pet.EngagementExpiresAt or 0) <= os.clock() or (pet.Trust or 0) < Config.TrustRequired then
		return false, "NeedTrust"
	end
	if following[player] then return false, "AlreadyFollowing" end
	local slot, reason = shelter.ReserveSlot(player, pet.Id)
	if not slot then return false, reason end
	pet.Busy = true
	local ok, err = pcall(function()
		pet.Owner = player
		pet.Slot = slot
		pet.State = "Following"
		pet.EngagedBy = nil
		pet.EngagementExpiresAt = 0
		Follow.Add(player, pet)
		following[player] = pet
		player:SetAttribute("FollowingPetId", pet.Id)
		publish(pet)
	end)
	if not ok then
		Follow.Remove(player)
		following[player] = nil
		player:SetAttribute("FollowingPetId", "")
		shelter.FreeSlot(player, pet.Id)
		pet.Owner, pet.Slot, pet.State = nil, nil, "Available"
		pet.EngagedBy = player
		pet.EngagementExpiresAt = os.clock() + Config.TrustSessionSeconds
		publish(pet)
		pet.Busy = false
		warn("Pet pickup rolled back: " .. tostring(err))
		return false, "RescueFailed"
	end
	local spawn = spawnSlots[pet.SpawnIndex]
	spawn.Pet = nil
	spawn.ReadyAt = os.clock() + world.SpawnDefinitions[pet.SpawnIndex].RespawnSeconds
	pet.SpawnIndex = nil
	pet.Busy = false
	Events.Emit(player, "Rescue", 1, pet.Rarity)
	return true, "Rescued"
end

-- Requires a nearby living owner and a valid, idle sheltered pet.
local function canManage(player, pet)
	return pet ~= nil and pet.Owner == player and pet.State == "Sheltered" and not pet.Busy
		and pet.Model:IsDescendantOf(workspace)
		and Validation.Near(player, pet.Model:GetPivot().Position + Vector3.new(0, 2, 0), Config.InteractionDistance)
end

-- Locks an eligible owned pet for an NPC trip; pays and frees capacity only after successful departure.
function PetService.TryAdopt(player, petId)
	if not permitted(player, "Adopt") then return false, "Cooldown" end
	if type(petId) ~= "string" or #petId > 64 then return false, "PetUnavailable" end
	local pet = records[petId]
	if not canManage(player, pet) or pet.Locked then return false, "CannotAdopt" end
	local value, bonus, matched = adoptionOffer(pet)
	pet.Busy = true
	pet.State = "Adopting"
	publish(pet)
	-- Restores a cancelled adoption's pet to its bed without changing the player's cash.
	local function cancel()
		if not records[pet.Id] then return end
		pet.State, pet.Busy = "Sheltered", false
		local plot = shelter.GetPlot(player)
		if plot then pet.Model:PivotTo(plot.Slots[pet.Slot]) end
		publish(pet)
		shelter.Notify(player, "AdoptionCancelled")
	end
	local ok, started = pcall(Adoption.StartJob, player, pet, shelter.GetPlot(player), function()
		if records[pet.Id] ~= pet or pet.State ~= "Adopting" or pet.Owner ~= player then return end
		if player:GetAttribute("ProfileReady") ~= true then cancel(); return end
		local rewarded = shelter.CommitReward(player, value, function() destroyPet(pet) end)
		if rewarded then
			if matched then requestService.Complete(player, pet) end
			Events.Emit(player, "Adopt")
			shelter.Notify(player, "Adopted", { Value = value, Bonus = bonus, Matched = matched })
		else cancel() end
	end, cancel)
	if not ok or not started then cancel(); return false, "AdoptionBusy" end
	return true, "AdoptionStarted"
end

-- Validates ownership, range and the per-pet XP deadline, then spends food and grants configured XP.
function PetService.TryFeed(player, petId)
	if not permitted(player, "Feed") then return false, "Cooldown" end
	if type(petId) ~= "string" or #petId > 64 then return false, "PetUnavailable" end
	local pet = records[petId]
	if not canManage(player, pet) then return false, "CannotFeed" end
	local now = os.time()
	local eligible, reason, remaining = Progression.CanGainFeedingXP(pet, now, Config)
	if not eligible then return false, reason, remaining end
	if not food.TryConsume(player, Config.FoodCostPerFeed) then return false, "NoFood" end
	local level = pet.Level
	local reward = Upgrades.Stats(shelter.GetPlot(player).Upgrades, Config).FeedingXPReward
	pet.NextFeedAt = now + Config.FeedingXPCooldown
	pet.Happiness = RescueTrust.Happiness(pet.Happiness, Config.FeedingHappinessGain, Config)
	PetService.AddPetXP(pet.Id, reward)
	pet.Model:SetAttribute("LastFeedingXP", reward)
	pet.Model:SetAttribute("LastFedAt", workspace:GetServerTimeNow())
	Events.Emit(player, "Feed")
	return true, "Fed", { XP = reward, Level = pet.Level, Leveled = pet.Level > level, Name = pet.Name }
end

-- Performs one configured care action, enforcing ownership, distance, level and a per-pet server deadline.
function PetService.TryCare(player, petId, careId)
	if type(petId) ~= "string" or #petId > 64 or type(careId) ~= "string" or #careId > 16 or not PetCare.Get(careId) then
		return false, "UnknownCare"
	end
	if not permitted(player, "Care:" .. careId) then return false, "Cooldown" end
	local pet = records[petId]
	if not canManage(player, pet) then return false, "CannotCare" end
	local now = os.time()
	local stats = Upgrades.Stats(shelter.GetPlot(player).Upgrades, Config)
	local reward, reason, remaining = PetCare.Commit(pet, careId, now, stats.CareMultiplier)
	if not reward then return false, reason, remaining end
	local previous = pet.Level
	local awardedXP = if previous >= Config.MaxPetLevel then 0 else reward
	pet.Happiness = RescueTrust.Happiness(pet.Happiness, Config.CareHappinessGain[careId] or 0, Config)
	if awardedXP > 0 then PetService.AddPetXP(pet.Id, awardedXP) end
	pet.Model:SetAttribute("LastCareAction", careId)
	pet.Model:SetAttribute("LastCareXP", awardedXP)
	pet.Model:SetAttribute("LastCareAt", workspace:GetServerTimeNow())
	publish(pet)
	Events.Emit(player, "Care", 1, careId)
	return true, "Cared", { Action = PetCare.Get(careId).Title, XP = awardedXP, Level = pet.Level, Leveled = pet.Level > previous, Name = pet.Name }
end

-- Toggles adoption protection for one nearby owned pet and persists it with the pet record.
function PetService.TryFavorite(player, petId)
	if not permitted(player, "Favorite") then return false, "Cooldown" end
	if type(petId) ~= "string" or #petId > 64 then return false, "PetUnavailable" end
	local pet = records[petId]
	if not canManage(player, pet) then return false, "CannotCare" end
	pet.Locked = not pet.Locked
	publish(pet)
	return true, "FavoriteChanged", { Name = pet.Name, Favorite = pet.Locked }
end

-- Filters and commits a custom pet name while keeping the permanent GUID and definition unchanged.
function PetService.TryRename(player, petId, requestedName)
	if type(petId) ~= "string" or #petId > 64 or type(requestedName) ~= "string"
		or #requestedName > Config.CustomPetNameMaxLength * 4 then return false, "InvalidPetName" end
	if not permitted(player, "Rename") then return false, "Cooldown" end
	local pet = records[petId]
	if not canManage(player, pet) then return false, "CannotCare" end
	local trimmed = string.match(requestedName, "^%s*(.-)%s*$")
	local validUtf8, length = pcall(utf8.len, trimmed or "")
	if not trimmed or not validUtf8 or not length or length < 2 or length > Config.CustomPetNameMaxLength
		or string.find(trimmed, "[%c]") then return false, "InvalidPetName" end
	pet.Busy = true
	local ok, filtered = pcall(function()
		if RunService:IsStudio() then
			assert(string.match(trimmed, "^[%w%s%-']+$"), "Studio name contains unsupported characters")
			return trimmed
		end
		local result = TextService:FilterStringAsync(trimmed, player.UserId, Enum.TextFilterContext.PublicChat)
		return result:GetNonChatStringForBroadcastAsync()
	end)
	if records[petId] ~= pet or pet.Owner ~= player or pet.State ~= "Sheltered" then
		if records[petId] == pet then pet.Busy = false end
		return false, "PetUnavailable"
	end
	pet.Busy = false
	local validFiltered, filteredLength = pcall(utf8.len, if type(filtered) == "string" then filtered else "")
	if not ok or type(filtered) ~= "string" or not validFiltered or not filteredLength
		or filteredLength < 2 or filteredLength > Config.CustomPetNameMaxLength then return false, "RenameUnavailable" end
	pet.CustomName = filtered
	pet.Name = filtered
	pet.Model.Name = filtered
	local plot = shelter.GetPlot(player)
	if plot and pet.Slot then PlotBuilder.SetHousingOccupant(plot, pet.Slot, pet.Id, pet.Name, pet.Definition.Species) end
	publish(pet)
	return true, "Renamed", filtered
end

-- Returns the current level for a known pet ID, or nil if it no longer exists.
function PetService.GetPetLevel(petId)
	local pet = records[petId]
	return pet and Progression.GetPetLevel(pet)
end

-- Grants server-authorized XP, refreshes visual tiers, and publishes progression and best-index-level changes.
function PetService.AddPetXP(petId, amount)
	if type(amount) ~= "number" or not Validation.Finite(amount) or amount <= 0 then return false end
	local pet = records[petId]
	if not pet or pet.State ~= "Sheltered" or pet.Busy then return false end
	Progression.AddPetXP(pet, amount, Config)
	local stage = Progression.GetModelStage(pet.Definition, pet.Level, pet.Coat)
	if stage.Stage ~= pet.VisualStage or stage.ModelKey ~= pet.VisualKey then
		if Builder.RefreshVisual(pet.Model, pet.Definition, pet.Coat, stage) then
			pet.VisualStage, pet.VisualKey = stage.Stage, stage.ModelKey
		end
	end
	publish(pet)
	if pet.Owner then Collection.Discover(pet.Owner, pet, true) end
	return true
end

-- Requires owner and follower inside their intake; commits the bed, removes the leash and records discovery.
function PetService.TryDeliver(player, petId)
	local pet = records[petId]
	local root = Validation.Root(player)
	local plot = shelter.GetPlot(player)
	if not pet or pet.State ~= "Following" or pet.Owner ~= player or pet.Busy
		or following[player] ~= pet or not root or not plot then return false end
	if not Validation.InZone(root.Position, plot.Intake)
		or not Validation.InZone(pet.Model:GetPivot().Position, plot.Intake)
		or not shelter.HasReservation(player, pet.Id, pet.Slot) then return false end
	pet.Busy = true
	local before = pet.Model:GetPivot()
	local ok, err = pcall(function()
		pet.Model:PivotTo(plot.Slots[pet.Slot])
		pet.State = "Sheltered"
		publish(pet)
		assert(shelter.CommitDelivery(player, pet.Id), "Missing reservation at delivery")
	end)
	if not ok then
		-- Cancel the failed rescue and free even a partially committed reservation.
		-- No payment was involved; replenishment supplies another park pet.
		warn("Pet delivery cancelled: " .. tostring(err))
		pet.Model:PivotTo(before)
		destroyPet(pet)
		return false
	end
	Follow.Remove(player)
	following[player] = nil
	player:SetAttribute("FollowingPetId", "")
	pet.Busy = false
	PlotBuilder.SetHousingOccupant(plot, pet.Slot, pet.Id, pet.Name, pet.Definition.Species)
	local fresh = Collection.Discover(player, pet, false)
	Events.Emit(player, "Deliver")
	if fresh then Events.Emit(player, "Discover", 1, pet.Rarity) end
	shelter.Notify(player, if fresh then "Discovered" else "Delivered", pet.Name .. " • " .. pet.Rarity)
	return true
end

-- Routes sheltered pets to the validated details dialog and available pets to the rescue transaction.
local function onPrompt(player, pet)
	if pet.State == "Sheltered" then
		if not permitted(player, "Preview") then return end
		if canManage(player, pet) then
			remotes.PetDetails:FireClient(player, pet.Id)
		else
			shelter.Notify(player, "CannotAdopt")
		end
		return
	end
	local ok, reason = PetService.TryBeginRescue(player, pet.Id)
	if not ok then shelter.Notify(player, reason) end
end

-- Creates a random park pet or a saved owned pet, builds its art and registers its prompt/record.
local function spawnPet(index, saved, owner)
	if total >= #world.SpawnPoints + Config.PlotCount * (Config.MaxPetCapacity+1) then return end
	if index then
		local point = world.SpawnPoints[index].Position
		for _, player in Players:GetPlayers() do
			local root = Validation.Root(player)
			if root and (root.Position-point).Magnitude < world.SpawnDefinitions[index].PlayerClearance then
				spawnSlots[index].ReadyAt = os.clock() + 1
				return
			end
		end
		for _, other in records do
			if (other.Model:GetPivot().Position-point).Magnitude < 7 then
				spawnSlots[index].ReadyAt = os.clock() + 1
				return
			end
		end
	end
	local definition, coat
	if saved then definition, coat = Catalog.Get(saved.DefinitionId, saved.Variant)
	else
		local biome = Biomes[world.SpawnZones[index]]
		definition, coat = Catalog.Roll(function() return random:NextNumber() end, biome.RarityWeights, biome.Id, biome.Species)
	end
	assert(definition and coat, "Unknown saved pet")
	local model = Instance.new("Model")
	local pet = {
		Id = if saved then saved.Id else HttpService:GenerateGUID(false), Model = model, State = if saved then "Sheltered" else "Available",
		Name = if saved and saved.CustomName then saved.CustomName else coat.Name .. " " .. (definition.DisplayName or definition.Species),
		CustomName = saved and saved.CustomName or nil,
		Personality = if saved then saved.Personality else PetCare.PersonalityAt(random:NextInteger(0, 1000000)),
		Locked = saved and saved.Locked == true or false,
		CareCooldowns = if saved and saved.CareCooldowns then table.clone(saved.CareCooldowns) else {},
		SpawnIndex = index, Busy = false,
		BiomeId = if index then world.SpawnZones[index] else "",
		Definition = definition, Coat = coat, Rarity = if saved then saved.Rarity else coat.Rarity, Level = if saved then saved.Level else 1, XP = if saved then saved.XP else 0,
		NextFeedAt = if saved then saved.NextFeedAt else 0, Owner = owner,
		Happiness = if saved then saved.Happiness or Config.StartingPetHappiness else Config.StartingPetHappiness,
		Trust = if saved then Config.TrustRequired else 0,
		SpawnPosition = if index then world.SpawnPoints[index].Position else Vector3.zero,
	}
	if index then pet.Trust = RescueTrust.Initial(pet.Rarity, pet.Personality, Config) end
	assert(not records[pet.Id], "Duplicate pet identity")
	if saved then pet.Slot = assert(shelter.ReserveSlot(owner, pet.Id)) end
	local stage = Progression.GetModelStage(definition, pet.Level, coat)
	pet.VisualStage, pet.VisualKey = stage.Stage, stage.ModelKey
	local ok, err = pcall(function()
		model.Name = pet.Name
		pet.Prompt = Builder.Build(model, definition, coat, stage)
		model:SetAttribute("PetId", pet.Id)
		model:SetAttribute("Species", definition.Species)
		model:SetAttribute("Coat", coat.Name)
		model:SetAttribute("PetName", pet.Name)
		publish(pet)
		model:PivotTo(if saved then shelter.GetPlot(owner).Slots[pet.Slot] else world.SpawnPoints[index])
		model.Parent = world.Pets
		pet.Connection = pet.Prompt.Triggered:Connect(function(player) onPrompt(player, pet) end)
	end)
	if not ok then
		model:Destroy()
		if index then spawnSlots[index].ReadyAt = os.clock() + world.SpawnDefinitions[index].RespawnSeconds end
		if owner then shelter.FreeSlot(owner, pet.Id) end
		warn("Pet spawn failed: " .. tostring(err))
		return
	end
	records[pet.Id] = pet
	if index then spawnSlots[index].Pet = pet end
	if saved then
		assert(shelter.CommitDelivery(owner, pet.Id))
		PlotBuilder.SetHousingOccupant(shelter.GetPlot(owner), pet.Slot, pet.Id, pet.Name, pet.Definition.Species)
		Collection.Discover(owner, pet, true)
	end
	total += 1
	return pet
end

-- Snapshots sheltered/adopting pets for saving; incomplete rescues are deliberately excluded.
function PetService.Export(player)
	local result = {}
	for _, pet in records do
		if pet.Owner == player and (pet.State == "Sheltered" or pet.State == "Adopting") then
			table.insert(result, { Id = pet.Id, DefinitionId = pet.Definition.DefinitionId, Variant = pet.Coat.Id,
				Rarity = pet.Rarity, Level = pet.Level, XP = pet.XP, NextFeedAt = pet.NextFeedAt or 0,
				Happiness = pet.Happiness,
				CustomName = pet.CustomName, Personality = pet.Personality, Locked = pet.Locked == true,
				CareCooldowns = table.clone(pet.CareCooldowns or {}) })
		end
	end
	return result
end

-- Rebuilds validated saved pets into reserved shelter spaces while retaining their identities and progress.
function PetService.Restore(player, pets)
	for _, saved in pets do assert(spawnPet(nil, saved, player), "Pet restoration failed") end
end

-- Starts population, rescue/follow, action-remote and lifecycle handlers once using the supplied services.
function PetService.Start(shelterService, remoteFolder, foodService, adopterRequestService)
	if shelter then return end
	shelter, remotes, food, requestService = shelterService, remoteFolder, foodService, adopterRequestService
	world = shelter.GetWorld()
	Adoption.Start()
	requestService.SetChangedHandler(function(player)
		for _, pet in records do
			if pet.Owner == player and pet.State == "Sheltered" then publish(pet) end
		end
	end)
	for index = 1, #world.SpawnPoints do
		spawnSlots[index] = { ReadyAt = 0 }
		spawnPet(index)
	end
	-- Registers one character-removal listener to cancel rescues and adoptions for this player.
	local function watch(player)
		if characters[player] or player.Parent ~= Players then return end
		characters[player] = player.CharacterRemoving:Connect(function()
			PetService.CancelFollowing(player)
			Adoption.Cancel(player)
			for _, pet in records do
				if pet.State == "Available" and pet.EngagedBy == player then
					pet.EngagedBy = nil
					pet.Trust = RescueTrust.Initial(pet.Rarity, pet.Personality, Config)
					publish(pet)
				end
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do watch(player) end
	shelter.SetCleanupHandler(PetService.CleanupPlayer)
	Events.Connect(function(player, action)
		if action ~= "Upgrade" then return end
		local plot = shelter.GetPlot(player)
		if not plot then return end
		for _, pet in records do
			if pet.Owner == player and pet.Slot and (pet.State == "Sheltered" or pet.State == "Adopting") then
				if pet.State == "Sheltered" then pet.Model:PivotTo(plot.Slots[pet.Slot]) end
				PlotBuilder.SetHousingOccupant(plot, pet.Slot, pet.Id, pet.Name, pet.Definition.Species)
			end
		end
	end)
	Follow.Start(world, function(player, pet) PetService.TryDeliver(player, pet.Id) end, PetService.CancelFollowing)
	remotes.PetAction.OnServerEvent:Connect(function(player, action, petId, detail)
		local ok, reason, value
		if action == "Adopt" then ok, reason, value = PetService.TryAdopt(player, petId)
		elseif action == "Feed" then ok, reason, value = PetService.TryFeed(player, petId)
		elseif action == "Care" then ok, reason, value = PetService.TryCare(player, petId, detail)
		elseif action == "Favorite" then ok, reason, value = PetService.TryFavorite(player, petId)
		elseif action == "Rename" then ok, reason, value = PetService.TryRename(player, petId, detail)
		elseif action == "Calm" or action == "Treat" then ok, reason, value = PetService.TryTrustAction(player, petId, action)
		elseif action == "Leash" then ok, reason, value = PetService.TryRescue(player, petId)
		else return end
		shelter.Notify(player, reason, value)
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		local available = 0
		for index, spawn in spawnSlots do
			if not spawn.Pet and os.clock() >= spawn.ReadyAt then spawnPet(index) end
			if spawn.Pet then available += 1 end
		end
		for _, pet in records do
			if pet.State == "Available" and pet.EngagedBy then
				local now = os.clock()
				local root = Validation.Root(pet.EngagedBy)
				if now >= (pet.EngagementExpiresAt or 0) or not root
					or (root.Position - pet.Model:GetPivot().Position).Magnitude > Config.TrustAbandonDistance then
					pet.EngagedBy = nil
					pet.Trust = RescueTrust.Initial(pet.Rarity, pet.Personality, Config)
					publish(pet)
				else reactToRush(pet, root, now) end
			end
		end
		world.Model:SetAttribute("AvailablePetCount", available)
		world.Model:SetAttribute("TotalPetCount", total)
	end)
end

return PetService
