local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShelterService = require(script:WaitForChild("Shelter"):WaitForChild("ShelterService"))
local PadService = require(script:WaitForChild("Shelter"):WaitForChild("PadService"))
local PetService = require(script:WaitForChild("Pets"):WaitForChild("PetService"))
local FoodService = require(script:WaitForChild("Food"):WaitForChild("FoodService"))
local ProfileService = require(script:WaitForChild("Persistence"):WaitForChild("ProfileService"))
local MovementService = require(script:WaitForChild("Players"):WaitForChild("MovementService"))
local Rewards = require(script.Players.RewardService)
local Biomes = require(script.World.BiomeService)
local AdopterRequests = require(script.Pets.AdopterRequestService)

local remotes = Instance.new("Folder")
remotes.Name = "ShelterRemotes"
for _, name in { "Feedback", "PetDetails", "PetEncounter", "PetAction", "SprintRequest", "RewardClaim", "GuideAction" } do
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
end
remotes.Parent = ReplicatedStorage

ShelterService.Start(remotes.Feedback)
FoodService.Start(ShelterService)
AdopterRequests.Start(ShelterService)
PetService.Start(ShelterService, remotes, FoodService, AdopterRequests)
Rewards.Start(ShelterService, remotes)
ProfileService.Start(ShelterService, PetService, FoodService)
PadService.Start(ShelterService)
MovementService.Start(remotes.SprintRequest)
Biomes.Start()
