-- Visual housing profiles are separate from the shelter's authoritative slot ledger.
local Housing = {}

Housing.Profiles = table.freeze({
	Dog = table.freeze({ Title = "KENNEL", Color = { 222, 171, 116 } }),
	Cat = table.freeze({ Title = "CAT NOOK", Color = { 184, 165, 222 } }),
	Bunny = table.freeze({ Title = "BUNNY HUTCH", Color = { 181, 209, 158 } }),
	Hamster = table.freeze({ Title = "SMALL PET HOME", Color = { 234, 187, 129 } }),
	GuineaPig = table.freeze({ Title = "SMALL PET HOME", Color = { 234, 187, 129 } }),
})

-- Chooses a safe generic suite for any future species that has no art profile yet.
function Housing.Get(species)
	return Housing.Profiles[species] or { Title = "COZY SUITE", Color = { 213, 186, 161 } }
end

return table.freeze(Housing)
