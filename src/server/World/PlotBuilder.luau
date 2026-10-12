local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Upgrades = require(game:GetService("ReplicatedStorage").Shared.Config.ShelterUpgrades)
local Build = require(script.Parent.Parent.Common.BuildUtil)
local Housing = require(game:GetService("ReplicatedStorage").Shared.Pets.PetHousing)
local PlotBuilder = {}
local fenceColor = Color3.fromRGB(236, 221, 190)
local wood = Color3.fromRGB(180, 134, 92)

-- Builds one fenced plot with pads, spawn and intake; returns its runtime record without assigning ownership.
function PlotBuilder.CreatePlot(parent, id, frame, color)
	local model = Instance.new("Model")
	model.Name = "Plot" .. id
	model:SetAttribute("PlotId", id)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("KennelPurchased", false)
	model:SetAttribute("PetCount", 0)
	model:SetAttribute("ReservedCount", 0)
	model:SetAttribute("MaxPetCapacity", Config.PetCapacity)
	model:SetAttribute("StoredFood", 0)
	model:SetAttribute("FoodCapacity", Config.FoodStorageCapacity)
	model:SetAttribute("FoodDropStartedAt", 0)
	model:SetAttribute("ShelterTier", 0)
	model:SetAttribute("AdopterRequestId", "")
	model:SetAttribute("AdopterRequestText", "")
	model:SetAttribute("AdopterRequestKind", "")
	model:SetAttribute("AdopterRequestValue", "")
	model:SetAttribute("AdopterRequestBonus", 1)
	model:SetAttribute("AdopterRequestExpiresAt", 0)
	-- Creates geometry relative to this plot/kennel's frame so all six shelters share the same layout.
	local function part(name, size, offset, tint, material)
		return Build.Part(model, name, size, frame * CFrame.new(offset), tint, material)
	end
	part("Lawn", Vector3.new(112, 0.4, 112), Vector3.new(0, 0.2, 0), Color3.fromRGB(144, 177, 118), Enum.Material.Grass)
	part("Walkway", Vector3.new(14, 0.15, 88), Vector3.new(0, 0.48, -10), Color3.fromRGB(224, 212, 182))
	-- Local -Z faces the park. Front fence has a 16-stud opening.
	for _, height in { 2.3, 5 } do
		part("Fence", Vector3.new(2, 1.1, 112), Vector3.new(-56, height, 0), fenceColor)
		part("Fence", Vector3.new(2, 1.1, 112), Vector3.new(56, height, 0), fenceColor)
		part("Fence", Vector3.new(112, 1.1, 2), Vector3.new(0, height, 56), fenceColor)
		for _, x in { -32, 32 } do
			part("Fence", Vector3.new(48, 1.1, 2), Vector3.new(x, height, -56), fenceColor)
		end
	end
	for _, x in { -56, 56 } do
		for z = -56, 56, 14 do
			part("Post", Vector3.new(2.5, 6, 2.5), Vector3.new(x, 3, z), fenceColor)
		end
	end
	for _, x in { -42, -28, -14, 14, 28, 42 } do
		part("Post", Vector3.new(2.5, 6, 2.5), Vector3.new(x, 3, 56), fenceColor)
		part("Post", Vector3.new(2.5, 6, 2.5), Vector3.new(x, 3, -56), fenceColor)
	end
	for _, x in { -9, 9 } do
		part("EntrancePost", Vector3.new(2, 9, 2), Vector3.new(x, 4.5, -56), color)
	end
	local sign = part("EntranceSign", Vector3.new(19, 2, 1), Vector3.new(0, 9, -56), color)
	local title = Build.Label(sign, "Shelter " .. id .. "\nWalk in to claim — FREE", 140)
	local claimPad = part("ClaimPad", Vector3.new(14, 0.25, 9), Vector3.new(0, 0.65, -53), color)
	local claimZone = Build.Zone(model, "ClaimZone", Vector3.new(14, 7, 9), frame * CFrame.new(0, 3.9, -53))
	local buyPad = part("PurchasePad", Vector3.new(10, 0.25, 9), Vector3.new(0, 0.65, -33), Color3.fromRGB(244, 193, 78))
	local buyLabel = Build.Label(buyPad, "Walk here to build\nKennel — " .. Config.KennelCost .. " cash")
	local buyZone = Build.Zone(model, "PurchaseZone", Vector3.new(10, 7, 9), frame * CFrame.new(0, 3.9, -33))
	local upgradePad = part("UpgradePad", Vector3.new(10, 0.25, 9), Vector3.new(25, 0.65, -20), Color3.fromRGB(145, 119, 211))
	local upgradeLabel = Build.Label(upgradePad, "Expand to " .. Config.CapacityUpgrade.Capacity .. " beds\n" .. Config.CapacityUpgrade.Cost .. " cash")
	upgradePad.Transparency = 1
	upgradePad.CanCollide = false
	upgradeLabel.Parent.Enabled = false
	local upgradeZone = Build.Zone(model, "UpgradeZone", Vector3.new(10, 7, 9), frame * CFrame.new(25, 3.9, -20))
	local upgradePads = { Beds = { Part = upgradePad, Zone = upgradeZone, Label = upgradeLabel } }
	for _, entry in { { "Pantry", -44, -33 }, { "Storage", -25, 7 }, { "Care", 35, -3 } } do
		local branch, x, z = entry[1], entry[2], entry[3]
		local pad = part(branch .. "UpgradePad", Vector3.new(9, 0.25, 8), Vector3.new(x, 0.65, z), Color3.fromRGB(111, 171, 207))
		pad.Transparency, pad.CanCollide = 1, false
		local label = Build.Label(pad, "")
		label.Parent.Enabled = false
		local zone = Build.Zone(model, branch .. "UpgradeZone", Vector3.new(9, 7, 8), frame * CFrame.new(x, 3.9, z))
		upgradePads[branch] = { Part = pad, Zone = zone, Label = label }
	end
	local spawn = Build.Spawn(model, "HomeSpawn", frame * CFrame.new(20, 1, -34), false)
	local intake = Build.Zone(model, "IntakeZone", Vector3.new(32, 9, 18), frame * CFrame.new(0, 4.5, 5))
	model.Parent = parent
	return {
		Id = id, Model = model, Frame = frame, Color = color, Owner = nil,
		ClaimPad = claimPad, ClaimZone = claimZone, PurchasePad = buyPad, PurchaseZone = buyZone,
		PurchaseLabel = buyLabel, Title = title, Spawn = spawn, Intake = intake,
		UpgradePad = upgradePad, UpgradeZone = upgradeZone, UpgradeLabel = upgradeLabel,
		UpgradePads = upgradePads, Upgrades = Upgrades.New(),
		Capacity = Config.PetCapacity,
		Purchased = false, Busy = false, Kennel = nil,
		Slots = PlotBuilder.GetSlots({ Frame = frame }, Config.PetCapacity),
	}
