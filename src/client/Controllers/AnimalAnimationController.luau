local Run = game:GetService("RunService")
local Player = game:GetService("Players").LocalPlayer
local Animations = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Pets"):WaitForChild("AnimationProfiles"))
local Controller = {}

-- Stops the active approved rig track and clears its animator binding.
local function stopTrack(entry)
	if entry.Track then entry.Track:Stop(0.12); entry.Track:Destroy() end
	entry.Track, entry.TrackState = nil, nil
end

-- Finds an Animator in a reviewed rig without creating per-pet update connections.
local function findAnimator(model)
	for _, item in model:GetDescendants() do
		if item:IsA("Animator") then return item end
	end
	return nil
end

-- Changes a rig track only when state or rig changes; missing approved IDs use procedural fallback.
local function playRig(entry, model, state, settings)
	if not settings or type(settings.AssetId) ~= "string" or not string.match(settings.AssetId, "^rbxassetid://%d+$") then
		if entry.Track then stopTrack(entry) end
		return
	end
	local rigKey = model:GetAttribute("ModelKey") or ""
	if entry.RigKey ~= rigKey then
		stopTrack(entry)
		entry.RigKey, entry.Animator = rigKey, findAnimator(model)
	end
	local animator = entry.Animator
	if not animator then if entry.Track then stopTrack(entry) end; return end
	if entry.Animator == animator and entry.TrackState == state and entry.Track then return end
	stopTrack(entry)
	local animation = Instance.new("Animation")
	animation.AnimationId = settings.AssetId
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	animation:Destroy()
	if not ok then return end
	entry.Animator, entry.TrackState, entry.Track = animator, state, track
	track.Looped = state ~= "Eat" and state ~= "Happy"
	track:Play(0.12)
end

-- Animates all nearby pets through one culled loop using approved rig tracks or procedural fallbacks.
function Controller.Start()
	local pets = workspace:WaitForChild("ShelterWorld"):WaitForChild("Pets")
	local entries = {}
	-- Registers one replicated pet without allocating its own frame connection.
	local function watch(model)
		entries[model] = {}
	end
	pets.ChildAdded:Connect(watch)
	pets.ChildRemoved:Connect(function(model)
		local entry = entries[model]
		if entry then stopTrack(entry) end
		entries[model] = nil
	end)
	for _, model in pets:GetChildren() do watch(model) end
	local elapsed = 0
	Run.RenderStepped:Connect(function(dt)
		elapsed += dt
		if elapsed < 1 / 30 then return end
		local step = math.min(elapsed, 0.1)
		elapsed = 0
		local now = workspace:GetServerTimeNow()
		local camera = workspace.CurrentCamera
		for model, entry in entries do
			if not model.PrimaryPart then continue end
			local target = model:GetPivot()
			local visual = model:FindFirstChild("Visuals")
			if camera and (target.Position - camera.CFrame.Position).Magnitude > 140 then
				if visual and entry.Rest then visual:PivotTo(target * entry.Rest) end
				entry.Frame = target
				if entry.Track then stopTrack(entry) end
				continue
			end
			local state = model:GetAttribute("State")
			local animation = if state == "Following" then model:GetAttribute("MovementState") or "Idle"
				elseif state == "Adopting" then "Adoption" else "Idle"
			local fed = now - (model:GetAttribute("LastFedAt") or -100)
			local cared = now - (model:GetAttribute("LastCareAt") or -100)
			local trusted = now - (model:GetAttribute("LastTrustAt") or -100)
			if fed < 1.1 then animation = "Eat" elseif fed < 2.2 or cared < 1.7 or trusted < 1.2 then animation = "Happy" end
			local profile = Animations.Get(model:GetAttribute("AnimationProfile") or model:GetAttribute("Species"))
			local settings = profile.States[animation] or profile.States.Idle
			playRig(entry, model, animation, settings)
			if not visual then continue end
			if entry.Visual ~= visual then
				entry.Visual = visual
				entry.Rest = model:GetPivot():ToObjectSpace(visual:GetPivot())
				entry.Frame = model:GetPivot()
				entry.Blend = 0
			end
			entry.Blend += (settings.Bob - entry.Blend) * (1 - math.exp(-12 * step))
			local alpha = 1 - math.exp(-22 * step)
			entry.Frame = if (target.Position - entry.Frame.Position).Magnitude > 40 or state ~= "Following"
				then target else entry.Frame:Lerp(target, alpha)
			local bob = if Player:GetAttribute("ReduceMotion") then 0 else math.abs(math.sin(now * settings.Rate)) * entry.Blend
			local turn = if animation == "Idle" then math.sin(now * 0.8 + target.X) * 0.05 else 0
			visual:PivotTo(entry.Frame * CFrame.new(0, bob, 0)
				* CFrame.Angles(math.rad(settings.Pitch or 0), turn, 0) * entry.Rest)
		end
	end)
end

return Controller
