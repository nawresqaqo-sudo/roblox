--!strict
-- Custom run and slide animations, made in code instead of uploaded animation assets.
-- Every client animates every character this way, so everyone sees them on everyone.
-- Works on R15 (full body) and R6 (no elbows, knees or waist on that rig).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local SlideController = require(script.Parent.SlideController)

local TAU = math.pi * 2
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local RESCAN_INTERVAL = 0.5

type Joint = {
	motor: Motor6D,
	rotation: CFrame,
	inverse: CFrame,
}

-- Joint name -> how that joint should be rotated, in its parent part's space.
-- +X swings a limb forward (or bends an elbow); -X leans a torso forward (or bends a knee).
type Pose = { [string]: CFrame }

type Rig = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	joints: { [string]: Joint },
	nextScan: number,
	isLocal: boolean,
	run: number,
	slide: number,
	phase: number,
	dustAttachment: Attachment,
	dust: ParticleEmitter,
}

-- Joint name -> { part holding the Motor6D, Motor6D name }
local R15_JOINTS: { [string]: { string } } = {
	Root = { "LowerTorso", "Root" },
	Waist = { "UpperTorso", "Waist" },
	Neck = { "Head", "Neck" },
	LeftShoulder = { "LeftUpperArm", "LeftShoulder" },
	RightShoulder = { "RightUpperArm", "RightShoulder" },
	LeftElbow = { "LeftLowerArm", "LeftElbow" },
	RightElbow = { "RightLowerArm", "RightElbow" },
	LeftHip = { "LeftUpperLeg", "LeftHip" },
	RightHip = { "RightUpperLeg", "RightHip" },
	LeftKnee = { "LeftLowerLeg", "LeftKnee" },
	RightKnee = { "RightLowerLeg", "RightKnee" },
}
local R6_JOINTS: { [string]: { string } } = {
	Root = { "HumanoidRootPart", "RootJoint" },
	Neck = { "Torso", "Neck" },
	LeftShoulder = { "Torso", "Left Shoulder" },
	RightShoulder = { "Torso", "Right Shoulder" },
	LeftHip = { "Torso", "Left Hip" },
	RightHip = { "Torso", "Right Hip" },
}

-- Feet-first slide: body dropped low and leaning back, lead leg out, back leg tucked, one hand down.
local SLIDE_POSE: Pose = {
	Root = CFrame.new(0, -1.1, 0) * CFrame.Angles(1.15, 0, 0),
	Waist = CFrame.Angles(-0.35, 0, 0),
	Neck = CFrame.Angles(-0.5, 0, 0),
	RightHip = CFrame.Angles(0.25, 0, 0),
	RightKnee = CFrame.Angles(-0.1, 0, 0),
	LeftHip = CFrame.Angles(0.75, 0, -0.15),
	LeftKnee = CFrame.Angles(-1.6, 0, 0),
	LeftShoulder = CFrame.Angles(-0.7, 0, -0.7),
	LeftElbow = CFrame.Angles(0.3, 0, 0),
	RightShoulder = CFrame.Angles(1.8, 0, 0.35),
	RightElbow = CFrame.Angles(0.5, 0, 0),
}

-- Sprint: forward lean, big arm pumps, high knees, a little bounce and upper-body twist.
local function runPose(phase: number, amount: number): Pose
	local s = math.sin(phase)
	local c = math.cos(phase)
	return {
		Root = CFrame.new(0, 0.18 * math.abs(s) - 0.08, 0) * CFrame.Angles(-0.25, s * 0.08, 0),
		Waist = CFrame.Angles(-0.08, -s * 0.25 * amount, 0),
		Neck = CFrame.Angles(0.22, s * 0.12, 0),
		LeftHip = CFrame.Angles(s * 0.95 * amount, 0, 0),
		RightHip = CFrame.Angles(-s * 0.95 * amount, 0, 0),
		-- A knee bends most while its leg swings forward.
		LeftKnee = CFrame.Angles(-(0.25 + 1.3 * math.max(0, c)) * amount, 0, 0),
		RightKnee = CFrame.Angles(-(0.25 + 1.3 * math.max(0, -c)) * amount, 0, 0),
		LeftShoulder = CFrame.Angles(-s * 0.9 * amount, 0, -0.08),
		RightShoulder = CFrame.Angles(s * 0.9 * amount, 0, 0.08),
		LeftElbow = CFrame.Angles(1.1 + 0.25 * s, 0, 0),
		RightElbow = CFrame.Angles(1.1 - 0.25 * s, 0, 0),
	}
end

local CharacterAnimator = {}

local rigs: { [Model]: Rig } = {}

local function findJoints(character: Model, humanoid: Humanoid): { [string]: Joint }
	local map: { [string]: { string } } = if humanoid.RigType == Enum.HumanoidRigType.R6 then R6_JOINTS else R15_JOINTS
	local joints: { [string]: Joint } = {}
	for name, path in map do
		local part = character:FindFirstChild(path[1])
		local motor = part and part:FindFirstChild(path[2])
		if motor and motor:IsA("Motor6D") then
			local rotation = motor.C0.Rotation
			joints[name] = { motor = motor, rotation = rotation, inverse = rotation:Inverse() }
		end
	end
	return joints
