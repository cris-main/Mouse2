local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Mouse2 = require(ReplicatedStorage.Mouse2)

local isMouse2Enabled = false
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.LeftAlt then
        isMouse2Enabled = not isMouse2Enabled
        Mouse2:MouseLockEnabled(isMouse2Enabled)
    end
end)
 Mouse2:MouseTrailEnabled(true) -- Enable mouse trail effect