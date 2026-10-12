local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local PetCare = require(ReplicatedStorage.Shared.Pets.PetCare)
local UI = require(script.Parent.Parent.UI.Components)
local PetController = {}
local started = false

-- Creates one styled dialog button at an explicit responsive-grid position.
local function makeButton(parent, text, position, size, secondary)
	local button = Instance.new("TextButton")
	button.Position = position
	button.Size = size
	button.Text = text
	button.TextSize = 15
	button.Parent = parent
	UI.Button(button, secondary)
	return button
end

-- Creates pet details, care, naming, favorite and adoption UI from replicated server state.
function PetController.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("ShelterRemotes")
	local actionRemote = remotes:WaitForChild("PetAction")
	local pets = workspace:WaitForChild("ShelterWorld"):WaitForChild("Pets")
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetDetailsDialog"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.4
	shade.Visible = false
	shade.Active = true
	shade.Parent = gui
	local dialog = Instance.new("Frame")
	dialog.AnchorPoint = Vector2.new(0.5, 0.5)
	dialog.Position = UDim2.fromScale(0.5, 0.5)
	dialog.Size = UDim2.fromOffset(440, 570)
	dialog.Parent = shade
	UI.Panel(dialog)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(440, 570)
	limit.Parent = dialog
	local responsiveScale = Instance.new("UIScale")
	responsiveScale.Parent = dialog
	-- Keeps the complete care dialog inside portrait and short landscape safe areas.
	local function fitDialog()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(440, 570)
		responsiveScale.Scale = math.clamp(math.min((viewport.X - 24) / 440, (viewport.Y - 32) / 570), 0.48, 1)
	end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fitDialog) end
	fitDialog()

	local title = Instance.new("TextLabel")
	title.Position = UDim2.fromOffset(18, 12)
	title.Size = UDim2.new(1, -36, 0, 132)
	title.BackgroundTransparency = 1
	title.TextSize = 17
	title.TextWrapped = true
	title.Parent = dialog
	UI.Text(title, true)
	local request = Instance.new("TextLabel")
	request.Position = UDim2.fromOffset(16, 146)
	request.Size = UDim2.new(1, -32, 0, 54)
	request.TextSize = 14
	request.TextWrapped = true
	request.Parent = dialog
	UI.Card(request, UI.Colors.Peach)
	UI.Text(request, true)
	local feed = makeButton(dialog, "Feed", UDim2.fromOffset(16, 210), UDim2.new(1, -32, 0, 44), false)
	local careTitle = Instance.new("TextLabel")
	careTitle.BackgroundTransparency = 1
	careTitle.Text = "CARE ACTIVITIES • each pet has separate cooldowns"
	careTitle.TextSize = 12
	careTitle.Position = UDim2.fromOffset(18, 260)
	careTitle.Size = UDim2.new(1, -36, 0, 22)
	careTitle.Parent = dialog
	UI.Text(careTitle, true)
	local careButtons = {}
	for index, careId in { "Pet", "Brush", "Play", "Walk" } do
		local button = makeButton(dialog, careId, UDim2.new((index - 1) * 0.25, 10, 0, 285), UDim2.new(0.25, -14, 0, 42), index % 2 == 0)
		careButtons[careId] = button
	end
	local favorite = makeButton(dialog, "☆ FAVORITE", UDim2.fromOffset(16, 337), UDim2.new(0.38, -20, 0, 42), true)
	local rename = Instance.new("TextBox")
	rename.Position = UDim2.new(0.38, 4, 0, 337)
	rename.Size = UDim2.new(0.42, -8, 0, 42)
	rename.PlaceholderText = "New pet name"
	rename.Text = ""
	rename.ClearTextOnFocus = false
	rename.TextSize = 14
	rename.Parent = dialog
	UI.Card(rename, UI.Colors.White)
	UI.Text(rename)
	local renameButton = makeButton(dialog, "RENAME", UDim2.new(0.8, 2, 0, 337), UDim2.new(0.2, -18, 0, 42), false)
	local keep = makeButton(dialog, "Keep pet", UDim2.fromOffset(16, 405), UDim2.new(0.5, -24, 0, 48), true)
	local adopt = makeButton(dialog, "Adopt out", UDim2.new(0.5, 8, 0, 405), UDim2.new(0.5, -24, 0, 48), false)
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Text = "Favoriting protects a pet from adoption. Names are filtered by Roblox."
	hint.TextSize = 12
	hint.TextWrapped = true
	hint.Position = UDim2.fromOffset(18, 464)
	hint.Size = UDim2.new(1, -36, 0, 42)
	hint.Parent = dialog
	UI.Text(hint)
	local close = makeButton(dialog, "CLOSE", UDim2.fromOffset(16, 516), UDim2.new(1, -32, 0, 38), true)

	local selectedId
	local confirming = false
	-- Finds the currently selected live replicated model by its stable pet identity.
	local function selectedPet()
		if not selectedId then return nil end
		for _, model in pets:GetChildren() do
			if model:GetAttribute("PetId") == selectedId then return model end
		end
		return nil
	end
	-- Clears selection and gamepad focus without changing authoritative pet data.
	local function hide()
		selectedId = nil
		confirming = false
		shade.Visible = false
		GuiService.SelectedObject = nil
	end
	-- Formats a server timestamp as a short ready/cooldown label.
	local function cooldown(deadline)
		local remaining = math.max(0, math.ceil((deadline or 0) - workspace:GetServerTimeNow()))
		return if remaining == 0 then "READY" else string.format("%d:%02d", math.floor(remaining / 60), remaining % 60)
	end
	-- Renders all pet identity, progression, request and care controls from replicated attributes.
	local function render()
		local pet = selectedPet()
		if not pet or pet:GetAttribute("State") ~= "Sheltered" then hide(); return end
		local required = pet:GetAttribute("XPRequired") or 0
		local xp = if required == 0 then "MAX LEVEL" else (pet:GetAttribute("XP") or 0) .. " / " .. required .. " XP"
		local isFavorite = pet:GetAttribute("Favorite") == true
		title.Text = (if isFavorite then "★ " else "") .. (pet:GetAttribute("PetName") or pet.Name)
			.. "\n" .. (pet:GetAttribute("Personality") or "Gentle") .. " • " .. (pet:GetAttribute("Rarity") or "Common")
			.. "\nLevel " .. (pet:GetAttribute("Level") or 1) .. " • " .. xp
			.. "\n♥ Happiness " .. (pet:GetAttribute("Happiness") or Config.StartingPetHappiness) .. "/100"
			.. (if confirming then "\n\nConfirm adoption? The adopter will take this pet home." else "")
		local plot = pets.Parent.Plots:FindFirstChild("Plot" .. (player:GetAttribute("PlotId") or 0))
		local requestText = plot and plot:GetAttribute("AdopterRequestText") or ""
		local value = pet:GetAttribute("AdoptionValue") or 0
		local bonus = pet:GetAttribute("AdoptionBonus") or 0
		request.Text = "ADOPTER REQUEST: " .. (requestText ~= "" and requestText or "Any pet welcome")
			.. "\nOffer: " .. value .. " cash" .. (if bonus > 0 then "  •  MATCH BONUS +" .. bonus else "")
		local feedRemaining = cooldown(pet:GetAttribute("NextFeedAt"))
		local feedingXP = plot and plot:GetAttribute("FeedingXPReward") or Config.FeedingXPReward
		feed.Text = if required == 0 then "MAX LEVEL" elseif feedRemaining ~= "READY" then "Feeding XP ready in " .. feedRemaining
			else "FEED • " .. Config.FoodCostPerFeed .. " food → +" .. feedingXP .. " XP"
		for careId, button in careButtons do
			local definition = PetCare.Get(careId)
			button.Text = string.upper(definition.Title) .. "\n" .. cooldown(pet:GetAttribute("Care" .. careId .. "At"))
			button.Active = true
		end
		favorite.Text = if isFavorite then "★ FAVORITED" else "☆ FAVORITE"
		adopt.Text = if isFavorite then "Unlock favorite first" elseif confirming then "CONFIRM ADOPTION" else "Adopt out"
		adopt.Active = not isFavorite
		adopt.BackgroundTransparency = if isFavorite then 0.45 else 0
	end
	feed.Activated:Connect(function()
		confirming = false
		if selectedId then actionRemote:FireServer("Feed", selectedId) end
	end)
	for careId, button in careButtons do
		button.Activated:Connect(function()
			confirming = false
			if selectedId then actionRemote:FireServer("Care", selectedId, careId) end
		end)
	end
	favorite.Activated:Connect(function()
		confirming = false
		if selectedId then actionRemote:FireServer("Favorite", selectedId) end
	end)
	renameButton.Activated:Connect(function()
		confirming = false
		if selectedId and rename.Text ~= "" then actionRemote:FireServer("Rename", selectedId, rename.Text); rename.Text = "" end
	end)
	rename.FocusLost:Connect(function(enterPressed)
		if enterPressed and selectedId and rename.Text ~= "" then actionRemote:FireServer("Rename", selectedId, rename.Text); rename.Text = "" end
	end)
	keep.Activated:Connect(hide)
	close.Activated:Connect(hide)
	adopt.Activated:Connect(function()
		local pet = selectedPet()
		if not pet or pet:GetAttribute("Favorite") then return end
		if not confirming then confirming = true; render(); return end
		local id = selectedId
		hide()
		if id then actionRemote:FireServer("Adopt", id) end
	end)
	remotes:WaitForChild("PetDetails").OnClientEvent:Connect(function(id)
		selectedId = id
		confirming = false
		rename.Text = ""
		UI.CloseMenus()
		shade.Visible = true
		UI.Pop(dialog)
		render()
		GuiService.SelectedObject = keep
	end)
	player.CharacterRemoving:Connect(hide)

	local entries = {}
	-- Shows one lightweight local care popup without adding persistent world objects.
	local function popup(model, message, color)
		local billboard = Instance.new("BillboardGui")
		billboard.Adornee = model.PrimaryPart
		billboard.Size = UDim2.fromOffset(220, 70)
		billboard.StudsOffset = Vector3.new(0, 5, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = model
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = message
		text.TextColor3 = color
		text.TextStrokeTransparency = 0.3
		text.TextSize = 22
		text.Font = Enum.Font.GothamBold
		text.Parent = billboard
		if not player:GetAttribute("ReduceMotion") then
			TweenService:Create(billboard, TweenInfo.new(1.7), { StudsOffset = Vector3.new(0, 8, 0) }):Play()
		end
		Debris:AddItem(billboard, 1.8)
	end
	-- Owns listeners for one replicated pet and refreshes prompt/UI visibility safely after stage swaps.
	local function watch(model)
		if entries[model] then return end
		local entry = { Connections = {} }
		entries[model] = entry
		local function refresh()
			local state = model:GetAttribute("State")
			local prompt = model:FindFirstChild("PetPrompt", true)
			if prompt then prompt.Enabled = state == "Available" or (state == "Sheltered" and model:GetAttribute("OwnerUserId") == player.UserId) end
			if selectedId == model:GetAttribute("PetId") then render() end
		end
		for _, attribute in { "State", "OwnerUserId", "Level", "XP", "XPRequired", "Happiness", "AdoptionValue", "AdoptionBonus",
			"RequestMatched", "Rarity", "NextFeedAt", "PetName", "Personality", "Favorite",
			"CarePetAt", "CareBrushAt", "CarePlayAt", "CareWalkAt" } do
			table.insert(entry.Connections, model:GetAttributeChangedSignal(attribute):Connect(refresh))
		end
		table.insert(entry.Connections, model.DescendantAdded:Connect(refresh))
		table.insert(entry.Connections, model.DescendantRemoving:Connect(function() task.defer(refresh) end))
		table.insert(entry.Connections, model:GetAttributeChangedSignal("LastFedAt"):Connect(function()
			popup(model, "♥ YUM! +" .. (model:GetAttribute("LastFeedingXP") or Config.FeedingXPReward) .. " XP ♥", Color3.fromRGB(255, 195, 122))
		end))
		table.insert(entry.Connections, model:GetAttributeChangedSignal("LastCareAt"):Connect(function()
			local xp = model:GetAttribute("LastCareXP") or 0
			popup(model, if xp > 0 then "♥ " .. string.upper(model:GetAttribute("LastCareAction") or "CARE") .. " +" .. xp .. " XP ♥"
				else "♥ HAPPY FRIEND ♥", Color3.fromRGB(186, 226, 198))
		end))
		table.insert(entry.Connections, model:GetAttributeChangedSignal("LastTrustAt"):Connect(function()
			popup(model, "♥ TRUST " .. (model:GetAttribute("Trust") or 0) .. "/" .. Config.TrustRequired .. " ♥", Color3.fromRGB(245, 199, 155))
		end))
		table.insert(entry.Connections, model:GetAttributeChangedSignal("LastStartleAt"):Connect(function()
			popup(model, "SLOW DOWN • I'M NERVOUS", Color3.fromRGB(243, 185, 156))
		end))
		refresh()
	end
	pets.ChildAdded:Connect(watch)
	pets.ChildRemoved:Connect(function(model)
		local entry = entries[model]
		if entry then for _, connection in entry.Connections do connection:Disconnect() end; entries[model] = nil end
		if selectedId == model:GetAttribute("PetId") then hide() end
	end)
	for _, model in pets:GetChildren() do watch(model) end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then elapsed = 0; if shade.Visible then render() end end
	end)
end

return PetController

