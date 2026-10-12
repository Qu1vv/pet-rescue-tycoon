local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config.GameConfig)
local Upgrades = require(Shared.Config.ShelterUpgrades)
local UI = require(script.Parent.Parent.UI.Components)

local ShelterDashboardController = {}
local started = false

-- Formats the next tier's concrete benefit without duplicating upgrade calculations.
local function benefit(branch, tier)
	if branch == "Beds" then return tier.Capacity .. " total pet spaces" end
	if branch == "Pantry" then return "A treat every " .. tier.Interval .. " seconds" end
	if branch == "Storage" then return tier.Capacity .. " stored food • " .. tier.BinCapacity .. " bin" end
	if branch == "Care" then return "+" .. tier.FeedingXP .. " feeding XP • " .. math.floor((tier.CareMultiplier - 1) * 100 + 0.5) .. "% care XP" end
	return tier.Title
end

-- Creates a reusable dashboard card for one independent shelter upgrade branch.
local function upgradeCard(parent, branch, order)
	local card = Instance.new("Frame")
	card.Name = branch
	card.LayoutOrder = order
	card.Size = UDim2.new(1, -8, 0, 96)
	card.Parent = parent
	UI.Card(card, UI.Colors.White)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 9)
	title.Size = UDim2.new(0.34, -16, 0, 30)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = string.upper(branch)
	title.TextSize = 17
	title.Parent = card
	UI.Text(title, true)

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.new(0.34, 0, 0, 8)
	status.Size = UDim2.new(0.66, -14, 0, 76)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
	status.TextSize = 13
	status.Parent = card
	UI.Text(status)
	return card
end

