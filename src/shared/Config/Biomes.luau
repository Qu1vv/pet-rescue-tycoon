-- Coordinates are plain data so build tools, gameplay and tests use one layout.
local Biomes = {
 DogPark = { Id = "DogPark", Name = "Dog Park", Center = {-320, 1.1, 0}, Radius = 48,
  Species = {Dog = true}, MaxActive = 6, RespawnSeconds = 7, PlayerClearance = 10,
  RarityWeights = {Common = 62, Uncommon = 28, Rare = 7, Epic = 2, Legendary = 1},
  Color = {154, 193, 116}, Ambience = "DogPark", EventTags = {},
  Points = {{-23,-22},{0,-26},{24,-19},{-25,12},{0,24},{25,15}},
  Route = {{0,1.1,0},{-320,1.1,0}} },
 Forest = { Id = "Forest", Name = "Whisperwood Forest", Center = {0, 1.1, -335}, Radius = 42,
  Species = {Bunny = true, Hamster = true, GuineaPig = true}, MaxActive = 6, RespawnSeconds = 9, PlayerClearance = 10,
  RarityWeights = {Common = 45, Uncommon = 30, Rare = 18, Epic = 5, Legendary = 1, Mythic = 1},
  Color = {91, 145, 111}, Ambience = "Forest", EventTags = {},
  Points = {{-22,-18},{0,-24},{23,-13},{-22,13},{0,23},{24,15}},
  Route = {{0,1.1,0},{90,1.1,-75},{90,1.1,-315},{0,1.1,-315}} },
 Orchard = { Id = "Orchard", Name = "Cat Orchard", Center = {320, 1.1, 0}, Radius = 48,
  Species = {Cat = true}, MaxActive = 6, RespawnSeconds = 8, PlayerClearance = 10,
  RarityWeights = {Common = 55, Uncommon = 25, Rare = 12, Epic = 6, Legendary = 2},
  Color = {196, 173, 189}, Ambience = "Orchard", EventTags = {},
  Points = {{-23,-22},{0,-26},{24,-19},{-25,12},{0,24},{25,15}},
  Route = {{0,1.1,0},{320,1.1,0}} },
}
return Biomes