end

-- Updates purchase/upgrade pad visibility and replicated kennel state after a build-state change.
function PlotBuilder.SetPurchased(plot, purchased)
	plot.PurchasePad.Transparency = if purchased then 1 else 0
	plot.PurchasePad.CanCollide = not purchased
	plot.PurchaseLabel.Parent.Enabled = not purchased
	plot.Model:SetAttribute("KennelPurchased", purchased)
	for branch, pad in plot.UpgradePads do
		local nextTier = Upgrades.Next(plot.Upgrades, branch, Config)
		local available = purchased and nextTier ~= nil
		pad.Part.Transparency, pad.Part.CanCollide = if available then 0 else 1, available
		pad.Label.Parent.Enabled = available
		if nextTier then pad.Label.Text = nextTier.Title .. "\nWalk here · " .. nextTier.Cost .. " cash" end
		plot.Model:SetAttribute("Upgrade" .. branch, plot.Upgrades[branch])
	end
	local stats = Upgrades.Stats(plot.Upgrades, Config)
	local tier = 0
	for _, level in plot.Upgrades do tier += level end
	plot.Model:SetAttribute("ShelterTier", tier)
	plot.Model:SetAttribute("FoodCapacity", stats.FoodStorageCapacity)
	plot.Model:SetAttribute("FoodBinCapacity", stats.FoodBinCapacity)
	plot.Model:SetAttribute("FoodProductionInterval", stats.FoodProductionInterval)
	plot.Model:SetAttribute("FeedingXPReward", stats.FeedingXPReward)
