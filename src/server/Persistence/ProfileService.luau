local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config.GameConfig)
local Catalog = require(Shared.Pets.PetCatalog)
local Data = require(script.Parent.ProfileData)
local Collection = require(script.Parent.Parent.Pets.CollectionService)
local Rewards = require(script.Parent.Parent.Players.RewardService)
local Profiles = {}
local sessions = {}
local shelter, pets, food, store
local persistent = not RunService:IsStudio() or Config.StudioPersistence
local token = game.JobId .. ":" .. HttpService:GenerateGUID(false)

-- Captures a validated, independent profile while preserving saved pets if no plot has been claimed.
local function snapshot(player, session)
	local data = session.Data
	if session.Restored then
		local plot = shelter.GetPlot(player)
		assert(plot, "Restored profile has no shelter")
		data = { Version = 5, Purchased = plot.Purchased, Capacity = plot.Capacity, Upgrades = table.clone(plot.Upgrades),
			Pets = pets.Export(player), Food = food.Export(player) }
	else
		data = table.clone(data) -- unclaimed saved shelter is retained
	end
	data.Cash = shelter.GetCash(player) or data.Cash
	data.Index = Collection.Export(player)
	data.Rewards = Rewards.Export(player)
	return Data.Validate(data, Config, Catalog)
end

local save
-- Serializes UpdateAsync writes under our lease; retries failures and prioritizes the final departure snapshot.
save = function(player, session)
	if session.Busy or session.Failed then return end
	if not persistent then if session.Closing then sessions[player] = nil end; return end
	session.Busy = true
	player:SetAttribute("SaveState", "Saving")
	task.spawn(function()
		local closing, saved = session.Closing, false
		local payload = session.Snapshot
		for attempt = 1, Config.SaveRetryCount do
			local ok, result = pcall(function()
				return store:UpdateAsync("Player_" .. player.UserId, function(old)
					if type(old) ~= "table" or not Data.Owns(old.Lock, token) then return nil end
					return { Data = payload, Lock = if closing then nil else { Token = token, Expires = os.time() + Config.SessionLockSeconds } }
				end)
			end)
			if ok and result then saved = true; break end
			if ok then
				session.Failed = true
				player:SetAttribute("SaveState", "Error")
				player:SetAttribute("ProfileReady", false)
				if player.Parent == Players then player:Kick("Your save session changed. Please rejoin safely.") end
				break
			end
			warn("Shelter save retry: " .. tostring(result))
			task.wait(Config.SaveRetryDelay * attempt)
		end
		session.Busy = false
		if saved then
			session.LastSaved = os.clock()
			player:SetAttribute("LastSaveAt", os.time())
			player:SetAttribute("SaveState", "Saved")
		elseif not closing then
			player:SetAttribute("SaveState", "Retrying")
		end
		if closing then
			if not saved then warn("Final shelter save failed for " .. player.UserId .. "; last autosave retained") end
			sessions[player] = nil
		elseif session.Closing then
			save(player, session) -- final snapshot wins over an already-running autosave
		elseif not saved and os.clock() - session.LastSaved >= Config.SessionLockSeconds - Config.SaveInterval then
			player:SetAttribute("ProfileReady", false)
			player:Kick("Saving is unavailable. Please rejoin; your last saved progress is protected.")
		end
	end)
end

-- Captures progress before world cleanup, freezes actions and starts the final lease-releasing save.
local function close(player)
	local session = sessions[player]
	if not session or session.Closing then return end
	session.Closing = true
	player:SetAttribute("ProfileReady", false)
	if session.Loaded and not session.Failed then
		local ok, result = pcall(snapshot, player, session)
		if ok then session.Snapshot = result else session.Failed = true; warn("Profile snapshot rejected: " .. tostring(result)) end
		save(player, session)
	end
	Collection.Cleanup(player)
	Rewards.Cleanup(player)
	if session.Failed then sessions[player] = nil end
end

-- Acquires a profile lease, validates data and enables gameplay only after successful initialization.
local function load(player)
	if sessions[player] then return end
	-- PlayerAdded listeners are independent tasks; never assume the cash listener ran first.
	if not shelter.InitializePlayer(player) then return end
	local session = { Data = Data.New(Config), LastSaved = os.clock(), Restored = false }
	sessions[player] = session
	player:SetAttribute("PersistenceEnabled", persistent)
	player:SetAttribute("SaveState", "Loading")
	player:SetAttribute("LastSaveAt", 0)
	local ok, err = pcall(function()
		if persistent then
			local result = store:UpdateAsync("Player_" .. player.UserId, function(old)
				if old ~= nil then
					assert(type(old) == "table", "Invalid save envelope")
					if not Data.CanAcquire(old.Lock, token, os.time()) then return nil end
				end
				local data = if old then Data.Validate(old.Data, Config, Catalog) else Data.New(Config)
				return { Data = data, Lock = { Token = token, Expires = os.time() + Config.SessionLockSeconds } }
			end)
			assert(result, "Profile is still active in another server; retry shortly")
			session.Data = Data.Validate(result.Data, Config, Catalog)
		end
	end)
	if not ok then
		session.Failed = true
		player:SetAttribute("SaveState", "Error")
		warn("Profile load stopped without overwriting data: " .. tostring(err))
		if player.Parent == Players then player:Kick("Could not load your shelter safely. Please rejoin in a moment.") end
		sessions[player] = nil
		return
	end
	session.Loaded, session.Snapshot = true, session.Data
	player:SetAttribute("SaveState", if persistent then "Saved" else "Studio")
	if session.Closing or player.Parent ~= Players then session.Closing = true; save(player, session); return end
	Collection.Load(player, session.Data.Index)
	Rewards.Load(player, session.Data.Rewards)
	shelter.RestoreCash(player, session.Data.Cash)
	player:SetAttribute("ProfileReady", true)
end

-- Loads profiles, restores claimed shelters, and registers autosave/departure/shutdown handling with session leases.
function Profiles.Start(shelterService, petService, foodService)
	if shelter then return end
	shelter, pets, food = shelterService, petService, foodService
	if persistent then store = game:GetService("DataStoreService"):GetDataStore(Config.DataStoreName) end
	shelter.SetLifecycleHandlers(function(player)
		local session = sessions[player]
		if not session or not session.Loaded or session.Restored then return end
		local ok, err = pcall(function()
			shelter.RestorePlot(player, session.Data.Purchased, session.Data.Capacity, session.Data.Upgrades)
			food.Restore(player, session.Data.Food)
			pets.Restore(player, session.Data.Pets)
		end)
		if ok then session.Restored = true else
			session.Failed = true -- never save a partly restored shelter
			player:SetAttribute("ProfileReady", false)
			warn("Shelter restore failed: " .. tostring(err))
			player:Kick("Shelter restoration failed safely. Please rejoin.")
		end
	end, close)
	Players.PlayerAdded:Connect(function(player) task.spawn(load, player) end)
	for _, player in Players:GetPlayers() do task.spawn(load, player) end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.SaveInterval then return end
		elapsed = 0
		for player, session in sessions do
			if session.Loaded and not session.Closing and not session.Failed then
				local ok, result = pcall(snapshot, player, session)
				if ok then session.Snapshot = result; save(player, session)
				else session.Failed = true; player:SetAttribute("ProfileReady", false); warn(result); player:Kick("Unable to save safely. Please rejoin.") end
			end
		end
	end)
	game:BindToClose(function()
		for player in sessions do close(player) end
		local deadline = os.clock() + 25
		while next(sessions) and os.clock() < deadline do task.wait(0.1) end
	end)
end
return Profiles
