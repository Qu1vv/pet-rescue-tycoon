-- One bounded job per shelter; anchored waypoints and a visual leash, no NPC physics.
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Build = require(script.Parent.Parent.Common.BuildUtil)
local Adoption = {}
local jobs = {}
local started = false

-- Builds a lightweight anchored adopter and returns its hand attachment and leg animation data.
local function visitor(parent, frame)
	local model = Instance.new("Model")
	model.Name = "Adopter"
	local root = Build.Part(model, "Root", Vector3.one * 0.2, frame)
	root.Transparency = 1
	model.PrimaryPart = root
	Build.Part(model, "Coat", Vector3.new(2, 2.3, 1), frame * CFrame.new(0, 3, 0), Color3.fromRGB(123, 164, 210))
	local head = Build.Part(model, "Head", Vector3.one * 1.5, frame * CFrame.new(0, 4.9, 0), Color3.fromRGB(216, 174, 133))
	head.Shape = Enum.PartType.Ball
	for _, x in { -0.38, 0.38 } do
		local eye = Build.Part(model, "Eye", Vector3.one * 0.16, frame * CFrame.new(x, 5, -0.7), Color3.fromRGB(42, 42, 50))
		eye.Shape = Enum.PartType.Ball
	end
	local hand
	local legs = {}
	for _, x in { -1.3, 1.3 } do
		hand = Build.Part(model, "Arm", Vector3.new(0.55, 2.3, 0.7), frame * CFrame.new(x, 2.9, 0), Color3.fromRGB(216, 174, 133))
		local leg = Build.Part(model, "Leg", Vector3.new(0.7, 1.8, 0.9), frame * CFrame.new(x / 2, 0.9, 0), Color3.fromRGB(57, 67, 86))
		table.insert(legs, { Part = leg, Offset = CFrame.new(x / 2, 0.9, 0), Sign = math.sign(x) })
	end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, -1, 0)
	attachment.Parent = hand
	Build.FloatingLabel(head, "A loving home awaits ♥", 65)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then part.CanCollide, part.CanTouch, part.CanQuery = false, false, false end
	end
	model.Parent = parent
	return model, attachment, legs
end

-- Removes the job before invoking exactly one completion/cancellation callback and destroys its NPC.
local function finish(player, success)
	local job = jobs[player]
	if not job then return end
	jobs[player] = nil -- remove before callbacks so completion cannot be repeated
	job.Model:Destroy() -- owns Beam and hand attachment
	local ok, err = pcall(if success then job.Complete else job.Cancel)
	if not ok then warn("Adoption callback failed: " .. tostring(err)); if success then pcall(job.Cancel) end end
end

-- Cancels this player's active adoption and invokes its restoration callback without paying out.
function Adoption.Cancel(player) finish(player, false) end

-- Creates one adopter and a fixed entrance/bed/exit route; returns false if the player already has a job.
function Adoption.StartJob(player, pet, plot, complete, cancel)
	if jobs[player] then return false end
	local start = plot.Frame * CFrame.new(0, 0.8, -76)
	local model, hand, legs = visitor(plot.Model, start)
	local bed = plot.Slots[pet.Slot].Position
	-- Converts an adoption waypoint from plot-local coordinates to a ground-level world position.
	local function point(x, z) return (plot.Frame * CFrame.new(x, 0.8, z)).Position end
	-- Traverse the open entrance and central aisle, then approach the chosen bed.
	local localBed = plot.Frame:PointToObjectSpace(bed)
	local route = { point(0, -50), point(0, 5), point(5, 14), point(5, localBed.Z - 8),
		point(localBed.X, localBed.Z - 8), point(localBed.X, localBed.Z - 4),
		point(localBed.X, localBed.Z - 8), point(5, localBed.Z - 8), point(5, 14), point(0, 5), point(0, -50), point(0, -82) }
	jobs[player] = { Model = model, Hand = hand, Legs = legs, Pet = pet, Route = route, Index = 1,
		Started = os.clock(), Complete = complete, Cancel = cancel, Position = start.Position }
	return true
end

-- Starts the shared movement loop once; attaches leashes and completes or times out adoption jobs.
function Adoption.Start()
	if started then return end
	started = true
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < Config.FollowInterval then return end
		local step = math.min(elapsed, 0.2)
		elapsed = 0
		for player, job in jobs do
			if not job.Model.Parent or not job.Pet.Model.Parent or os.clock() - job.Started > Config.AdoptionTimeout then
				finish(player, false); continue
			end
			local destination = job.Route[job.Index]
			local delta = destination - job.Position
			local distance = delta.Magnitude
			local direction = if distance > 0.001 then delta.Unit else job.Model:GetPivot().LookVector
			job.Position += direction * math.min(distance, Config.AdopterSpeed * step)
			job.Model:PivotTo(CFrame.lookAt(job.Position, job.Position + direction))
			for _, leg in job.Legs do
				leg.Part.CFrame = job.Model:GetPivot() * leg.Offset * CFrame.Angles(math.sin(os.clock() * 10) * 0.3 * leg.Sign, 0, 0)
			end
			if job.Leashed then
				local petPosition = job.Position - direction * 3
				local current = job.Pet.Model:GetPivot().Position
				local movement = petPosition - current
				local nextPosition = current + movement * math.min(1, step * 10)
				job.Pet.Model:PivotTo(CFrame.lookAt(nextPosition, nextPosition + direction))
			end
			if distance <= Config.AdopterSpeed * step then
				if job.Index == 5 then
					local collar = job.Pet.Model:FindFirstChild("LeashAttachment", true)
					if not collar then finish(player, false); continue end
					local beam = Instance.new("Beam")
					beam.Name = "AdoptionLeash"
					beam.Attachment0, beam.Attachment1 = job.Hand, collar
					beam.Width0, beam.Width1 = 0.07, 0.07
					beam.Color = ColorSequence.new(Color3.fromRGB(243, 180, 105))
					beam.FaceCamera = true
					beam.Parent = job.Model
					job.Leashed = true
				end
				job.Index += 1
				if job.Index > #job.Route then finish(player, true) end
			end
		end
	end)
end

return Adoption
