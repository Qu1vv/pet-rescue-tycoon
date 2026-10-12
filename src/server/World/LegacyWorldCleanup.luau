local LegacyWorldCleanup = {}

-- Identifies any centered anchored slab large enough to cover the playable map.
function LegacyWorldCleanup.IsLegacySlab(instance)
	if not instance:IsA("BasePart") or not instance.Anchored then return false end
	if instance.Name == "Baseplate" then return true end
	local size = instance.Size
	local position = instance.Position
	local coversMapCenter = size.X >= 400 and size.X <= 650 and size.Z >= 400 and size.Z <= 650
	local isFloorSlab = size.Y > 0 and size.Y <= 64
	local centered = math.abs(position.X) <= 16 and math.abs(position.Z) <= 16 and math.abs(position.Y) <= 64
	return coversMapCenter and isFloorSlab and centered
end

-- Removes retained or renamed covering slabs while preserving the generated 768-stud ground.
function LegacyWorldCleanup.Run(container)
	local removed = 0
	for _, instance in container:GetDescendants() do
		if LegacyWorldCleanup.IsLegacySlab(instance) then
			instance:Destroy()
			removed += 1
		end
	end
	return removed
end

-- Removes future covering slabs immediately if Studio or another source reinserts one.
function LegacyWorldCleanup.Watch(container)
	return container.DescendantAdded:Connect(function(instance)
		task.defer(function()
			if instance.Parent and LegacyWorldCleanup.IsLegacySlab(instance) then
				instance:Destroy()
			end
		end)
	end)
end

return LegacyWorldCleanup
