local BuildUtil = {}

-- Creates a named anchored part with the requested geometry, position, color and material.
function BuildUtil.Part(parent, name, size, cframe, color, material)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color or Color3.fromRGB(228, 223, 205)
	part.Material = material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Mounts readable text directly on a physical board or pad; returns its TextLabel for live updates.
function BuildUtil.Label(part, text, _distance, face)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Label"
	gui.Face = face or (if part.Size.Y < 1 then Enum.NormalId.Top else Enum.NormalId.Front)
	gui.PixelsPerStud = 32
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.MaxDistance = _distance or 90
	gui.Active = false
	gui.LightInfluence = 0
	gui.ZOffset = 0.03
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 1, -8)
	label.Position = UDim2.fromOffset(6, 4)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 250, 235)
	label.TextStrokeTransparency = 0.5
	label.TextWrapped = true
	label.Text = text
	label.Parent = gui
	local size = Instance.new("UITextSizeConstraint")
	size.MaxTextSize = 30
	size.MinTextSize = 10
	size.Parent = label
	return label
end

-- Floating labels are reserved for characters that have no physical sign surface.
function BuildUtil.FloatingLabel(part, text, distance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingLabel"
	gui.Size = UDim2.fromOffset(240, 48)
	gui.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	gui.MaxDistance = distance or 65
	gui.Adornee = part
	gui.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(255, 250, 235)
	label.TextStrokeTransparency = 0.35
	label.Text = text
	label.Parent = gui
	return label
end

-- Creates a functional invisible spawn without decorative decals or collision.
function BuildUtil.Spawn(parent, name, cframe, enabled)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = name
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = cframe
	spawn.Anchored = true
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Enabled = enabled
	for _, item in spawn:GetDescendants() do
		if item:IsA("Decal") or item:IsA("Texture") then item:Destroy() end
	end
	spawn.Parent = parent
	return spawn
end

-- Creates an invisible, non-physical volume used by server position checks.
function BuildUtil.Zone(parent, name, size, cframe)
	local zone = BuildUtil.Part(parent, name, size, cframe)
	zone.Transparency = 1
	zone.CanCollide = false
	zone.CanTouch = false
	zone.CanQuery = false
	return zone
end

return BuildUtil
