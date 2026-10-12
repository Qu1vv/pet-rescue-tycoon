local SoundService=game:GetService("SoundService")
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("Audio"))
local Audio={}
local last,voices={},{}
local master=Config.MasterVolume
local ambience
-- Returns the current local master volume for UI state without exposing server gameplay state.
function Audio.GetVolume()
 return master
end
-- Updates local volume without changing anyone else's preferences.
function Audio.SetVolume(volume)
 master=math.clamp(volume,0,1)
 for sound,category in voices do sound.Volume=master*(Config.Categories[category] or 0.5) end
end
-- Plays an approved configured cue with category volume, rate limit, voice cap and hard cleanup.
function Audio.Play(id)
 local cue=Config.Cues[id]
 if not cue or type(cue.SoundId)~="string" or not string.match(cue.SoundId,"^rbxassetid://%d+$") then return end
 local now=os.clock()
 if last[id] and now-last[id]<(cue.Cooldown or 0.2) then return end
 local count=0; for _ in voices do count+=1 end
 if count>=Config.MaxVoices then return end
 last[id]=now
 local sound=Instance.new("Sound")
 sound.SoundId,sound.Looped=cue.SoundId,cue.Looped==true
 sound.Volume=master*(Config.Categories[cue.Category] or 0.5)
 sound.Parent=SoundService; voices[sound]=cue.Category
 sound.Destroying:Connect(function() voices[sound]=nil end)
 if not sound.Looped then sound.Ended:Once(function() sound:Destroy() end); game:GetService("Debris"):AddItem(sound,12) end
 sound:Play()
 return sound
end
-- Keeps exactly one subtle biome ambience loop, replacing it on entry/exit.
function Audio.SetBiome(id)
 if ambience then ambience:Destroy(); ambience=nil end
 ambience=Audio.Play(id)
end
-- Maps server feedback to cues; missing approved assets deliberately remain silent.
function Audio.Start()
 local player=game.Players.LocalPlayer
 local remotes=game.ReplicatedStorage:WaitForChild("ShelterRemotes")
 local cues={Rescued="Rescue",TrustGained="Care",TrustReady="Rescue",Fed="Feed",Adopted="Adopt",Discovered="Discovery",FoodCollected="Collect",Upgraded="Upgrade",Purchased="Upgrade",RewardClaimed="Reward",QuestComplete="QuestComplete",CollectionReward="CollectionReward",Cared="Care",FavoriteChanged="Favorite",Renamed="Rename"}
 remotes.Feedback.OnClientEvent:Connect(function(code,detail)
  Audio.Play(if code=="Fed" and type(detail)=="table" and detail.Leveled then "LevelUp" else cues[code])
 end)
 player:GetAttributeChangedSignal("BiomeId"):Connect(function() Audio.SetBiome(player:GetAttribute("BiomeId")) end)
 Audio.SetBiome(player:GetAttribute("BiomeId"))
end
return Audio
