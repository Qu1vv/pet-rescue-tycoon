-- RGB values stay portable to tests. Text remains visible alongside the color.
return table.freeze({
	Common = table.freeze({ Color = { 176, 183, 193 }, Rank = 1 }),
	Uncommon = table.freeze({ Color = { 101, 218, 126 }, Rank = 2 }),
	Rare = table.freeze({ Color = { 91, 167, 255 }, Rank = 3 }),
	Epic = table.freeze({ Color = { 187, 123, 255 }, Rank = 4 }),
	Legendary = table.freeze({ Color = { 255, 215, 77 }, Rank = 5 }),
	Mythic = table.freeze({ Color = { 255, 137, 187 }, Rank = 6 }),
})
