local Biomes = require(game:GetService("ReplicatedStorage").Shared.Config.Biomes)
local Build = require(script.Parent.Parent.Common.BuildUtil)
local BiomeBuilder = {}

-- Adds a small pair of readable park benches without introducing imported assets.
local function bench(parent, frame, color)
 Build.Part(parent,"BenchSeat",Vector3.new(8,0.7,2.4),frame*CFrame.new(0,1.8,0),color,Enum.Material.Wood)
 Build.Part(parent,"BenchBack",Vector3.new(8,2.3,0.45),frame*CFrame.new(0,3,1.15),color,Enum.Material.Wood)
end

-- Adds low-cost orchard trees whose fruit color gives the biome a distinct silhouette.
local function orchardTree(parent, position)
 Build.Part(parent,"OrchardTrunk",Vector3.new(2.2,8,2.2),CFrame.new(position+Vector3.new(0,4,0)),Color3.fromRGB(125,86,60),Enum.Material.Wood)
 local crown=Build.Part(parent,"OrchardCrown",Vector3.new(12,10,12),CFrame.new(position+Vector3.new(0,11,0)),Color3.fromRGB(133,178,104),Enum.Material.Grass)
 crown.Shape=Enum.PartType.Ball
 for _, offset in {Vector3.new(-2,11,-4),Vector3.new(3,13,-3),Vector3.new(1,9,4)} do
  local fruit=Build.Part(parent,"OrchardFruit",Vector3.one*1.2,CFrame.new(position+offset),Color3.fromRGB(230,126,112))
  fruit.Shape=Enum.PartType.Ball; fruit.CanCollide=false; fruit.CanTouch=false
 end
