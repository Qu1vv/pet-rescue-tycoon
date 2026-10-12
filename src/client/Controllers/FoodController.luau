local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("GameConfig"))
local FoodController = {}
local Audio = require(script.Parent.AudioController)
local started = false

-- Observes drop sequences and animates bounded local treats, belts, bin fill and button feedback.
function FoodController.Start()
	if started then return end
	started = true
	local plots = workspace:WaitForChild("ShelterWorld"):WaitForChild("Plots")
	local entries = {}
	-- Registers a fixed plot's food replication listeners and owns its local visual state.
	local function watch(plot)
		if entries[plot] then return end
		local entry = { Drops = {} }
		entries[plot] = entry
		-- Destroys this plot's active cosmetic food and resets its remembered drop sequence.
		local function clear()
			entry.Last = nil
			for _, drop in entry.Drops do drop.Part:Destroy() end
			table.clear(entry.Drops)
		end
		-- Creates a bounded local treat for a newly replicated drop without granting any inventory.
		local function spawn()
			local time = plot:GetAttribute("FoodDropStartedAt") or 0
			if time == 0 then clear(); return end
			local sequence = plot:GetAttribute("FoodDropSequence") or 0
			if sequence == entry.Last then return end
			entry.Last = sequence
			if #entry.Drops >= Config.MaxVisibleFoodItems then return end
			local first = plot:FindFirstChild("FoodDropStart", true)
			local last = plot:FindFirstChild("FoodDropEnd", true)
			local bin = plot:FindFirstChild("FoodBinTarget", true)
			if not first or not last or not bin or workspace:GetServerTimeNow() - time >= Config.FoodTravelSeconds then return end
			local part = Instance.new("Model")
			part.Name = "CosmeticFood"
			-- Builds one anchored, non-colliding part of a cosmetic treat.
			local function piece(size, position, ball, color)
				local p = Instance.new("Part")
				p.Size, p.Position = size, position
				p.Color = color or Color3.fromRGB(236, 206, 151)
				p.Anchored = true
				p.CanCollide, p.CanTouch, p.CanQuery = false, false, false
				if ball then p.Shape = Enum.PartType.Ball end
				p.Parent = part
				return p
			end
			-- Alternating bone treats and clusters of round kibble; no physics.
			local root = piece(Vector3.new(1.5, 0.45, 0.5), Vector3.zero, false)
			part.PrimaryPart = root
			for _, x in { -0.8, 0.8 } do
				for _, z in { -0.22, 0.22 } do
					piece(Vector3.one * 0.65, Vector3.new(x, 0, z), true, if sequence % 2 == 0 then Color3.fromRGB(175, 108, 51) else nil)
				end
			end
			part:PivotTo(first.CFrame)
			part.Parent = workspace
			local character = game.Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and (root.Position-first.Position).Magnitude < 45 then Audio.Play("Drop") end
			table.insert(entry.Drops, { Part = part, From = first.CFrame, To = last.CFrame, Bin = bin.CFrame, Started = time })
		end
		entry.Clear = clear
		plot:GetAttributeChangedSignal("OwnerUserId"):Connect(clear)
		plot:GetAttributeChangedSignal("FoodDropSequence"):Connect(spawn)
		-- Refreshes cached machine parts after construction, upgrades or delayed replication.
		local function refreshMachine()
			entry.Stripes = {}
			for _, object in plot:GetDescendants() do
				if object.Name == "BeltStripe" then table.insert(entry.Stripes, { Part = object, Frame = object:GetAttribute("RestFrame") or object.CFrame }) end
			end
			entry.Fill = plot:FindFirstChild("BinFill", true)
			entry.Label = plot:FindFirstChild("FoodReadyLabel", true)
			entry.Button = plot:FindFirstChild("GenerateButton", true)
			entry.ButtonFrame = entry.Button and (entry.Button:GetAttribute("RestFrame") or entry.Button.CFrame)
		end
		local queued = false
		-- Re-scan after replacement/removal settles so caches cannot retain the old kennel.
		local function queueRefresh()
			if queued then return end
			queued = true
			task.defer(function() queued = false; refreshMachine() end)
		end
		plot.DescendantAdded:Connect(queueRefresh)
		plot.DescendantRemoving:Connect(queueRefresh)
		refreshMachine()
		spawn()
	end
	plots.ChildAdded:Connect(watch)
	for _, plot in plots:GetChildren() do watch(plot) end
	RunService.RenderStepped:Connect(function()
		local now = workspace:GetServerTimeNow()
		for plot, entry in entries do
			if not plot.Parent then entry.Clear(); entries[plot] = nil; continue end
			local ready = plot:GetAttribute("PendingFood") or 0
			local label = entry.Label
			if label and label.Parent then label.Text = "FOOD READY: " .. ready .. "\n✋ Collect into storage" end
			if entry.Fill and entry.Fill.Parent then
				entry.Fill.Transparency = if ready == 0 then 1 else 0
				local height = 0.2 + 2 * ready / (plot:GetAttribute("FoodBinCapacity") or Config.FoodBinCapacity)
				entry.Fill.Size = Vector3.new(8, height, 6)
				local rest = entry.Fill:GetAttribute("RestFrame")
				if rest then entry.Fill.CFrame = rest * CFrame.new(0, (height - 0.2) / 2, 0) end
			end
			for _, stripe in entry.Stripes or {} do
				if stripe.Part.Parent then stripe.Part.CFrame = stripe.Frame * CFrame.new(0, 0, (now * Config.ConveyorSpeed) % 2) end
			end
			if entry.Button and entry.Button.Parent then
				local pulse = math.clamp(1 - (now - (plot:GetAttribute("ManualFoodAt") or 0)) / 0.3, 0, 1)
				entry.Button.CFrame = entry.ButtonFrame * CFrame.new(0, -0.35 * pulse, 0)
				entry.Button.Color = Color3.fromRGB(110, 220, 142):Lerp(Color3.new(1, 1, 1), pulse)
			end
			for index = #entry.Drops, 1, -1 do
				local drop = entry.Drops[index]
				local progress = math.clamp((now - drop.Started) / Config.FoodTravelSeconds, 0, 1)
				if progress >= 1 then
					drop.Part:Destroy()
					table.remove(entry.Drops, index)
				else
					-- Fall from nozzle, ride the belt, then tumble into the pending bin.
					local belt = CFrame.new(drop.From.X, drop.To.Y, drop.From.Z) * drop.From.Rotation
					local age = math.max(0, now - drop.Started)
					local beltSeconds = Config.ConveyorLength / Config.ConveyorSpeed
					if age < Config.FoodDropSeconds then
						drop.Part:PivotTo(drop.From:Lerp(belt, age / Config.FoodDropSeconds))
					elseif age < Config.FoodDropSeconds + beltSeconds then
						drop.Part:PivotTo(belt:Lerp(drop.To, (age - Config.FoodDropSeconds) / beltSeconds))
					else
						local fall = (age - Config.FoodDropSeconds - beltSeconds) / Config.FoodDropSeconds
						drop.Part:PivotTo(drop.To:Lerp(drop.Bin, fall) * CFrame.Angles(fall * math.pi, 0, 0))
					end
				end
			end
		end
	end)
end

return FoodController
