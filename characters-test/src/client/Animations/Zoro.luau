--!strict
-- Zoro's animations, made in code as keyframed poses (see Controllers/MoveAnimator and Util/Rig for
-- how poses work). Times line up with the numbers in Shared.Characters.Zoro.Tuning.
-- Made a real animation in Eclipse/Moon Animator? Put its id in that move's AnimationId and the
-- coded clip is skipped for it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Parent.Parent:WaitForChild("Controllers")
local MoveAnimator = require(Controllers:WaitForChild("MoveAnimator"))
local ZoroData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Characters"):WaitForChild("Zoro"))

type Clip = MoveAnimator.Clip

local Tuning = ZoroData.Tuning
local A = CFrame.Angles
local Quart = Enum.EasingStyle.Quart
local Back = Enum.EasingStyle.Back

-- Arm helper: raise the arm forward by `forward`, then swing it around the body by `turn`
-- (positive turns toward the character's left).
local function arm(forward: number, turn: number, outward: number?): CFrame
	return A(0, turn, 0) * A(forward, 0, outward or 0)
end

local NEUTRAL = {
	Root = CFrame.identity,
	Waist = CFrame.identity,
	Neck = CFrame.identity,
	RightShoulder = CFrame.identity,
	LeftShoulder = CFrame.identity,
	RightElbow = CFrame.identity,
	LeftElbow = CFrame.identity,
	RightHip = CFrame.identity,
	LeftHip = CFrame.identity,
	RightKnee = CFrame.identity,
	LeftKnee = CFrame.identity,
}

local Clips = {}

-- 1: Onigiri. Crouch with all three blades crossed in front, burst forward with the arms flung wide,
-- then stand behind the target with the blades swept back.
do
	local t = Tuning.Onigiri
	local crossed = {
		Root = CFrame.new(0, -0.95, 0) * A(-0.45, 0, 0),
		Waist = A(-0.15, 0, 0),
		Neck = A(0.4, 0, 0),
		RightShoulder = arm(1.3, 0.95),
		RightElbow = A(1.6, 0, 0),
		LeftShoulder = arm(1.3, -0.95),
		LeftElbow = A(1.6, 0, 0),
		RightHip = A(1.05, 0, 0.1),
		RightKnee = A(-1.45, 0, 0),
		LeftHip = A(-0.5, 0, -0.1),
		LeftKnee = A(-1.1, 0, 0),
	}
	local dash = {
		Root = CFrame.new(0, -0.7, 0) * A(-0.65, 0, 0),
		Waist = A(-0.1, 0, 0),
		Neck = A(0.5, 0, 0),
		RightShoulder = arm(1.45, -1.25),
		RightElbow = A(0.15, 0, 0),
		LeftShoulder = arm(1.45, 1.25),
		LeftElbow = A(0.15, 0, 0),
		RightHip = A(0.9, 0, 0),
		RightKnee = A(-0.6, 0, 0),
		LeftHip = A(-0.9, 0, 0),
		LeftKnee = A(-0.4, 0, 0),
	}
	local after = {
		Root = CFrame.new(0, -0.55, 0) * A(-0.2, 0, 0),
		Waist = A(0.05, 0, 0),
		Neck = A(0.1, 0, 0),
		RightShoulder = A(-0.55, 0, 0.6),
		RightElbow = A(0.15, 0, 0),
		LeftShoulder = A(-0.55, 0, -0.6),
		LeftElbow = A(0.15, 0, 0),
		RightHip = A(0.3, 0, 0.25),
		RightKnee = A(-0.5, 0, 0),
		LeftHip = A(-0.3, 0, -0.25),
		LeftKnee = A(-0.4, 0, 0),
	}
	Clips.Onigiri = {
		length = t.Windup + t.DashTime + 0.6,
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = 0.12, pose = crossed, ease = Back },
			{ time = t.Windup, pose = crossed },
			{ time = t.Windup + 0.05, pose = dash, ease = Quart },
			{ time = t.Windup + t.DashTime + 0.08, pose = after, ease = Quart },
		},
		fadeOut = 0.25,
	} :: Clip
end

-- 2: Bird Dance. Wind Enma back over the right shoulder, then one huge horizontal sweep.
do
	local t = Tuning.BirdDance
	local windup = {
		Root = CFrame.new(0, -0.45, 0) * A(-0.1, -0.3, 0),
		Waist = A(0, -0.75, 0),
		Neck = A(0, 0.6, 0),
		RightShoulder = arm(1.5, -1.35),
		RightElbow = A(0.7, 0, 0),
		LeftShoulder = A(0.5, 0, -0.5),
		LeftElbow = A(1.1, 0, 0),
		RightHip = A(-0.35, 0, 0.3),
		RightKnee = A(-0.5, 0, 0),
		LeftHip = A(0.45, 0, -0.3),
		LeftKnee = A(-0.6, 0, 0),
	}
	local release = {
		Root = CFrame.new(0, -0.65, 0) * A(-0.25, 0.3, 0),
		Waist = A(-0.05, 0.85, 0),
		Neck = A(0, -0.5, 0),
		RightShoulder = arm(1.5, 1.25),
		RightElbow = A(0.1, 0, 0),
		LeftShoulder = A(-0.45, 0, -0.65),
		LeftElbow = A(0.2, 0, 0),
		RightHip = A(0.55, 0, 0.3),
		RightKnee = A(-0.9, 0, 0),
		LeftHip = A(-0.4, 0, -0.3),
		LeftKnee = A(-0.5, 0, 0),
	}
	Clips.BirdDance = {
		length = t.Windup + 0.55,
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = t.Windup * 0.7, pose = windup, ease = Back },
			{ time = t.Windup, pose = windup },
			{ time = t.Windup + 0.07, pose = release, ease = Quart },
		},
		fadeOut = 0.25,
	} :: Clip
