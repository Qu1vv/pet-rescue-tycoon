local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local Actions = game:GetService("ContextActionService")
local Movement = {}

-- Shift holds sprint; gamepad L3 and the mobile RUN button toggle it.
function Movement.Start()
	local player = Players.LocalPlayer
	local remote = game:GetService("ReplicatedStorage"):WaitForChild("ShelterRemotes"):WaitForChild("SprintRequest")
	local requested = false
	-- Sends only changes in sprint intent and updates the touch button's next action.
	local function request(running)
		if running and player:GetAttribute("ProfileReady") ~= true then return end
		if requested == running then return end
		requested = running
		remote:FireServer(running)
		Actions:SetTitle("ShelterSprint", if running then "WALK" else "RUN")
	end
	Actions:BindAction("ShelterSprint", function(_, state, input)
		-- Key-up must release sprint even if chat gained focus while Shift was held.
		local shift = input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift
		if shift and (state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel) then
			request(false)
			return Enum.ContextActionResult.Sink
		end
		if Input:GetFocusedTextBox() then return Enum.ContextActionResult.Pass end
		if shift then
			if state == Enum.UserInputState.Begin then request(true) end
		elseif state == Enum.UserInputState.Begin then request(not requested) end
		return Enum.ContextActionResult.Sink
	end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.RightShift, Enum.KeyCode.ButtonL3)
	Actions:SetTitle("ShelterSprint", "RUN")
	Actions:SetPosition("ShelterSprint", UDim2.new(1, -155, 1, -150))
	Input.WindowFocusReleased:Connect(function() request(false) end)
	player.CharacterRemoving:Connect(function() request(false) end)
end
return Movement
