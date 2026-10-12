local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared").Config.GameConfig)
local Onboarding = {}
local started = false

-- Finds the closest unowned claim pad so guidance never points across the whole map.
local function nearestClaimPad(player, plots)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local selected, selectedDistance
	for _, candidate in plots:GetChildren() do
		if candidate:GetAttribute("OwnerUserId") == 0 then
			local pad = candidate:FindFirstChild("ClaimPad")
			if pad then
				local distance = if root then (pad.Position - root.Position).Magnitude else candidate:GetAttribute("PlotId") or math.huge
				if not selectedDistance or distance < selectedDistance then
					selected, selectedDistance = pad, distance
				end
			end
		end
	end
	return selected
end

-- Selects a visible target while prioritizing required claim and kennel prerequisites.
local function resolveTarget(player, world, step)
	local plots = world:FindFirstChild("Plots")
	if not plots then return nil end
	local plot = plots:FindFirstChild("Plot" .. (player:GetAttribute("PlotId") or 0))
	if not plot then
		return nearestClaimPad(player, plots), "Claim a FREE shelter"
	end
	if not plot:GetAttribute("KennelPurchased") then
		return plot:FindFirstChild("PurchasePad"), "Build your kennel — " .. GameConfig.KennelCost .. " cash"
	end

	if step == 1 then
		local biomes = world:FindFirstChild("Biomes")
		local dogPark = biomes and biomes:FindFirstChild("DogPark")
		return dogPark and dogPark:FindFirstChild("Welcome"), "Follow the Dog Park trail"
	elseif step == 2 then
		local pets = world:FindFirstChild("Pets")
		if pets then
			for _, pet in pets:GetChildren() do
				if pet:GetAttribute("State") == "Available" and pet:GetAttribute("BiomeId") == "DogPark" then
					return pet.PrimaryPart
				end
			end
		end
	elseif step == 3 then
		return plot:FindFirstChild("EntranceSign")
	elseif step == 4 then
		return plot:FindFirstChild("GenerateButton", true)
	elseif step == 5 then
		return plot:FindFirstChild("FoodCollection", true)
	elseif step == 6 then
		local pets = world:FindFirstChild("Pets")
		if pets then
			for _, pet in pets:GetChildren() do
				if pet:GetAttribute("OwnerUserId") == player.UserId and pet:GetAttribute("State") == "Sheltered" then
					return pet.PrimaryPart
				end
			end
		end
	elseif step == 7 then
		local biomes = world:FindFirstChild("Biomes")
		local forest = biomes and biomes:FindFirstChild("Forest")
		return forest and forest:FindFirstChild("Welcome")
	end
	return nil
end

-- Displays one local NEXT marker and highlight without participating in authoritative gameplay.
function Onboarding.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local world = workspace:WaitForChild("ShelterWorld")
	local gui = Instance.new("ScreenGui")
	gui.Name = "OnboardingGuide"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local marker = Instance.new("BillboardGui")
	marker.Name = "NextMarker"
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(210, 54)
	marker.StudsOffset = Vector3.new(0, 5, 0)
	marker.Enabled = false
	marker.Parent = gui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(250, 195, 110)
	label.BackgroundTransparency = 0.08
	label.TextColor3 = Color3.fromRGB(45, 57, 66)
	label.TextStrokeTransparency = 1
	label.TextSize = 18
	label.TextWrapped = true
	label.Font = Enum.Font.GothamBold
	label.Parent = marker
	Instance.new("UICorner", label).CornerRadius = UDim.new(0, 12)

	local highlight = Instance.new("Highlight")
	highlight.Name = "OnboardingHighlight"
	highlight.FillColor = Color3.fromRGB(255, 207, 104)
	highlight.FillTransparency = 0.65
	highlight.OutlineColor = Color3.fromRGB(255, 248, 218)
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = workspace

	local elapsed = 1
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.5 then return end
		elapsed = 0
		local step = player:GetAttribute("GuidedStep") or 1
		local target, overrideText
		if player:GetAttribute("ProfileReady") then
			target, overrideText = resolveTarget(player, world, step)
		end
		marker.Adornee = target
		highlight.Adornee = target
		marker.Enabled = target ~= nil
		highlight.Enabled = target ~= nil
		local objective = overrideText or player:GetAttribute("GuidedObjective") or ""
		label.Text = "NEXT" .. string.char(10) .. objective
	end)
end

return Onboarding
