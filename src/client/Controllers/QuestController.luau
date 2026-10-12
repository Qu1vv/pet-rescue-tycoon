local UI=require(script.Parent.Parent.UI.Components)
local Biomes=require(game.ReplicatedStorage.Shared.Config.Biomes)
local Audio=require(script.Parent.AudioController)
local Quest={}
-- Creates event-driven daily/collection reward cards; claim requests carry only type and ID.
function Quest.Start()
 local player=game.Players.LocalPlayer
 local gui=Instance.new("ScreenGui"); gui.Name="RescueQuests"; gui.ResetOnSpawn=false; gui.DisplayOrder=6; gui.Parent=player:WaitForChild("PlayerGui")
 local toggle=Instance.new("TextButton"); toggle.Text="GOALS"; toggle.TextSize=18; toggle.Size=UDim2.fromOffset(126,42); toggle.Position=UDim2.new(0.5,5,1,-54); toggle.Parent=gui; UI.Button(toggle)
 local panel=Instance.new("Frame"); panel.Size=UDim2.new(1,-24,0.8,0); panel.AnchorPoint=Vector2.new(0.5,0.5); panel.Position=UDim2.fromScale(0.5,0.5); panel.Visible=false; panel.Parent=gui; UI.Panel(panel)
 local limit=Instance.new("UISizeConstraint",panel); limit.MaxSize=Vector2.new(520,620)
 local title=Instance.new("TextLabel"); title.BackgroundTransparency=1; title.Text="DAILY ADVENTURES"; title.TextSize=23; title.Size=UDim2.new(1,-50,0,46); title.Parent=panel; UI.Text(title,true)
 local close=Instance.new("TextButton"); close.Text="×"; close.TextSize=24; close.Size=UDim2.fromOffset(38,38); close.Position=UDim2.new(1,-44,0,5); close.Parent=panel; UI.Button(close,true)
 local skip=Instance.new("TextButton"); skip.TextSize=11; skip.Size=UDim2.fromOffset(104,30); skip.Position=UDim2.new(1,-156,0,9); skip.Parent=panel; UI.Button(skip,true)
 local guide=game.ReplicatedStorage:WaitForChild("ShelterRemotes"):WaitForChild("GuideAction")
 local skipConfirm=false
 local function guideState()
  local active=(player:GetAttribute("GuidedObjective") or "")~=""
  skip.Visible=active
  skip.Text=if skipConfirm then "CONFIRM SKIP" else "SKIP TUTORIAL"
 end
 skip.Activated:Connect(function()
  if not skipConfirm then skipConfirm=true; guideState(); return end
  skipConfirm=false; guide:FireServer("Skip")
 end)
 player:GetAttributeChangedSignal("GuidedObjective"):Connect(function() skipConfirm=false; guideState() end)
 guideState()
 local reset=Instance.new("TextLabel"); reset.BackgroundTransparency=1; reset.TextSize=12; reset.Position=UDim2.fromOffset(10,45); reset.Size=UDim2.new(1,-20,0,28); reset.Parent=panel; UI.Text(reset)
 local list=Instance.new("ScrollingFrame"); list.Position=UDim2.fromOffset(12,78); list.Size=UDim2.new(1,-24,1,-90); list.BackgroundTransparency=1; list.BorderSizePixel=0; list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.new(); list.ScrollBarThickness=5; list.Parent=panel
 local layout=Instance.new("UIListLayout",list); layout.Padding=UDim.new(0,10); layout.SortOrder=Enum.SortOrder.LayoutOrder
 toggle.Activated:Connect(function() UI.SetMenuVisible(panel,not panel.Visible) end)
 close.Activated:Connect(function() UI.SetMenuVisible(panel,false) end)
 local volume=Instance.new("TextButton"); volume.Text="SOUND ON"; volume.TextSize=12; volume.Size=UDim2.fromOffset(100,30); volume.Position=UDim2.new(1,-112,0,12); volume.Parent=gui; UI.Button(volume,true)
 local enabledVolume=Audio.GetVolume()
 local muted=enabledVolume<=0
 volume.Text=if muted then "SOUND OFF" else "SOUND ON"
 volume.Activated:Connect(function() muted=not muted; Audio.SetVolume(if muted then 0 else enabledVolume); volume.Text=if muted then "SOUND OFF" else "SOUND ON" end)
 local banner=Instance.new("TextLabel"); banner.AnchorPoint=Vector2.new(0.5,0); banner.Position=UDim2.fromScale(0.5,0.1); banner.Size=UDim2.new(1,-32,0,50); banner.TextSize=25; banner.Visible=false; banner.Parent=gui; UI.Notification(banner,UI.Colors.Mint)
 local bannerLimit=Instance.new("UISizeConstraint",banner); bannerLimit.MaxSize=Vector2.new(440,50)
 local version=0
 player:GetAttributeChangedSignal("BiomeId"):Connect(function()
  version+=1; local current=version; local biome=Biomes[player:GetAttribute("BiomeId")]
  if not biome then banner.Visible=false; return end
  banner.Text=biome.Name; banner.Visible=true; UI.Pop(banner)
  task.delay(2.5,function() if version==current then banner.Visible=false end end)
 end)
 local folder=player:WaitForChild("RescueGoals")
 local rows,connections={},{}
 local claim=game.ReplicatedStorage:WaitForChild("ShelterRemotes"):WaitForChild("RewardClaim")
 -- Creates one event-driven quest card and observes its replicated display attributes.
 local function watch(item)
  if rows[item] then return end
  local card=Instance.new("Frame"); card.Size=UDim2.new(1,-8,0,110); card.Parent=list; UI.QuestCard(card); rows[item]=card
  local text=Instance.new("TextLabel"); text.BackgroundTransparency=1; text.TextWrapped=true; text.TextSize=16; text.Position=UDim2.fromOffset(12,6); text.Size=UDim2.new(1,-128,0,66); text.Parent=card; UI.Text(text,true)
  local button=Instance.new("TextButton"); button.Size=UDim2.fromOffset(95,38); button.Position=UDim2.new(1,-106,0,24); button.TextSize=14; button.Parent=card; UI.Button(button)
  local progress=UI.Progress(card,UDim2.fromOffset(12,83),UDim2.new(1,-24,0,10))
  -- Refreshes text, claim state and the progress bar from server-owned attributes.
  local function render()
   local current,target=item:GetAttribute("Progress") or 0,item:GetAttribute("Target") or 1
   local claimed=item:GetAttribute("Claimed")==true
   text.Text=(item:GetAttribute("Title") or item.Name).."\n"..current.." / "..target
   button.Text=if claimed then "Claimed ✓" elseif current>=target then "+$"..(item:GetAttribute("Cash") or 0) else "In progress"
   button.Active=not claimed and current>=target
   button.BackgroundTransparency=if claimed or current<target then 0.5 else 0
   card.LayoutOrder=if item:GetAttribute("Kind")=="Daily" then 0 else 1
   progress(current/target)
  end
  button.Activated:Connect(function() claim:FireServer(item:GetAttribute("Kind"),item.Name) end)
  connections[item]=item.AttributeChanged:Connect(render); render()
 end
 folder.ChildAdded:Connect(watch)
 folder.ChildRemoved:Connect(function(item) if connections[item] then connections[item]:Disconnect(); connections[item]=nil end; if rows[item] then rows[item]:Destroy(); rows[item]=nil end end)
 for _,item in folder:GetChildren() do watch(item) end
 -- Formats the next server-defined UTC reset time without using the client clock for authority.
 local function timer()
  reset.Text="Daily reset: "..os.date("!%H:%M UTC",folder:GetAttribute("ResetsAt") or 0).."  •  Collection rewards never reset"
 end
 folder:GetAttributeChangedSignal("ResetsAt"):Connect(timer); timer()
end
return Quest
