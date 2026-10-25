--!strict
-- Turns Zoro's coded animations into real KeyframeSequences, so you can open, polish and publish them
-- in Eclipse Animator, Moon Animator or Roblox's Animation Editor.
--
-- In Studio (edit mode, not playing), paste this into the command bar:
--   require(game.ServerStorage.Dev.ExportAnimations)()
-- That builds an R15 rig called "ZoroAnimRig" with every clip saved in its AnimSaves. To use your own
-- R15 rig instead (e.g. from Avatar > Rig Builder), pass it in:
--   require(game.ServerStorage.Dev.ExportAnimations)(workspace.Rig)
-- Then select the rig in your animation plugin, load a clip, edit it, publish it, and paste the id
-- into that move's AnimationId in ReplicatedStorage.Shared.Characters.Zoro.
local StarterPlayer = game:GetService("StarterPlayer")

local Client = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("Client")
local MoveAnimator = require(Client.Controllers.MoveAnimator)
local Rig = require(Client.Util.Rig)
local Clips = require(Client.Animations.Zoro)

local SPIN_STEP = 0.05 -- spins are written as a keyframe every this many seconds
local PREFIX = "Zoro_"

-- Clip -> the body part each joint moves, and each part's parent in the pose tree.
local JOINT_PART: { [string]: string } = {
	Root = "LowerTorso",
	Waist = "UpperTorso",
	Neck = "Head",
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	LeftShoulder = "LeftUpperArm",
	LeftElbow = "LeftLowerArm",
	RightHip = "RightUpperLeg",
	RightKnee = "RightLowerLeg",
	LeftHip = "LeftUpperLeg",
	LeftKnee = "LeftLowerLeg",
}
local PARENT_PART: { [string]: string } = {
	LowerTorso = "HumanoidRootPart",
	UpperTorso = "LowerTorso",
	Head = "UpperTorso",
	RightUpperArm = "UpperTorso",
	RightLowerArm = "RightUpperArm",
	LeftUpperArm = "UpperTorso",
	LeftLowerArm = "LeftUpperArm",
	RightUpperLeg = "LowerTorso",
	RightLowerLeg = "RightUpperLeg",
	LeftUpperLeg = "LowerTorso",
	LeftLowerLeg = "LeftUpperLeg",
}

-- A plain R15 block rig: the right part names and joints, which is all an animation editor needs.
type RigPart = {
	name: string,
	size: Vector3,
	position: Vector3,
	joint: string?, -- the Motor6D that attaches it to its parent part
	parent: string?,
	at: Vector3?, -- where that joint pivots
}

local function part(
	name: string,
	size: Vector3,
	position: Vector3,
	joint: string?,
	parent: string?,
	at: Vector3?
): RigPart
	return { name = name, size = size, position = position, joint = joint, parent = parent, at = at }
end

local RIG_PARTS: { RigPart } = {
	part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0)),
	part(
		"LowerTorso",
		Vector3.new(2, 0.4, 1),
		Vector3.new(0, 2.8, 0),
		"Root",
		"HumanoidRootPart",
		Vector3.new(0, 2.8, 0)
	),
	part("UpperTorso", Vector3.new(2, 1.6, 1), Vector3.new(0, 3.8, 0), "Waist", "LowerTorso", Vector3.new(0, 3, 0)),
	part("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 5.2, 0), "Neck", "UpperTorso", Vector3.new(0, 4.6, 0)),
	part(
		"RightUpperArm",
		Vector3.new(1, 1.2, 1),
		Vector3.new(1.5, 4, 0),
		"RightShoulder",
		"UpperTorso",
		Vector3.new(1.5, 4.6, 0)
	),
	part(
		"RightLowerArm",
		Vector3.new(1, 1.1, 1),
		Vector3.new(1.5, 2.85, 0),
		"RightElbow",
		"RightUpperArm",
		Vector3.new(1.5, 3.4, 0)
	),
	part(
		"RightHand",
		Vector3.new(1, 0.4, 1),
		Vector3.new(1.5, 2.1, 0),
		"RightWrist",
		"RightLowerArm",
		Vector3.new(1.5, 2.3, 0)
	),
	part(
		"LeftUpperArm",
		Vector3.new(1, 1.2, 1),
		Vector3.new(-1.5, 4, 0),
		"LeftShoulder",
		"UpperTorso",
		Vector3.new(-1.5, 4.6, 0)
	),
	part(
		"LeftLowerArm",
		Vector3.new(1, 1.1, 1),
		Vector3.new(-1.5, 2.85, 0),
		"LeftElbow",
		"LeftUpperArm",
		Vector3.new(-1.5, 3.4, 0)
	),
	part(
		"LeftHand",
		Vector3.new(1, 0.4, 1),
		Vector3.new(-1.5, 2.1, 0),
		"LeftWrist",
		"LeftLowerArm",
		Vector3.new(-1.5, 2.3, 0)
	),
	part(
		"RightUpperLeg",
		Vector3.new(1, 1.15, 1),
		Vector3.new(0.5, 2.025, 0),
		"RightHip",
		"LowerTorso",
		Vector3.new(0.5, 2.6, 0)
	),
	part(
		"RightLowerLeg",
		Vector3.new(1, 1.15, 1),
		Vector3.new(0.5, 0.875, 0),
		"RightKnee",
		"RightUpperLeg",
		Vector3.new(0.5, 1.45, 0)
	),
	part(
		"RightFoot",
		Vector3.new(1, 0.3, 1),
		Vector3.new(0.5, 0.15, 0),
		"RightAnkle",
		"RightLowerLeg",
		Vector3.new(0.5, 0.3, 0)
	),
	part(
		"LeftUpperLeg",
		Vector3.new(1, 1.15, 1),
		Vector3.new(-0.5, 2.025, 0),
		"LeftHip",
		"LowerTorso",
		Vector3.new(-0.5, 2.6, 0)
	),
	part(
		"LeftLowerLeg",
		Vector3.new(1, 1.15, 1),
		Vector3.new(-0.5, 0.875, 0),
		"LeftKnee",
		"LeftUpperLeg",
		Vector3.new(-0.5, 1.45, 0)
	),
	part(
		"LeftFoot",
		Vector3.new(1, 0.3, 1),
		Vector3.new(-0.5, 0.15, 0),
		"LeftAnkle",
		"LeftLowerLeg",
		Vector3.new(-0.5, 0.3, 0)
	),
}

