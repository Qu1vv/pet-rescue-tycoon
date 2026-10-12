local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Upgrades = require(game:GetService("ReplicatedStorage").Shared.Config.ShelterUpgrades)
local Builder = require(script.Parent.Parent.World.PlotBuilder)
local WorldBuilder = require(script.Parent.Parent.World.WorldBuilder)
local State = require(script.Parent.ShelterState)
local Validation = require(script.Parent.Parent.Common.Validation)
local Events = require(script.Parent.Parent.Common.GameplayEvents)

local ShelterService = {}
local world, state, feedback, cleanup
local beforeCleanup, onClaimed
local balances, attempts, notices = {}, {}, {}

-- Publishes how many plots remain unclaimed for waiting players' HUDs.
local function availablePlots()
	local count = 0
	for _, plot in world.Plots do if not plot.Owner then count += 1 end end
	world.Model:SetAttribute("AvailablePlots", count)
end

-- Replicates delivered/reserved bed totals and the current capacity for one plot.
local function syncCounts(plot)
	local count, reserved = state:Counts(plot.Id)
	plot.Model:SetAttribute("PetCount", count)
	plot.Model:SetAttribute("ReservedCount", reserved)
	local _, maximum = state:GetCapacity(plot.Owner)
	plot.Model:SetAttribute("MaxPetCapacity", maximum)
end

-- Returns used capacity including reservations, the maximum, and whether a purchased shelter has a free slot.
function ShelterService.GetPetCapacity(player)
	local current, maximum, available = state:GetCapacity(player)
	local plot = ShelterService.GetPlot(player)
	available = available and plot ~= nil and plot.Purchased
	return { currentPetCount = current, maxPetCapacity = maximum, hasAvailablePetSlot = available }
end

-- Server-only reward transaction. Validate currency before the non-yielding commit.
-- The callback removes the adopted pet and frees its slot before crediting cash.
-- Validates the balance, runs a non-yielding removal callback, then credits the server-calculated reward.
function ShelterService.CommitReward(player, amount, commit)
	local cash = balances[player]
	if not Validation.Player(player) or not cash or cash.Parent ~= player:FindFirstChild("leaderstats") then return false end
	if type(amount) ~= "number" or not Validation.Finite(amount) or amount < 0 or amount % 1 ~= 0
		or cash.Value < 0 or cash.Value + amount > 1000000000 then return false end
	local balance = cash.Value
	commit()
	cash.Value = balance + amount
	return true
end

-- Requires an initialized, loaded player and applies the shared claim/purchase/upgrade cooldown.
local function permitted(player)
	if not Validation.Player(player) or not balances[player] or player:GetAttribute("ProfileReady") ~= true then return false, "LoadingProfile" end
	local now = os.clock()
	if attempts[player] and now - attempts[player] < Config.PurchaseCooldown then return false, "Cooldown" end
	attempts[player] = now
	return true
end

-- Sends a throttled server-selected feedback message to a connected player.
function ShelterService.Notify(player, code, detail)
	if not Validation.Player(player) then return end
	local now = os.clock()
	if notices[player] and now - notices[player] < 0.35 then return end
	notices[player] = now
	feedback:FireClient(player, code, detail)
end

-- Returns the runtime plot owned by this player, or nil when unclaimed.
function ShelterService.GetPlot(player)
	local id = state and state.Owners[player]
	return id and world.Plots[id]
end

-- Returns the generated world record used by cooperating server services.
function ShelterService.GetWorld()
	return world
end

-- Validates entry and exclusive ownership, assigns the spawn, then invokes saved-shelter restoration.
function ShelterService.TryClaim(player, plotId)
	local ok, reason = permitted(player)
	if not ok then return false, reason end
	local plot = world.Plots[plotId]
	local root = Validation.Root(player)
	if not plot or not root or not Validation.InZone(root.Position, plot.ClaimZone) then return false, "TooFar" end
	local claimSucceeded, claimReason = state:Claim(player, plotId)
	if not claimSucceeded then return false, claimReason end
	plot.Owner = player
	plot.Model:SetAttribute("OwnerUserId", player.UserId)
	plot.Model:SetAttribute("OwnerName", player.DisplayName)
	plot.Title.Text = player.DisplayName .. "'s shelter\nShelter " .. plotId
	local facade = plot.Kennel and plot.Kennel:FindFirstChild("ShelterFacadeLabel", true)
	if facade then facade.Text = player.DisplayName .. "'s PET RESCUE" end
	plot.Spawn.Enabled = true
	player.RespawnLocation = plot.Spawn
	player:SetAttribute("PlotId", plotId)
	availablePlots()
	if onClaimed then onClaimed(player) end
	return true, "Claimed"
end

