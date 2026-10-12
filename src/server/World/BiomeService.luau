local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local Biomes = require(game:GetService("ReplicatedStorage").Shared.Config.Biomes)
local Validation = require(script.Parent.Parent.Common.Validation)
local Events = require(script.Parent.Parent.Common.GameplayEvents)
local BiomeService = {}
local started = false
-- Uses one slow spatial update for biome entry; quest progress changes only on entry events.
function BiomeService.Start()
 if started then return end
 started = true
 local elapsed = 0
 Run.Heartbeat:Connect(function(dt)
  elapsed += dt
  if elapsed < 0.5 then return end
  elapsed = 0
  for _, player in Players:GetPlayers() do
   local root = Validation.Root(player)
   if not root or player:GetAttribute("ProfileReady") ~= true then continue end
   local id = ""
   for key, biome in Biomes do
    local center = Vector3.new(table.unpack(biome.Center))
    local delta = root.Position-center
    if math.abs(delta.X) <= biome.Radius and math.abs(delta.Z) <= biome.Radius and math.abs(delta.Y)<30 then id=key; break end
   end
   if player:GetAttribute("BiomeId") ~= id then
    player:SetAttribute("BiomeId", id)
    if id ~= "" then Events.Emit(player,"Visit",1,id) end
   end
  end
 end)
end
return BiomeService
