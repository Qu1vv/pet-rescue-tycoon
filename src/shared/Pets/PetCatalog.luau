-- Data only: stable IDs are save/index keys. Colors are RGB triples for portability.
local Catalog = { Definitions = {}, Entries = {}, ById = {} }
-- Creates a configurable coat/rarity entry with default spawn and adoption weights.
local function variant(id, name, color, rarity, pattern)
	return { Id = id, Name = name, Color = color, Rarity = rarity, Pattern = pattern, Weight = 1, AdoptionMultiplier = 1 }
end
-- Registers a species definition, its default visual tiers and discoverable variant entries.
local function define(id, name, species, shape, value, variants)
	local habitat = if species == "Dog" then "DogPark" elseif species == "Cat" then "Orchard" else "Forest"
	local def = { DefinitionId = id, DisplayName = name, Species = species, Shape = shape,
		BaseAdoptionValue = value, SpawnWeight = 1, Habitat = habitat, SpawnZones = { "RescuePark", habitat }, EventTags = {}, Variants = variants,
		ModelKey = id .. ".Puppy", AssetKey = id .. ".Puppy", ModelContract = "GroundPetV1",
		MovementProfile = species, AnimationProfile = species, ModelProgression = {} }
	for index, stage in { {1,"Puppy",0.82}, {5,"Young",0.95}, {10,"Adult",1.08}, {20,"Champion",1.15} } do
		local assetKey = id .. "." .. stage[2]
		table.insert(def.ModelProgression, { MinLevel = stage[1], ModelKey = assetKey, AssetKey = assetKey, Stage = index, Scale = stage[3] })
	end
	Catalog.ById[id] = def
	table.insert(Catalog.Definitions, def)
	for _, coat in variants do
		table.insert(Catalog.Entries, { Key = id .. ":" .. coat.Id, Definition = def, Variant = coat, Rarity = coat.Rarity })
	end
end
define("GoldenRetriever", "Golden Retriever", "Dog", "Floppy", 12, {
	variant("Golden", "Golden", {221,173,102}, "Common"), variant("Cream", "Cream", {242,224,187}, "Common"),
})
define("Labrador", "Labrador", "Dog", "Floppy", 12, {
	variant("Chocolate", "Chocolate", {116,79,60}, "Common"), variant("Black", "Black", {54,58,68}, "Uncommon"),
})
define("Husky", "Husky", "Dog", "Pointed", 16, {
	variant("Gray", "Gray", {145,157,171}, "Rare", "Mask"), variant("White", "White", {238,237,226}, "Epic", "Mask"),
})
define("Corgi", "Corgi", "Dog", "Short", 14, { variant("Fawn", "Fawn", {213,151,82}, "Uncommon", "Mask") })
define("ShibaInu", "Shiba Inu", "Dog", "Pointed", 18, { variant("Sesame", "Sesame", {208,143,84}, "Legendary", "Mask") })
define("HouseCat", "House Cat", "Cat", "Cat", 12, {
	variant("Orange", "Orange", {228,154,81}, "Common"), variant("Black", "Black", {54,61,74}, "Common"),
	variant("Tuxedo", "Tuxedo", {52,58,70}, "Uncommon", "Tuxedo"), variant("Calico", "Calico", {239,226,198}, "Rare", "Calico"),
})
define("Siamese", "Siamese", "Cat", "Cat", 16, { variant("SealPoint", "Seal Point", {224,207,176}, "Epic", "Mask") })
define("Bunny", "Bunny", "Bunny", "Bunny", 14, {
	variant("White", "White", {240,233,225}, "Rare"), variant("Lop", "Cream Lop", {227,208,179}, "Mythic", "Lop"),
})
define("WoodlandRabbit", "Woodland Rabbit", "Bunny", "Bunny", 12, {
	variant("Chestnut", "Chestnut", {174,126,90}, "Common"),
	variant("Silver", "Silver", {180,190,199}, "Uncommon"),
})
define("GermanShepherd", "German Shepherd", "Dog", "Pointed", 16, {
	variant("Sable", "Sable", { 180, 137, 93 }, "Rare", "Mask"),
})
define("Persian", "Persian", "Cat", "Fluffy", 18, {
	variant("Pearl", "Pearl", { 242, 228, 214 }, "Epic"), variant("Silver", "Silver", { 178, 191, 202 }, "Legendary"),
})
define("Hamster", "Hamster", "Hamster", "Round", 10, {
	variant("Honey", "Honey", { 228, 180, 112 }, "Common"), variant("Panda", "Panda", { 92, 89, 101 }, "Uncommon", "Mask"),
})
define("GuineaPig", "Guinea Pig", "GuineaPig", "Round", 12, {
	variant("Ginger", "Ginger", { 214, 149, 105 }, "Uncommon"), variant("Tricolor", "Tricolor", { 235, 215, 183 }, "Rare", "Spotted"),
})

-- Looks up a stable definition/variant pair; returns nil when the saved identifiers are unknown.
function Catalog.Get(definitionId, variantId)
	local def = Catalog.ById[definitionId]
	if def then for _, coat in def.Variants do if coat.Id == variantId then return def, coat end end end
	return nil
end

-- Rolls an eligible rarity tier, then a weighted variant within that tier for the requested zone.
function Catalog.Roll(randomNumber, rarityWeights, zone, allowedSpecies)
	local pools, tiers, sum = {}, {}, 0
	for _, entry in Catalog.Entries do
		if table.find(entry.Definition.SpawnZones, zone) and (not allowedSpecies or allowedSpecies[entry.Definition.Species]) then
			pools[entry.Rarity] = pools[entry.Rarity] or {}
			table.insert(pools[entry.Rarity], entry)
		end
	end
	for _, rarity in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		if pools[rarity] and (rarityWeights[rarity] or 0) > 0 then
			sum += rarityWeights[rarity]; table.insert(tiers, { rarity, sum })
		end
	end
	assert(sum > 0, "No eligible pets for zone")
	local roll, chosen = randomNumber() * sum, tiers[#tiers][1]
	for _, tier in tiers do if roll < tier[2] then chosen = tier[1]; break end end
	local pool, total = pools[chosen], 0
	for _, entry in pool do total += entry.Definition.SpawnWeight * entry.Variant.Weight end
	roll = randomNumber() * total
	for _, entry in pool do
		roll -= entry.Definition.SpawnWeight * entry.Variant.Weight
		if roll < 0 then return entry.Definition, entry.Variant end
	end
	local entry = pool[#pool]
	return entry.Definition, entry.Variant
end

return Catalog
