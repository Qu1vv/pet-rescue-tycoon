local Tween=game:GetService("TweenService")
local Audio=require(script.Parent.Parent.Controllers.AudioController)
local UI={Colors={Ink=Color3.fromRGB(51,64,79),Cream=Color3.fromRGB(255,248,232),Mint=Color3.fromRGB(171,224,190),
 Peach=Color3.fromRGB(250,195,158),Purple=Color3.fromRGB(206,188,241),White=Color3.fromRGB(255,253,247)}}
local openPanel
local activePops=setmetatable({},{__mode="k"})
-- Applies rounded card styling shared by HUD, pet cards, popups and quest rows.
function UI.Card(frame,color)
 frame.BackgroundColor3=color or UI.Colors.Cream; frame.BorderSizePixel=0
 local corner=frame:FindFirstChildOfClass("UICorner") or Instance.new("UICorner",frame)
 corner.CornerRadius=UDim.new(0,18)
 local stroke=frame:FindFirstChild("CardStroke") or Instance.new("UIStroke",frame); stroke.Name="CardStroke"; stroke.Color=UI.Colors.Ink
 local highContrast=game.Players.LocalPlayer and game.Players.LocalPlayer:GetAttribute("HighContrast")
 stroke.Transparency=if highContrast then 0.25 else 0.86; stroke.Thickness=if highContrast then 3 else 2
 return frame
end
-- Applies a readable rounded heading or body type style using built-in Roblox fonts.
function UI.Text(label,heading)
 label.Font=if heading then Enum.Font.FredokaOne else Enum.Font.GothamMedium
 label.TextColor3=UI.Colors.Ink
 label.TextStrokeTransparency=1
 if label:GetAttribute("BaseTextSize")==nil then label:SetAttribute("BaseTextSize",label.TextSize) end
 return label
end
-- Styles a full menu panel while keeping panel construction consistent across controllers.
function UI.Panel(frame)
 return UI.Card(frame,UI.Colors.Cream)
end
-- Styles a prominent cash/food value using the shared heading typography and accent color.
function UI.Currency(label)
 UI.Text(label,true); label.TextColor3=Color3.fromRGB(63,119,85); return label
end
-- Styles one Pet Index entry without coupling the component to catalog data.
function UI.PetCard(frame)
 return UI.Card(frame,UI.Colors.White)
end
-- Styles one daily or collection objective card without coupling it to reward logic.
function UI.QuestCard(frame)
 return UI.Card(frame,UI.Colors.White)
end
-- Styles a transient message surface; callers control its text and lifetime.
function UI.Notification(label,color)
 UI.Card(label,color or UI.Colors.Peach); UI.Text(label,true); return label
end
-- Shows one main menu at a time and applies the shared entrance animation.
function UI.SetMenuVisible(panel,visible)
 if visible and openPanel and openPanel~=panel then openPanel.Visible=false end
 panel.Visible=visible
 if visible then openPanel=panel; UI.Pop(panel) elseif openPanel==panel then openPanel=nil end
end
-- Closes the current full menu before a higher-priority modal opens.
function UI.CloseMenus()
 if openPanel then openPanel.Visible=false; openPanel=nil end
end
-- Styles and animates one action button with short, non-blocking tweens.
function UI.Button(button,secondary)
 UI.Card(button,if secondary then UI.Colors.Purple else UI.Colors.Mint)
 UI.Text(button,true); button.AutoButtonColor=false; button.Selectable=true
 local scale=Instance.new("UIScale",button)
 local size=Instance.new("UISizeConstraint",button); size.MinSize=Vector2.new(40,36)
 local active
 -- Replaces the active hover/press tween so repeated input never stacks animations.
 local function animate(value)
  if active then active:Cancel() end
  if game.Players.LocalPlayer:GetAttribute("ReduceMotion") then scale.Scale=1; return end
  active=Tween:Create(scale,TweenInfo.new(0.1),{Scale=value}); active:Play()
 end
 button.MouseEnter:Connect(function() animate(1.035); Audio.Play("Hover") end)
 button.MouseLeave:Connect(function() animate(1) end)
 button.MouseButton1Down:Connect(function() animate(0.96) end)
 button.MouseButton1Up:Connect(function() animate(1) end)
 button.Activated:Connect(function() animate(1); Audio.Play("Click") end)
 return button
end
-- Gives a menu or reward card a brief entrance pop, cancelling any previous scale tween.
function UI.Pop(frame)
 local scale=frame:FindFirstChildOfClass("UIScale") or Instance.new("UIScale",frame)
 if game.Players.LocalPlayer:GetAttribute("ReduceMotion") then scale.Scale=1; Audio.Play("Menu"); return end
 scale.Scale=0.94
 if activePops[frame] then activePops[frame]:Cancel() end
 local tween=Tween:Create(scale,TweenInfo.new(0.16,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1})
 activePops[frame]=tween; tween:Play()
 Audio.Play("Menu")
end
-- Creates a clipped progress bar and returns a setter for a normalized value.
function UI.Progress(parent,position,size)
 local bar=Instance.new("Frame"); bar.Position,bar.Size=position,size; bar.Parent=parent
 UI.Card(bar,Color3.fromRGB(228,227,218)); bar.ClipsDescendants=true
 local fill=Instance.new("Frame"); fill.Size=UDim2.fromScale(0,1); fill.Parent=bar; UI.Card(fill,UI.Colors.Mint)
 return function(value) fill.Size=UDim2.fromScale(math.clamp(value,0,1),1) end
end
-- Creates a rarity badge suitable for cards and detail panels.
function UI.Badge(parent,text,color)
 local label=Instance.new("TextLabel"); label.Text=text; label.TextSize=12; label.Size=UDim2.fromOffset(95,22); label.Parent=parent
 UI.Card(label,color); UI.Text(label,true); return label
end
return UI
