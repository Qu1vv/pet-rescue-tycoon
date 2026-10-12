-- Empty IDs are intentional asset slots. Set only owned/approved Roblox audio IDs.
return { MasterVolume=0.65, MaxVoices=6, Categories={UI=0.45,Pets=0.65,World=0.22,Tycoon=0.5},
 Cues={
  Hover={Category="UI",Cooldown=0.1}, Click={Category="UI",Cooldown=0.08}, Menu={Category="UI",Cooldown=0.2}, Reward={Category="UI",Cooldown=0.5},
  QuestComplete={Category="UI",Cooldown=0.7}, CollectionReward={Category="UI",Cooldown=0.8},
  Rescue={Category="Pets",Cooldown=0.3}, Feed={Category="Pets",Cooldown=0.3}, LevelUp={Category="Pets",Cooldown=0.5},
  Adopt={Category="Pets",Cooldown=0.5}, Discovery={Category="Pets",Cooldown=1},
  Care={Category="Pets",Cooldown=0.3}, Favorite={Category="Pets",Cooldown=0.3}, Rename={Category="UI",Cooldown=0.3},
  Drop={Category="Tycoon",Cooldown=0.5}, Collect={Category="Tycoon",Cooldown=0.3}, Upgrade={Category="Tycoon",Cooldown=0.5},
  DogPark={Category="World",Looped=true}, Forest={Category="World",Looped=true}, Orchard={Category="World",Looped=true},
 } }