end

-- Returns stable suite transforms on both sides of a clear central aisle as capacity grows.
function PlotBuilder.GetSlots(plot, capacity)
	local slots = {}
	local columns = { -25, -12, 12, 25 }
	for index = 1, capacity do
		local row = math.floor((index - 1) / 4)
		slots[index] = plot.Frame * CFrame.new(columns[((index - 1) % 4) + 1], 0.85, 23 + row * 16)
	end
	return slots
end

-- Builds kennel geometry, pet spaces and the food machine into a supplied unparented model.
function PlotBuilder.BuildKennel(model, plot, capacity)
	capacity = capacity or plot.Capacity
	local extraDepth = (math.ceil(capacity / 4) - 1) * 16
	local depth = 24 + extraDepth
	local width = 70
	model.Name = "BasicKennel"
	local base = plot.Frame * CFrame.new(0, 0.4, 21 + extraDepth / 2)
	-- Creates geometry relative to this plot/kennel's frame so all six shelters share the same layout.
	local function part(name, size, offset, color)
		return Build.Part(model, name, size, base * CFrame.new(offset), color or wood)
	end
	part("Floor", Vector3.new(width, 0.25, depth), Vector3.new(0, 0.125, 0))
	part("Back", Vector3.new(width, 10, 0.5), Vector3.new(0, 5, depth / 2))
	for _, x in { -width / 2, width / 2 } do
		part("Side", Vector3.new(0.5, 10, depth), Vector3.new(x, 5, 0))
	end
	-- The short awning reads as a building entrance while leaving every suite visible from above.
	part("EntranceAwning", Vector3.new(width + 3, 0.7, 5), Vector3.new(0, 10.3, -depth / 2 + 2.5), plot.Color)
	local aisle = part("CentralAisle", Vector3.new(10, 0.06, depth - 4), Vector3.new(0, 0.28, 1), Color3.fromRGB(225, 211, 185))
	aisle.CanCollide = false
	-- A facade board sits above the open entrance instead of floating over the roof.
	local facade = part("ShelterFacadeSign", Vector3.new(18, 2.6, 0.5), Vector3.new(0, 11.5, -depth / 2 - 0.35), plot.Color)
	local facadeLabel = Build.Label(facade, "PET RESCUE SHELTER", 110)
	facadeLabel.Name = "ShelterFacadeLabel"
	local visualTier = 0
	for _, level in plot.Upgrades do visualTier += level end
	local upgradeBoard = part("UpgradeBoard", Vector3.new(13, 6, 0.5), Vector3.new(width / 2 - 7, 4, -depth / 2 + 1), plot.Color)
	Build.Label(upgradeBoard, "SHELTER TIER " .. visualTier
		.. "\nBeds " .. plot.Upgrades.Beds .. " · Pantry " .. plot.Upgrades.Pantry
		.. "\nStorage " .. plot.Upgrades.Storage .. " · Care " .. plot.Upgrades.Care, 70)
	local requestBoard = part("AdopterRequestBoard", Vector3.new(13, 5, 0.5), Vector3.new(-width / 2 + 7, 3.5, -depth / 2 + 1), Color3.fromRGB(250, 195, 158))
	local requestLabel = Build.Label(requestBoard, "ADOPTER REQUEST" .. string.char(10) .. "Finding a local family…", 70)
	requestLabel.Name = "AdopterRequestLabel"
	local adoptionDesk = part("AdoptionDesk", Vector3.new(9, 2, 3), Vector3.new(-22, 1.2, -depth / 2 - 4), Color3.fromRGB(245, 202, 169))
	local deskSign = part("AdoptionDeskSign", Vector3.new(8.5, 1.6, 0.25), Vector3.new(-22, 3.1, -depth / 2 - 5.55), plot.Color)
	Build.Label(deskSign, "ADOPTION DESK", 70)
	local suites = Instance.new("Folder")
	suites.Name = "HousingSpaces"
	suites.Parent = model
	for index, frame in PlotBuilder.GetSlots(plot, capacity) do
		local suite = Instance.new("Model")
		suite.Name = "Suite" .. index
		suite:SetAttribute("HousingSlotId", index)
		suite:SetAttribute("PetUniqueId", "")
		suite:SetAttribute("Occupied", false)
		suite:SetAttribute("HabitatType", "Cozy")
		suite.Parent = suites
		Build.Part(suite, "SuiteFloor", Vector3.new(9.4, 0.17, 12), frame * CFrame.new(0, -0.17, 0), Color3.fromRGB(246, 230, 199))
		for _, x in { -4.5, 4.5 } do
			Build.Part(suite, "LowDivider", Vector3.new(0.25, 2, 11), frame * CFrame.new(x, 0.9, 0.5), plot.Color)
		end
		Build.Part(suite, "BackRail", Vector3.new(9.3, 2, 0.25), frame * CFrame.new(0, 0.9, 5.8), plot.Color)
		local cushion = Build.Part(suite, "SoftBed", Vector3.new(5.2, 0.35, 3.6), frame * CFrame.new(0, -0.03, 2), Color3.fromRGB(232, 161, 170))
		cushion.Shape = Enum.PartType.Ball
		local bowl = Build.Part(suite, "WaterBowl", Vector3.new(1.5, 0.35, 1.5), frame * CFrame.new(2.8, -0.02, -2.2), Color3.fromRGB(110, 184, 219))
		bowl.Shape = Enum.PartType.Cylinder
		local toy = Build.Part(suite, "ToyBall", Vector3.one * 0.9, frame * CFrame.new(-2.8, 0.2, -2.5), Color3.fromRGB(245, 190, 86))
		toy.Shape = Enum.PartType.Ball
		local board = Build.Part(suite, "NameBoard", Vector3.new(5.2, 1.2, 0.25), frame * CFrame.new(0, 2, -5.65), plot.Color)
		local label = Build.Label(board, "SUITE " .. index .. "  •  READY")
		label.Name = "HousingNameLabel"
	end
	local machine = plot.Frame
	local stats = Upgrades.Stats(plot.Upgrades, Config)
	local generator = Build.Part(model, "FoodGenerator", Vector3.new(7, 6, 5), machine * CFrame.new(-36, 3.4, -19), plot.Color)
	Build.Label(generator, "PAW PANTRY · " .. (plot.Upgrades.Pantry + 1) .. "\nTreats every " .. stats.FoodProductionInterval .. "s")
	if plot.Upgrades.Pantry > 0 then
		Build.Part(model, "PantryExtension", Vector3.new(5, 3, 5), machine * CFrame.new(-36, 9, -19), Color3.fromRGB(244, 194, 83))
		if plot.Upgrades.Pantry > 1 then
			Build.Part(model, "SecondNozzle", Vector3.new(2.5, 2, 2.5), machine * CFrame.new(-32, 5.5, -15), Color3.fromRGB(190, 203, 211))
		end
	end
	for index = 1, plot.Upgrades.Storage do
		local store = Build.Part(model, "StorageCabinet", Vector3.new(6, 7, 5), machine * CFrame.new(-47, 4, -12 + index * 10), plot.Color)
		Build.Label(store, "PANTRY STORE\n" .. stats.FoodStorageCapacity .. " capacity", 45)
	end
	if plot.Upgrades.Care > 0 then
		Build.Part(model, "CareRug", Vector3.new(18, 0.25, 12), machine * CFrame.new(36, 0.6, -15), Color3.fromRGB(218, 182, 191))
		local sign = Build.Part(model, "CareSign", Vector3.new(8, 3, 0.3), machine * CFrame.new(36, 4, -22), plot.Color)
		Build.Label(sign, "CARE CORNER\n+" .. stats.FeedingXPReward .. " XP per meal", 65)
		for _, x in { 30, 35, 40 } do
			local toy = Build.Part(model, "PlayBall", Vector3.one * 2, machine * CFrame.new(x, 1.7, -15), Color3.fromRGB(242, 192, 107))
			toy.Shape = Enum.PartType.Ball
		end
	end
	Build.Part(model, "Hopper", Vector3.new(9, 2, 7), machine * CFrame.new(-36, 7, -19), Color3.fromRGB(244, 194, 83))
	Build.Part(model, "Nozzle", Vector3.new(3, 2, 3), machine * CFrame.new(-36, 5.5, -15), Color3.fromRGB(190, 203, 211))
	Build.Part(model, "FoodConveyor", Vector3.new(7, 1, 20), machine * CFrame.new(-36, 2, -7), Color3.fromRGB(65, 75, 82))
	for _, x in { -40, -32 } do
		Build.Part(model, "ConveyorRail", Vector3.new(0.5, 1, 20), machine * CFrame.new(x, 2.8, -7), plot.Color)
	end
	for z = -15, 1, 2 do
		local stripe = Build.Part(model, "BeltStripe", Vector3.new(6.8, 0.08, 0.25), machine * CFrame.new(-36, 2.55, z), Color3.fromRGB(117, 139, 146))
		stripe.CanCollide = false
		stripe:SetAttribute("BeltZ", z)
		stripe:SetAttribute("RestFrame", stripe.CFrame)
	end
	Build.Zone(model, "FoodDropStart", Vector3.one, machine * CFrame.new(-36, 5, -15))
	Build.Zone(model, "FoodDropEnd", Vector3.one, machine * CFrame.new(-36, 3, 1))
	Build.Zone(model, "FoodBinTarget", Vector3.one, machine * CFrame.new(-36, 1.6, 5))
	local bin = Build.Part(model, "FoodCollection", Vector3.new(9, 0.6, 7), machine * CFrame.new(-36, 0.7, 5), Color3.fromRGB(218, 166, 74))
	for _, x in { -40.5, -31.5 } do
		Build.Part(model, "BinWall", Vector3.new(0.5, 3, 7), machine * CFrame.new(x, 2, 5), plot.Color)
	end
	for _, z in { 1.5, 8.5 } do
		Build.Part(model, "BinWall", Vector3.new(9, if z == 1.5 then 1 else 3, 0.5), machine * CFrame.new(-36, if z == 1.5 then 1 else 2, z), plot.Color)
	end
	local fill = Build.Part(model, "BinFill", Vector3.new(8, 0.15, 6), machine * CFrame.new(-36, 1.1, 5), Color3.fromRGB(199, 139, 69))
	fill.CanCollide = false
	fill:SetAttribute("RestFrame", fill.CFrame)
	local binBoard = Build.Part(model, "FoodBinBoard", Vector3.new(8, 2, 0.3), machine * CFrame.new(-36, 3.2, 1.25), plot.Color)
	local label = Build.Label(binBoard, "FOOD READY: 0\nCollect into storage", 90)
	label.Name = "FoodReadyLabel"
	local button = Build.Part(model, "GenerateButton", Vector3.new(3, 0.6, 3), machine * CFrame.new(-28, 2.8, -16), Color3.fromRGB(110, 220, 142))
	button:SetAttribute("RestFrame", button.CFrame)
	Build.Part(model, "ButtonStand", Vector3.new(4, 2, 4), machine * CFrame.new(-28, 1.5, -16), Color3.fromRGB(70, 85, 96))
	Build.Label(button, "GENERATE FOOD\nPress for an extra treat", 85)
	for _, pair in { { button, "Generate food" }, { bin, "Collect food" } } do
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "FoodInteraction"
		prompt.ActionText = pair[2]
		prompt.ObjectText = "Paw Pantry"
		prompt.MaxActivationDistance = Config.InteractionDistance
		prompt.RequiresLineOfSight = false
		prompt.Parent = pair[1]
	end
