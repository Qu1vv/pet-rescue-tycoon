local HUDController = require(script:WaitForChild("Controllers"):WaitForChild("HUDController"))
local PetController = require(script:WaitForChild("Controllers"):WaitForChild("PetController"))
local FoodController = require(script:WaitForChild("Controllers"):WaitForChild("FoodController"))
local AccessibilityController = require(script.Controllers.AccessibilityController)

-- Accessibility defaults exist before presentation controllers construct their interfaces.
AccessibilityController.Start()

-- Controllers subscribe independently, including during initial replication.
task.spawn(HUDController.Start)
task.spawn(PetController.Start)
task.spawn(require(script.Controllers.RescueController).Start)
task.spawn(FoodController.Start)
task.spawn(require(script:WaitForChild("Controllers"):WaitForChild("IndexController")).Start)
task.spawn(require(script:WaitForChild("Controllers"):WaitForChild("MovementController")).Start)
task.spawn(require(script:WaitForChild("Controllers"):WaitForChild("PetNameplateController")).Start)
task.spawn(require(script.Controllers.AudioController).Start)
task.spawn(require(script.Controllers.AnimalAnimationController).Start)
task.spawn(require(script.Controllers.QuestController).Start)
task.spawn(require(script.Controllers.OnboardingController).Start)
task.spawn(require(script.Controllers.MyPetsController).Start)
task.spawn(require(script.Controllers.ShelterDashboardController).Start)
