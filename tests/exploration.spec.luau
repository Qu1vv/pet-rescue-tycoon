local Biomes=require("../src/shared/Config/Biomes")
local Catalog=require("../src/shared/Pets/PetCatalog")
local Profiles=require("../src/shared/Pets/MovementProfiles")
local Animations=require("../src/shared/Pets/AnimationProfiles")
local Motion=require("../src/shared/Pets/AnimalMotion")
local Rewards=require("../src/shared/Config/Rewards")
local State=require("../src/shared/Config/RewardState")
local Data=require("../src/server/Persistence/ProfileData")
local Config=require("../src/shared/Config/GameConfig")
local checks=0
local function check(value,message) checks+=1; assert(value,message) end
local population=0
for id,biome in Biomes do
 check(biome.Id==id and biome.MaxActive<=#biome.Points and biome.RespawnSeconds>0,"Biome capacity and timing")
 population+=biome.MaxActive
 for i,p in biome.Points do
  assert(math.abs(p[1])<biome.Radius-6 and math.abs(p[2])<biome.Radius-6,"Point in bounds")
  for j,q in biome.Points do if i~=j then assert((p[1]-q[1])^2+(p[2]-q[2])^2>=14^2,"Separated clearings") end end
 end
 for _=1,10000 do
  local def,variant=Catalog.Roll(math.random,biome.RarityWeights,id,biome.Species)
  assert(biome.Species[def.Species] and variant.Rarity and def.Habitat==id,"Biome-eligible spawn")
 end
 check(true,"Ten thousand biome rolls: "..id)
end
check(population==18,"Bounded configured world population")
local bunny=Catalog.Get("WoodlandRabbit","Chestnut")
check(bunny.Species=="Bunny" and bunny.Habitat=="Forest","New rabbit uses shared catalog")
for _,species in {"Dog","Bunny","Cat","Hamster"} do
 local p=Profiles.Get(species)
 local speed,far=0,0
 for _=1,1000 do
  local nextSpeed,nextFar,recover=Motion.Step(speed,25,20,far,0.05,p)
  assert(nextSpeed<=p.CatchupSpeed and math.abs(nextSpeed-speed)<=p.Acceleration*0.05+0.001 and not recover,"Bounded acceleration without ordinary teleport")
  speed,far=nextSpeed,nextFar
 end
 local stopped=Motion.Step(speed,0,4,0,0.05,p)
 check(stopped==0,"No destination overshoot: "..species)
 far=0
 for _=1,59 do local _,n,r=Motion.Step(0,100,100,far,0.05,p); far=n; assert(not r) end
 local _,_,recovered=Motion.Step(0,100,100,far,0.1,p)
 check(recovered,"Sustained extreme-distance recovery")
 local _,reset=Motion.Step(0,1,3,far,0.05,p)
 check(reset==0,"Normal distance cancels recovery timer")
end
check(Animations.Get("Bunny").States.Walk.Bob>Animations.Get("Dog").States.Walk.Bob,"Rabbit hop profile")
local state=State.New(100)
local quests=State.Active(100,Rewards)
check(#quests==3,"Small daily rotation")
local q=quests[1]
check(not State.Eligible(state,"Daily",q.Id,0,Rewards),"Incomplete quest cannot pay")
State.Record(state,q.Event,999,q.Detail,Rewards)
check(state.Progress[q.Id]==q.Target,"Progress is bounded")
check(State.Eligible(state,"Daily",q.Id,0,Rewards)==q,"Completed quest eligible")
state.Claimed[q.Id]=true
check(not State.Eligible(state,"Daily",q.Id,0,Rewards),"Duplicate daily claim blocked")
check(not State.Eligible(state,"Collection","Collection5",4,Rewards),"Collection threshold enforced")
check(State.Eligible(state,"Collection","Collection5",5,Rewards).Cash==35,"Collection cash server configuration")
state.Milestones.Collection5=true
check(not State.Eligible(state,"Collection","Collection5",24,Rewards),"Duplicate collection reward blocked")
State.Record(state,"Visit",1,"Forest",Rewards)
check(state.GuidedStep==1,"Guide respects event detail")
State.Record(state,"Visit",1,"DogPark",Rewards)
check(state.GuidedStep==2,"Guide advances on expected event")
check(not State.Reset(state,100*86400+86399,Rewards),"No early daily reset")
check(State.Reset(state,101*86400,Rewards) and next(state.Progress)==nil and next(state.Claimed)==nil,"Exact UTC daily boundary")
check(state.Milestones.Collection5 and state.GuidedStep==2,"Lifetime rewards and guide survive reset")
local copy=State.Validate(state,Rewards); copy.Milestones.Collection5=nil
check(state.Milestones.Collection5,"Reward snapshots independent")
local bad=State.New(1); bad.Progress.Rescue=0/0
check(not pcall(State.Validate,bad,Rewards),"Malformed quest saves rejected")
local legacy=Data.New(Config); legacy.Version=2; legacy.Rewards=nil
local migrated=Data.Validate(legacy,Config,Catalog)
check(migrated.Version==5 and migrated.Rewards.GuidedStep==1,"Schema 2 gets fresh rewards without erasing shelter")
migrated.Rewards=state
check(Data.Validate(migrated,Config,Catalog).Rewards.Milestones.Collection5,"Quest and reward persistence round-trip")
print("PASS: "..checks.." exploration/reward checks plus 30,000 biome rolls")
