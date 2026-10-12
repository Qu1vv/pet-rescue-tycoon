local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Validation = require(script.Parent.Parent.Common.Validation)
local Movement = {}
local attempts, connections = {}, {}
local started = false

-- Accepts only a desired running flag; speed values always come from server configuration.
function Movement.SetRunning(player, running)
	if type(running) ~= "boolean" or not Validation.Player(player) then return false end
	local now = os.clock()
	-- Always allow release so a quick key-up or lost focus cannot leave sprint stuck on.
	if running and attempts[player] and now - attempts[player] < Config.SprintRequestCooldown then return false end
	attempts[player] = now
	local root = Validation.Root(player)
	if not root or (running and player:GetAttribute("ProfileReady") ~= true) then return false end
	root.Parent:FindFirstChildOfClass("Humanoid").WalkSpeed = if running then Config.RunSpeed else Config.WalkSpeed
	player:SetAttribute("Running", running)
	return true
end

-- Resets movement on respawn and binds one validated sprint request endpoint.
function Movement.Start(remote)
	if started then return end
	started = true
	-- Registers one respawn listener per player, including players already present.
	local function watch(player)
		if connections[player] then return end
		-- Restores walking speed only if this is still the player's current character.
		local function spawned(character)
			player:SetAttribute("Running", false)
			local humanoid = character:WaitForChild("Humanoid", 10)
			if humanoid and player.Character == character then humanoid.WalkSpeed = Config.WalkSpeed end
		end
		connections[player] = player.CharacterAdded:Connect(spawned)
		if player.Character then task.spawn(spawned, player.Character) end
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		if connections[player] then connections[player]:Disconnect() end
		connections[player], attempts[player] = nil, nil
	end)
	for _, player in Players:GetPlayers() do watch(player) end
	remote.OnServerEvent:Connect(Movement.SetRunning)
end
return Movement
