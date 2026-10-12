-- Original plush-style art described as portable geometry, shared with the art preview.
-- No uploaded meshes, textures, external IDs or executable asset contents are used.
local Geometry = {}

-- Returns a small coherent sculpt with breed-specific silhouettes and visible growth accessories.
function Geometry.Build(definition, variant, stage)
	local parts = {}
	local fur = variant.Color
	local cream, ink, pink = { 255, 240, 211 }, { 35, 31, 44 }, { 241, 165, 167 }
	-- Derives a darker RGB coat color for facial masks and patches.
	local function shade(color, amount)
		return { math.floor(color[1] * amount), math.floor(color[2] * amount), math.floor(color[3] * amount) }
	end
	-- Appends a portable part descriptor; the builder creates the Roblox instance later.
	local function add(name, size, position, color, rotation)
		table.insert(parts, { Name = name, Size = size, Position = position, Color = color, Rotation = rotation or { 0, 0, 0 } })
	end
	local small = definition.Species == "Hamster" or definition.Species == "GuineaPig"
	local bunny = definition.Species == "Bunny"
	local cat = definition.Species == "Cat"
	local bodyDepth = if definition.Shape == "Short" then 2.8 elseif small then 2.1 else 2.35
	add("Body", { 2.05, 1.85, bodyDepth }, { 0, 1.22, 0.42 }, fur)
	add("Belly", { 1.48, 1.1, 0.55 }, { 0, 1.15, -0.55 }, cream)
	for _, x in { -0.65, 0.65 } do
		for _, z in { -0.55, 1.1 } do add("Paw", { 0.78, 0.52, 0.94 }, { x, 0.28, z }, cream) end
	end
	add("Head", { 2.65, 2.35, 2.18 }, { 0, 2.38, -0.68 }, fur)
	if variant.Pattern == "Mask" or definition.DefinitionId == "Siamese" then
		add("FaceMask", { 2.2, 1.64, 0.63 }, { 0, 2.21, -1.4 }, if definition.DefinitionId == "Siamese" then shade(fur, 0.46) else cream)
	end
	if variant.Pattern == "Calico" or variant.Pattern == "Spotted" then
		add("CheekPatch", { 1.15, 1.45, 0.4 }, { 0.61, 2.54, -1.37 }, shade(fur, 0.48), { 0, -15, 12 })
		add("BackPatch", { 1.1, 0.4, 1.3 }, { -0.35, 2.02, 0.8 }, { 184, 112, 67 })
	end
	-- Large inset eyes and a compact two-lobed muzzle keep the face readable at game distance.
	for _, side in { -1, 1 } do
		local x = side * 0.54
		add("Eye", { 0.53, 0.66, 0.23 }, { x, 2.52, -1.68 }, ink, { 0, side * -12, side * -5 })
		add("EyeShine", { 0.17, 0.19, 0.08 }, { x - 0.09, 2.69, -1.806 }, { 255, 255, 255 })
		add("EyeSparkle", { 0.075, 0.08, 0.05 }, { x + 0.075, 2.40, -1.81 }, { 238, 239, 255 })
		add("Blush", { 0.33, 0.17, 0.12 }, { side * 0.91, 2.13, -1.48 }, pink)
		add("Muzzle", { 0.58, 0.43, 0.38 }, { side * 0.22, 2.04, -1.68 }, cream)
		add("Smile", { 0.21, 0.055, 0.05 }, { side * 0.09, 1.99, -1.88 }, ink, { 0, 0, side * 18 })
	end
	add("Nose", { 0.29, 0.19, 0.18 }, { 0, 2.22, -1.91 }, if bunny or small then pink else ink)
	if bunny then
		for _, side in { -1, 1 } do
			local lop = variant.Pattern == "Lop"
			local pos = if lop then { side * 1.25, 2.9, -0.35 } else { side * 0.65, 4.22, -0.55 }
			local angle = if lop then side * 16 else side * -10
			add("Ear", { 0.75, 2.1, 0.6 }, pos, fur, { 0, 0, angle })
			add("EarInner", { 0.36, 1.46, 0.16 }, { pos[1], pos[2], pos[3] - 0.28 }, pink, { 0, 0, angle })
		end
		add("Tail", { 0.95, 0.95, 0.95 }, { 0, 1.14, 1.72 }, cream)
	elseif small then
		for _, side in { -1, 1 } do
			add("Ear", { 0.84, 0.84, 0.5 }, { side * 1.03, 3.30, -0.6 }, fur)
			add("EarInner", { 0.5, 0.5, 0.16 }, { side * 1.03, 3.32, -0.87 }, pink)
		end
		add("Tail", { 0.25, 0.25, 0.25 }, { 0, 0.76, 1.5 }, pink)
	elseif definition.Shape == "Floppy" then
		for _, side in { -1, 1 } do
			add("Ear", { 0.80, 1.8, 0.86 }, { side * 1.23, 2.35, -0.57 }, shade(fur, 0.84), { 0, 0, side * 13 })
		end
		add("Tail", { 0.55, 0.68, 1.48 }, { 0, 1.55, 1.86 }, fur, { -32, 0, 0 })
	else
		-- Rounded tapered ear stacks avoid harsh wedges and share the same plush silhouette.
		for _, side in { -1, 1 } do
			add("Ear", { 0.94, 1.20, 0.78 }, { side * 0.92, 3.37, -0.57 }, fur, { 0, 0, side * -18 })
			add("EarTip", { 0.57, 0.73, 0.5 }, { side * 1.08, 3.84, -0.57 }, fur, { 0, 0, side * -18 })
			add("EarInner", { 0.42, 0.70, 0.12 }, { side * 0.95, 3.49, -0.97 }, pink, { 0, 0, side * -18 })
		end
		add("Tail", if cat then { 0.47, 1.8, 0.6 } else { 0.86, 1.02, 1.25 }, { 0, 1.66, 1.85 }, fur, { 20, 0, 0 })
	end
	local collarColor = if stage and stage.Stage >= 3 then { 248, 188, 73 } else { 79, 182, 165 }
	add("Collar", { 1.76, 0.24, 1.43 }, { 0, 1.44, -0.56 }, collarColor)
	add("Tag", { 0.32, 0.36, 0.12 }, { 0, 1.25, -1.30 }, { 255, 211, 99 })
	if stage and stage.Stage >= 2 then
		for _, side in { -1, 1 } do
			add("Bow", { 0.54, 0.40, 0.20 }, { side * 0.28, 1.43, -1.34 }, if stage.Stage >= 3 then { 135, 120, 207 } else { 238, 136, 147 }, { 0, 0, side * -20 })
		end
		add("BowKnot", { 0.22, 0.26, 0.23 }, { 0, 1.43, -1.42 }, collarColor)
	end
	if stage and stage.Stage >= 4 then
		add("CrownBand", { 1.24, 0.22, 0.84 }, { 0, 3.58, -0.7 }, { 255, 211, 99 })
		for _, x in { -0.42, 0, 0.42 } do
			add("CrownPoint", { 0.24, 0.58, 0.24 }, { x, 3.86, -0.82 }, { 255, 215, 101 })
		end
	end
	return parts
end
return Geometry