local function buildRig(origin: CFrame): Model
	local rig = Instance.new("Model")
	rig.Name = "ZoroAnimRig"
	local parts: { [string]: BasePart } = {}
	for _, spec in RIG_PARTS do
		local part = Instance.new("Part")
		part.Name = spec.name
		part.Size = spec.size
		part.CFrame = origin * CFrame.new(spec.position)
		part.Color = Color3.fromRGB(163, 162, 165)
		part.Anchored = part.Name == "HumanoidRootPart"
		part.CanCollide = false
		part.Transparency = if part.Name == "HumanoidRootPart" then 1 else 0
		part.Parent = rig
		parts[part.Name] = part
	end
	for _, spec in RIG_PARTS do
		local jointName, parentName, at = spec.joint, spec.parent, spec.at
		if jointName and parentName and at then
			local part1 = parts[spec.name]
			local part0 = parts[parentName]
			local jointWorld = origin * CFrame.new(at)
			local motor = Instance.new("Motor6D")
			motor.Name = jointName
			motor.Part0 = part0
			motor.Part1 = part1
			motor.C0 = part0.CFrame:ToObjectSpace(jointWorld)
			motor.C1 = part1.CFrame:ToObjectSpace(jointWorld)
			motor.Parent = part1
		end
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	Instance.new("Animator").Parent = humanoid
	humanoid.Parent = rig
	rig.PrimaryPart = parts.HumanoidRootPart
	rig.Parent = workspace
	return rig
end

-- Every time a keyframe is needed: the clip's keyframes, extra ones through spins, and the end.
local function keyframeTimes(clip: MoveAnimator.Clip): { number }
	local times: { number } = {}
	for _, keyframe in clip.keyframes do
		table.insert(times, keyframe.time)
	end
	local spin = clip.spin
	if spin then
		local t = spin.from
		while t < spin.to do
			table.insert(times, t)
			t += SPIN_STEP
		end
		table.insert(times, spin.to)
	end
	table.insert(times, clip.length)
	table.sort(times)
	local unique: { number } = {}
	for _, t in times do
		if #unique == 0 or t - unique[#unique] > 1e-3 then
			table.insert(unique, t)
		end
	end
	return unique
end

local function buildSequence(name: string, clip: MoveAnimator.Clip, joints: { [string]: Rig.Joint }): KeyframeSequence
	local sequence = Instance.new("KeyframeSequence")
	sequence.Name = PREFIX .. name
	sequence.Loop = false
	sequence.Priority = Enum.AnimationPriority.Action

	local used: { [string]: boolean } = {}
	for _, keyframe in clip.keyframes do
		for jointName in keyframe.pose do
			used[jointName] = true
		end
	end
	if clip.spin then
		used.Root = true
	end

	for _, t in keyframeTimes(clip) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = t
		local poses: { [string]: Pose } = {}
		local function poseFor(partName: string): Pose
			local existing = poses[partName]
			if existing then
				return existing
			end
			local pose = Instance.new("Pose")
			pose.Name = partName
			pose.Weight = 1
			-- Pose easing "In" decelerates into the next keyframe: the snappy anime feel of the coded clips.
			pose.EasingStyle = Enum.PoseEasingStyle.Cubic
			pose.EasingDirection = Enum.PoseEasingDirection.In
			local parentName = PARENT_PART[partName]
			pose.Parent = if parentName then poseFor(parentName) else keyframe
			poses[partName] = pose
			return pose
		end
		for jointName in used do
			local joint = joints[jointName]
			local partName = JOINT_PART[jointName]
			if joint and partName then
				local value = MoveAnimator.sample(clip, t, jointName)
				local spin = clip.spin
				if spin and jointName == "Root" then
					value = CFrame.Angles(0, spin.rate * math.clamp(t - spin.from, 0, spin.to - spin.from), 0) * value
				end
				poseFor(partName).CFrame = Rig.toJointSpace(joint, value)
			end
		end
		keyframe.Parent = sequence
	end
	return sequence
end

return function(existingRig: Model?): Model
	local rig = existingRig or buildRig(CFrame.new(0, 0, 60))
	local joints = Rig.findJoints(rig)
	if Rig.isR6(rig) or not joints.Root then
		error("ExportAnimations needs an R15 rig (Avatar tab > Rig Builder > R15).")
	end

	local saves: Instance = rig:FindFirstChild("AnimSaves") or Instance.new("Model")
	saves.Name = "AnimSaves"
	saves.Parent = rig
	local count = 0
	for name, clip in Clips :: { [string]: MoveAnimator.Clip } do
		local old = saves:FindFirstChild(PREFIX .. name)
		if old then
			old:Destroy()
		end
		buildSequence(name, clip, joints).Parent = saves
		count += 1
	end
	print(`[ExportAnimations] saved {count} Zoro animations into {rig:GetFullName()}.AnimSaves`)
	return rig
end
