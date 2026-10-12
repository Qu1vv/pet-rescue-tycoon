local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local UI = require(script.Parent.Parent.UI.Components)

local RescueController = {}
local started = false

-- Presents a short pet-specific trust encounter while the server owns all trust and food changes.
function RescueController.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local remotes = ReplicatedStorage:WaitForChild("ShelterRemotes")
	local action = remotes:WaitForChild("PetAction")
	local pets = workspace:WaitForChild("ShelterWorld"):WaitForChild("Pets")
	local gui = Instance.new("ScreenGui")
	gui.Name = "PetRescueDialog"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 11
	gui.Parent = player:WaitForChild("PlayerGui")
	local shade = Instance.new("Frame")
	shade.Size = UDim2.fromScale(1, 1)
	shade.BackgroundColor3 = Color3.new(0, 0, 0)
	shade.BackgroundTransparency = 0.5
	shade.Active = true
	shade.Visible = false
	shade.Parent = gui
	local card = Instance.new("Frame")
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.Size = UDim2.fromOffset(390, 340)
	card.Parent = shade
	UI.Panel(card)
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local function fit()
		local view = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(390, 340)
		scale.Scale = math.clamp(math.min((view.X - 24) / 390, (view.Y - 30) / 340), 0.55, 1)
	end
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
	fit()
	local heading = Instance.new("TextLabel")
	heading.Position = UDim2.fromOffset(16, 15)
	heading.Size = UDim2.new(1, -32, 0, 102)
	heading.BackgroundTransparency = 1
	heading.TextSize = 20
	heading.TextWrapped = true
	heading.Parent = card
	UI.Text(heading, true)
	local progressBack = Instance.new("Frame")
	progressBack.Position = UDim2.fromOffset(18, 125)
	progressBack.Size = UDim2.new(1, -36, 0, 20)
	progressBack.BackgroundColor3 = Color3.fromRGB(79, 91, 91)
	progressBack.BorderSizePixel = 0
	progressBack.Parent = card
	Instance.new("UICorner", progressBack).CornerRadius = UDim.new(1, 0)
	local progress = Instance.new("Frame")
	progress.Size = UDim2.fromScale(0, 1)
	progress.BackgroundColor3 = Color3.fromRGB(116, 207, 157)
	progress.BorderSizePixel = 0
	progress.Parent = progressBack
	Instance.new("UICorner", progress).CornerRadius = UDim.new(1, 0)
	local hint = Instance.new("TextLabel")
	hint.Position = UDim2.fromOffset(18, 151)
	hint.Size = UDim2.new(1, -36, 0, 44)
	hint.BackgroundTransparency = 1
	hint.TextSize = 14
	hint.TextWrapped = true
	hint.Parent = card
	UI.Text(hint)
	local function button(text, y, secondary)
		local item = Instance.new("TextButton")
		item.Position = UDim2.fromOffset(18, y)
		item.Size = UDim2.new(1, -36, 0, 39)
		item.Text = text
		item.TextSize = 16
		item.Parent = card
		UI.Button(item, secondary)
		return item
	end
	local calm = button("CALM PET", 202, true)
	local treat = button("OFFER TREAT", 247, true)
	local leash = button("LEASH PET", 292, false)
	local selectedId
	local nextActionAt = 0
	local openedAt = 0
	local dismiss = Instance.new("TextButton")
	dismiss.Position = UDim2.new(1, -43, 0, 7)
	dismiss.Size = UDim2.fromOffset(32, 32)
	dismiss.Text = "×"
	dismiss.TextSize = 22
	dismiss.Parent = card
	UI.Button(dismiss, true)
	local function selected()
		if not selectedId then return nil end
		for _, model in pets:GetChildren() do
			if model:GetAttribute("PetId") == selectedId then return model end
		end
		return nil
	end
	local function close()
		selectedId = nil
		shade.Visible = false
		GuiService.SelectedObject = nil
	end
	-- Reads replicated state after every server action; local buttons never set trust or consume food.
	local function render()
		if not shade.Visible then return end
		local pet = selected()
		if not pet or pet:GetAttribute("State") ~= "Available" or pet:GetAttribute("EngagedUserId") ~= player.UserId then
			if os.clock() - openedAt > 2 then close() end
			return
		end
		local trust = pet:GetAttribute("Trust") or 0
		local required = pet:GetAttribute("TrustRequired") or Config.TrustRequired
		local ready = trust >= required
		heading.Text = (if ready then "♥ PET TRUSTED YOU!" else "EARN THEIR TRUST")
			.. "\n" .. (pet:GetAttribute("PetName") or pet.Name)
			.. "  •  " .. (pet:GetAttribute("Rarity") or "Common")
			.. "\n" .. trust .. " / " .. required .. " trust  •  " .. (pet:GetAttribute("RescueMood") or "Nervous")
		progress.Size = UDim2.fromScale(math.clamp(trust / required, 0, 1), 1)
		hint.Text = if ready then "Ready to walk home together. Bring your friend through your shelter entrance."
			else "Move gently. Calm them for free, or use 1 stored food for a faster trust boost."
		calm.Visible = not ready
		treat.Visible = not ready
		leash.Visible = ready
		if ready then GuiService.SelectedObject = leash end
	end
	local function request(kind)
		if not selectedId or os.clock() < nextActionAt then return end
		nextActionAt = os.clock() + (if kind == "Leash" then 0.5 else Config.TrustActionCooldown)
		action:FireServer(kind, selectedId)
		if kind == "Leash" then close() end
	end
	calm.Activated:Connect(function() request("Calm") end)
	treat.Activated:Connect(function() request("Treat") end)
	leash.Activated:Connect(function() request("Leash") end)
	dismiss.Activated:Connect(close)
	shade.InputBegan:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then close() end
	end)
	player.CharacterRemoving:Connect(close)
	remotes:WaitForChild("PetEncounter").OnClientEvent:Connect(function(id)
		if type(id) ~= "string" then return end
		selectedId = id
		openedAt = os.clock()
		nextActionAt = 0
		UI.CloseMenus()
		shade.Visible = true
		UI.Pop(card)
		render()
		GuiService.SelectedObject = if calm.Visible then calm else leash
	end)
	local elapsed = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not shade.Visible then return end
		elapsed += dt
		if elapsed >= 0.15 then elapsed = 0; render() end
	end)
end

return RescueController
