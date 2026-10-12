-- Paste this complete file into the SERVER Command Bar during a fresh Play session.
local Server = game:GetService("ServerScriptService"):WaitForChild("Server")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Catalog = require(Shared.Pets.PetCatalog)
local Assets = require(Shared.Pets.PetAssets)
local Contract = require(Shared.Pets.PetModelContract)
local Movement = require(Shared.Pets.MovementProfiles)
local Animations = require(Shared.Pets.AnimationProfiles)
local Builder = require(Server.Pets.PetBuilder)
local world = workspace:WaitForChild("ShelterWorld")

for _, definition in Catalog.Definitions do
	assert(Contract.ValidateDefinition(definition, Assets, Movement, Animations), "Invalid contract: " .. definition.DefinitionId)
end

local pets = world:WaitForChild("Pets"):GetChildren()
assert(#pets >= 18, "Expected the initial habitat population")
for _, model in pets do
	assert(model.PrimaryPart and model.PrimaryPart.Name == "Root", "Pet lacks normalized Root")
	assert(model.PrimaryPart:FindFirstChild("LeashAttachment"), "Pet lacks root leash attachment")
	assert(model.PrimaryPart:FindFirstChild("PromptAttachment"), "Pet lacks root interaction attachment")
	assert(model:GetAttribute("ModelContractVersion") == 1 and model:GetAttribute("ForwardAxis") == "-Z", "Pet contract metadata")
	assert(model:GetAttribute("MovementProfile") and model:GetAttribute("AnimationProfile"), "Pet profile metadata")
	assert(model:GetExtentsSize().Magnitude <= 12, "Pet exceeds model bounds budget")
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			assert(not item.CanCollide and not item.CanTouch and not item.CanQuery, "Pet collision policy regression")
		end
		assert(not item:IsA("LuaSourceContainer") and not item:IsA("RemoteEvent") and not item:IsA("RemoteFunction"), "Unsafe pet descendant")
	end
end

for _, id in { "DogPark", "Forest", "Orchard" } do
	local biome = world.Biomes:FindFirstChild(id)
	assert(biome and #biome:GetChildren() > 20, id .. " polish props missing")
	assert(#biome:GetChildren() < 120, id .. " part budget unexpectedly high")
end

-- Exercise one live visual-stage replacement and confirm the logical/prompt contract survives.
local sample = pets[1]
local definition, variant = Catalog.Get(sample:GetAttribute("DefinitionId"), sample:GetAttribute("Variant"))
assert(definition and variant, "Could not resolve sample pet")
local identity = sample:GetAttribute("PetUniqueId")
local prompt = sample:FindFirstChild("PetPrompt", true)
assert(Builder.RefreshVisual(sample, definition, variant, definition.ModelProgression[2]), "Stage replacement failed")
assert(sample:GetAttribute("PetUniqueId") == identity and sample:FindFirstChild("PetPrompt", true) == prompt, "Stage swap replaced logical pet or prompt")
assert(sample.PrimaryPart:FindFirstChild("LeashAttachment"), "Stage swap lost leash attachment")

print("PASS: M8 model contract, stage replacement, collision policy and biome budgets")
