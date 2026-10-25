--!strict
-- Custom animations made in code instead of uploaded animation assets: a sprint, a feet-first slide,
-- and a flail when you get launched. Characters lean into turns. Sliding characters get a dust
-- trail, a speed streak and a wind sound. Every client animates every character this way, so
-- everyone sees it on everyone. Works on R15 (full body) and R6 (no elbows, knees or waist).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Sfx = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Sfx"))
local SlideController = require(script.Parent.SlideController)

local TAU = math.pi * 2
local DUST_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"
local RESCAN_INTERVAL = 0.5
local FLAIL_SPEED = 16 -- radians per second of arm windmilling
local FALLING_FLAIL_SPEED = -45 -- falling faster than this makes anyone flail

type Joint = {
	motor: Motor6D,
	rotation: CFrame,
	inverse: CFrame,
}

-- Joint name -> how that joint should be rotated, in its parent part's space.
-- +X swings a limb forward (or bends an elbow); -X leans a torso forward (or bends a knee);
-- +Z on the Root leans the body left.
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
	flail: number,
	phase: number,
	flailPhase: number,
	bank: number,
	lastLook: Vector3,
	wasSliding: boolean,
	dust: ParticleEmitter,
	trail: Trail,
	wind: Sound?,
	extras: { Instance },
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