end

-- 3: Black Rope Dragon Twister. Arms straight out with the blades level, crouched, spinning hard.
do
	local t = Tuning.DragonTwister
	local spread = {
		Root = CFrame.new(0, -0.6, 0) * A(-0.2, 0, 0),
		Waist = CFrame.identity,
		Neck = A(-0.15, 0, 0),
		RightShoulder = A(0.3, 0, 1.45),
		RightElbow = A(0.1, 0, 0),
		LeftShoulder = A(0.3, 0, -1.45),
		LeftElbow = A(0.1, 0, 0),
		RightHip = A(0.3, 0, 0.3),
		RightKnee = A(-0.6, 0, 0),
		LeftHip = A(0.3, 0, -0.3),
		LeftKnee = A(-0.6, 0, 0),
	}
	local finish = {
		Root = CFrame.new(0, -0.3, 0) * A(0.1, 0, 0),
		Waist = A(0.1, 0, 0),
		Neck = A(0.3, 0, 0),
		RightShoulder = A(2.6, 0, 0.4),
		RightElbow = A(0.2, 0, 0),
		LeftShoulder = A(2.6, 0, -0.4),
		LeftElbow = A(0.2, 0, 0),
		RightHip = A(0.1, 0, 0.15),
		RightKnee = A(-0.2, 0, 0),
		LeftHip = A(0.1, 0, -0.15),
		LeftKnee = A(-0.2, 0, 0),
	}
	local spinEnd = t.Windup + t.Duration
	Clips.DragonTwister = {
		length = spinEnd + 0.45,
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = t.Windup, pose = spread, ease = Quart },
			{ time = spinEnd, pose = spread },
			{ time = spinEnd + 0.1, pose = finish, ease = Back },
		},
		spin = { rate = 22, from = t.Windup, to = spinEnd },
		fadeOut = 0.3,
	} :: Clip
end

