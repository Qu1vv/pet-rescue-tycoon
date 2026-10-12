local Styles = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Pets"):WaitForChild("RarityStyles"))
local Plates = {}

-- Gives every pet a persistent, distance-limited name/rarity/level plate; prompt proximity is not required.
function Plates.Start()
	local pets = workspace:WaitForChild("ShelterWorld"):WaitForChild("Pets")
	local entries = {}
	-- Creates one nameplate per replicated pet and tracks its update connections.
	local function watch(model)
		if entries[model] then return end
		local gui = Instance.new("BillboardGui")
		gui.Name, gui.Size, gui.MaxDistance = "PetNameplate", UDim2.fromOffset(210, 57), 85
		gui.AlwaysOnTop = true
		gui.Parent = model
		local title = Instance.new("TextLabel")
		title.Size, title.BackgroundTransparency = UDim2.new(1, 0, 0, 24), 1
		title.TextSize, title.Font = 15, Enum.Font.GothamBold
		title.TextColor3, title.TextStrokeTransparency = Color3.new(1, 1, 1), 0.35
		title.Parent = gui
		local rarity = title:Clone()
		rarity.Position, rarity.TextSize = UDim2.fromOffset(0, 25), 18
		rarity.Parent = gui
		-- Refreshes text, rarity color and height from server-replicated pet attributes.
		local function render()
			local tier = model:GetAttribute("Rarity") or "Common"
			local style = Styles[tier] or Styles.Common
			gui.Adornee = model.PrimaryPart
			gui.StudsOffsetWorldSpace = Vector3.new(0, model:GetAttribute("NameplateHeight") or 5, 0)
			title.Text = (if model:GetAttribute("Favorite") then "★ " else "") .. (model:GetAttribute("PetName") or model.Name) .. " • " .. (model:GetAttribute("Personality") or "Gentle")
			rarity.Text = string.upper(tier) .. "  •  LV " .. (model:GetAttribute("Level") or 1)
			rarity.TextColor3 = Color3.fromRGB(table.unpack(style.Color))
		end
		entries[model] = { model.AttributeChanged:Connect(render), model:GetPropertyChangedSignal("PrimaryPart"):Connect(render) }
		render()
	end
	pets.ChildAdded:Connect(watch)
	pets.ChildRemoved:Connect(function(model)
		for _, connection in entries[model] or {} do connection:Disconnect() end
		entries[model] = nil
	end)
	for _, model in pets:GetChildren() do watch(model) end
end
return Plates

