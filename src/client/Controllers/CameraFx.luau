--!strict
-- All camera effects live here so they don't fight each other: lower camera and wider view while
-- sliding, screen shake, and quick field-of-view punches.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SlideController = require(script.Parent.SlideController)

local SLIDE_DROP = 1.2
local SLIDE_FOV = 8
local MAX_SHAKE = 1.1 -- studs of camera offset at full shake
local SHAKE_DECAY = 1.8 -- shake lost per second

local CameraFx = {}

local player = Players.LocalPlayer
local trauma = 0
local punch = 0
local drop = 0
local boost = 0
local baseFov = 70
local applying = false

-- Adds screen shake (0-1; it stacks and fades out).
function CameraFx.shake(amount: number)
	trauma = math.min(1, trauma + amount)
end

-- Kicks the field of view out by `degrees`, springing back right after.
function CameraFx.punch(degrees: number)
	punch += degrees
end

local function update(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local sliding = SlideController.isSliding()
	local alpha = math.min(1, dt * 10)
	drop += ((if sliding then -SLIDE_DROP else 0) - drop) * alpha
	boost += ((if sliding then SLIDE_FOV else 0) - boost) * alpha
	punch -= punch * math.min(1, dt * 8)
	trauma = math.max(0, trauma - SHAKE_DECAY * dt)

	local active = math.abs(drop) > 0.01 or boost > 0.05 or math.abs(punch) > 0.05 or trauma > 0
	if not active and not applying then
		return -- leave the camera alone when we have nothing to add
	end
	if not applying then
		baseFov = camera.FieldOfView
	end
	applying = active

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not active then
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
		camera.FieldOfView = baseFov
		return
	end

	local shake = trauma * trauma * MAX_SHAKE
	local t = os.clock() * 35
	if humanoid then
		humanoid.CameraOffset = Vector3.new(math.noise(t, 0.5) * shake, drop + math.noise(0.5, t) * shake, 0)
	end
	camera.FieldOfView = baseFov + boost + punch
end

function CameraFx.start()
	RunService.RenderStepped:Connect(update)
end

return CameraFx