-- 4: Dragon Damnation. Crouch with Enma raised as the sky goes black, spring into the sky, hang
-- there with the blades raised while the dragon coils, then dive head-first. The landing is its own clip.
do
	local t = Tuning.DragonDamnation
	local gather = {
		Root = CFrame.new(0, -1.0, 0) * A(-0.3, 0, 0),
		Waist = A(-0.1, -0.2, 0),
		Neck = A(0.3, 0.15, 0),
		RightShoulder = A(2.65, 0, 0.25),
		RightElbow = A(0.35, 0, 0),
		LeftShoulder = arm(1.1, -0.5),
		LeftElbow = A(0.9, 0, 0),
		RightHip = A(1.0, 0, 0.15),
		RightKnee = A(-1.5, 0, 0),
		LeftHip = A(-0.4, 0, -0.15),
		LeftKnee = A(-1.2, 0, 0),
	}
	local spring = {
		Root = A(0.15, 0, 0),
		Waist = A(0.15, 0, 0),
		Neck = A(0.4, 0, 0),
		RightShoulder = A(-0.6, 0, 0.35),
		RightElbow = A(0.2, 0, 0),
		LeftShoulder = A(-0.6, 0, -0.35),
		LeftElbow = A(0.2, 0, 0),
		RightHip = A(-0.25, 0, 0),
		RightKnee = A(-0.1, 0, 0),
		LeftHip = A(-0.25, 0, 0),
		LeftKnee = A(-0.1, 0, 0),
	}
	local tuck = {
		Root = A(-0.5, 0, 0),
		Waist = A(-0.3, 0, 0),
		Neck = A(0.2, 0, 0),
		RightShoulder = A(1.3, 0, 0.6),
		RightElbow = A(1.2, 0, 0),
		LeftShoulder = A(1.3, 0, -0.6),
		LeftElbow = A(1.2, 0, 0),
		RightHip = A(1.4, 0, 0),
		RightKnee = A(-2.0, 0, 0),
		LeftHip = A(1.4, 0, 0),
		LeftKnee = A(-2.0, 0, 0),
	}
	local hover = {
		Root = A(0.1, 0, 0),
		Waist = A(0.2, 0, 0),
		Neck = A(-0.55, 0, 0),
		RightShoulder = A(2.85, 0, 0.5),
		RightElbow = A(0.4, 0, 0),
		LeftShoulder = A(2.85, 0, -0.5),
		LeftElbow = A(0.4, 0, 0),
		RightHip = A(0.3, 0, 0.1),
		RightKnee = A(-0.7, 0, 0),
		LeftHip = A(0.1, 0, -0.1),
		LeftKnee = A(-0.4, 0, 0),
	}
	local dive = {
		Root = A(-1.3, 0, 0),
		Waist = A(-0.2, 0, 0),
		Neck = A(0.6, 0, 0),
		RightShoulder = A(3.0, 0, 0.15),
		RightElbow = A(0.1, 0, 0),
		LeftShoulder = A(3.0, 0, -0.15),
		LeftElbow = A(0.1, 0, 0),
		RightHip = A(-0.2, 0, 0.05),
		RightKnee = A(-0.2, 0, 0),
		LeftHip = A(-0.2, 0, -0.05),
		LeftKnee = A(-0.3, 0, 0),
	}
	local riseStart = t.Charge
	local hoverStart = riseStart + t.RiseTime
	local diveStart = hoverStart + t.Hover
	Clips.DragonDamnation = {
		length = diveStart + t.MaxDiveTime + 0.5, -- the landing clip takes over at impact
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = 0.25, pose = gather, ease = Back },
			{ time = riseStart - 0.05, pose = gather },
			{ time = riseStart + 0.05, pose = spring, ease = Quart },
			{ time = riseStart + 0.3, pose = tuck },
			{ time = hoverStart + 0.1, pose = hover, ease = Back },
			{ time = diveStart - 0.05, pose = hover },
			{ time = diveStart + 0.08, pose = dive, ease = Quart },
		},
		fadeIn = 0.1,
	} :: Clip

	Clips.DragonDamnationLand = {
		length = 1.0,
		keyframes = {
			{ time = 0, pose = dive },
			{
				time = 0.08,
				pose = {
					Root = CFrame.new(0, -1.25, 0) * A(-0.45, 0, 0),
					Waist = A(-0.2, 0, 0),
					Neck = A(0.15, 0, 0),
					RightShoulder = A(0.25, 0, 1.0),
					RightElbow = A(0.2, 0, 0),
					LeftShoulder = A(0.25, 0, -1.0),
					LeftElbow = A(0.2, 0, 0),
					RightHip = A(1.25, 0, 0.1),
					RightKnee = A(-1.85, 0, 0),
					LeftHip = A(-0.3, 0, -0.1),
					LeftKnee = A(-1.6, 0, 0),
				},
				ease = Quart,
			},
		},
		fadeIn = 0,
		fadeOut = 0.4,
	} :: Clip
end

-- 5: Asura. Arms spread wide with the head lowered while the demon rises, a low dash, then standing
-- tall past the target with the blades lowered as the nine cuts appear behind him.
do
	local t = Tuning.Asura
	local stance = {
		Root = CFrame.new(0, -0.55, 0) * A(-0.15, 0, 0),
		Waist = A(0.05, 0, 0),
		Neck = A(-0.35, 0, 0),
		RightShoulder = A(0.6, 0, 1.15),
		RightElbow = A(0.55, 0, 0),
		LeftShoulder = A(0.6, 0, -1.15),
		LeftElbow = A(0.55, 0, 0),
		RightHip = A(0.2, 0, 0.35),
		RightKnee = A(-0.75, 0, 0),
		LeftHip = A(-0.2, 0, -0.35),
		LeftKnee = A(-0.7, 0, 0),
	}
	local dash = {
		Root = CFrame.new(0, -0.85, 0) * A(-0.75, 0, 0),
		Waist = A(-0.1, 0, 0),
		Neck = A(0.55, 0, 0),
		RightShoulder = A(-0.45, 0, 0.95),
		RightElbow = A(0.1, 0, 0),
		LeftShoulder = A(-0.45, 0, -0.95),
		LeftElbow = A(0.1, 0, 0),
		RightHip = A(0.9, 0, 0),
		RightKnee = A(-0.7, 0, 0),
		LeftHip = A(-0.9, 0, 0),
		LeftKnee = A(-0.4, 0, 0),
	}
	local after = {
		Root = CFrame.new(0, -0.3, 0),
		Waist = A(0.05, 0, 0),
		Neck = A(0.15, 0, 0),
		RightShoulder = A(0.25, 0, 0.4),
		RightElbow = A(0.2, 0, 0),
		LeftShoulder = A(0.25, 0, -0.4),
		LeftElbow = A(0.2, 0, 0),
		RightHip = A(0.1, 0, 0.15),
		RightKnee = A(-0.2, 0, 0),
		LeftHip = A(-0.1, 0, -0.15),
		LeftKnee = A(-0.2, 0, 0),
	}
	Clips.Asura = {
		length = t.Charge + t.DashTime + t.CutDelay + 0.6,
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = 0.35, pose = stance, ease = Back },
			{ time = t.Charge - 0.05, pose = stance },
			{ time = t.Charge + 0.04, pose = dash, ease = Quart },
			{ time = t.Charge + t.DashTime + 0.06, pose = after, ease = Quart },
		},
		fadeOut = 0.4,
	} :: Clip
end

return Clips
