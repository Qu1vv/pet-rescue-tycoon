-- Run with the standalone Luau CLI; stdout is JSON for tools/render_pet_preview.py.
local Catalog = require("../src/shared/Pets/PetCatalog")
local Geometry = require("../src/shared/Pets/PetGeometry")
local Progression = require("../src/shared/Pets/PetProgression")
local function json(value)
	if type(value) == "string" then return string.format("%q", value) end
	if type(value) == "number" or type(value) == "boolean" then return tostring(value) end
	local items = {}
	if #value > 0 then
		for _, item in value do table.insert(items, json(item)) end
		return "[" .. table.concat(items, ",") .. "]"
	end
	for key, item in value do table.insert(items, json(key) .. ":" .. json(item)) end
	return "{" .. table.concat(items, ",") .. "}"
end
local previews = {}
for _, definition in Catalog.Definitions do
	local coat = definition.Variants[1]
	local stage = Progression.GetModelStage(definition, 1, coat)
	table.insert(previews, { Title = definition.DisplayName, Subtitle = coat.Name .. " / " .. coat.Rarity,
		Scale = stage.Scale, Parts = Geometry.Build(definition, coat, stage) })
end
for _, level in { 1, 5, 10, 20 } do
	local definition = Catalog.Definitions[1]
	local coat = definition.Variants[1]
	local stage = Progression.GetModelStage(definition, level, coat)
	table.insert(previews, { Title = "Level " .. level, Subtitle = stage.ModelKey,
		Scale = stage.Scale, Parts = Geometry.Build(definition, coat, stage) })
end
print(json(previews))
