-- Server-owned timed deliveries. Visual drops never determine storage amounts.
local FoodState = {}
FoodState.__index = FoodState

-- Creates an empty food ledger with production and manual-generation deadlines.
function FoodState.new(config, now)
	return setmetatable({ Config = config, Amount = 0, Ready = 0, Pending = {}, NextManual = 0, NextDrop = now + config.FoodProductionInterval }, FoodState)
end

-- Queues a timed drop if cooldown, visible-item and bin-capacity limits allow it.
function FoodState:Produce(now, manual)
	local config = self.Config
	if manual then
		if now < self.NextManual then return false end
		self.NextManual = now + config.ManualGenerateCooldown
	end
	local committed = self.Ready
	for _, drop in self.Pending do committed += drop.Amount end
	if #self.Pending >= config.MaxVisibleFoodItems or committed + config.FoodPerDrop > config.FoodBinCapacity then return false end
	table.insert(self.Pending, { Due = now + config.FoodTravelSeconds, Amount = config.FoodPerDrop })
	return true
end

-- Transfers only the food that fits in storage, retaining overflow in the bin; returns the amount moved.
function FoodState:Collect()
	local amount = math.min(self.Ready, self.Config.FoodStorageCapacity - self.Amount)
	self.Ready -= amount
	self.Amount += amount
	return amount
end

-- Settles arrived drops into the bin and schedules at most one passive drop, avoiding catch-up bursts.
function FoodState:Step(now)
	local config = self.Config
	for index = #self.Pending, 1, -1 do
		local drop = self.Pending[index]
		if now >= drop.Due then
			self.Ready += drop.Amount
			table.remove(self.Pending, index)
		end
	end
	if now < self.NextDrop then return false end
	-- No unbounded catch-up burst after a stalled server frame.
	self.NextDrop = now + config.FoodProductionInterval
	return self:Produce(now, false)
end

-- Rejects invalid or unaffordable amounts; otherwise subtracts food and returns true.
function FoodState:TryConsume(amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount % 1 ~= 0 or self.Amount < amount then return false end
	self.Amount -= amount
	return true
end

return FoodState