end

-- Decorates one occupied suite from its species profile without changing the authoritative slot ledger.
function PlotBuilder.SetHousingOccupant(plot, slotId, petId, name, species)
	local suites = plot.Kennel and plot.Kennel:FindFirstChild("HousingSpaces")
	local suite = suites and suites:FindFirstChild("Suite" .. tostring(slotId))
	if not suite then return false end
	local old = suite:FindFirstChild("PetDecoration")
	if old then old:Destroy() end
	local occupied = type(petId) == "string" and petId ~= ""
	suite:SetAttribute("PetUniqueId", if occupied then petId else "")
	suite:SetAttribute("Occupied", occupied)
	local profile = Housing.Get(species)
	suite:SetAttribute("HabitatType", if occupied then profile.Title else "Cozy")
	local board = suite:FindFirstChild("NameBoard")
	local label = board and board:FindFirstChild("HousingNameLabel", true)
	if label then label.Text = if occupied then profile.Title .. "  •  " .. (name or "Friend") else "SUITE " .. slotId .. "  •  READY" end
	if not occupied then return true end
	local frame = plot.Slots[slotId]
	local decor = Instance.new("Model")
	decor.Name = "PetDecoration"
	decor.Parent = suite
	local tint = Color3.fromRGB(table.unpack(profile.Color))
	if species == "Dog" then
		Build.Part(decor, "DogHouseBack", Vector3.new(3.2, 2.2, 0.3), frame * CFrame.new(-2.4, 1.1, 4.6), tint)
		Build.Part(decor, "DogHouseRoof", Vector3.new(3.8, 0.3, 2.5), frame * CFrame.new(-2.4, 2.5, 3.5), tint)
	elseif species == "Cat" then
		Build.Part(decor, "CatPost", Vector3.new(0.5, 2.6, 0.5), frame * CFrame.new(-2.8, 1.3, 3.8), tint)
		Build.Part(decor, "CatPerch", Vector3.new(2.6, 0.25, 2), frame * CFrame.new(-2.8, 2.7, 3.8), tint)
	else
		Build.Part(decor, "CozyHideout", Vector3.new(3, 1.6, 2), frame * CFrame.new(-2.4, 0.8, 4), tint)
	end
	return true
