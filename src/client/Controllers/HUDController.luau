local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local HUDController = {}
local UI = require(script.Parent.Parent.UI.Components)
local started = false

local messages = {
	Claimed = "Shelter claimed! Walk onto the gold pad to build your kennel.",
	Purchased = "Kennel ready! Follow a habitat trail to find a friend.",
	AlreadyOwnPlot = "You already have a shelter. Follow your HOME marker.",
	PlotTaken = "This shelter belongs to another player.",
	NeedPlot = "Claim a free shelter first — walk onto an entrance pad.",
	NeedKennel = "Build your kennel before rescuing a pet.",
	NotOwner = "Only this shelter's owner can use that pad.",
	InsufficientCash = "You need 25 ShelterCash. Step off the pad before trying again.",
	AlreadyPurchased = "Your kennel is already built.",
	TooFar = "Move closer to interact.",
	ShelterFull = "Shelter full — adopt out a pet or buy more beds.",
	AlreadyFollowing = "Bring your current pet home first.",
	PetUnavailable = "That pet has already been rescued.",
	Rescued = "You're a team! Follow HOME and walk into the kennel entrance.",
	PetBusy = "Someone is calming this pet. Try another friend nearby.",
	EncounterExpired = "That pet wandered off. Press E near it to start again.",
	NeedTrust = "Earn this pet's trust before attaching the leash.",
	TrustCooldown = "Give your new friend a moment before trying again.",
	TrustReady = "PET TRUSTED YOU! Attach the leash and walk home together.",
	TrustGained = "Your new friend is feeling safer.",
	Delivered = "Safe at home! Your new friend has a cozy spot.",
	Adopted = "Pet adopted! You have space for another rescue.",
	CannotAdopt = "Move close to a sheltered pet you own to arrange adoption.",
	Upgraded = "Shelter improvement built! Check your new beds, pantry, storage or care corner.",
	AlreadyUpgraded = "This upgrade branch is complete.",
	UpgradeFunds = "Not enough cash for this upgrade. Adopt out pets to earn more.",
	BuildFailed = "Construction failed. Your cash was returned. Step off and try again.",
	RescueFailed = "That rescue couldn't start. Please try again.",
	Cooldown = "Please wait a moment and try again.",
	AdoptionStarted = "An adopter is on the way! Payment arrives when your pet leaves.",
	AdoptionBusy = "Your shelter already has an adoption in progress.",
	AdoptionCancelled = "Adoption paused. Your pet is safe in its bed; try again.",
	CannotFeed = "Move close to a sheltered pet you own to feed it.",
	NoFood = "Generate treats, then collect them from your food bin.",
	MaxLevel = "This pet has reached the maximum level. No food spent.",
	LoadingProfile = "Loading your shelter safely…",
	QuestComplete = "Adventure complete! Open GOALS to claim your reward.",
	RewardClaimed = "Reward claimed!",
	CollectionReward = "Collection milestone claimed!",
	TutorialSkipped = "Tutorial hidden. GOALS and world prompts remain available.",
	CannotCare = "Move close to a sheltered pet you own.",
	CareCooldown = "This care activity is still recharging. No XP was awarded.",
	UnknownCare = "That care activity is unavailable.",
	InvalidPetName = "Use a name between 2 and 20 characters.",
	RenameUnavailable = "That name could not be approved. Try another.",
	Renamed = "Pet renamed!",
	FavoriteChanged = "Favorite protection updated.",
	Cared = "Your pet enjoyed the attention!",
}

