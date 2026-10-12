local Players = game:GetService("Players")
local Validation = {}

-- Rejects NaN and infinite numeric values used in positions, health and economy checks.
function Validation.Finite(number)
	return number == number and math.abs(number) < math.huge
end

-- Checks that all three coordinates are finite before using a world position.
function Validation.Position(position)
	return Validation.Finite(position.X) and Validation.Finite(position.Y) and Validation.Finite(position.Z)
end

-- Checks that the argument is a Player currently connected to this server.
function Validation.Player(player)
	return typeof(player) == "Instance" and player:IsA("Player") and player.Parent == Players
end

-- Returns a finite root part for a living character in Workspace, otherwise nil.
function Validation.Root(player)
	if not Validation.Player(player) then return nil end
	local character = player.Character
	if not character or not character:IsDescendantOf(workspace) then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not Validation.Finite(humanoid.Health) or humanoid.Health <= 0 then return nil end
	if not root or not root:IsA("BasePart") or not Validation.Position(root.Position) then return nil end
	return root
end

-- Checks a finite point against a live zone's oriented bounding box.
function Validation.InZone(position, zone)
	if not zone or not zone:IsDescendantOf(workspace) or not Validation.Position(position) then return false end
	local point = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size * 0.5
	return math.abs(point.X) <= half.X and math.abs(point.Y) <= half.Y and math.abs(point.Z) <= half.Z
end

-- Checks a living character's server-observed distance from a finite interaction position.
function Validation.Near(player, position, distance)
	local root = Validation.Root(player)
	return root ~= nil and Validation.Position(position) and (root.Position - position).Magnitude <= distance
end

return Validation
