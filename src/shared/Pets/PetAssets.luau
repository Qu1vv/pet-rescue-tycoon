-- Approved LOCAL paths only. No Marketplace IDs and no runtime asset insertion.
-- Reviewed files live beneath src/server/Pets/PetModels/<definition>/<stage>.rbxmx.
local Assets = { Groups = {}, ByKey = {} }

local groups = {
	Dogs = {
		{ "GoldenRetriever", "Dog" }, { "Labrador", "Dog" }, { "Husky", "Dog" },
		{ "Corgi", "Dog" }, { "ShibaInu", "Dog" }, { "GermanShepherd", "Dog" },
	},
	Cats = { { "HouseCat", "Cat" }, { "Siamese", "Cat" }, { "Persian", "Cat" } },
	Rabbits = { { "Bunny", "Bunny" }, { "WoodlandRabbit", "Bunny" } },
	SmallPets = { { "Hamster", "Hamster" }, { "GuineaPig", "GuineaPig" } },
}
local speciesScale = { Dog = 1, Cat = 0.92, Bunny = 0.9, Hamster = 0.72, GuineaPig = 0.78 }

-- Add reviewed per-stage overrides here after the static/manual asset review is complete.
-- Example fields: Status, Source, Creator, Permission, ReviewDate, RigMode, Scale,
-- ForwardYaw, GroundOffset, LeashOffset, InteractionHeight and reviewed dependency flags.
local approved = {}

-- Registers one logical stage key with its review metadata and normalization contract.
local function register(groupName, definitionId, species, stage)
	local key = definitionId .. "." .. stage
	local review = approved[key] or {}
	local record = table.freeze({
		Key = key,
		DefinitionId = definitionId,
		Species = species,
		Stage = stage,
		Path = review.Path or { "PetModels", definitionId, stage },
		Status = review.Status or "GeneratedPlaceholder",
		Source = review.Source or "Original project geometry",
		Creator = review.Creator,
		Permission = review.Permission,
		ReviewDate = review.ReviewDate,
		Contract = "GroundPetV1",
		ForwardAxis = "-Z",
		ForwardYaw = review.ForwardYaw or 0,
		GroundOffset = review.GroundOffset or 0,
		Scale = review.Scale or speciesScale[species] or 1,
		FallbackScale = speciesScale[species] or 1,
		LeashOffset = review.LeashOffset,
		InteractionHeight = review.InteractionHeight,
		MovementProfile = review.MovementProfile or species,
		AnimationProfile = review.AnimationProfile or species,
		DependenciesReviewed = review.DependenciesReviewed == true,
		AnimationsReviewed = review.AnimationsReviewed == true,
		RigMode = review.RigMode,
		AllowConstraints = review.AllowConstraints,
		MaxDescendants = review.MaxDescendants or 180,
	})
	Assets[key], Assets.ByKey[key] = record, record
	table.insert(Assets.Groups[groupName], key)
end

for groupName, definitions in groups do
	Assets.Groups[groupName] = {}
	for _, definition in definitions do
		for _, stage in { "Puppy", "Young", "Adult", "Champion" } do
			register(groupName, definition[1], definition[2], stage)
		end
	end
	Assets.Groups[groupName] = table.freeze(Assets.Groups[groupName])
end

-- Resolves one logical asset key without exposing any runtime asset-loading mechanism.
function Assets.Get(key)
	return Assets.ByKey[key]
end

Assets.Groups = table.freeze(Assets.Groups)
Assets.ByKey = table.freeze(Assets.ByKey)
return table.freeze(Assets)
