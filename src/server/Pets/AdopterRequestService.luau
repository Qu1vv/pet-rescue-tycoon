local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Definitions = require(game:GetService("ReplicatedStorage").Shared.Pets.AdoptionRequests)

local RequestService = {}
local requests = {}
local random = Random.new()
local shelter
local changed
local started = false

-- Copies one server request into plot attributes used only for presentation.
local function publish(plot, request)
	local values = {
		AdopterRequestId = request and request.Id or "",
		AdopterRequestText = request and request.Text or "",
		AdopterRequestKind = request and request.Kind or "",
		AdopterRequestValue = request and request.Value or "",
		AdopterRequestBonus = request and request.BonusMultiplier or 1,
		AdopterRequestExpiresAt = request and request.ExpiresAt or 0,
	}
	for key, value in values do
		if plot.Model:GetAttribute(key) ~= value then plot.Model:SetAttribute(key, value) end
	end
	local label = plot.Kennel and plot.Kennel:FindFirstChild("AdopterRequestLabel", true)
	if label then
		local newline = string.char(10)
		local percent = if request then math.floor((request.BonusMultiplier - 1) * 100 + 0.5) else 0
		label.Text = if request then "ADOPTER REQUEST" .. newline .. request.Text .. newline .. percent .. "% match bonus"
			else "ADOPTER REQUEST" .. newline .. "Finding a local family…"
	end
end

-- Returns the current request, rolling a new server-owned preference after expiry.
function RequestService.Ensure(player)
	local plot = shelter and shelter.GetPlot(player)
	if not plot or not plot.Purchased then return nil end
	local request = requests[player]
	if not request or request.ExpiresAt <= os.time() then
		request = Definitions.Roll(function() return random:NextNumber() end, os.time())
		requests[player] = request
		publish(plot, request)
		if changed then changed(player) end
	end
	publish(plot, request)
	return request
end

-- Calculates the display and transaction offer from current private pet data.
function RequestService.GetOffer(player, pet, baseValue)
	local request = RequestService.Ensure(player)
	if not request then return baseValue, 0, false end
	return Definitions.GetOffer(request, pet, baseValue)
end

-- Rotates a fulfilled preference after the successful adopter exit transaction.
function RequestService.Complete(player, pet)
	local request = requests[player]
	if not Definitions.Matches(request, pet) then return false end
	requests[player] = nil
	local plot = shelter.GetPlot(player)
	if plot then publish(plot, nil); RequestService.Ensure(player) end
	return true
end

-- Removes transient request state when a player no longer owns a purchased shelter.
local function sweep()
	for player in requests do
		local plot = shelter.GetPlot(player)
		if player.Parent ~= Players or not plot or not plot.Purchased then
			if plot then publish(plot, nil) end
			requests[player] = nil
		end
	end
	for _, player in Players:GetPlayers() do RequestService.Ensure(player) end
end

-- Registers a server callback that republishes pet offers whenever preferences rotate.
function RequestService.SetChangedHandler(handler)
	changed = handler
end

-- Starts one low-frequency request lifecycle loop for all six shelters.
function RequestService.Start(shelterService)
	if started then return end
	started = true
	shelter = shelterService
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 then return end
		elapsed = 0
		sweep()
	end)
end

return RequestService
