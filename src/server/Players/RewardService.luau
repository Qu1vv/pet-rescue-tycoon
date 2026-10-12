local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local Config=require(Shared.Config.Rewards)
local State=require(Shared.Config.RewardState)
local Events=require(script.Parent.Parent.Common.GameplayEvents)
local Collection=require(script.Parent.Parent.Pets.CollectionService)
local Rewards={}
local data,attempts={},{}
local shelter,feedback
-- Counts permanent discoveries independently of currently owned pets.
local function count(player)
 local n=0; for _ in Collection.Export(player) do n+=1 end; return n
end
-- Publishes one compact folder per objective, containing display progress but no client authority.
local function publish(player)
 local state=data[player]; if not state then return end
 local folder=player:FindFirstChild("RescueGoals")
 if not folder then folder=Instance.new("Folder"); folder.Name="RescueGoals"; folder.Parent=player end
 local valid={}
 -- Creates or refreshes one replicated objective row from authoritative reward state.
 local function item(id,title,current,target,cash,claimed,kind)
  valid[id]=true
  local row=folder:FindFirstChild(id) or Instance.new("Folder")
  row.Name=id
  for key,value in {Title=title,Progress=current,Target=target,Cash=cash,Claimed=claimed,Kind=kind} do row:SetAttribute(key,value) end
  row.Parent=folder
 end
 for _,q in State.Active(state.Day,Config) do item(q.Id,q.Title,state.Progress[q.Id] or 0,q.Target,q.Cash,state.Claimed[q.Id]==true,"Daily") end
 local discovered=count(player)
 for _,r in Config.Milestones do item(r.Id,"Discover "..r.Target.." pet variants",math.min(discovered,r.Target),r.Target,r.Cash,state.Milestones[r.Id]==true,"Collection") end
 for _,row in folder:GetChildren() do if not valid[row.Name] then row:Destroy() end end
 folder:SetAttribute("ResetsAt",(state.Day+1)*Config.ResetSeconds)
 local step=Config.Guided[state.GuidedStep]
 player:SetAttribute("GuidedStep",state.GuidedStep)
 player:SetAttribute("GuidedObjective",if step then step.Title else "")
end
-- Loads migrated progress before gameplay is enabled and applies a server-clock daily reset.
function Rewards.Load(player,saved)
 data[player]=State.Validate(saved,Config)
 State.Reset(data[player],os.time(),Config)
 publish(player)
end
-- Returns an independent save snapshot using the existing profile write schedule.
function Rewards.Export(player) return State.Validate(data[player] or State.New(),Config) end
-- Releases player state only after the profile's final snapshot.
function Rewards.Cleanup(player) data[player],attempts[player]=nil,nil end
-- Validates ID, period, eligibility and rate limit, then atomically marks a reward and credits cash.
function Rewards.Claim(player,kind,id)
 if player.Parent~=Players or player:GetAttribute("ProfileReady")~=true or not data[player]
  or type(kind)~="string" or type(id)~="string" or #id>40 then return false end
 local now=os.clock()
 if attempts[player] and now-attempts[player]<0.5 then return false end
 attempts[player]=now
 local state=data[player]
 State.Reset(state,os.time(),Config)
 local reward=State.Eligible(state,kind,id,count(player),Config)
 if not reward then publish(player); return false end
 local ok=shelter.CommitReward(player,reward.Cash,function()
  (if kind=="Daily" then state.Claimed else state.Milestones)[id]=true
 end)
 if ok then publish(player); feedback:FireClient(player,if kind=="Collection" then "CollectionReward" else "RewardClaimed",reward.Cash) end
 return ok
end
-- Completes optional first-session guidance without awarding cash or advancing daily goals.
function Rewards.SkipGuide(player)
 if player.Parent~=Players or player:GetAttribute("ProfileReady")~=true or not data[player] then return false end
 data[player].GuidedStep=#Config.Guided+1
 publish(player)
 feedback:FireClient(player,"TutorialSkipped")
 return true
end

-- Binds claim/guide endpoints and subscribes to server gameplay events; no objective polling.
function Rewards.Start(shelterService,remotes)
 if shelter then return end
 shelter,feedback=shelterService,remotes.Feedback
 remotes.RewardClaim.OnServerEvent:Connect(Rewards.Claim)
 remotes.GuideAction.OnServerEvent:Connect(function(player,action)
  if action=="Skip" then Rewards.SkipGuide(player) end
 end)
 Events.Connect(function(player,event,amount,detail)
  local state=data[player]
  if not state or player:GetAttribute("ProfileReady")~=true then return end
  State.Reset(state,os.time(),Config)
  local before={}
  for _,q in State.Active(state.Day,Config) do before[q.Id]=(state.Progress[q.Id] or 0)>=q.Target end
  State.Record(state,event,amount,detail,Config)
  publish(player)
  for _,q in State.Active(state.Day,Config) do
   if not before[q.Id] and (state.Progress[q.Id] or 0)>=q.Target then feedback:FireClient(player,"QuestComplete",q.Title); break end
  end
 end)
 local elapsed=0
 game:GetService("RunService").Heartbeat:Connect(function(dt)
  elapsed+=dt; if elapsed<30 then return end; elapsed=0
  for player,state in data do if State.Reset(state,os.time(),Config) then publish(player) end end
 end)
end
return Rewards