-- Sprint: forward lean, big arm pumps, high knees, a little bounce and upper-body twist.
local function runPose(phase: number, amount: number, bank: number): Pose
	local s = math.sin(phase)
	local c = math.cos(phase)
	return {
		Root = CFrame.Angles(0, 0, bank)
			* CFrame.new(0, 0.18 * math.abs(s) - 0.08, 0)
			* CFrame.Angles(-0.25, s * 0.08, 0),
		Waist = CFrame.Angles(-0.08, -s * 0.25 * amount, 0),
		Neck = CFrame.Angles(0.22, s * 0.12, -bank * 0.5),
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

-- Feet-first slide: body dropped low and leaning back, lead leg out, back leg tucked, one hand
-- trailing on the ground, the other arm up for balance. Leans into steering.
local function slidePose(t: number, bank: number): Pose
	local sway = math.sin(t * 9) * 0.06
	return {
		Root = CFrame.Angles(0, 0, bank * 1.4) * CFrame.new(0, -1.1, 0) * CFrame.Angles(1.15, 0, 0),
		Waist = CFrame.Angles(-0.35, 0, bank * 0.4),
		Neck = CFrame.Angles(-0.5, 0, -bank * 0.6),
		RightHip = CFrame.Angles(0.25, 0, 0),
		RightKnee = CFrame.Angles(-0.1, 0, 0),
		LeftHip = CFrame.Angles(0.75, 0, -0.15),
		LeftKnee = CFrame.Angles(-1.6, 0, 0),
		LeftShoulder = CFrame.Angles(-0.7 + sway, 0, -0.7),
		LeftElbow = CFrame.Angles(0.3, 0, 0),
		RightShoulder = CFrame.Angles(1.8 - sway, 0, 0.35),
		RightElbow = CFrame.Angles(0.5 + sway, 0, 0),
	}
end

-- Launched: arms windmilling, legs kicking, back arched.
local function flailPose(phase: number): Pose
	local s = math.sin(phase * 0.8)
	local c = math.cos(phase * 0.8)
	return {
		Root = CFrame.Angles(0.3, 0, 0),
		Waist = CFrame.Angles(0.25 + 0.1 * s, 0, 0),
		Neck = CFrame.Angles(0.35, 0.3 * s, 0),
		LeftShoulder = CFrame.Angles(phase, 0, -1.1),
		RightShoulder = CFrame.Angles(math.pi - phase, 0, 1.1),
		LeftElbow = CFrame.Angles(0.4 + 0.3 * c, 0, 0),
		RightElbow = CFrame.Angles(0.4 - 0.3 * c, 0, 0),
		LeftHip = CFrame.Angles(0.3 + 0.7 * s, 0, -0.25),
		RightHip = CFrame.Angles(0.3 - 0.7 * s, 0, 0.25),
		LeftKnee = CFrame.Angles(-0.8 - 0.5 * c, 0, 0),
		RightKnee = CFrame.Angles(-0.8 + 0.5 * c, 0, 0),
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

local function flatUnit(vector: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.zero
end

local function approach(current: number, goal: number, rate: number, dt: number): number
	return current + (goal - current) * math.min(1, rate * dt)
end

local function attachmentAt(root: BasePart, name: string, y: number): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Name = name
	attachment.Position = Vector3.new(0, y, 0)
	attachment.Parent = root
	return attachment
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

	local ground = if humanoid.RigType == Enum.HumanoidRigType.R6 then -3 else -(root.Size.Y / 2 + humanoid.HipHeight)

	local dustAttachment = attachmentAt(root, "SlideDust", ground + 0.3)
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = DUST_TEXTURE
	dust.Color = ColorSequence.new(Color3.fromRGB(225, 220, 210))
	dust.Transparency = NumberSequence.new(0.35, 1)
	dust.Size = NumberSequence.new(0.8, 2.8)
	dust.Lifetime = NumberRange.new(0.35, 0.6)
	dust.Rate = 50
	dust.Speed = NumberRange.new(2, 6)
	dust.SpreadAngle = Vector2.new(35, 35)
	dust.EmissionDirection = Enum.NormalId.Back
	dust.Acceleration = Vector3.new(0, 3, 0)
	dust.Enabled = false
	dust.Parent = dustAttachment

	-- A ribbon from the feet to the waist that streaks behind you while sliding or flying.
	local low = attachmentAt(root, "TrailLow", ground + 0.3)
	local high = attachmentAt(root, "TrailHigh", ground + 1.9)
	local trail = Instance.new("Trail")
	trail.Attachment0 = low
	trail.Attachment1 = high
	trail.Lifetime = 0.3
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 210, 255))
	trail.Transparency = NumberSequence.new(0.5, 1)
	trail.LightEmission = 0.6
	trail.Enabled = false
	trail.Parent = root

	local wind = Sfx.make(Config.Sounds.SlideLoop, root, 0, 1.3)
	if wind then
		wind.Looped = true
	end
	local extras: { Instance } = { dustAttachment, low, high, trail }
	if wind then
		table.insert(extras, wind)
	end

	rigs[character] = {
		character = character,
		humanoid = humanoid,
		root = root,
		joints = findJoints(character, humanoid),
		nextScan = 0,
		isLocal = isLocal,
		run = 0,
		slide = 0,
		flail = 0,
		phase = 0,
		flailPhase = 0,
		bank = 0,
		lastLook = Vector3.zero,
		wasSliding = false,
		dust = dust,
		trail = trail,
		wind = wind,
		extras = extras,
	}
end

local function removeCharacter(character: Model)
	local rig = rigs[character]
	if rig then
		for _, instance in rig.extras do
			instance:Destroy()
		end
		rigs[character] = nil
	end
end

local function updateEffects(rig: Rig, speed: number)
	rig.dust.Enabled = rig.slide > 0.5
	rig.trail.Enabled = rig.slide > 0.5 or (rig.flail > 0.5 and speed > 25)
	local wind = rig.wind
	if wind then
		local volume = 0.6 * rig.slide + 0.4 * rig.flail
		wind.Volume = volume
		if volume > 0.02 and not wind.IsPlaying then
			wind:Play()
		elseif volume <= 0.02 and wind.IsPlaying then
			wind:Stop()
		end
	end
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
	if isSliding and not rig.wasSliding then
		Sfx.playAt(Config.Sounds.SlideStart, root.Position, 0.7, 0.8)
	end
	rig.wasSliding = isSliding

	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local flailing = isDown or velocity.Y < FALLING_FLAIL_SPEED
	local running = not isSliding and not flailing and speed > 2.5 and math.abs(velocity.Y) < 12

	rig.run = approach(rig.run, if running then 1 else 0, 10, dt)
	rig.slide = approach(rig.slide, if isSliding and not flailing then 1 else 0, 14, dt)
	rig.flail = approach(rig.flail, if flailing then 1 else 0, 12, dt)
	updateEffects(rig, speed)

	-- Lean into turns: how fast the character is turning, smoothed.
	local look = flatUnit(root.CFrame.LookVector)
	if dt > 0 and rig.lastLook ~= Vector3.zero and look ~= Vector3.zero then
		local turnRate = math.asin(math.clamp(rig.lastLook:Cross(look).Y, -1, 1)) / dt
		rig.bank = approach(rig.bank, math.clamp(turnRate * Config.Animation.TurnLean, -0.4, 0.4), 8, dt)
	end
	rig.lastLook = look

	if rig.run < 0.01 and rig.slide < 0.01 and rig.flail < 0.01 then
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
	if flailing then
		rig.flailPhase = (rig.flailPhase + dt * FLAIL_SPEED) % TAU
	end

	local amount = math.clamp(speed / 16, 0.4, 1.2) * Config.Animation.RunAmount
	local layers: { { pose: Pose, weight: number } } = {
		{ pose = runPose(rig.phase, amount, rig.bank), weight = rig.run },
		{ pose = slidePose(now, rig.bank), weight = rig.slide },
		{ pose = flailPose(rig.flailPhase), weight = rig.flail },
	}
	for name, joint in rig.joints do
		-- Transform already holds this frame's normal animation; blend our poses over it.
		local transform = joint.motor.Transform
		for _, layer in layers do
			local target = layer.pose[name]
			if target and layer.weight > 0.01 then
				transform = transform:Lerp(toJointSpace(joint, target), layer.weight)
			end
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