end

-- Destroys the departing owner's kennel and restores a vacant plot, base capacity and empty food displays.
function PlotBuilder.Reset(plot)
	if plot.Kennel then plot.Kennel:Destroy() end
	plot.Kennel = nil
	plot.Purchased = false
	plot.Busy = false
	plot.Owner = nil
	plot.Capacity = Config.PetCapacity
	plot.Upgrades = Upgrades.New()
	plot.Slots = PlotBuilder.GetSlots(plot, plot.Capacity)
	plot.Spawn.Enabled = false
	plot.Title.Text = "Shelter " .. plot.Id .. "\nWalk in to claim — FREE"
	plot.Model:SetAttribute("OwnerUserId", 0)
	plot.Model:SetAttribute("OwnerName", "")
	plot.Model:SetAttribute("PetCount", 0)
	plot.Model:SetAttribute("ReservedCount", 0)
	plot.Model:SetAttribute("MaxPetCapacity", plot.Capacity)
	plot.Model:SetAttribute("StoredFood", 0)
	plot.Model:SetAttribute("PendingFood", 0)
	plot.Model:SetAttribute("FoodDropSequence", 0)
	plot.Model:SetAttribute("FoodDropStartedAt", 0)
	plot.Model:SetAttribute("ShelterTier", 0)
	plot.Model:SetAttribute("AdopterRequestId", "")
	plot.Model:SetAttribute("AdopterRequestText", "")
	plot.Model:SetAttribute("AdopterRequestKind", "")
	plot.Model:SetAttribute("AdopterRequestValue", "")
	plot.Model:SetAttribute("AdopterRequestBonus", 1)
	plot.Model:SetAttribute("AdopterRequestExpiresAt", 0)
	PlotBuilder.SetPurchased(plot, false)
end

return PlotBuilder
