local Shared=game.ReplicatedStorage:WaitForChild("Shared")
local Catalog=require(Shared.Pets.PetCatalog)
local Styles=require(Shared.Pets.RarityStyles)
local UI=require(script.Parent.Parent.UI.Components)
local Preview=require(script.Parent.Parent.UI.PetPreview)
local Index={}
-- Shows bounded model-preview cards, species filters and permanent variant discoveries.
function Index.Start()
 local player=game.Players.LocalPlayer
 local gui=Instance.new("ScreenGui"); gui.Name="PetIndex"; gui.ResetOnSpawn=false; gui.DisplayOrder=7; gui.Parent=player:WaitForChild("PlayerGui")
 local toggle=Instance.new("TextButton"); toggle.Size=UDim2.fromOffset(126,42); toggle.Position=UDim2.new(0.5,-131,1,-54); toggle.Text="PET INDEX"; toggle.TextSize=18; toggle.Parent=gui; UI.Button(toggle,true)
 local panel=Instance.new("Frame"); panel.Size=UDim2.new(1,-24,0.8,0); panel.AnchorPoint=Vector2.new(0.5,0.5); panel.Position=UDim2.fromScale(0.5,0.5); panel.Visible=false; panel.Parent=gui; UI.Panel(panel)
 local limit=Instance.new("UISizeConstraint",panel); limit.MaxSize=Vector2.new(550,650)
 local header=Instance.new("TextLabel"); header.BackgroundTransparency=1; header.Size=UDim2.new(1,-50,0,44); header.TextSize=24; header.Parent=panel; UI.Text(header,true)
 local close=Instance.new("TextButton"); close.Size=UDim2.fromOffset(38,38); close.Position=UDim2.new(1,-44,0,4); close.Text="×"; close.TextSize=23; close.Parent=panel; UI.Button(close,true)
 local search=Instance.new("TextBox"); search.Position=UDim2.fromOffset(12,49); search.Size=UDim2.new(1,-24,0,32); search.PlaceholderText="Search pet, coat, rarity or habitat"; search.Text=""; search.ClearTextOnFocus=false; search.TextSize=14; search.Parent=panel; UI.Card(search,UI.Colors.White); UI.Text(search)
 local filters=Instance.new("Frame"); filters.Position=UDim2.fromOffset(12,89); filters.Size=UDim2.new(1,-24,0,30); filters.BackgroundTransparency=1; filters.Parent=panel
 local list=Instance.new("ScrollingFrame"); list.Position=UDim2.fromOffset(12,127); list.Size=UDim2.new(1,-24,1,-181); list.AutomaticCanvasSize=Enum.AutomaticSize.Y; list.CanvasSize=UDim2.new(); list.ScrollBarThickness=5; list.BackgroundTransparency=1; list.BorderSizePixel=0; list.Parent=panel
 local layout=Instance.new("UIListLayout",list); layout.Padding=UDim.new(0,8); layout.SortOrder=Enum.SortOrder.LayoutOrder
 local page,category=1,"All"
 local revealKey
 local folder=player:WaitForChild("PetIndex")
 local previous=Instance.new("TextButton"); previous.Text="‹ Previous"; previous.Size=UDim2.new(0.46,0,0,32); previous.Position=UDim2.new(0.02,0,1,-41); previous.TextSize=14; previous.Parent=panel; UI.Button(previous,true)
 local nextPage=Instance.new("TextButton"); nextPage.Text="Next ›"; nextPage.Size=previous.Size; nextPage.Position=UDim2.new(0.52,0,1,-41); nextPage.TextSize=14; nextPage.Parent=panel; UI.Button(nextPage,true)
 -- Rebuilds only six previews when the visible page changes; hidden menus allocate none.
 local function render()
  local found,entries=0,{}
  for _,entry in Catalog.Entries do
   if folder:FindFirstChild(entry.Key) then found+=1 end
   local def=entry.Definition
   local matches=category=="All" or def.Species==category or (category=="Small" and (def.Species=="Hamster" or def.Species=="GuineaPig"))
   local haystack=string.lower(def.DisplayName.." "..entry.Variant.Name.." "..entry.Rarity.." "..def.Habitat)
   if matches and string.find(haystack,string.lower(search.Text),1,true) then table.insert(entries,entry) end
  end
  table.sort(entries,function(a,b) if Styles[a.Rarity].Rank~=Styles[b.Rarity].Rank then return Styles[a.Rarity].Rank<Styles[b.Rarity].Rank end; return a.Key<b.Key end)
  local pages=math.max(1,math.ceil(#entries/6)); page=math.clamp(page,1,pages)
  header.Text="PET INDEX  "..found.." / "..#Catalog.Entries
  nextPage.Text="Next ›  "..page.." / "..pages
  for _,child in list:GetChildren() do if child:IsA("Frame") then child:Destroy() end end
  if not panel.Visible then return end
  for i=(page-1)*6+1,math.min(page*6,#entries) do
   local entry=entries[i]; local discovery=folder:FindFirstChild(entry.Key)
   local card=Instance.new("Frame"); card.Name=entry.Key; card.Size=UDim2.new(1,-8,0,132); card.LayoutOrder=i; card.Parent=list; UI.PetCard(card)
   Preview.Create(card,entry.Definition,entry.Variant,not discovery)
   local label=Instance.new("TextLabel"); label.BackgroundTransparency=1; label.TextWrapped=true; label.TextXAlignment=Enum.TextXAlignment.Left; label.Position=UDim2.fromOffset(110,8); label.Size=UDim2.new(1,-119,0,87); label.TextSize=14; label.Parent=card; UI.Text(label,true)
   label.Text=if discovery then "✓ "..entry.Variant.Name.." "..entry.Definition.DisplayName.."\n"..entry.Definition.Species.." • "..entry.Definition.Habitat.."\nBest level "..(discovery:GetAttribute("BestLevel") or 1)
    else "?  ???\n"..entry.Definition.Species.." • "..entry.Definition.Habitat.."\nNot discovered yet"
   local badge=UI.Badge(card,entry.Rarity,Color3.fromRGB(table.unpack(Styles[entry.Rarity].Color))); badge.Position=UDim2.fromOffset(111,101)
   if revealKey==entry.Key then UI.Pop(card) end
  end
  revealKey=nil
 end
 for i,filter in { {"All","ALL"},{"Dog","DOGS"},{"Bunny","RABBITS"},{"Cat","CATS"},{"Small","SMALL"} } do
  local b=Instance.new("TextButton"); b.Size=UDim2.new(0.2,-4,1,0); b.Position=UDim2.new((i-1)*0.2,0,0,0); b.Text=filter[2]; b.TextSize=11; b.Parent=filters; UI.Button(b,true)
  b.Activated:Connect(function() category=filter[1]; page=1; render() end)
 end
 toggle.Activated:Connect(function() UI.SetMenuVisible(panel,not panel.Visible); render() end)
 close.Activated:Connect(function() UI.SetMenuVisible(panel,false); render() end)
 previous.Activated:Connect(function() page=math.max(1,page-1); render(); list.CanvasPosition=Vector2.zero end)
 nextPage.Activated:Connect(function() page+=1; render(); list.CanvasPosition=Vector2.zero end)
 search:GetPropertyChangedSignal("Text"):Connect(function() page=1; render() end)
 local queued=false
 -- Coalesces related replicated attribute changes into one card refresh.
 local function schedule()
  if queued then return end; queued=true
  task.defer(function() queued=false; render() end)
 end
 local connections={}
 -- Owns one progress listener per discovery entry, cleaned on removal.
 local function watch(item,announce) if announce then revealKey=item.Name end; connections[item]=item.AttributeChanged:Connect(schedule); schedule() end
 folder.ChildAdded:Connect(function(item) watch(item,true) end)
 folder.ChildRemoved:Connect(function(item) if connections[item] then connections[item]:Disconnect(); connections[item]=nil end; schedule() end)
 for _,item in folder:GetChildren() do watch(item) end
 render()
end
return Index