-- Creates the HUD/home marker and subscribes to replicated cash, plot objectives and server feedback.
function HUDController.Start()
	if started then return end
	started = true
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ShelterHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(12, 12)
	panel.Size = UDim2.new(1, -24, 0, 230)
	panel.BackgroundColor3 = Color3.fromRGB(28, 51, 47)
	panel.BackgroundTransparency = 0.08
	panel.BorderSizePixel = 0
	panel.Parent = gui
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(350, 230)
	limit.Parent = panel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = panel
	UI.Card(panel)
	-- Creates a consistently styled HUD label with the requested position and text size.
	local function text(parent, name, y, height, size)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.Position = UDim2.fromOffset(14, y)
		label.Size = UDim2.new(1, -28, 0, height)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(248, 241, 222)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextWrapped = true
		label.Font = Enum.Font.GothamMedium
		label.TextSize = size
		label.Text = ""
		label.Parent = parent
		UI.Text(label, size >= 20)
		return label
	end
	text(panel, "Title", 10, 22, 15).Text = "PET RESCUE • SHELTER"
	local cashLabel = text(panel, "Cash", 36, 29, 23)
	UI.Currency(cashLabel)
	cashLabel.Text = "ShelterCash: …"
	local countLabel = text(panel, "Collection", 70, 23, 16)
	local foodLabel = text(panel, "Food", 95, 23, 16)
	local objective = text(panel, "Objective", 121, 65, 17)
	objective.Text = "Loading shelter…"
	local notice = text(panel, "SessionNotice", 191, 30, 12)
	notice.TextColor3 = Color3.fromRGB(89, 108, 99)
	notice.Text = "Prototype — progress resets when you leave"
	local toast = text(panel, "Feedback", 240, 72, 16)
	toast.BackgroundColor3 = Color3.fromRGB(35, 60, 52)
	toast.BackgroundTransparency = 0.05
	toast.Visible = false
	local toastCorner = Instance.new("UICorner")
	toastCorner.Parent = toast
	UI.Notification(toast, UI.Colors.Peach)
	local toastVersion = 0
	local remotes = ReplicatedStorage:WaitForChild("ShelterRemotes")
	remotes:WaitForChild("Feedback").OnClientEvent:Connect(function(code, detail)
		toastVersion += 1
		local version = toastVersion
		toast.Text = messages[code] or "That action isn't available right now."
		if code == "Adopted" then
			local value = if type(detail) == "table" then detail.Value else detail
			local bonus = if type(detail) == "table" then detail.Bonus or 0 else 0
			toast.Text = "Pet adopted! +" .. tostring(value) .. " cash. A bed is now free."
			if bonus > 0 then toast.Text ..= "\nAdopter request matched: +" .. bonus .. " bonus!" end
		end
		if code == "Discovered" then toast.Text = "NEW PET DISCOVERED!\n" .. tostring(detail) .. "\nAdded to your Pet Index." end
		if code == "FoodCollected" then toast.Text = if detail > 0 then "+" .. detail .. " Food collected!" else "Bin empty or storage full. Excess food stays in the bin." end
		if code == "FeedingCooldown" then toast.Text = string.format("Max feeding XP reached. Ready again in %d:%02d. No food spent.", math.floor(detail / 60), detail % 60) end
		if code == "Fed" then toast.Text = if detail.Leveled then "LEVEL UP! " .. detail.Name .. " reached Level " .. detail.Level else "+" .. detail.XP .. " XP — happy pet!" end
		if code == "RewardClaimed" then toast.Text = "Adventure reward! +" .. tostring(detail) .. " cash" end
		if code == "CollectionReward" then toast.Text = "COLLECTION REWARD! +" .. tostring(detail) .. " cash" end
		if code == "QuestComplete" then toast.Text = tostring(detail) .. " complete!\nOpen GOALS to claim your reward." end
		if code == "CareCooldown" then toast.Text = string.format("Care XP ready again in %d:%02d.", math.floor(detail / 60), detail % 60) end
		if code == "Cared" then toast.Text = (if detail.Leveled then "LEVEL UP! " .. detail.Name .. " reached Level " .. detail.Level
			elseif detail.XP == 0 then detail.Action .. " time! Happiness increased."
			else detail.Action .. " time! +" .. detail.XP .. " XP") end
		if code == "TrustGained" and type(detail) == "table" then toast.Text = detail.Name .. " trusts you more! " .. detail.Trust .. "/" .. Config.TrustRequired end
		if code == "FavoriteChanged" then toast.Text = detail.Name .. (if detail.Favorite then " is now favorited and protected." else " can now be adopted.") end
		if code == "Renamed" then toast.Text = "Your pet is now named " .. tostring(detail) .. "!" end
		toast.Visible = true
		UI.Pop(toast)
		task.delay(4, function() if version == toastVersion then toast.Visible = false end end)
	end)
	local world = workspace:WaitForChild("ShelterWorld")
	local plots = world:WaitForChild("Plots")
	local cash = player:WaitForChild("leaderstats"):WaitForChild("ShelterCash")
	local marker
	local markedPlot
	-- Derives cash, food, capacity, objective and home marker from the current replicated state.
	local function render()
		local saveState = player:GetAttribute("SaveState") or ""
		notice.Text = if player:GetAttribute("PersistenceEnabled") then "Saving: " .. saveState .. " • claim a plot to restore" else "Studio preview — progress resets when you leave"
		cashLabel.Text = "ShelterCash: " .. cash.Value
		local id = player:GetAttribute("PlotId") or 0
		local plot = plots:FindFirstChild("Plot" .. id)
		local count = if plot then (plot:GetAttribute("PetCount") or 0) else 0
		local reserved = if plot then (plot:GetAttribute("ReservedCount") or 0) else 0
		local maximum = if plot then (plot:GetAttribute("MaxPetCapacity") or Config.PetCapacity) else Config.PetCapacity
		countLabel.Text = "Pet capacity: " .. (count + reserved) .. " / " .. maximum .. (if reserved > 0 then " (1 on leash)" else "")
			.. (if plot then " • Shelter tier " .. (plot:GetAttribute("ShelterTier") or 0) else "")
		foodLabel.Text = "Stored food: " .. (if plot then (plot:GetAttribute("StoredFood") or 0) else 0)
			.. " / " .. (if plot then (plot:GetAttribute("FoodCapacity") or Config.FoodStorageCapacity) else Config.FoodStorageCapacity)
			.. " • Bin: " .. (if plot then plot:GetAttribute("PendingFood") or 0 else 0)
		if player:GetAttribute("ProfileReady") ~= true then
			objective.Text = "Loading your shelter safely…"
		elseif not plot then
			objective.Text = if world:GetAttribute("AvailablePlots") == 0 then "All shelters occupied" else "Walk onto a FREE entrance pad to claim your shelter."
		elseif not plot:GetAttribute("KennelPurchased") then
			objective.Text = "Build your kennel — " .. Config.KennelCost .. " cash. Walk onto the gold pad."
		elseif (player:GetAttribute("FollowingPetId") or "") ~= "" then
			objective.Text = "Bring your pet HOME. Walk into your kennel entrance."
		elseif count >= maximum then
			objective.Text = "Shelter full — view a pet to adopt it out, or buy more beds."
		elseif count > 0 then
			objective.Text = "Collect food from your bin. View a pet to FEED it or arrange adoption."
		else
			objective.Text = "Follow a habitat trail. Press E or tap a pet to rescue."
		end
		local guided = player:GetAttribute("GuidedObjective")
		if plot and plot:GetAttribute("KennelPurchased") and guided and guided ~= "" and (player:GetAttribute("FollowingPetId") or "") == "" and count < maximum then objective.Text = guided end
		if markedPlot ~= plot then
			if marker then marker:Destroy() end
			marker = nil
			markedPlot = plot
			if plot then
				marker = Instance.new("BillboardGui")
				marker.Name = "HomeMarker"
				marker.Adornee = plot:FindFirstChild("EntranceSign")
				marker.AlwaysOnTop = true
				marker.Size = UDim2.fromOffset(150, 38)
				marker.StudsOffset = Vector3.new(0, 10, 0)
				marker.Parent = gui
				local title = text(marker, "Home", 0, 38, 22)
				title.Text = "▼ HOME"
				title.TextStrokeTransparency = 0.2
				title.TextXAlignment = Enum.TextXAlignment.Center
			end
		end
		if marker and plot then marker.Adornee = plot:FindFirstChild("EntranceSign") end
	end
	-- Observe each fixed plot once; no connections accumulate as ownership changes.
	local observed = {}
	-- Subscribes once to a fixed plot's display-relevant attributes and refreshes the HUD.
	local function observe(plot)
		if observed[plot] then return end
		observed[plot] = true
		for _, attribute in { "PetCount", "ReservedCount", "MaxPetCapacity", "StoredFood", "PendingFood", "FoodCapacity", "KennelPurchased", "OwnerUserId", "ShelterTier", "AdopterRequestText" } do
			plot:GetAttributeChangedSignal(attribute):Connect(render)
		end
		plot.ChildAdded:Connect(render)
		render()
	end
	plots.ChildAdded:Connect(observe)
	for _, plot in plots:GetChildren() do observe(plot) end
	cash:GetPropertyChangedSignal("Value"):Connect(render)
	player:GetAttributeChangedSignal("PlotId"):Connect(render)
	player:GetAttributeChangedSignal("FollowingPetId"):Connect(render)
	player:GetAttributeChangedSignal("ProfileReady"):Connect(render)
	player:GetAttributeChangedSignal("PersistenceEnabled"):Connect(render)
	player:GetAttributeChangedSignal("SaveState"):Connect(render)
	player:GetAttributeChangedSignal("GuidedObjective"):Connect(render)
	world:GetAttributeChangedSignal("AvailablePlots"):Connect(render)
	render()
end

return HUDController
