-- Pure session ledger. No Roblox instances or yielding: claims and reservations
-- are atomic and can be tested with the standalone Luau runtime.
local ShelterState = {}
ShelterState.__index = ShelterState

-- Creates an empty ownership/slot ledger for the configured number of plots.
function ShelterState.new(plotCount, capacity)
	local self = setmetatable({ Plots = {}, Owners = {}, Pets = {}, Capacity = capacity }, ShelterState)
	for id = 1, plotCount do self.Plots[id] = { Owner = nil, Slots = {}, Capacity = capacity } end
	return self
end

-- Atomically assigns one vacant plot to a player who does not already own one.
function ShelterState:Claim(player, plotId)
	local plot = self.Plots[plotId]
	if not plot then return false, "Unavailable" end
	if self.Owners[player] then return false, "AlreadyOwnPlot" end
	if plot.Owner then return false, "PlotTaken" end
	plot.Owner = player
	self.Owners[player] = plotId
	return true, "Claimed"
end

-- Claims the first free bed for a unique pet ID; returns its slot or a rejection reason.
function ShelterState:Reserve(player, petId)
	local plotId = self.Owners[player]
	local plot = plotId and self.Plots[plotId]
	if not plot then return nil, "NeedPlot" end
	if self.Pets[petId] then return nil, "PetUnavailable" end
	for slot = 1, plot.Capacity do
		if not plot.Slots[slot] then
			plot.Slots[slot] = petId
			self.Pets[petId] = { Player = player, PlotId = plotId, Slot = slot, Delivered = false }
			return slot, "Reserved"
		end
	end
	return nil, "ShelterFull"
end

-- Marks the owner's existing reservation as delivered, rejecting repeat or foreign commits.
function ShelterState:Commit(player, petId)
	local pet = self.Pets[petId]
	if not pet or pet.Player ~= player or self.Owners[player] ~= pet.PlotId or pet.Delivered then
		return false
	end
	pet.Delivered = true
	return true
end

-- Removes only the specified owner's pet entry and makes its bed available again.
function ShelterState:Free(player, petId)
	local pet = self.Pets[petId]
	if not pet or pet.Player ~= player then return false end
	self.Plots[pet.PlotId].Slots[pet.Slot] = nil
	self.Pets[petId] = nil
	return true
end

-- Returns separate delivered and reserved counts for a plot.
function ShelterState:Counts(plotId)
	local delivered, reserved = 0, 0
	local plot = self.Plots[plotId]
	if plot then
		for _, petId in plot.Slots do
			if self.Pets[petId].Delivered then delivered += 1 else reserved += 1 end
		end
	end
	return delivered, reserved
end

-- Clears ownership and pet entries, resets capacity, and returns the released plot ID.
function ShelterState:ReleasePlot(player)
	local id = self.Owners[player]
	if not id then return nil end
	local plot = self.Plots[id]
	for _, petId in plot.Slots do self.Pets[petId] = nil end
	table.clear(plot.Slots)
	plot.Owner = nil
	plot.Capacity = self.Capacity
	self.Owners[player] = nil
	return id
end

-- Returns total occupied/reserved beds, maximum capacity and whether any bed is free.
function ShelterState:GetCapacity(player)
	local id = self.Owners[player]
	if not id then return 0, 0, false end
	local count, reserved = self:Counts(id)
	local maximum = self.Plots[id].Capacity
	return count + reserved, maximum, count + reserved < maximum
end

-- Changes capacity only if it is valid and does not discard an occupied slot.
function ShelterState:SetCapacity(player, capacity)
	local id = self.Owners[player]
	if not id or type(capacity) ~= "number" or capacity ~= capacity or capacity == math.huge
		or capacity < 1 or capacity % 1 ~= 0 then return false end
	for slot in self.Plots[id].Slots do if slot > capacity then return false end end
	self.Plots[id].Capacity = capacity
	return true
end

return ShelterState
