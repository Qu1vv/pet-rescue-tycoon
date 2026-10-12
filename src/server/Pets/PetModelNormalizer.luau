local Shared = game:GetService("ReplicatedStorage").Shared
local Contract = require(Shared.Pets.PetModelContract)
local Normalizer = {}

-- Returns whether an inspected constraint class was explicitly approved in registry metadata.
local function constraintAllowed(item, asset)
	for _, className in asset.AllowConstraints or {} do
		if item:IsA(className) then return true end
	end
	return false
end

-- Rejects executable, networked or unrelated content before a reviewed template can enter gameplay.
function Normalizer.Audit(model, asset)
	if not model or not model:IsA("Model") then return false, "Asset is not a Model" end
	local count = 0
	for _, item in model:GetDescendants() do
		count += 1
		if count > (asset.MaxDescendants or 180) then return false, "Descendant budget exceeded" end
		if item:IsA("LuaSourceContainer") or item:IsA("RemoteEvent") or item:IsA("RemoteFunction")
			or item:IsA("BindableEvent") or item:IsA("BindableFunction") or item:IsA("ObjectValue")
			or item:IsA("ProximityPrompt") or item:IsA("ClickDetector") or item:IsA("Sound")
			or item:IsA("ParticleEmitter") or item:IsA("Trail") or item:IsA("Beam")
			or item:IsA("GuiObject") or item:IsA("LayerCollector") then
			return false, "Forbidden descendant: " .. item.ClassName
		end
		if item:IsA("Constraint") and not constraintAllowed(item, asset) then
			return false, "Unapproved constraint: " .. item.ClassName
		end
		if item:IsA("MeshPart") and (item.MeshId ~= "" or item.TextureID ~= "") and asset.DependenciesReviewed ~= true then
			return false, "Mesh or texture dependencies were not reviewed"
		end
		if item:IsA("Animation") and item.AnimationId ~= "" and asset.AnimationsReviewed ~= true then
			return false, "Animation dependency was not reviewed"
		end
	end
	return true
end

-- Creates a ground-level invisible root when an approved visual model did not supply one.
local function ensureRoot(model, contract)
	local root = model:FindFirstChild(contract.RootName)
	if root and root:IsA("BasePart") then return root end
	if root then root:Destroy() end
	local frame, size = model:GetBoundingBox()
	assert(size.Magnitude > 0, "Pet model contains no geometry")
	root = Instance.new("Part")
	root.Name = contract.RootName
	root.Size = Vector3.one * 0.2
	root.CFrame = CFrame.new(frame.Position.X, frame.Position.Y - size.Y / 2, frame.Position.Z)
	root.Transparency = 1
	root.Parent = model
	return root
end

-- Replaces arbitrary attachment placement with direct, contract-defined root attachments.
local function attachment(model, root, name, offset)
	for _, item in model:GetDescendants() do
		if item:IsA("Attachment") and item.Name == name and item.Parent ~= root then item:Destroy() end
	end
	local point = root:FindFirstChild(name)
	if point and not point:IsA("Attachment") then point:Destroy(); point = nil end
	if not point then point = Instance.new("Attachment"); point.Name = name; point.Parent = root end
	point.Position = Vector3.new(table.unpack(offset))
	return point
end

-- Applies scale/orientation, root/attachments, collision policy and replicated contract metadata.
function Normalizer.Normalize(model, definition, asset, stage)
	asset = asset or {}
	local ok, reason = Normalizer.Audit(model, asset)
	assert(ok, reason)
	local contract = Contract.Resolve(definition, asset, stage)
	local root = ensureRoot(model, contract)
	model.PrimaryPart = root
	model:ScaleTo(contract.Scale)
	model:PivotTo(CFrame.new(0, contract.GroundOffset, 0) * CFrame.Angles(0, math.rad(contract.ForwardYaw), 0))
	attachment(model, root, contract.LeashAttachmentName, contract.LeashOffset)
	attachment(model, root, contract.InteractionAttachmentName, { 0, contract.InteractionHeight, 0 })
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = item == root or asset.RigMode ~= "Motor6D"
			item.CanCollide = false
			item.CanTouch = false
			item.CanQuery = false
			item.Massless = item ~= root
			item.CastShadow = item ~= root
		end
	end
	assert(model:GetExtentsSize().Magnitude <= contract.MaxBounds, "Normalized pet exceeds bounds budget")
	model:SetAttribute("ModelContractVersion", contract.Version)
	model:SetAttribute("ForwardAxis", contract.ForwardAxis)
	model:SetAttribute("MovementProfile", contract.MovementProfile)
	model:SetAttribute("AnimationProfile", contract.AnimationProfile)
	return contract
end

return Normalizer
