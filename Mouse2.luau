--[[
NOTES:
THIS SHOULD BE REQUIRED BY 1 SCRIPT AND CLIENT ONLY
OR IDK WHAT WILL HAPPEN

USAGE:
-- Example usage of the Mouse2 module
-- Place this LocalScript in StarterPlayerScripts or a UI element
]]

-- Class
local CrosshairClass = {}
CrosshairClass.__index = CrosshairClass

CrosshairClass.new = function()
	local self = setmetatable({}, CrosshairClass)
	self.Crosshair = Instance.new("ScreenGui")
	self.Crosshair.Name = "Crosshair"
	self.Crosshair.ResetOnSpawn = false
	self.Crosshair.DisplayOrder = 0
	self.Crosshair.Parent = script

	self.Icon = Instance.new("ImageLabel")
	self.Icon.Name = "Icon"
	self.Icon.Parent = self.Crosshair
	self.Icon.BackgroundTransparency = 1
	self.Icon.Size = UDim2.new(0.1, 0, 0.1, 0)
	self.Icon.AnchorPoint = Vector2.new(0.5, 0.5)
	self.Icon.Position = UDim2.new(0.5, 0, 0.5, 0)
	self.Icon.Image = "rbxassetid://11984821416" -- Default crosshair image

	self.UIAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
	self.UIAspectRatioConstraint.Parent = self.Icon

	return self
end

-- Services
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Camera = workspace.CurrentCamera
local UGS = UserSettings().GameSettings

local CFrameLerp = require(script.CFrameLerpOnce)

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
end)

local Crosshair = CrosshairClass.new() -- Acts like shift lock if enabled
local Icon = Crosshair.Icon -- Crosshair image
local PlayerGui = player:WaitForChild("PlayerGui")

local TargetOffset = CFrame.new(1.5, 1, 0) -- Offset from the default camera's position
local DefaultOffset = CFrame.new(0, 0, 0) -- Default offset
local CurrentOffset = { value = CFrame.new() }
local LerpDuration = 0.5
local HeadDistance = 2 -- Distance from the head to determine if the player is in first-person mode

local Mouse2 = {}

-- Helper function to check if the player is in first-person mode
local function isFirstPerson()
	if not character then
		return false
	end
	local head = character:FindFirstChild("Head")
	if not head then
		return false
	end
	return (Camera.CFrame.Position - head.Position).Magnitude < HeadDistance
end

-- Toggle mouse lock
RunService:BindToRenderStep("Mouse2Shiftlock", Enum.RenderPriority.Camera.Value + 1, function()
	if
		Camera.CameraType ~= Enum.CameraType.Scriptable
		and not isFirstPerson()
		and humanoid
		and humanoid:GetState() ~= Enum.HumanoidStateType.Swimming
	then
		Camera.CFrame = Camera.CFrame * CurrentOffset.value
		Camera.Focus = CFrame.fromMatrix(Camera.Focus.Position, Camera.CFrame.RightVector, Camera.CFrame.UpVector)
			* CurrentOffset.value
	end
end)

function Mouse2:GetMouse()
	if Crosshair.Parent == PlayerGui then
		-- Raycast from the center of the Icon
		local iconPosition = Icon.AbsolutePosition + Icon.AbsoluteSize / 2 -- Center of the Icon
		local ray = Camera:ScreenPointToRay(iconPosition.X, iconPosition.Y)
		local raycastParams = RaycastParams.new()
		raycastParams.FilterDescendantsInstances = { player.Character or player.CharacterAdded:Wait() }
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
		if raycastResult then
			return CFrame.new(raycastResult.Position)
		else
			-- If no hit, return a position far along the ray
			return CFrame.new(ray.Origin + ray.Direction * 1000)
		end
	else
		-- Default mouse behavior
		return mouse.Hit
	end
end

function Mouse2:EnableMouseLock()
	Crosshair.Parent = PlayerGui
	Icon.Position = UDim2.new(0.5, 0, 0.5, 0) -- Center the crosshair
	Icon.Visible = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	UGS.RotationType = Enum.RotationType.CameraRelative
	CFrameLerp:Lerp("Mouse2Shiftlock", CurrentOffset, TargetOffset, LerpDuration)
end

function Mouse2:DisableMouseLock()
	Crosshair.Parent = script
	Icon.Visible = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	UGS.RotationType = Enum.RotationType.MovementRelative
	CFrameLerp:Lerp("Mouse2Shiftlock", CurrentOffset, DefaultOffset, LerpDuration)
end

function Mouse2:ChangeCrossHairIcon(image: string)
	Icon.Image = image
end

function Mouse2:GetIcon()
	return Icon
end

return Mouse2
