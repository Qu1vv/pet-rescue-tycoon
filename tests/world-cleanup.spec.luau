local Cleanup = require("../src/server/World/LegacyWorldCleanup")

local checks = 0
local function check(value, message)
	checks += 1
	assert(value, message)
end

-- Creates the minimal BasePart surface needed to exercise the cleanup signature.
local function part(name, size, position, anchored)
	local object = {
		Name = name,
		Size = size,
		Position = position,
		Anchored = anchored,
		Destroyed = false,
	}
	function object:IsA(class) return class == "BasePart" end
	function object:Destroy() self.Destroyed = true end
	return object
end

local named = part("Baseplate", { X = 12, Y = 1, Z = 12 }, { X = 0, Y = 0, Z = 0 }, true)
local renamed = part("Part", { X = 512, Y = 20, Z = 512 }, { X = 0, Y = -10, Z = 0 }, true)
local elevated = part("OldFloor", { X = 512, Y = 20, Z = 512 }, { X = 0, Y = 0, Z = 0 }, true)
local ground = part("Ground", { X = 768, Y = 2, Z = 768 }, { X = 0, Y = 0, Z = 0 }, true)
local thinDecoration = part("Decoration", { X = 512, Y = 1, Z = 512 }, { X = 0, Y = 4, Z = 0 }, true)
local loose = part("Loose", { X = 512, Y = 20, Z = 512 }, { X = 0, Y = -10, Z = 0 }, false)
local offset = part("Offset", { X = 512, Y = 20, Z = 512 }, { X = 100, Y = -10, Z = 0 }, true)

check(Cleanup.IsLegacySlab(named), "Named baseplate is always identified")
check(Cleanup.IsLegacySlab(renamed), "Renamed template slab is identified")
check(Cleanup.IsLegacySlab(elevated), "Elevated retained slab from the screenshot is identified")
check(not Cleanup.IsLegacySlab(ground), "Generated 768-stud ground is preserved")
check(Cleanup.IsLegacySlab(thinDecoration), "Thin centered covering surface is identified")
check(not Cleanup.IsLegacySlab(loose), "Unanchored part is preserved")
check(not Cleanup.IsLegacySlab(offset), "Unrelated offset structure is preserved")

local container = {}
function container:GetDescendants()
	return { named, renamed, elevated, ground, thinDecoration, loose, offset }
end
check(Cleanup.Run(container) == 4, "Cleanup removes every centered covering slab")
check(named.Destroyed and renamed.Destroyed and elevated.Destroyed and thinDecoration.Destroyed, "Every covering slab was destroyed")
check(not ground.Destroyed and not loose.Destroyed and not offset.Destroyed, "Generated ground and unrelated geometry survived")

print("PASS: " .. checks .. " legacy world cleanup checks")

