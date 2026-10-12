local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetCare = require(Shared.Pets.PetCare)
local Styles = require(Shared.Pets.RarityStyles)
local UI = require(script.Parent.Parent.UI.Components)

local MyPetsController = {}
local started = false

-- Returns a short server-clock cooldown label used by roster cards.
local function cooldownLabel(deadline)
	local remaining = math.max(0, math.ceil((deadline or 0) - workspace:GetServerTimeNow()))
	if remaining == 0 then return "Ready" end
	return string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
end

-- Creates a temporary local-only marker so a pet can be found without bypassing world interactions.
local function locatePet(gui, pet)
	local old = gui:FindFirstChild("PetLocator")
	if old then old:Destroy() end
	local oldHighlight = pet:FindFirstChild("LocalPetLocator")
	if oldHighlight then oldHighlight:Destroy() end

	local marker = Instance.new("BillboardGui")
	marker.Name = "PetLocator"
	marker.Adornee = pet.PrimaryPart
	marker.Size = UDim2.fromOffset(180, 54)
	marker.StudsOffset = Vector3.new(0, 5.5, 0)
	marker.AlwaysOnTop = true
	marker.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "▼ " .. (pet:GetAttribute("PetName") or "YOUR PET")
	label.TextSize = 18
	label.TextStrokeTransparency = 0.15
	label.Parent = marker
	UI.Text(label, true)

	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalPetLocator"
	highlight.Adornee = pet
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = UI.Colors.Mint
	highlight.FillTransparency = 0.62
	highlight.OutlineColor = UI.Colors.Cream
	highlight.Parent = pet
	Debris:AddItem(marker, 8)
	Debris:AddItem(highlight, 8)
end

-- Builds one compact pet row from replicated, server-authored identity and progression attributes.
local function createCard(parent, pet, gui)
	local card = Instance.new("Frame")
	card.Name = pet:GetAttribute("PetId") or pet.Name
	card.Size = UDim2.new(1, -8, 0, 112)
	card.Parent = parent
	UI.PetCard(card)

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(14, 9)
	title.Size = UDim2.new(1, -128, 0, 48)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextYAlignment = Enum.TextYAlignment.Top
	title.TextWrapped = true
	title.TextSize = 16
	title.Parent = card
	UI.Text(title, true)

	local details = Instance.new("TextLabel")
	details.BackgroundTransparency = 1
	details.Position = UDim2.fromOffset(14, 56)
	details.Size = UDim2.new(1, -128, 0, 47)
	details.TextXAlignment = Enum.TextXAlignment.Left
	details.TextYAlignment = Enum.TextYAlignment.Top
	details.TextWrapped = true
	details.TextSize = 12
	details.Parent = card
	UI.Text(details)

	local locate = Instance.new("TextButton")
	locate.Position = UDim2.new(1, -108, 0, 13)
	locate.Size = UDim2.fromOffset(94, 40)
	locate.Text = "LOCATE"
	locate.TextSize = 13
	locate.Parent = card
	UI.Button(locate, true)
	locate.Activated:Connect(function() locatePet(gui, pet) end)

	local rarity = pet:GetAttribute("Rarity") or "Common"
	local style = Styles[rarity] or Styles.Common
	local badge = UI.Badge(card, rarity, Color3.fromRGB(table.unpack(style.Color)))
	badge.Position = UDim2.new(1, -109, 0, 67)

	local favorite = if pet:GetAttribute("Favorite") then "★ " else ""
	local required = pet:GetAttribute("XPRequired") or 0
	local xpText = if required == 0 then "MAX" else tostring(pet:GetAttribute("XP") or 0) .. "/" .. required .. " XP"
	title.Text = favorite .. (pet:GetAttribute("PetName") or pet.Name)
		.. "  •  Lv. " .. (pet:GetAttribute("Level") or 1)
		.. string.char(10) .. (pet:GetAttribute("Variant") or "") .. " " .. (pet:GetAttribute("DefinitionId") or "Pet")
	local ready = cooldownLabel(pet:GetAttribute("NextFeedAt"))
	local careReady = 0
	for actionId in PetCare.Actions do
		if cooldownLabel(pet:GetAttribute("Care" .. actionId .. "At")) == "Ready" then careReady += 1 end
	end
	details.Text = (pet:GetAttribute("Personality") or "Gentle") .. " • " .. xpText
		.. string.char(10) .. "Feed: " .. ready .. " • Care ready: " .. careReady .. "/4"
		.. (if pet:GetAttribute("RequestMatched") then " • REQUEST MATCH" else "")
	return card
end

