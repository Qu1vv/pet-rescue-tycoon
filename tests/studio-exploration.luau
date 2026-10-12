-- Paste this complete file into the SERVER Command Bar during a fresh solo Play session.
-- It validates the exploration/reward milestone without requiring private DataStore access.
local Players = game:GetService("Players")
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Biomes = require(Shared.Config.Biomes)
local RewardConfig = require(Shared.Config.Rewards)
local RewardService = require(Server.Players.RewardService)
local Events = require(Server.Common.GameplayEvents)

local player = Players:GetPlayers()[1]
assert(player, "Start a solo Play session first")
local deadline = os.clock() + 15
while player:GetAttribute("ProfileReady") ~= true and os.clock() < deadline do task.wait(0.1) end
assert(player:GetAttribute("ProfileReady") == true, "Profile did not finish loading")

local world = workspace:FindFirstChild("ShelterWorld")
local cleanup = require(game.ServerScriptService.Server.World.LegacyWorldCleanup)
for _, instance in workspace:GetDescendants() do
    assert(not cleanup.IsLegacySlab(instance), "Legacy map-sized slab survived runtime cleanup: " .. instance:GetFullName())
end
assert(world and not workspace:FindFirstChild("ShelterPreview"), "Runtime world did not replace the edit preview")
local habitatFolder = world:FindFirstChild("Biomes")
assert(habitatFolder and habitatFolder:FindFirstChild("DogPark") and habitatFolder:FindFirstChild("Forest")
	and habitatFolder:FindFirstChild("Orchard"), "Expected three built habitats")

local counts, positions = {}, {}
for _, pet in world.Pets:GetChildren() do
	if pet:GetAttribute("State") == "Available" then
		local biomeId = pet:GetAttribute("BiomeId")
		local biome = Biomes[biomeId]
		assert(biome, "Available pet is missing a configured biome")
		assert(biome.Species[pet:GetAttribute("Species")] == true, "Pet species is not allowed in its biome")
		counts[biomeId] = (counts[biomeId] or 0) + 1
		table.insert(positions, pet:GetPivot().Position)
	end
end
for id, biome in Biomes do
	assert(counts[id] == biome.MaxActive, id .. " population mismatch")
end
for i = 1, #positions do
	for j = i + 1, #positions do
		assert((positions[i] - positions[j]).Magnitude >= 6, "Two available pets overlap")
	end
end
assert(counts.Forest > 0, "Forest needs rabbit and small-animal candidates")

for _, descendant in workspace:GetDescendants() do
	if descendant:IsA("SpawnLocation") then
		assert(descendant.Transparency == 1, "A visible default spawn marker remains")
		for _, child in descendant:GetChildren() do
			assert(not child:IsA("Decal") and not child:IsA("Texture"), "Spawn decoration remains")
		end
	end
end

-- Complete one active daily through the internal server event bus, then prove it pays exactly once.
local goalFolder = player:WaitForChild("RescueGoals")
local day = math.floor(os.time() / RewardConfig.ResetSeconds)
local quest = require(Shared.Config.RewardState).Active(day, RewardConfig)[1]
Events.Emit(player, quest.Event, quest.Target, quest.Detail)
task.wait()
local row = goalFolder:FindFirstChild(quest.Id)
assert(row and row:GetAttribute("Progress") == quest.Target, "Server event did not advance the daily")
local cash = player.leaderstats.ShelterCash
local before = cash.Value
assert(RewardService.Claim(player, "Daily", quest.Id), "Completed daily reward was rejected")
assert(cash.Value == before + quest.Cash, "Daily reward amount was not server configured")
assert(not RewardService.Claim(player, "Daily", quest.Id), "Daily reward paid twice")
assert(cash.Value == before + quest.Cash, "Duplicate claim changed cash")

print("PASS: habitats, biome populations, spawn cleanup and one-time server reward")