-- Creates a read-only shelter overview driven entirely by replicated server attributes.
function ShelterDashboardController.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local world = workspace:WaitForChild("ShelterWorld")
	local plots = world:WaitForChild("Plots")

	local gui = Instance.new("ScreenGui")
	gui.Name = "ShelterDashboard"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(148, 42)
	toggle.Position = UDim2.new(1, -160, 1, -102)
	toggle.Text = "SHELTER"
	toggle.TextSize = 18
	toggle.Parent = gui
	UI.Button(toggle)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -24, 0.82, 0)
	panel.Visible = false
	panel.Parent = gui
	UI.Panel(panel)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(570, 680)
	limit.Parent = panel

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(16, 8)
	header.Size = UDim2.new(1, -68, 0, 40)
	header.Text = "SHELTER DASHBOARD"
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.TextSize = 24
	header.Parent = panel
	UI.Text(header, true)

	local close = Instance.new("TextButton")
	close.Position = UDim2.new(1, -48, 0, 6)
	close.Size = UDim2.fromOffset(40, 40)
	close.Text = "×"
	close.TextSize = 24
	close.Parent = panel
	UI.Button(close, true)

	local summary = Instance.new("TextLabel")
	summary.Position = UDim2.fromOffset(12, 54)
	summary.Size = UDim2.new(1, -24, 0, 98)
	summary.TextXAlignment = Enum.TextXAlignment.Left
	summary.TextYAlignment = Enum.TextYAlignment.Top
	summary.TextWrapped = true
	summary.TextSize = 15
	summary.Parent = panel
	UI.Card(summary, UI.Colors.Mint)
	UI.Text(summary, true)

	local request = Instance.new("TextLabel")
	request.Position = UDim2.fromOffset(12, 160)
	request.Size = UDim2.new(1, -24, 0, 66)
	request.TextXAlignment = Enum.TextXAlignment.Left
	request.TextWrapped = true
	request.TextSize = 14
	request.Parent = panel
	UI.Card(request, UI.Colors.Peach)
	UI.Text(request, true)

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 236)
	list.Size = UDim2.new(1, -24, 1, -286)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 5
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local cards = {}
	for index, branch in { "Beds", "Pantry", "Storage", "Care" } do
		cards[branch] = upgradeCard(list, branch, index)
	end

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 14, 1, -43)
	footer.Size = UDim2.new(1, -28, 0, 34)
	footer.Text = "Build upgrades by walking onto their pads inside your shelter."
	footer.TextWrapped = true
	footer.TextSize = 12
	footer.Parent = panel
	UI.Text(footer)

	-- Resolves the player's current plot without accepting any client-owned shelter state.
	local function currentPlot()
		return plots:FindFirstChild("Plot" .. (player:GetAttribute("PlotId") or 0))
	end

	-- Refreshes current resources, adopter request, and every branch's next purchasable tier.
	local function render()
		if not panel.Visible then return end
		local plot = currentPlot()
		if not plot then
			summary.Text = "Claim a free shelter to unlock your dashboard."
			request.Text = "ADOPTER REQUEST" .. string.char(10) .. "Build a kennel to meet local adopters."
			for _, card in cards do card.Status.Text = "Not available until you claim and build a shelter." end
			return
		end
		local count = (plot:GetAttribute("PetCount") or 0) + (plot:GetAttribute("ReservedCount") or 0)
		local capacity = plot:GetAttribute("MaxPetCapacity") or Config.PetCapacity
		local stored = plot:GetAttribute("StoredFood") or 0
		local foodCapacity = plot:GetAttribute("FoodCapacity") or Config.FoodStorageCapacity
		local pending = plot:GetAttribute("PendingFood") or 0
		local binCapacity = plot:GetAttribute("FoodBinCapacity") or Config.FoodBinCapacity
		local interval = plot:GetAttribute("FoodProductionInterval") or Config.FoodProductionInterval
		summary.Text = "TIER " .. (plot:GetAttribute("ShelterTier") or 0)
			.. "  •  PETS " .. count .. "/" .. capacity
			.. string.char(10) .. "FOOD " .. stored .. "/" .. foodCapacity .. " stored  •  " .. pending .. "/" .. binCapacity .. " ready"
			.. string.char(10) .. "PANTRY SPEED  one treat every " .. interval .. " seconds"

		local expires = math.max(0, math.ceil((plot:GetAttribute("AdopterRequestExpiresAt") or 0) - workspace:GetServerTimeNow()))
		request.Text = "ADOPTER REQUEST" .. string.char(10)
			.. ((plot:GetAttribute("AdopterRequestText") or "") ~= "" and plot:GetAttribute("AdopterRequestText") or "Finding a local family…")
			.. (if expires > 0 then string.format("  •  refreshes in %d:%02d", math.floor(expires / 60), expires % 60) else "")

		for branch, card in cards do
			local level = plot:GetAttribute("Upgrade" .. branch) or 0
			local nextTier = Upgrades.Next({ [branch] = level }, branch, Config)
			if nextTier then
				card.Status.Text = "Level " .. level .. " / " .. #Config.Upgrades[branch]
					.. string.char(10) .. "NEXT: " .. nextTier.Title .. " — " .. nextTier.Cost .. " cash"
					.. string.char(10) .. benefit(branch, nextTier)
			else
				local current = Config.Upgrades[branch][level]
				card.Status.Text = "Level " .. level .. " / " .. #Config.Upgrades[branch]
					.. string.char(10) .. "MAXIMUM UPGRADE"
					.. (current and (string.char(10) .. benefit(branch, current)) or "")
			end
		end
	end

	-- Observes all dashboard attributes once per fixed plot.
	for _, plot in plots:GetChildren() do
		for _, attribute in { "PetCount", "ReservedCount", "MaxPetCapacity", "StoredFood", "PendingFood", "FoodCapacity",
			"FoodBinCapacity", "FoodProductionInterval", "ShelterTier", "AdopterRequestText", "AdopterRequestExpiresAt",
			"UpgradeBeds", "UpgradePantry", "UpgradeStorage", "UpgradeCare" } do
			plot:GetAttributeChangedSignal(attribute):Connect(render)
		end
	end
	toggle.Activated:Connect(function() UI.SetMenuVisible(panel, not panel.Visible); render() end)
	close.Activated:Connect(function() UI.SetMenuVisible(panel, false) end)
	player:GetAttributeChangedSignal("PlotId"):Connect(render)
	task.spawn(function()
		while gui.Parent do
			task.wait(1)
			if panel.Visible then render() end
		end
	end)
end

return ShelterDashboardController

