local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local FoodState = require(script.Parent.FoodState)
local Upgrades = require(game:GetService("ReplicatedStorage").Shared.Config.ShelterUpgrades)
local Validation = require(script.Parent.Parent.Common.Validation)
local Events = require(script.Parent.Parent.Common.GameplayEvents)
local FoodService = {}
local shelter
local sessions = {}
local interactions = {}

-- Replicates food totals and advances the visual drop sequence only when a drop was produced.
local function publish(plot, state, dropped)
	plot.Model:SetAttribute("StoredFood", state.Amount)
	plot.Model:SetAttribute("PendingFood", state.Ready)
	if dropped then
		plot.Model:SetAttribute("FoodDropStartedAt", workspace:GetServerTimeNow())
		plot.Model:SetAttribute("FoodDropSequence", (plot.Model:GetAttribute("FoodDropSequence") or 0) + 1)
	end
end

-- Returns the current owner's food ledger, creating one only for a purchased shelter.
local function session(plot, now)
	if not plot or not plot.Owner or not plot.Purchased then return nil end
	local current = sessions[plot.Id]
	if not current or current.Owner ~= plot.Owner then
		current = { Owner = plot.Owner, State = FoodState.new(Upgrades.Stats(plot.Upgrades, Config), now), Levels = plot.Upgrades }
		sessions[plot.Id] = current
	end
	if current.Levels ~= plot.Upgrades then
		current.State.Config = Upgrades.Stats(plot.Upgrades, Config)
		current.State.NextDrop = math.min(current.State.NextDrop, now + current.State.Config.FoodProductionInterval)
		current.Levels = plot.Upgrades
	end
	return current.State
end

-- Returns spendable food for the player's purchased shelter, or zero without a food session.
function FoodService.GetStoredFood(player)
	local state = session(shelter.GetPlot(player), os.clock())
	return if state then state.Amount else 0
end

-- Snapshots stored and bin food; visual items still travelling on the belt are excluded.
function FoodService.Export(player)
	local state = session(shelter.GetPlot(player), os.clock())
	return { Stored = if state then state.Amount else 0, Pending = if state then state.Ready else 0 }
end

-- Restores validated saved food totals into the player's session and refreshes replicated values.
function FoodService.Restore(player, data)
	local plot = shelter.GetPlot(player)
	local state = session(plot, os.clock())
	if state then
		state.Amount, state.Ready = data.Stored, data.Pending
		publish(plot, state, false)
	end
end

-- Validates profile, ownership, living proximity and rate limits before generating or collecting food.
function FoodService.Interact(player, target)
	if player:GetAttribute("ProfileReady") ~= true then return false end
	local now = os.clock()
	if interactions[player] and now - interactions[player] < 0.2 then return false end
	interactions[player] = now
	local plot = shelter.GetPlot(player)
	if not plot or not plot.Kennel or not target:IsDescendantOf(plot.Kennel)
		or not target:IsA("BasePart") or not Validation.Near(player, target.Position, Config.InteractionDistance) then return false end
	local state = session(plot, now)
	if not state then return false end
	if target.Name == "GenerateButton" then
		local dropped = state:Produce(now, true)
		publish(plot, state, dropped)
		if dropped then plot.Model:SetAttribute("ManualFoodAt", workspace:GetServerTimeNow()); Events.Emit(player, "Generate") end
		return dropped
	elseif target.Name == "FoodCollection" then
		local amount = state:Collect()
		publish(plot, state, false)
		shelter.Notify(player, "FoodCollected", amount)
		if amount > 0 then Events.Emit(player, "CollectFood", amount) end
		return amount > 0
	end
	return false
end

-- Debits food only when the session can afford it, then updates the replicated storage amount.
function FoodService.TryConsume(player, amount)
	local plot = shelter.GetPlot(player)
	local state = session(plot, os.clock())
	if not state or not state:TryConsume(amount) then return false end
	plot.Model:SetAttribute("StoredFood", state.Amount)
	return true
end

-- Registers server food interactions and one timed production loop for all shelters.
function FoodService.Start(shelterService)
	if shelter then return end
	shelter = shelterService
	game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt, player)
		if prompt.Name == "FoodInteraction" then FoodService.Interact(player, prompt.Parent) end
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player) interactions[player] = nil end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then return end
		elapsed = 0
		local now = os.clock()
		for _, plot in shelter.GetWorld().Plots do
			local state = session(plot, now)
			if state then
				publish(plot, state, state:Step(now))
			else
				sessions[plot.Id] = nil
			end
		end
	end)
end

return FoodService
