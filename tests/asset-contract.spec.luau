local Assets = require("../src/shared/Pets/PetAssets")
local Catalog = require("../src/shared/Pets/PetCatalog")
local Contract = require("../src/shared/Pets/PetModelContract")
local Movement = require("../src/shared/Pets/MovementProfiles")
local Animations = require("../src/shared/Pets/AnimationProfiles")

local checks = 0
local function check(value, message) checks += 1; assert(value, message) end

for _, species in { "Dog", "Cat", "Bunny", "Hamster", "GuineaPig" } do
	check(Movement.Get(species).Mode == "Ground", species .. " movement profile")
	check(Animations.Validate(species), species .. " animation profile")
	check(Animations.Get(species).States.Adoption ~= nil, species .. " adoption animation state")
end

local keys = {}
for _, definition in Catalog.Definitions do
	check(Contract.ValidateDefinition(definition, Assets, Movement, Animations), definition.DefinitionId .. " model contract")
	for _, stage in definition.ModelProgression do
		local asset = Assets.Get(stage.AssetKey)
		check(asset == Assets[stage.ModelKey], "Flat and logical registry lookup agree")
		check(asset.Contract == definition.ModelContract and asset.ForwardAxis == "-Z", "Stage uses normalized forward contract")
		check(asset.Status == "GeneratedPlaceholder" or asset.Status == "Reviewed", "Only known review states")
		check(not keys[asset.Key], "Unique asset key")
		keys[asset.Key] = true
	end
end

local resolved = Contract.Resolve(Catalog.ById.Bunny, Assets.Get("Bunny.Puppy"), Catalog.ById.Bunny.ModelProgression[1])
check(resolved.RootName == "Root" and resolved.LeashAttachmentName == "LeashAttachment", "Stable root and leash names")
check(resolved.InteractionAttachmentName == "PromptAttachment" and resolved.InteractionHeight > 0, "Stable interaction point")
check(math.abs(resolved.Scale - 0.738) < 0.0001 and resolved.MovementProfile == "Bunny" and resolved.AnimationProfile == "Bunny", "Stage/profile resolution")
check(#Assets.Groups.Dogs == 24 and #Assets.Groups.Cats == 12 and #Assets.Groups.Rabbits == 8 and #Assets.Groups.SmallPets == 8,
	"Registry groups every model stage")

print("PASS: " .. checks .. " pet asset contract and animation checks")
