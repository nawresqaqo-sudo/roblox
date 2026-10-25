--!strict
-- Finds a character's animation joints and turns poses into joint transforms, for everything that
-- animates in code. Poses are rotations in each joint's parent part space (character faces -Z):
--   Shoulder/Hip +X swings the limb forward; Elbow +X bends it; Knee -X bends it.
--   Right shoulder +Z raises the arm out to the side (left shoulder uses -Z).
--   Root/Waist -X leans forward, +Y turns left, CFrame.new(0, -y, 0) on Root crouches.
local Rig = {}

export type Joint = {
	motor: Motor6D,
	rotation: CFrame,
	inverse: CFrame,
}

export type Pose = { [string]: CFrame }

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

function Rig.isR6(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.RigType == Enum.HumanoidRigType.R6
end

function Rig.findJoints(character: Model): { [string]: Joint }
	local map: { [string]: { string } } = if Rig.isR6(character) then R6_JOINTS else R15_JOINTS
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

-- Joints get replaced when an avatar finishes loading; true means look them up again.
function Rig.isStale(joints: { [string]: Joint }): boolean
	if next(joints) == nil then
		return true
	end
	for _, joint in joints do
		if not joint.motor.Parent then
			return true
		end
	end
	return false
end

function Rig.toJointSpace(joint: Joint, pose: CFrame): CFrame
	return joint.inverse * pose * joint.rotation
end

-- Where a joint pivots in the world right now.
function Rig.pivot(joint: Joint): CFrame?
	local part0 = joint.motor.Part0
	if not part0 then
		return nil
	end
	return part0.CFrame * joint.motor.C0
end

function Rig.part(character: Instance?, names: { string }): BasePart?
	if not character then
		return nil
	end
	for _, name in names do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- The middle of the fist: -Z points the way a held blade would, -Y toward the fingers.
function Rig.hand(character: Model, side: "Left" | "Right"): CFrame?
	local hand = Rig.part(character, { side .. "Hand" })
	if hand then
		return hand.CFrame
	end
	local arm = Rig.part(character, { side .. " Arm" })
	if arm then
		return arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)
	end
	return nil
end

-- The hips, where swords hang.
function Rig.hip(character: Model): CFrame?
	local lower = Rig.part(character, { "LowerTorso" })
	if lower then
		return lower.CFrame
	end
	local torso = Rig.part(character, { "Torso" })
	if torso then
		return torso.CFrame * CFrame.new(0, -0.8, 0)
	end
	return nil
end

-- Parts that make up one arm, shoulder to hand.
function Rig.armParts(character: Model, side: "Left" | "Right"): { BasePart }
	local parts: { BasePart } = {}
	for _, name in { side .. "UpperArm", side .. "LowerArm", side .. "Hand", side .. " Arm" } do
		local part = Rig.part(character, { name })
		if part then
			table.insert(parts, part)
		end
	end
	return parts
end

return Rig
