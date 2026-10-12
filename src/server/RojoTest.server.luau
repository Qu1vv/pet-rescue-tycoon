print("ROJO + CODEX CONNECTION WORKS")

local Cleanup = require(script.Parent:WaitForChild("World"):WaitForChild("LegacyWorldCleanup"))

-- Cleans the current place and watches for Studio retaining or reinserting a covering slab.
Cleanup.Run(workspace)
Cleanup.Watch(workspace)
