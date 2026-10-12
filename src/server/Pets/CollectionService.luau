local Collection = {}
local data = {}
-- Creates or updates the replicated folder describing one discovered variant.
local function publish(player, key, entry)
	local folder = player:FindFirstChild("PetIndex")
	if not folder then folder = Instance.new("Folder"); folder.Name = "PetIndex"; folder.Parent = player end
	local item = folder:FindFirstChild(key) or Instance.new("Folder")
	item.Name = key
	item:SetAttribute("BestLevel", entry.BestLevel)
	item:SetAttribute("TotalDiscovered", entry.TotalDiscovered)
	item.Parent = folder
end
-- Loads a player's discovery entries and creates their replicated Pet Index folder.
function Collection.Load(player, entries)
	if not player:FindFirstChild("PetIndex") then local folder = Instance.new("Folder"); folder.Name = "PetIndex"; folder.Parent = player end
	data[player] = entries or {}
	for key, entry in data[player] do publish(player, key, entry) end
end
-- Unlocks or updates a variant entry; restored/levelled pets update best level without adding another rescue.
function Collection.Discover(player, pet, restored)
	local entries = data[player]
	if not entries then return false end
	local key = pet.Definition.DefinitionId .. ":" .. pet.Coat.Id
	local fresh = entries[key] == nil
	local entry = entries[key] or { BestLevel = 1, TotalDiscovered = 0 }
	entry.BestLevel = math.max(entry.BestLevel, pet.Level)
	if not restored then entry.TotalDiscovered += 1 end
	entries[key] = entry
	publish(player, key, entry)
	return fresh
end
-- Returns independent copies of discovery entries for a consistent save snapshot.
function Collection.Export(player)
	local result = {}
	for key, entry in data[player] or {} do result[key] = table.clone(entry) end
	return result
end
-- Releases this player's in-memory collection after the departure snapshot is captured.
function Collection.Cleanup(player) data[player] = nil end
return Collection
