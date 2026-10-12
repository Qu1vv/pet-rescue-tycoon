local Packs = require("../src/shared/Pets/PetModelPacks")

local pack = assert(Packs.Get("FreeStarter"), "Free Starter pack is registered")
assert(pack.AssetMode == "GeneratedPlaceholder", "Starter pack is dependency-free")
assert(pack.License:find("Original project geometry"), "Starter pack has clear provenance")
assert(#pack.Definitions == 5 and #pack.Stages == 4, "Starter pack coverage")

print("PASS: free starter pet model pack")