end

-- Joints get replaced when an avatar finishes loading, so look them up again when that happens.
local function jointsAreStale(rig: Rig): boolean
	if next(rig.joints) == nil then
		return true
	end
	for _, joint in rig.joints do
		if not joint.motor.Parent then
			return true
		end
	end
	return false
end

-- Converts a pose rotation (in the parent part's space) into the joint's own Transform space.
local function toJointSpace(joint: Joint, pose: CFrame): CFrame
	return joint.inverse * pose * joint.rotation
end

local function makeDust(root: BasePart, humanoid: Humanoid): (Attachment, ParticleEmitter)
	local groundOffset = if humanoid.RigType == Enum.HumanoidRigType.R6
		then -3
		else -(root.Size.Y / 2 + humanoid.HipHeight)
	local attachment = Instance.new("Attachment")
	attachment.Name = "SlideDust"
	attachment.Position = Vector3.new(0, groundOffset + 0.3, 0)

	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(225, 220, 210))
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.Size = NumberSequence.new(0.8, 2.6)
	dust.Lifetime = NumberRange.new(0.35, 0.6)
	dust.Rate = 45
	dust.Speed = NumberRange.new(2, 5)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.EmissionDirection = Enum.NormalId.Back
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Enabled = false
	dust.Parent = attachment
	attachment.Parent = root
	return attachment, dust
end

local function addCharacter(character: Model, isLocal: boolean)
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	if not character.Parent then
		return
	end
	local dustAttachment, dust = makeDust(root, humanoid)
	rigs[character] = {
		character = character,
		humanoid = humanoid,
		root = root,
		joints = findJoints(character, humanoid),
		nextScan = 0,
		isLocal = isLocal,
		run = 0,
		slide = 0,
		phase = 0,
		dustAttachment = dustAttachment,
		dust = dust,
	}
end

local function removeCharacter(character: Model)
	local rig = rigs[character]
	if rig then
		rig.dustAttachment:Destroy()
		rigs[character] = nil
	end
end

local function approach(current: number, goal: number, rate: number, dt: number): number
	return current + (goal - current) * math.min(1, rate * dt)
end

local function updateRig(rig: Rig, dt: number)
	local humanoid, root = rig.humanoid, rig.root
	if humanoid.Health <= 0 or not root.Parent then
		return
	end

	local isSliding, isDown
	if rig.isLocal then
		isSliding, isDown = SlideController.isSliding(), SlideController.isDown()
	else
		isSliding = rig.character:GetAttribute("Sliding") == true
		isDown = rig.character:GetAttribute("Down") == true
	end
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local running = not isSliding and not isDown and speed > 2.5 and math.abs(velocity.Y) < 12

	rig.run = approach(rig.run, if running then 1 else 0, 10, dt)
	rig.slide = approach(rig.slide, if isSliding and not isDown then 1 else 0, 14, dt)
	rig.dust.Enabled = rig.slide > 0.5
	if rig.run < 0.01 and rig.slide < 0.01 then
		return -- leave the normal Roblox animations alone
	end

	local now = os.clock()
	if now >= rig.nextScan and jointsAreStale(rig) then
		rig.joints = findJoints(rig.character, humanoid)
		rig.nextScan = now + RESCAN_INTERVAL
	end
	if running then
		rig.phase = (rig.phase + dt * math.min(speed, 40) * Config.Animation.RunStrideRate) % TAU
	end
	local amount = math.clamp(speed / 16, 0.4, 1.2) * Config.Animation.RunAmount
	local run = runPose(rig.phase, amount)

	for name, joint in rig.joints do
		-- Transform already holds this frame's normal animation; blend our poses over it.
		local transform = joint.motor.Transform
		local runTarget = run[name]
		if runTarget and rig.run > 0.01 then
			transform = transform:Lerp(toJointSpace(joint, runTarget), rig.run)
		end
		local slideTarget = SLIDE_POSE[name]
		if slideTarget and rig.slide > 0.01 then
			transform = transform:Lerp(toJointSpace(joint, slideTarget), rig.slide)
		end
		joint.motor.Transform = transform
	end
end

local function watchPlayer(other: Player)
	local isLocal = other == Players.LocalPlayer
	other.CharacterAdded:Connect(function(character)
		addCharacter(character, isLocal)
	end)
	other.CharacterRemoving:Connect(removeCharacter)
	if other.Character then
		task.spawn(addCharacter, other.Character, isLocal)
	end
end

function CharacterAnimator.start()
	Players.PlayerAdded:Connect(watchPlayer)
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end

	-- Stepped runs after Roblox's animations each frame, so what we write here is what gets drawn.
	RunService.Stepped:Connect(function(_time: number, dt: number)
		for character, rig in rigs do
			if character.Parent then
				updateRig(rig, dt)
			else
				removeCharacter(character)
			end
		end
	end)
end

return CharacterAnimator
