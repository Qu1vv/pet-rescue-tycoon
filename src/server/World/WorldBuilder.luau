local Config = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Build = require(script.Parent.Parent.Common.BuildUtil)
local PlotBuilder = require(script.Parent.PlotBuilder)
local BiomeBuilder = require(script.Parent.BiomeBuilder)
local LegacyWorldCleanup = require(script.Parent.LegacyWorldCleanup)
local WorldBuilder = {}
local colors = {
	Color3.fromRGB(83, 174, 157), Color3.fromRGB(109, 162, 219), Color3.fromRGB(176, 137, 202),
	Color3.fromRGB(224, 148, 161), Color3.fromRGB(228, 171, 90), Color3.fromRGB(159, 180, 101),
}

-- Generates the edit-preview replacement, six inward-facing plots, central spawn, routes and biome pet slots.
function WorldBuilder.Build()
	local preview = workspace:FindFirstChild("ShelterPreview")
	if preview then preview:Destroy() end -- baked edit-mode geometry is replaced by authoritative runtime records
    LegacyWorldCleanup.Run(workspace)
	assert(not workspace:FindFirstChild("ShelterWorld"), "ShelterWorld already exists; restart Play after syncing code")
	local world = Instance.new("Model")
	world.Name = "ShelterWorld"
	world:SetAttribute("AvailablePlots", Config.PlotCount)
	world:SetAttribute("AvailablePetCount", 0)
	Build.Part(world, "Ground", Vector3.new(Config.MapSize, 2, Config.MapSize), CFrame.new(0, 0, 0), Color3.fromRGB(112, 151, 101), Enum.Material.Grass)
	Build.Part(world, "RescuePark", Vector3.new(120, 0.25, 120), CFrame.new(0, 1.125, 0), Color3.fromRGB(178, 196, 142), Enum.Material.Grass)
	Build.Part(world, "Plaza", Vector3.new(24, 0.2, 24), CFrame.new(0, 1.3, 0), Color3.fromRGB(234, 220, 189))
	local spawn = Build.Spawn(world, "PlazaSpawn", CFrame.new(0, 2, 0), true)
	local welcome = Build.Part(world, "WelcomeSign", Vector3.new(14, 5, 1), CFrame.new(0, 6, 13), colors[1])
	Build.Label(welcome, "PET RESCUE PARK\nClaim a shelter · Rescue a friend", 120)
	local plotsFolder = Instance.new("Folder")
	plotsFolder.Name = "Plots"
	plotsFolder.Parent = world
	local pets = Instance.new("Folder")
	pets.Name = "Pets"
	pets.Parent = world
	local plots = {}
	for index = 1, Config.PlotCount do
		local angle = (index - 1) * math.pi * 2 / Config.PlotCount
		local direction = Vector3.new(math.sin(angle), 0, math.cos(angle))
		local center = direction * Config.PlotRadius + Vector3.new(0, 1, 0)
		local frame = CFrame.lookAt(center, Vector3.new(0, 1, 0))
		plots[index] = PlotBuilder.CreatePlot(plotsFolder, index, frame, colors[index])
		local pathLength = Config.PlotRadius - Config.PlotSize / 2 - 52
		local pathCenter = direction * (52 + pathLength / 2) + Vector3.new(0, 1.12, 0)
		Build.Part(world, "Path", Vector3.new(16, 0.2, pathLength + 4), CFrame.lookAt(pathCenter, pathCenter - direction), Color3.fromRGB(224, 212, 182))
		local treeAngle = angle + math.pi / 6
		for _, radius in { 90, 145, 310 } do
			local pos = Vector3.new(math.sin(treeAngle) * radius, 1, math.cos(treeAngle) * radius)
			Build.Part(world, "TreeTrunk", Vector3.new(3, 12, 3), CFrame.new(pos + Vector3.new(0, 6, 0)), Color3.fromRGB(122, 91, 65), Enum.Material.Wood)
			local crown = Build.Part(world, "TreeCrown", Vector3.new(16, 17, 16), CFrame.new(pos + Vector3.new(0, 17, 0)), colors[6], Enum.Material.Grass)
			crown.Shape = Enum.PartType.Ball
		end
		local benchFrame = CFrame.new(math.sin(treeAngle) * 64, 1, math.cos(treeAngle) * 64) * CFrame.Angles(0, treeAngle, 0)
		Build.Part(world, "Bench", Vector3.new(10, 1, 3), benchFrame * CFrame.new(0, 2, 0), Color3.fromRGB(172, 128, 86))
		Build.Part(world, "BenchBack", Vector3.new(10, 3, 0.5), benchFrame * CFrame.new(0, 3.5, 1.5), Color3.fromRGB(172, 128, 86))
	end
	for _, x in { -384, 384 } do
		Build.Part(world, "Boundary", Vector3.new(3, 9, 768), CFrame.new(x, 5.5, 0), colors[6], Enum.Material.Grass)
	end
	for _, z in { -384, 384 } do
		Build.Part(world, "Boundary", Vector3.new(768, 9, 3), CFrame.new(0, 5.5, z), colors[6], Enum.Material.Grass)
	end
	local spawnPoints, spawnZones, spawnDefinitions = BiomeBuilder.Build(world)
	world.Parent = workspace
	return { Model = world, Plots = plots, Pets = pets, Spawn = spawn, SpawnPoints = spawnPoints, SpawnZones = spawnZones, SpawnDefinitions = spawnDefinitions }
end

return WorldBuilder