-- Creates and maintains the owned-pet roster from replicated world models.
function MyPetsController.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local world = workspace:WaitForChild("ShelterWorld")
	local pets = world:WaitForChild("Pets")
	local plots = world:WaitForChild("Plots")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MyPetsMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 7
	gui.Parent = player:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Size = UDim2.fromOffset(126, 42)
	toggle.Position = UDim2.new(0, 12, 1, -102)
	toggle.Text = "MY PETS"
	toggle.TextSize = 18
	toggle.Parent = gui
	UI.Button(toggle, true)

	local panel = Instance.new("Frame")
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.5)
	panel.Size = UDim2.new(1, -24, 0.8, 0)
	panel.Visible = false
	panel.Parent = gui
	UI.Panel(panel)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 650)
	limit.Parent = panel

	local header = Instance.new("TextLabel")
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(16, 8)
	header.Size = UDim2.new(1, -66, 0, 42)
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

	local filterBar = Instance.new("Frame")
	filterBar.BackgroundTransparency = 1
	filterBar.Position = UDim2.fromOffset(12, 54)
	filterBar.Size = UDim2.new(1, -24, 0, 36)
	filterBar.Parent = panel

	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(12, 100)
	list.Size = UDim2.new(1, -24, 1, -150)
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 5
	list.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Position = UDim2.new(0, 14, 1, -43)
	footer.Size = UDim2.new(1, -28, 0, 34)
	footer.Text = "Locate helps you find a pet. Walk close and use View pet to manage it."
	footer.TextWrapped = true
	footer.TextSize = 12
	footer.Parent = panel
	UI.Text(footer)

	local filter = "All"
	local queued = false
	local connections = {}

	-- Returns only this player's live pets; server ownership attributes remain authoritative.
	local function ownedPets()
		local result = {}
		for _, pet in pets:GetChildren() do
			local state = pet:GetAttribute("State")
			if pet:GetAttribute("OwnerUserId") == player.UserId
				and (state == "Sheltered" or state == "Following" or state == "Adopting") then
				local include = filter == "All"
					or (filter == "Favorites" and pet:GetAttribute("Favorite") == true)
					or (filter == "Ready" and (pet:GetAttribute("NextFeedAt") or 0) <= workspace:GetServerTimeNow())
					or (filter == "Request" and pet:GetAttribute("RequestMatched") == true)
				if include then table.insert(result, pet) end
			end
		end
		table.sort(result, function(a, b)
			if a:GetAttribute("Favorite") ~= b:GetAttribute("Favorite") then return a:GetAttribute("Favorite") == true end
			local ar = (Styles[a:GetAttribute("Rarity") or "Common"] or Styles.Common).Rank
			local br = (Styles[b:GetAttribute("Rarity") or "Common"] or Styles.Common).Rank
			if ar ~= br then return ar > br end
			if (a:GetAttribute("Level") or 1) ~= (b:GetAttribute("Level") or 1) then
				return (a:GetAttribute("Level") or 1) > (b:GetAttribute("Level") or 1)
			end
			return (a:GetAttribute("PetName") or a.Name) < (b:GetAttribute("PetName") or b.Name)
		end)
		return result
	end

	-- Rebuilds bounded rows only while the roster is visible.
	local function render()
		if not panel.Visible then return end
		for _, child in list:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
		local entries = ownedPets()
		local plot = plots:FindFirstChild("Plot" .. (player:GetAttribute("PlotId") or 0))
		local maximum = plot and plot:GetAttribute("MaxPetCapacity") or 0
		header.Text = "MY PETS  " .. #entries .. (filter == "All" and (" / " .. maximum) or "")
		if #entries == 0 then
			local empty = Instance.new("Frame")
			empty.Size = UDim2.new(1, -8, 0, 100)
			empty.Parent = list
			UI.PetCard(empty)
			local text = Instance.new("TextLabel")
			text.BackgroundTransparency = 1
			text.Size = UDim2.new(1, -24, 1, -24)
			text.Position = UDim2.fromOffset(12, 12)
			text.TextWrapped = true
			text.TextSize = 16
			text.Text = if filter == "All" then "No sheltered pets yet. Explore a habitat and rescue your first friend." else "No pets match this filter."
			text.Parent = empty
			UI.Text(text, true)
		else
			for index, pet in entries do
				local card = createCard(list, pet, gui)
				card.LayoutOrder = index
			end
		end
	end

	-- Coalesces replicated changes so a burst of attributes produces one roster rebuild.
	local function schedule()
		if queued then return end
		queued = true
		task.defer(function() queued = false; render() end)
	end

	-- Watches display attributes for one replicated pet and releases every listener on removal.
	local function watch(pet)
		if connections[pet] then return end
		local owned = {}
		for _, attribute in { "State", "OwnerUserId", "PetName", "Favorite", "Level", "XP", "XPRequired", "Rarity",
			"Variant", "Personality", "NextFeedAt", "RequestMatched", "CarePetAt", "CareBrushAt", "CarePlayAt", "CareWalkAt" } do
			table.insert(owned, pet:GetAttributeChangedSignal(attribute):Connect(schedule))
		end
		connections[pet] = owned
		schedule()
	end
	pets.ChildAdded:Connect(watch)
	pets.ChildRemoved:Connect(function(pet)
		if connections[pet] then for _, connection in connections[pet] do connection:Disconnect() end end
		connections[pet] = nil
		schedule()
	end)
	for _, pet in pets:GetChildren() do watch(pet) end

	for index, definition in { { "All", "ALL" }, { "Favorites", "★ FAVORITES" }, { "Ready", "FEED READY" }, { "Request", "REQUEST" } } do
		local button = Instance.new("TextButton")
		button.Size = UDim2.new(0.25, -5, 1, 0)
		button.Position = UDim2.new((index - 1) * 0.25, 0, 0, 0)
		button.Text = definition[2]
		button.TextSize = 11
		button.Parent = filterBar
		UI.Button(button, true)
		button.Activated:Connect(function() filter = definition[1]; render() end)
	end
	toggle.Activated:Connect(function() UI.SetMenuVisible(panel, not panel.Visible); render() end)
	close.Activated:Connect(function() UI.SetMenuVisible(panel, false) end)
	player:GetAttributeChangedSignal("PlotId"):Connect(schedule)

	task.spawn(function()
		while gui.Parent do task.wait(1); if panel.Visible then render() end end
	end)
end

return MyPetsController

