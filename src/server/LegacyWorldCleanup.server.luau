local Cleanup = require(script.Parent:WaitForChild("World"):WaitForChild("LegacyWorldCleanup"))

-- Runs independently so a Rojo sync also removes a retained slab from an active Studio test.
Cleanup.Run(workspace)
