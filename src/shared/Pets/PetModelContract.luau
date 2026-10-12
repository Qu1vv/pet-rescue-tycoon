-- Portable model-interface rules shared by registry validation, server normalization and tests.
local Contract = { Version = 1 }

Contract.Presets = table.freeze({
	GroundPetV1 = table.freeze({
		RootName = "Root",
		LeashAttachmentName = "LeashAttachment",
		InteractionAttachmentName = "PromptAttachment",
		ForwardAxis = "-Z",
		ForwardYaw = 0,
		GroundOffset = 0,
		MaxBounds = 12,
		MaxDescendants = 180,
	}),
})

local species = table.freeze({
	Dog = table.freeze({ LeashOffset = { 0, 1.55, -1.25 }, InteractionHeight = 3.9 }),
	Cat = table.freeze({ LeashOffset = { 0, 1.5, -1.2 }, InteractionHeight = 3.8 }),
	Bunny = table.freeze({ LeashOffset = { 0, 1.75, -1.05 }, InteractionHeight = 4.4 }),
	Hamster = table.freeze({ LeashOffset = { 0, 1.25, -1 }, InteractionHeight = 3.6 }),
	GuineaPig = table.freeze({ LeashOffset = { 0, 1.3, -1 }, InteractionHeight = 3.6 }),
})

-- Produces one normalized contract without mutating catalog, registry or stage data.
function Contract.Resolve(definition, asset, stage)
	asset = asset or {}
	local preset = assert(Contract.Presets[asset.Contract or definition.ModelContract or "GroundPetV1"], "Unknown pet model contract")
	local speciesRule = species[definition.Species] or species.Dog
	return {
		Version = Contract.Version,
		RootName = preset.RootName,
		LeashAttachmentName = preset.LeashAttachmentName,
		InteractionAttachmentName = preset.InteractionAttachmentName,
		ForwardAxis = asset.ForwardAxis or preset.ForwardAxis,
		ForwardYaw = asset.ForwardYaw or preset.ForwardYaw,
		GroundOffset = asset.GroundOffset or preset.GroundOffset,
		MaxBounds = asset.MaxBounds or preset.MaxBounds,
		MaxDescendants = asset.MaxDescendants or preset.MaxDescendants,
		LeashOffset = asset.LeashOffset or speciesRule.LeashOffset,
		InteractionHeight = asset.InteractionHeight or speciesRule.InteractionHeight,
		Scale = (asset.Scale or 1) * (if stage then stage.Scale or 1 else 1),
		MovementProfile = asset.MovementProfile or definition.MovementProfile or definition.Species,
		AnimationProfile = asset.AnimationProfile or definition.AnimationProfile or definition.Species,
		AllowConstraints = asset.AllowConstraints or {},
	}
end

-- Validates one catalog definition against the logical registry and shared movement/animation profiles.
function Contract.ValidateDefinition(definition, assets, movementProfiles, animationProfiles)
	if type(definition) ~= "table" or type(definition.DefinitionId) ~= "string" or type(definition.Species) ~= "string" then return false end
	if not movementProfiles.Get(definition.MovementProfile or definition.Species) then return false end
	if not animationProfiles.Validate(definition.AnimationProfile or definition.Species) then return false end
	for _, stage in definition.ModelProgression or {} do
		local asset = assets.Get and assets.Get(stage.ModelKey) or assets[stage.ModelKey]
		if not asset or asset.Species ~= definition.Species or asset.DefinitionId ~= definition.DefinitionId then return false end
		local resolved = Contract.Resolve(definition, asset, stage)
		if resolved.Scale <= 0 or resolved.MaxBounds <= 0 or resolved.ForwardAxis ~= "-Z" then return false end
	end
	return true
end

return Contract
