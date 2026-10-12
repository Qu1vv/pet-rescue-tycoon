local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Build = require(script.Parent.Parent.Common.BuildUtil)
local Assets = require(game:GetService("ReplicatedStorage").Shared.Pets.PetAssets)
local Normalizer = require(script.Parent.PetModelNormalizer)
local PetBuilder = {}
local templates = {}

-- Constructs original plush geometry from the same descriptors used by the art preview.
local function original(model, definition, coat, stage)
	local Geometry = require(game:GetService("ReplicatedStorage").Shared.Pets.PetGeometry)
	local root = Build.Part(model, "Root", Vector3.one * 0.2, CFrame.new())
	root.Transparency = 1
	model.PrimaryPart = root
	local visuals = Instance.new("Model")
	visuals.Name, visuals.Parent = "Visuals", model
	for _, shape in Geometry.Build(definition, coat, stage) do
		local position, rotation = shape.Position, shape.Rotation
		local part = Build.Part(visuals, shape.Name, Vector3.new(table.unpack(shape.Size)),
			CFrame.new(table.unpack(position)) * CFrame.Angles(math.rad(rotation[1]), math.rad(rotation[2]), math.rad(rotation[3])),
			Color3.fromRGB(table.unpack(shape.Color)))
		part.Shape = Enum.PartType.Ball
	end
end
-- Caches an explicitly reviewed local template only after the safety audit accepts every descendant.
local function reviewedTemplate(key)
	if templates[key] ~= nil then return templates[key] or nil end
	templates[key] = false
	local asset = Assets.Get(key)
	if not asset or asset.Status ~= "Reviewed" then return nil end
	local source = script.Parent
	for _, segment in asset.Path do source = source and source:FindFirstChild(segment) end
	if not source then return nil end
	-- Templates are opt-in local files. Missing review metadata never blocks play.
	if not source:IsA("Model") or source:GetAttribute("Reviewed") ~= true then
		warn("Ignoring unreviewed pet template: " .. key)
		return nil
	end
	local ok, reason = Normalizer.Audit(source, asset)
	if not ok then
		warn("Ignoring unsafe pet template " .. key .. ": " .. reason)
		return nil
	end
	local clone = source:Clone()
	templates[key] = clone
	return clone
end

-- Builds reviewed template art or original geometry, applies its tier, and returns the rescue/details prompt.
function PetBuilder.Build(model, definition, coat, stage)
	local tint = table.clone(coat)
	tint.OriginalVariant = coat
	tint.Color = Color3.fromRGB(table.unpack(coat.Color))
	coat = tint
	local key = if stage then stage.AssetKey or stage.ModelKey else definition.AssetKey or definition.ModelKey
	local asset = assert(Assets.Get(key), "Missing pet asset registry entry: " .. tostring(key))
	local template = reviewedTemplate(key)
	local normalizationAsset = asset
	if template then
		for _, child in template:GetChildren() do child:Clone().Parent = model end
		for _, item in model:GetDescendants() do
			if item:IsA("BasePart") and item:GetAttribute("CoatTint") then item.Color = coat.Color end
		end
	else
		original(model, definition, tint.OriginalVariant, stage)
		if asset.Status == "Reviewed" then
			normalizationAsset = table.clone(asset)
			normalizationAsset.Scale, normalizationAsset.ForwardYaw, normalizationAsset.GroundOffset = asset.FallbackScale or 1, 0, 0
			normalizationAsset.RigMode, normalizationAsset.LeashOffset, normalizationAsset.InteractionHeight = nil, nil, nil
		end
	end
	local contract = Normalizer.Normalize(model, definition, normalizationAsset, stage)
	local point = assert(model.PrimaryPart:FindFirstChild(contract.InteractionAttachmentName), "Missing normalized interaction attachment")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PetPrompt"
	prompt.ActionText = "Rescue"
	prompt.ObjectText = coat.Name .. " " .. definition.Species
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.InteractionDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = point
	model:SetAttribute("NameplateHeight", math.max(contract.InteractionHeight + 0.5, model:GetExtentsSize().Y + 0.65))
	return prompt
end

-- Replaces only visual children, preserving the live model/root/prompt and all logical pet identity.
function PetBuilder.RefreshVisual(model, definition, coat, stage)
	local replacement = Instance.new("Model")
	local ok, err = pcall(function()
		PetBuilder.Build(replacement, definition, coat, stage)
		replacement:PivotTo(model:GetPivot())
	end)
	if not ok then replacement:Destroy(); warn("Pet appearance unchanged: " .. tostring(err)); return false end
	-- Retain the live root, prompt, attributes and model identity. Replace only art and rig joints.
	local old = {}
	for _, child in model:GetChildren() do if child ~= model.PrimaryPart then table.insert(old, child) end end
	for _, child in model.PrimaryPart:GetChildren() do
		if child.Name ~= "LeashAttachment" and child.Name ~= "PromptAttachment" then child:Destroy() end
	end
	model.PrimaryPart.Size = replacement.PrimaryPart.Size
	for _, name in { "LeashAttachment", "PromptAttachment" } do
		local current = model.PrimaryPart:FindFirstChild(name)
		local incoming = replacement.PrimaryPart:FindFirstChild(name)
		if current and incoming then current.Position = incoming.Position; current.Orientation = incoming.Orientation end
	end
	for _, child in replacement:GetChildren() do
		if child ~= replacement.PrimaryPart then child.Parent = model end
	end
	for _, child in replacement.PrimaryPart:GetChildren() do
		if child.Name ~= "LeashAttachment" and child.Name ~= "PromptAttachment" then child.Parent = model.PrimaryPart end
	end
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") then
			if item.Part0 == replacement.PrimaryPart then item.Part0 = model.PrimaryPart end
			if item.Part1 == replacement.PrimaryPart then item.Part1 = model.PrimaryPart end
		end
	end
	for _, child in old do child:Destroy() end
	for _, attribute in { "NameplateHeight", "ModelContractVersion", "ForwardAxis", "MovementProfile", "AnimationProfile" } do
		model:SetAttribute(attribute, replacement:GetAttribute(attribute))
	end
	replacement:Destroy()
	return true
end

return PetBuilder
