local Profiles = {}
local ground = { Mode = "Ground", Spacing = 4, Speed = 29, CatchupSpeed = 35, Acceleration = 34,
 Deceleration = 48, TurnRate = 8, CatchupDistance = 10, RecoveryDistance = 85, RecoveryDelay = 3,
 StopDistance = 0.12 }
Profiles.Dog = ground
Profiles.Cat = table.clone(ground)
Profiles.Cat.Spacing, Profiles.Cat.TurnRate = 3.7, 10
Profiles.Bunny = table.clone(ground)
Profiles.Bunny.Spacing, Profiles.Bunny.TurnRate = 3.2, 13
Profiles.Hamster = table.clone(ground)
Profiles.Hamster.Spacing, Profiles.Hamster.Speed, Profiles.Hamster.TurnRate = 2.5, 27, 14
Profiles.GuineaPig = table.clone(ground)
Profiles.GuineaPig.Spacing, Profiles.GuineaPig.Speed, Profiles.GuineaPig.TurnRate = 2.8, 25, 11
-- Resolves one species profile; future locomotion modes can dispatch from this interface.
function Profiles.Get(species) return Profiles[species] or ground end
return Profiles
