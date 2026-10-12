local State = {}
-- Allocates independent persistent quest fields; the server supplies the UTC period.
function State.New(day)
 return {Day=day or 0, Progress={}, Claimed={}, Milestones={}, GuidedStep=1}
end
-- Determines the daily rotation entirely from the server period and configured list.
function State.Active(day, config)
 local result={}
 for i=1,math.min(config.DailyCount,#config.Dailies) do
  table.insert(result,config.Dailies[(day+i-1)%#config.Dailies+1])
 end
 return result
end
-- Clears only daily state at a UTC boundary, preserving lifetime rewards and guide progress.
function State.Reset(state, now, config)
 local day=math.floor(now/config.ResetSeconds)
 if state.Day==day then return false end
 state.Day,state.Progress,state.Claimed=day,{},{}
 return true
end
-- Counts a committed gameplay event and advances at most one matching guided step.
function State.Record(state, event, amount, detail, config)
 for _, quest in State.Active(state.Day,config) do
  if quest.Event==event and (not quest.Detail or quest.Detail==detail) then
   state.Progress[quest.Id]=math.min(quest.Target,(state.Progress[quest.Id] or 0)+amount)
  end
 end
 local step=config.Guided[state.GuidedStep]
 if step and step.Event==event and (not step.Detail or step.Detail==detail) then state.GuidedStep+=1 end
end
-- Returns an eligible, unclaimed server reward definition; clients supply identifiers only.
function State.Eligible(state, kind, id, discovered, config)
 if kind=="Daily" then
  for _, quest in State.Active(state.Day,config) do
   if quest.Id==id and not state.Claimed[id] and (state.Progress[id] or 0)>=quest.Target then return quest end
  end
 elseif kind=="Collection" then
  for _, reward in config.Milestones do
   if reward.Id==id and not state.Milestones[id] and discovered>=reward.Target then return reward end
  end
 end
 return nil
end
-- Validates and copies saved quest fields; malformed progress never becomes a reward.
function State.Validate(source, config)
 assert(type(source)=="table" and type(source.Day)=="number" and source.Day%1==0 and source.Day>=0 and source.Day<10000000,"Invalid reward period")
 assert(type(source.GuidedStep)=="number" and source.GuidedStep%1==0 and source.GuidedStep>=1 and source.GuidedStep<=#config.Guided+1,"Invalid guide")
 local result=State.New(source.Day); result.GuidedStep=source.GuidedStep
 assert(type(source.Progress)=="table" and type(source.Claimed)=="table" and type(source.Milestones)=="table","Invalid rewards")
 local quests={}; for _, q in config.Dailies do quests[q.Id]=q end
 for id,value in source.Progress do
  assert(quests[id] and type(value)=="number" and value%1==0 and value>=0 and value<=quests[id].Target,"Invalid quest progress")
  result.Progress[id]=value
 end
 for id,value in source.Claimed do assert(quests[id] and value==true,"Invalid quest claim"); result.Claimed[id]=true end
 local milestones={}; for _, r in config.Milestones do milestones[r.Id]=true end
 for id,value in source.Milestones do assert(milestones[id] and value==true,"Invalid collection claim"); result.Milestones[id]=true end
 return result
end
return State
