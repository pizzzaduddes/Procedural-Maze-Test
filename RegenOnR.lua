local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RegenerateEvent = ReplicatedStorage:WaitForChild("RegenerateMaze")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.R then
		RegenerateEvent:FireServer()
	end
end)
