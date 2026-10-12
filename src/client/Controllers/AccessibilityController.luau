local Players = game:GetService("Players")
local UI = require(script.Parent.Parent.UI.Components)
local Accessibility = {}
local started = false

-- Applies current local display preferences to one supported UI descendant.
local function apply(instance, player)
	if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
		if instance:GetAttribute("BaseTextSize") == nil then instance:SetAttribute("BaseTextSize", instance.TextSize) end
		local multiplier = if player:GetAttribute("LargeText") then 1.16 else 1
		instance.TextSize = math.floor((instance:GetAttribute("BaseTextSize") or instance.TextSize) * multiplier + 0.5)
	end
	if instance:IsA("UIStroke") and instance.Name == "CardStroke" then
		instance.Transparency = if player:GetAttribute("HighContrast") then 0.25 else 0.86
		instance.Thickness = if player:GetAttribute("HighContrast") then 3 else 2
	end
end

-- Creates local accessibility controls and reapplies them to present and future interface objects.
function Accessibility.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	for _, name in { "ReduceMotion", "HighContrast", "LargeText" } do
		if player:GetAttribute(name) == nil then player:SetAttribute(name, false) end
	end
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "AccessibilityMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = playerGui
	local toggle = Instance.new("TextButton")
	toggle.Text = "SETTINGS"
	toggle.TextSize = 15
	toggle.Size = UDim2.fromOffset(116, 40)
	toggle.Position = UDim2.new(1, -128, 1, -52)
	toggle.Parent = gui
	UI.Button(toggle, true)
	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(1, 1)
	panel.Position = UDim2.new(1, -12, 1, -64)
	panel.Size = UDim2.fromOffset(310, 250)
	panel.Visible = false
	panel.Parent = gui
	UI.Panel(panel)
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Text = "ACCESSIBILITY"
	title.TextSize = 22
	title.Size = UDim2.new(1, -52, 0, 46)
	title.Position = UDim2.fromOffset(14, 4)
	title.Parent = panel
	UI.Text(title, true)
	local close = Instance.new("TextButton")
	close.Text = "×"
	close.TextSize = 22
	close.Size = UDim2.fromOffset(38, 38)
	close.Position = UDim2.new(1, -44, 0, 6)
	close.Parent = panel
	UI.Button(close, true)
	local controls = {}
	for index, entry in {
		{ "ReduceMotion", "Reduced motion" },
		{ "HighContrast", "High contrast" },
		{ "LargeText", "Larger text" },
	} do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(1, -28, 0, 48)
		button.Position = UDim2.fromOffset(14, 48 + (index - 1) * 57)
		button.TextSize = 16
		button.Parent = panel
		UI.Button(button, index % 2 == 0)
		controls[entry[1]] = { Button = button, Title = entry[2] }
		button.Activated:Connect(function()
			player:SetAttribute(entry[1], not player:GetAttribute(entry[1]))
		end)
	end
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Text = "Settings apply locally for this session."
	hint.TextSize = 12
	hint.Size = UDim2.new(1, -28, 0, 24)
	hint.Position = UDim2.new(0, 14, 1, -28)
	hint.Parent = panel
	UI.Text(hint)
	-- Refreshes button state and every existing supported UI object.
	local function refresh()
		for attribute, entry in controls do
			entry.Button.Text = entry.Title .. ": " .. (if player:GetAttribute(attribute) then "ON" else "OFF")
		end
		for _, item in playerGui:GetDescendants() do apply(item, player) end
	end
	for attribute in controls do player:GetAttributeChangedSignal(attribute):Connect(refresh) end
	playerGui.DescendantAdded:Connect(function(item) task.defer(apply, item, player) end)
	toggle.Activated:Connect(function() UI.SetMenuVisible(panel, not panel.Visible) end)
	close.Activated:Connect(function() UI.SetMenuVisible(panel, false) end)
	refresh()
end

return Accessibility