-- Registers profile hooks for plot restoration and a snapshot before departure cleanup.
function ShelterService.SetLifecycleHandlers(onClaim, onLeaving)
	onClaimed, beforeCleanup = onClaim, onLeaving
end

-- Returns the authoritative balance, or nil before player initialization/after cleanup.
function ShelterService.GetCash(player) return balances[player] and balances[player].Value end
-- Applies a validated saved balance to the server-created currency value.
function ShelterService.RestoreCash(player, amount) assert(balances[player]).Value = amount end

-- Rebuilds a saved purchased kennel and capacity without charging; fails if the plot was already restored.
function ShelterService.RestorePlot(player, purchased, capacity, upgrades)
	local plot = assert(ShelterService.GetPlot(player))
	assert(not plot.Purchased, "Plot already restored")
	plot.Upgrades = upgrades and table.clone(upgrades) or Upgrades.New()
	if not upgrades and capacity > Config.PetCapacity then
		for index, tier in Config.Upgrades.Beds do if tier.Capacity == capacity then plot.Upgrades.Beds = index end end
	end
	if not purchased then return end
	local model = Instance.new("Model")
	local ok, err = pcall(Builder.BuildKennel, model, plot, capacity)
	if not ok then model:Destroy(); error(err) end
	assert(state:SetCapacity(player, capacity))
	plot.Capacity = capacity
	plot.Slots = Builder.GetSlots(plot, capacity)
	plot.Kennel, plot.Purchased = model, true
	model.Parent = plot.Model
	local facade = model:FindFirstChild("ShelterFacadeLabel", true)
	if facade then facade.Text = player.DisplayName .. "'s PET RESCUE" end
	Builder.SetPurchased(plot, true)
	syncCounts(plot)
end

-- Validates owner, zone and cash; builds and charges once, rolling back partial construction on failure.
function ShelterService.TryPurchase(player, plotId)
	local ok, reason = permitted(player)
	if not ok then return false, reason end
	local plot = ShelterService.GetPlot(player)
	if not plot then return false, "NeedPlot" end
	if plotId and plot.Id ~= plotId then return false, "NotOwner" end
	if plot.Owner ~= player or not plot.Model:IsDescendantOf(workspace) then return false, "NotOwner" end
	if plot.Purchased then return false, "AlreadyPurchased" end
	if plot.Busy then return false, "Busy" end
	local root = Validation.Root(player)
	if not root or not Validation.InZone(root.Position, plot.PurchaseZone) then return false, "TooFar" end
	local cash = balances[player]
	local stats = player:FindFirstChild("leaderstats")
	if not stats or cash.Parent ~= stats or not cash:IsA("IntValue") then return false, "InvalidBalance" end
	if cash.Value < Config.KennelCost then return false, "InsufficientCash" end
	plot.Busy = true
	local before = cash.Value
	local kennel = Instance.new("Model")
	local built, err = pcall(function()
		Builder.BuildKennel(kennel, plot)
		cash.Value = before - Config.KennelCost
		kennel.Parent = plot.Model
		plot.Kennel = kennel
		plot.Purchased = true
		local facade = kennel:FindFirstChild("ShelterFacadeLabel", true)
		if facade then facade.Text = player.DisplayName .. "'s PET RESCUE" end
		Builder.SetPurchased(plot, true)
	end)
	if not built then
		kennel:Destroy()
		cash.Value = before
		plot.Kennel = nil
		plot.Purchased = false
		Builder.SetPurchased(plot, false)
		warn("Kennel purchase rolled back: " .. tostring(err))
	end
	plot.Busy = false
	return built, if built then "Purchased" else "BuildFailed"
end

-- Reserves capacity for a rescued pet only when the player's purchased kennel is valid.
function ShelterService.ReserveSlot(player, petId)
	local plot = ShelterService.GetPlot(player)
	if not plot then return nil, "NeedPlot" end
	if not plot.Purchased or not plot.Kennel or plot.Kennel.Parent ~= plot.Model then return nil, "NeedKennel" end
	local slot, reason = state:Reserve(player, petId)
	if slot then syncCounts(plot) end
	return slot, reason
end