end
-- Builds readable habitats and separated spawn slots from shared configuration, with clear walking routes.
function BiomeBuilder.Build(world)
 local points, zones, slots = {}, {}, {}
 local folder = Instance.new("Folder")
 folder.Name, folder.Parent = "Biomes", world
 for _, id in { "DogPark", "Forest", "Orchard" } do
  local biome = Biomes[id]
  local center = Vector3.new(table.unpack(biome.Center))
  local model = Instance.new("Model")
  model.Name, model.Parent = id, folder
  local color = Color3.fromRGB(table.unpack(biome.Color))
  Build.Part(model, "HabitatGround", Vector3.new(biome.Radius*2, 0.2, biome.Radius*2), CFrame.new(center), color, Enum.Material.Grass)
  for i = 2, #biome.Route do
   local a, b = Vector3.new(table.unpack(biome.Route[i-1])), Vector3.new(table.unpack(biome.Route[i]))
   Build.Part(model, "Trail", Vector3.new(12,0.16,(b-a).Magnitude+2), CFrame.lookAt((a+b)/2,b), Color3.fromRGB(216,200,166))
  end
  local board = Build.Part(model, "Welcome", Vector3.new(18,5,0.5), CFrame.new(center+Vector3.new(0,5,biome.Radius-3)), color)
  Build.Label(board, biome.Name .. "\nExplore · Rescue · Bring home", 100)
  local direction = center.Unit
  local signPosition = direction*34+Vector3.new(0,5,0)
  local sign = Build.Part(world, "TrailSign", Vector3.new(14,3,0.5), CFrame.lookAt(signPosition, Vector3.new(0,5,0)), color)
  Build.Label(sign, biome.Name .. " →", 85)
  -- Props stay at the perimeter, outside every reserved spawn clearing and main path.
  for _, offset in {Vector3.new(-36,0,-34),Vector3.new(36,0,-34),Vector3.new(-36,0,34),Vector3.new(36,0,34)} do
   local position = center+offset
   Build.Part(model,"TreeTrunk",Vector3.new(2.5,10,2.5),CFrame.new(position+Vector3.new(0,5,0)),Color3.fromRGB(126,91,65),Enum.Material.Wood)
   local crown = Build.Part(model,"TreeCanopy",Vector3.new(14,15,14),CFrame.new(position+Vector3.new(0,14,0)),if id=="Forest" then Color3.fromRGB(58,111,78) else Color3.fromRGB(136,183,99))
   crown.Shape = Enum.PartType.Ball
  end
  if id == "DogPark" then
   for _, z in {-39,39} do
   Build.Part(model,"ParkFence",Vector3.new(60,1,1),CFrame.new(center+Vector3.new(0,3,z)),Color3.fromRGB(230,216,184))
  end
   for _, x in {-39,39} do
    Build.Part(model,"ParkFence",Vector3.new(1,1,78),CFrame.new(center+Vector3.new(x,3,0)),Color3.fromRGB(230,216,184))
   end
   for _, x in {-12,12} do
    Build.Part(model,"AgilityPost",Vector3.new(1,4,1),CFrame.new(center+Vector3.new(x,2,0)),Color3.fromRGB(245,190,86))
   end
   Build.Part(model,"AgilityRail",Vector3.new(24,0.5,0.5),CFrame.new(center+Vector3.new(0,1,0)),Color3.fromRGB(245,190,86))
   Build.Part(model,"WaterBowl",Vector3.new(5,0.5,5),CFrame.new(center+Vector3.new(-34,0.4,0)),Color3.fromRGB(113,193,220))
   bench(model,CFrame.new(center+Vector3.new(30,0,0))*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(176,126,82))
   for _, z in {-12,0,12} do
   local pad=Build.Part(model,"AgilityStep",Vector3.new(5,0.5,5),CFrame.new(center+Vector3.new(31,0.35,z)),Color3.fromRGB(237,175,83))
    pad.CFrame *= CFrame.Angles(0,0,math.pi/2)
    pad.Shape=Enum.PartType.Cylinder; pad.CanCollide=false
   end
  elseif id == "Forest" then
   Build.Part(model,"FallenLog",Vector3.new(17,2,3),CFrame.new(center+Vector3.new(0,1,0)),Color3.fromRGB(131,97,64),Enum.Material.Wood)
   for _, x in {-32,32} do
    local bush=Build.Part(model,"BerryBush",Vector3.new(5,4,5),CFrame.new(center+Vector3.new(x,2,0)),Color3.fromRGB(80,130,93))
    bush.Shape=Enum.PartType.Ball
   end
   for _, offset in {Vector3.new(-14,0,-34),Vector3.new(10,0,-36),Vector3.new(34,0,24)} do
    local stone=Build.Part(model,"ForestStone",Vector3.new(5,1.2,4),CFrame.new(center+offset+Vector3.new(0,0.55,0)),Color3.fromRGB(119,130,117))
    stone.Shape=Enum.PartType.Ball
   end
   for _, offset in {Vector3.new(-35,0,-10),Vector3.new(34,0,-12)} do
    Build.Part(model,"ForestStump",Vector3.new(3.5,2.2,3.5),CFrame.new(center+offset+Vector3.new(0,1.1,0)),Color3.fromRGB(132,95,63),Enum.Material.Wood)
   end
  else
   Build.Part(model,"ReadingBench",Vector3.new(14,1,4),CFrame.new(center+Vector3.new(0,2,0)),Color3.fromRGB(203,157,119))
   for _, offset in {Vector3.new(-34,0,-20),Vector3.new(-34,0,20),Vector3.new(34,0,-20),Vector3.new(34,0,20)} do orchardTree(model,center+offset) end
   for _, x in {-18,18} do
    Build.Part(model,"FlowerBed",Vector3.new(10,0.45,4),CFrame.new(center+Vector3.new(x,0.3,34)),Color3.fromRGB(237,181,191),Enum.Material.Grass)
   end
  end
  for i=1,math.min(biome.MaxActive,#biome.Points) do
   local offset=biome.Points[i]
   local position=center+Vector3.new(offset[1],0.15,offset[2])
   local clearing=Build.Part(model,"SpawnClearing",Vector3.new(0.12,7,7),CFrame.new(position-Vector3.new(0,0.02,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(205,218,170),Enum.Material.Grass)
   clearing.Shape=Enum.PartType.Cylinder; clearing.Transparency=0.3; clearing.CanCollide=false; clearing.CanTouch=false; clearing.CanQuery=false
   table.insert(points,CFrame.lookAt(position,Vector3.new(center.X,position.Y,center.Z)))
   table.insert(zones,id)
   table.insert(slots,{Biome=id,RespawnSeconds=biome.RespawnSeconds,PlayerClearance=biome.PlayerClearance})
  end
 end
 return points,zones,slots
end
return BiomeBuilder
