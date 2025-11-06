--[[
Mouse2 Module
=============
Provides enhanced mouse and camera utilities for client-side scripts, including shift-lock, custom crosshair, and mouse trail effects.

USAGE:
    local Mouse2 = require(game.ReplicatedStorage.Mouse2)
    -- Enable mouse lock (shift-lock style)
    Mouse2:MouseLockEnabled(true)
    -- Change crosshair icon
    Mouse2:ChangeCrossHairIcon("rbxassetid://123456789")
    -- Enable mouse trail with custom options
    Mouse2:MouseTrailEnabled(true, {
        Color = ColorSequence.new(Color3.new(1, 0, 0)), -- Red trail
        Lifetime = 1,
        WidthScale = NumberSequence.new(0.3),
        Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.1),
            NumberSequenceKeypoint.new(1, 1)
        })
    })

API:
-----

Mouse2:GetMouse()
    Returns the current mouse hit CFrame, using the crosshair if enabled.

Mouse2:EnableMouseLock()
    Enables shift-lock style mouse lock and centers the crosshair.

Mouse2:MouseLockEnabled(enabled: boolean)
    Enables or disables mouse lock.

Mouse2:DisableMouseLock()
    Disables mouse lock and restores default mouse behavior.

Mouse2:ChangeCrossHairIcon(image: string)
    Changes the crosshair icon image.

Mouse2:GetIcon()
    Returns the crosshair icon ImageLabel instance.

Mouse2:MouseTrailEnabled(enabled: boolean, options: table?)
    Enables or disables a mouse trail effect that follows the mouse's 3D position.
    - enabled (boolean): Whether to enable or disable the trail.
    - options (table, optional): Customization for the Trail instance. Supported keys:
        - Color (ColorSequence): Trail color.
        - Lifetime (number): How long the trail persists.
        - MinLength (number): Minimum trail length.
        - FaceCamera (boolean): Whether the trail faces the camera.
        - LightInfluence (number): How much the trail is affected by lighting.
        - Transparency (NumberSequence): Trail transparency over its length.
        - WidthScale (NumberSequence): Trail width over its length.

    Example:
        Mouse2:MouseTrailEnabled(true, {
            Color = ColorSequence.new(Color3.new(0, 1, 1)), -- Cyan
            Lifetime = 0.8,
            WidthScale = NumberSequence.new(0.25)
        })

NOTES:
- This module should only be required by one client-side script at a time.
- Mouse trail effect uses a Trail instance attached to a small invisible part that follows the mouse's 3D position.
- All effects are client-side only.

]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Camera = workspace.CurrentCamera
local UGS = UserSettings().GameSettings

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
player.CharacterAdded:Connect(function(newCharacter)
	character = newCharacter
	humanoid = newCharacter:WaitForChild("Humanoid")
end)

local CrosshairClass = require(script.Classes.Crosshair)
local CFrameLerp = require(script.Utilities.CFrameLerpOnce)

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
	Crosshair:ParentTo(PlayerGui)
	Icon.Position = UDim2.new(0.5, 0, 0.5, 0) -- Center the crosshair
	Icon.Visible = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	UGS.RotationType = Enum.RotationType.CameraRelative
	CFrameLerp:Lerp("Mouse2Shiftlock", CurrentOffset, TargetOffset, LerpDuration)
end

function Mouse2:MouseLockEnabled(enabled: boolean)
	if enabled then
		self:EnableMouseLock()
	else
		self:DisableMouseLock()
	end
end

function Mouse2:DisableMouseLock()
	Crosshair:ParentTo(script)
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

-- Mouse trail effect variables
local mouseTrailEnabled = false
local trailPart = nil
local trailAttachment0 = nil
local trailAttachment1 = nil
local trailInstance = nil
local trailConnection = nil

-- Helper to clean up the trail
local function cleanupTrail()
	if trailConnection then
		trailConnection:Disconnect()
		trailConnection = nil
	end
	if trailInstance then
		trailInstance.Enabled = false
		trailInstance:Destroy()
		trailInstance = nil
	end
	if trailAttachment0 then
		trailAttachment0:Destroy()
		trailAttachment0 = nil
	end
	if trailAttachment1 then
		trailAttachment1:Destroy()
		trailAttachment1 = nil
	end
	if trailPart then
		trailPart:Destroy()
		trailPart = nil
	end