-- Rebuilds the kennel with more beds and charges once; restores old geometry, capacity and cash on failure.
function ShelterService.TryUpgrade(player, plotId, branch)
	local ok, reason = permitted(player)
	if not ok then return false, reason end
	local plot = ShelterService.GetPlot(player)
	if not plot or plot.Id ~= plotId then return false, "NotOwner" end
	if not plot.Purchased then return false, "NeedKennel" end
	branch = branch or "Beds"
	local pad = plot.UpgradePads[branch]
	local nextTier = Upgrades.Next(plot.Upgrades, branch, Config)
	if not pad or not nextTier then return false, "AlreadyUpgraded" end
	if plot.Busy then return false, "Busy" end
	local root = Validation.Root(player)
	if not root or not Validation.InZone(root.Position, pad.Zone) then return false, "TooFar" end
	local cash = balances[player]
	if not cash or cash.Parent ~= player:FindFirstChild("leaderstats") then return false, "InvalidBalance" end
	if cash.Value < nextTier.Cost then return false, "UpgradeFunds" end
	plot.Busy = true
	local before, previous, oldCapacity, oldSlots = cash.Value, plot.Kennel, plot.Capacity, plot.Slots
	local oldUpgrades = plot.Upgrades
	plot.Upgrades = table.clone(oldUpgrades)
	plot.Upgrades[branch] += 1
	local capacity = if branch == "Beds" then nextTier.Capacity else oldCapacity
	local replacement = Instance.new("Model")
	local built, err = pcall(function()
		Builder.BuildKennel(replacement, plot, capacity)
		plot.Slots = Builder.GetSlots(plot, capacity)
		assert(state:SetCapacity(player, capacity), "Capacity upgrade rejected")
		plot.Capacity = capacity
		cash.Value -= nextTier.Cost
		replacement.Parent = plot.Model
		plot.Kennel = replacement
		local facade = replacement:FindFirstChild("ShelterFacadeLabel", true)
		if facade then facade.Text = player.DisplayName .. "'s PET RESCUE" end
		syncCounts(plot)
		Builder.SetPurchased(plot, true)
	end)
	if built then
		previous:Destroy()
	else
		replacement:Destroy()
		state:SetCapacity(player, oldCapacity)
		plot.Kennel, plot.Capacity, plot.Slots = previous, oldCapacity, oldSlots
		plot.Upgrades = oldUpgrades
		cash.Value = before
		syncCounts(plot)
		Builder.SetPurchased(plot, true)
		warn("Shelter upgrade rolled back: " .. tostring(err))
	end
	plot.Busy = false
	if built then Events.Emit(player, "Upgrade", 1, branch) end
	return built, if built then "Upgraded" else "BuildFailed"
end

-- Checks that a pet still owns the expected undelivered slot in the player's current kennel.
function ShelterService.HasReservation(player, petId, slot)
	local plot = ShelterService.GetPlot(player)
	local pet = state.Pets[petId]
	return plot ~= nil and plot.Purchased and plot.Kennel ~= nil and plot.Kennel.Parent == plot.Model
		and pet ~= nil and pet.Player == player
		and pet.PlotId == plot.Id and pet.Slot == slot and not pet.Delivered
end

-- Converts a reservation into an occupied bed and republishes capacity counts.
function ShelterService.CommitDelivery(player, petId)
	if not state:Commit(player, petId) then return false end
	syncCounts(ShelterService.GetPlot(player))
	return true
end

-- Releases the specified pet's bed/reservation and refreshes the plot's counts.
function ShelterService.FreeSlot(player, petId)
	if state:Free(player, petId) then
		local plot = ShelterService.GetPlot(player)
		if plot then syncCounts(plot) end
	end
end

-- Registers pet cleanup to run before releasing a departing player's plot.
function ShelterService.SetCleanupHandler(handler)
	cleanup = handler
end

-- Creates currency and initial player attributes once, leaving actions disabled until profile loading finishes.
function ShelterService.InitializePlayer(player)
	if balances[player] then return true end
	if player.Parent ~= Players then return false end
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "ShelterCash"
	cash.Value = Config.StartingCash
	cash.Parent = stats
	stats.Parent = player
	balances[player] = cash
	player:SetAttribute("ProfileReady", false)
	player:SetAttribute("PlotId", 0)
	player:SetAttribute("FollowingPetId", "")
	player.RespawnLocation = world.Spawn
	return true
end

-- Snapshots progress, cleans up pets, releases the ledger and resets the departing player's plot.
local function removePlayer(player)
	if beforeCleanup then beforeCleanup(player) end
	if cleanup then cleanup(player) end
	local plot = ShelterService.GetPlot(player)
	state:ReleasePlot(player)
	if plot then Builder.Reset(plot) end
	balances[player], attempts[player], notices[player] = nil, nil, nil
	availablePlots()
end

-- Creates the world and ownership ledger once, then initializes existing and newly joined players.
function ShelterService.Start(feedbackRemote)
	if world then return world end
	feedback = feedbackRemote
	state = State.new(Config.PlotCount, Config.PetCapacity)
	world = WorldBuilder.Build()
	Players.PlayerAdded:Connect(ShelterService.InitializePlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do ShelterService.InitializePlayer(player) end
	return world
end

return ShelterService
