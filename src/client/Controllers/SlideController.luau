--!strict
-- Sliding. Hold the screen (mobile), the left mouse button, C, or R2 to slide; let go to get up.
-- Sliding into someone tells the server, which launches them. Getting launched is handled here too.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local HOLD_INPUT_TYPES: { [Enum.UserInputType]: boolean } = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.Touch] = true,
}
local HOLD_KEYS: { [Enum.KeyCode]: boolean } = {
	[Enum.KeyCode.C] = true,
	[Enum.KeyCode.ButtonR2] = true,
}
local PRESS_BUFFER = 0.4 -- pressing just before you land still starts a slide
local AIR_GRACE = 0.15 -- in the air longer than this ends the slide (you keep your momentum)

local SlideController = {}

local player = Players.LocalPlayer

local held: { [any]: boolean } = {}
local pressedAt = -math.huge
local slidSincePress = false

local sliding = false
local slides = 0
local slideStart = 0
local slideSpeed = 0
local slideDirection = Vector3.new(0, 0, -1)
local airTime = 0
local lastSlideEnd = -math.huge
local downUntil = 0
local hitThisSlide: { [Model]: boolean } = {}
local slideAttachment: Attachment? = nil
local slideVelocity: LinearVelocity? = nil
local slideAlign: AlignOrientation? = nil

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

function SlideController.isSliding(): boolean
	return sliding
end

function SlideController.isDown(): boolean
	return os.clock() < downUntil
end

-- How many slides this player has done (the HUD hides its hint after a few).
function SlideController.slideCount(): number
	return slides
end

-- 0-1: how fast the current slide still is compared to its starting speed.
function SlideController.intensity(): number
	if not sliding then
		return 0
	end
	return math.clamp(slideSpeed / Config.Slide.StartSpeed, 0, 1)
end

local function getCharacter(): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
	return nil, nil, nil
end

local function flatUnit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
end

-- Touches are tracked one by one; mouse and keys by which button it is.
local function holdKey(input: InputObject): any?
	if input.UserInputType == Enum.UserInputType.Touch then
		return input
	elseif HOLD_INPUT_TYPES[input.UserInputType] then
		return input.UserInputType
	elseif HOLD_KEYS[input.KeyCode] then
		return input.KeyCode
	end
	return nil
end

local function stopSlide()
	if not sliding then
		return
	end
	sliding = false
	lastSlideEnd = os.clock()
	if slideAttachment then
		slideAttachment:Destroy()
	end
	slideAttachment, slideVelocity, slideAlign = nil, nil, nil
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
	end
	Net.remote("SlideState"):FireServer(false)
end

local function startSlide()
	local now = os.clock()
	if sliding or now < downUntil or now - lastSlideEnd < Config.Slide.Cooldown then
		return
	end
	local _, humanoid, root = getCharacter()
	if not humanoid or not root or humanoid.FloorMaterial == Enum.Material.Air then
		return
	end
	local direction = flatUnit(humanoid.MoveDirection)
	if direction == Vector3.zero then
		direction = flatUnit(root.CFrame.LookVector)
	end
	if direction == Vector3.zero then
		return
	end

	sliding = true
	slides += 1
	slidSincePress = true
	slideStart = now
	slideDirection = direction
	local currentSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude
	slideSpeed = math.max(Config.Slide.StartSpeed, currentSpeed)
	airTime = 0
	table.clear(hitThisSlide)

	local attachment = Instance.new("Attachment")
	attachment.Name = "SlideAttachment"

	local velocity = Instance.new("LinearVelocity")
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	velocity.PrimaryTangentAxis = Vector3.xAxis
	velocity.SecondaryTangentAxis = Vector3.zAxis
	velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z) * slideSpeed
	velocity.MaxForce = math.huge
	velocity.Parent = attachment

	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.CFrame = CFrame.lookAt(Vector3.zero, direction)
	align.Parent = attachment

	attachment.Parent = root
	slideAttachment, slideVelocity, slideAlign = attachment, velocity, align
	humanoid.AutoRotate = false
	Net.remote("SlideState"):FireServer(true)
end

local function checkHits(character: Model, root: BasePart)
	overlapParams.FilterDescendantsInstances = { character }
	local size = Config.Slide.Hitbox
	local box = root.CFrame * CFrame.new(0, -0.5, -size.Z / 2)
	for _, part in workspace:GetPartBoundsInBox(box, size, overlapParams) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and not hitThisSlide[model] then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				hitThisSlide[model] = true
				Net.remote("SlideHit"):FireServer(model)
			end
		end
	end
end

-- Turns the slide toward where the player is steering, limited by TurnRate.
local function steer(wanted: Vector3, dt: number)
	if wanted == Vector3.zero then
		return
	end
	local angle = math.acos(math.clamp(slideDirection:Dot(wanted), -1, 1))
	if angle < 1e-3 then
		return
	end
	local turn = math.min(angle, Config.Slide.TurnRate * dt)
	local side = if slideDirection:Cross(wanted).Y >= 0 then 1 else -1
	slideDirection = CFrame.Angles(0, side * turn, 0):VectorToWorldSpace(slideDirection)
end

local function update(dt: number)
	if not sliding then
		-- Still holding from a press that happened in the air: slide as soon as we land.
		if next(held) ~= nil and not slidSincePress and os.clock() - pressedAt < PRESS_BUFFER then
			startSlide()
		end
		return
	end

	local character, humanoid, root = getCharacter()
	if not character or not humanoid or not root or not slideVelocity or not slideAlign then
		stopSlide()
		return
	end
	local elapsed = os.clock() - slideStart
	airTime = if humanoid.FloorMaterial == Enum.Material.Air then airTime + dt else 0
	local released = next(held) == nil and elapsed >= Config.Slide.MinTime
	if released or elapsed >= Config.Slide.MaxTime or airTime > AIR_GRACE then
		stopSlide()
		return
	end

	steer(flatUnit(humanoid.MoveDirection), dt)
	slideSpeed = math.max(Config.Slide.MinSpeed, slideSpeed - Config.Slide.Deceleration * dt)
	slideVelocity.PlaneVelocity = Vector2.new(slideDirection.X, slideDirection.Z) * slideSpeed
	slideAlign.CFrame = CFrame.lookAt(Vector3.zero, slideDirection)
	checkHits(character, root)
end

local function onKnockback(velocity: unknown, downTime: unknown)
	if typeof(velocity) ~= "Vector3" or typeof(downTime) ~= "number" then
		return
	end
	local _, humanoid, root = getCharacter()
	if not humanoid or not root then
		return
	end
	stopSlide()
	downUntil = os.clock() + downTime
	humanoid.PlatformStand = true
	root.AssemblyLinearVelocity = velocity
	root.AssemblyAngularVelocity = Vector3.new(math.random() * 8 - 4, 0, math.random() * 8 - 4)
	task.delay(downTime, function()
		if os.clock() >= downUntil - 0.01 and humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

function SlideController.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local key = holdKey(input)
		if key == nil then
			return
		end
		held[key] = true
		pressedAt = os.clock()
		slidSincePress = false
		startSlide()
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local key = holdKey(input)
		if key ~= nil then
			held[key] = nil
		end
	end)
	UserInputService.WindowFocusReleased:Connect(function()
		table.clear(held)
	end)

	player.CharacterAdded:Connect(function()
		-- The old character took the slide constraints with it.
		sliding = false
		slideAttachment, slideVelocity, slideAlign = nil, nil, nil
		downUntil = 0
	end)

	Net.remote("Knockback").OnClientEvent:Connect(onKnockback)
	RunService.Heartbeat:Connect(update)
end

return SlideController