end

--[[
Mouse2:MouseTrailEnabled(enabled: boolean, options: table?)
Enables or disables a mouse trail effect that follows the mouse's 3D position.

Parameters:
    enabled (boolean): Whether to enable or disable the trail.
    options (table, optional): Customization for the Trail instance. Supported keys:
        - Color (ColorSequence): Trail color.
        - Lifetime (number): How long the trail persists.
        - MinLength (number): Minimum trail length.
        - FaceCamera (boolean): Whether the trail faces the camera.
        - LightInfluence (number): How much the trail is affected by lighting.
        - Transparency (NumberSequence): Trail transparency over its length.
        - WidthScale (NumberSequence): Trail width over its length.

Example:
    Mouse2:MouseTrailEnabled(true, {
        Color = ColorSequence.new(Color3.new(1, 0, 0)), -- Red
        Lifetime = 1,
        WidthScale = NumberSequence.new(0.3)
    })
]]
function Mouse2:MouseTrailEnabled(enabled: boolean, options: table?)
	mouseTrailEnabled = enabled

	cleanupTrail()

	if enabled then
		-- Create a small invisible part to follow the mouse
		trailPart = Instance.new("Part")
		trailPart.Size = Vector3.new(0.2, 0.2, 0.2)
		trailPart.Anchored = true
		trailPart.CanCollide = false
		trailPart.Transparency = 1
		trailPart.Name = "MouseTrailPart"
		trailPart.Parent = workspace

		-- Attachments for the Trail
		trailAttachment0 = Instance.new("Attachment")
		trailAttachment0.Name = "TrailAttachment0"
		trailAttachment0.Position = Vector3.new(0, 0, 0)
		trailAttachment0.Parent = trailPart

		trailAttachment1 = Instance.new("Attachment")
		trailAttachment1.Name = "TrailAttachment1"
		trailAttachment1.Position = Vector3.new(0, 0, 0.2)
		trailAttachment1.Parent = trailPart

		-- Create the Trail instance
		trailInstance = Instance.new("Trail")
		trailInstance.Attachment0 = trailAttachment0
		trailInstance.Attachment1 = trailAttachment1

		-- Default trail properties
		trailInstance.Color = ColorSequence.new(Color3.new(1, 1, 0)) -- Yellow
		trailInstance.Lifetime = 0.5
		trailInstance.MinLength = 0.1
		trailInstance.FaceCamera = true
		trailInstance.LightInfluence = 0
		trailInstance.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		trailInstance.WidthScale = NumberSequence.new(0.2)

		-- Apply custom options if provided
		if options then
			if options.Color then
				trailInstance.Color = options.Color
			end
			if options.Lifetime then
				trailInstance.Lifetime = options.Lifetime
			end
			if options.MinLength then
				trailInstance.MinLength = options.MinLength
			end
			if options.FaceCamera ~= nil then
				trailInstance.FaceCamera = options.FaceCamera
			end
			if options.LightInfluence then
				trailInstance.LightInfluence = options.LightInfluence
			end
			if options.Transparency then
				trailInstance.Transparency = options.Transparency
			end
			if options.WidthScale then
				trailInstance.WidthScale = options.WidthScale
			end
		end

		trailInstance.Parent = trailPart
		trailInstance.Enabled = true

		-- Update the part's position to follow the mouse
		trailConnection = RunService.RenderStepped:Connect(function()
			-- Raycast from the center of the Mouse
			local ray = Camera:ScreenPointToRay(mouse.X, mouse.Y)
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = { player.Character, trailPart }
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			local raycastResult = workspace:Raycast(ray.Origin, ray.Direction * 1000, raycastParams)
			if raycastResult then
				trailPart.Position = raycastResult.Position
			else
				-- If no hit, position the part far along the ray
				trailPart.Position = ray.Origin + ray.Direction * 1000
			end
		end)
	end
end

return Mouse2
