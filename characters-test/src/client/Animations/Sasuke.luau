--!strict
-- Sasuke's animations, made in code as keyframed poses (see Controllers/MoveAnimator and Util/Rig for
-- how poses work). Times line up with the numbers in Shared.Characters.Sasuke.Tuning. Leg angles in
-- crouches and lunges were solved so the planted foot stays on the ground.
-- Moves that come in parts (Chidori: charge, dash, thrust) are separate clips; each one blends out of
-- whatever pose the last one left on screen.
-- Made a real animation in Eclipse/Moon Animator? Put its id in that move's AnimationId and the coded
-- clips are skipped for it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Controllers = script.Parent.Parent:WaitForChild("Controllers")
local MoveAnimator = require(Controllers:WaitForChild("MoveAnimator"))
local SasukeData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Characters"):WaitForChild("Sasuke"))

type Clip = MoveAnimator.Clip

local Tuning = SasukeData.Tuning
local A = CFrame.Angles
local Quart = Enum.EasingStyle.Quart
local Back = Enum.EasingStyle.Back
local Sine = Enum.EasingStyle.Sine

-- Arm helper: raise the arm forward by `forward`, then swing it around the body by `turn`
-- (positive turns toward the character's left).
local function arm(forward: number, turn: number, outward: number?): CFrame
	return A(0, turn, 0) * A(forward, 0, outward or 0)
end

-- Root helper: crouch by `down` studs, lean forward by `lean`, turn left by `turn`.
local function root(down: number, lean: number, turn: number?): CFrame
	return CFrame.new(0, -down, 0) * A(-lean, turn or 0, 0)
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

-- Copies `base` with some joints changed.
local function with(base: { [string]: CFrame }, changes: { [string]: CFrame }): { [string]: CFrame }
	local pose = table.clone(base)
	for name, value in changes do
		pose[name] = value
	end
	return pose
end

local Clips = {}

-- 1: Chidori. Crouch low with the lightning hand dragging by the ground and the other hand gripping
-- that wrist, sprint with it trailing behind, then one straight thrust. A miss eases out of the run.
do
	local t = Tuning.Chidori
	local crouch = {
		Root = root(1.0, 0.4, -0.15),
		Waist = A(-0.1, -0.3, 0),
		Neck = A(0.35, 0.4, 0),
		RightShoulder = A(0.25, 0, 0.35),
		RightElbow = A(0.2, 0, 0),
		LeftShoulder = arm(0.75, -0.95),
		LeftElbow = A(1.25, 0, 0),
		LeftHip = A(1.82, 0, -0.08),
		LeftKnee = A(-1.47, 0, 0),
		RightHip = A(0.14, 0, 0.12),
		RightKnee = A(-1.13, 0, 0),
	}
	local strain = with(crouch, {
		RightShoulder = A(0.05, 0, 0.45),
		Neck = A(0.32, 0.42, 0),
		LeftShoulder = arm(0.8, -1.0),
	})
	Clips.ChidoriCharge = {
		length = t.Charge + 0.5, -- held until the dash clip takes over
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = 0.1, pose = crouch, ease = Back },
			{ time = t.Charge, pose = strain, ease = Sine },
		},
		fadeIn = 0.05,
		fadeOut = 0.25,
	} :: Clip

	-- Sprinting with the Chidori trailing behind: the legs alternate, the free arm pumps.
	local run = {
		Root = root(0.65, 0.8, -0.1),
		Waist = A(-0.05, -0.25, 0),
		Neck = A(0.7, 0.3, 0),
		RightShoulder = A(-0.9, 0, 0.3),
		RightElbow = A(0.1, 0, 0),
	}
	local strideA = with(run, {
		LeftShoulder = A(-0.3, 0, -0.2),
		LeftElbow = A(1.2, 0, 0),
		LeftHip = A(2.0, 0, -0.05),
		LeftKnee = A(-1.7, 0, 0),
		RightHip = A(0.06, 0, 0.05),
		RightKnee = A(-0.05, 0, 0),
	})
	local strideB = with(run, {
		LeftShoulder = arm(0.9, -0.3),
		LeftElbow = A(1.1, 0, 0),
		RightHip = A(2.0, 0, 0.05),
		RightKnee = A(-1.7, 0, 0),
		LeftHip = A(0.06, 0, -0.05),
		LeftKnee = A(-0.05, 0, 0),
	})
	Clips.ChidoriDash = {
		length = t.MaxDashTime + 0.4, -- held until the thrust (or the stop) takes over
		keyframes = {
			{ time = 0, pose = strideA },
			{ time = 0.08, pose = strideB },
			{ time = 0.16, pose = strideA },
			{ time = 0.24, pose = strideB },
			{ time = 0.32, pose = strideA },
		},
		fadeIn = 0.05,
		fadeOut = 0.25,
	} :: Clip

	local thrust = {
		Root = root(0.8, 0.5, 0.2),
		Waist = A(-0.1, 0.45, 0),
		Neck = A(0.4, -0.55, 0),
		RightShoulder = arm(1.6, 0.25),
		RightElbow = A(0.05, 0, 0),
		LeftShoulder = A(-0.55, 0, -0.45),
		LeftElbow = A(0.9, 0, 0),
		LeftHip = A(1.59, 0, -0.08),
		LeftKnee = A(-0.56, 0, 0),
		RightHip = A(-0.04, 0, 0.1),
		RightKnee = A(-0.53, 0, 0),
	}
	local recover = {
		Root = root(0.35, 0.12, 0.05),
		Waist = A(0, 0.1, 0),
		Neck = A(0.1, -0.1, 0),
		RightShoulder = arm(0.6, 0.35),
		RightElbow = A(1.0, 0, 0),
		LeftShoulder = arm(0.45, -0.2),
		LeftElbow = A(0.9, 0, 0),
		LeftHip = A(0.86, 0, -0.1),
		LeftKnee = A(-1.0, 0, 0),
		RightHip = A(0.35, 0, 0.1),
		RightKnee = A(-0.98, 0, 0),
	}
	Clips.ChidoriThrust = {
		length = 0.5,
		keyframes = {
			{ time = 0, pose = thrust },
			{ time = 0.16, pose = with(thrust, { RightShoulder = arm(1.62, 0.22), Root = root(0.82, 0.55, 0.22) }) },
			{ time = 0.42, pose = recover },
		},
		fadeIn = 0.04,
		fadeOut = 0.3,
	} :: Clip

	local brake = {
		Root = root(0.5, 0.2, -0.05),
		Waist = A(0.05, -0.1, 0),
		Neck = A(0.15, 0.1, 0),
		RightShoulder = A(0.25, 0, 0.35),
		RightElbow = A(0.35, 0, 0),
		LeftShoulder = arm(0.55, -0.15),
		LeftElbow = A(0.8, 0, 0),
		LeftHip = A(1.16, 0, -0.08),
		LeftKnee = A(-0.96, 0, 0),
		RightHip = A(0.43, 0, 0.1),
		RightKnee = A(-1.15, 0, 0),
	}
	Clips.ChidoriFizzle = {
		length = 0.4,
		keyframes = {
			{ time = 0, pose = brake },
			{ time = 0.32, pose = recover },
		},
		fadeIn = 0.1,
		fadeOut = 0.3,
	} :: Clip
end

-- 2: Phoenix Flower. Two quick hand signs, a breath in with the hand at his mouth, then the fireballs
-- come out one after another while the other arm flicks shuriken into them. Only the upper body moves,
-- so he can keep walking.
do
	local t = Tuning.PhoenixFlower
	local still = {
		Waist = CFrame.identity,
		Neck = CFrame.identity,
		RightShoulder = CFrame.identity,
		RightElbow = CFrame.identity,
		LeftShoulder = CFrame.identity,
		LeftElbow = CFrame.identity,
	}
	local seal = {
		Waist = A(-0.05, 0.1, 0),
		Neck = A(0.2, -0.05, 0),
		RightShoulder = arm(0.95, 0.8),
		RightElbow = A(1.75, 0, 0),
		LeftShoulder = arm(0.95, -0.8),
		LeftElbow = A(1.75, 0, 0),
	}
	local tiger = {
		Waist = A(0, 0.05, 0),
		Neck = A(0.12, 0, 0),
		RightShoulder = arm(1.2, 0.75),
		RightElbow = A(1.95, 0, 0),
		LeftShoulder = arm(1.2, -0.75),
		LeftElbow = A(1.95, 0, 0),
	}
	local inhale = {
		Waist = A(0.2, 0, 0),
		Neck = A(-0.22, 0, 0),
		RightShoulder = arm(1.45, 0.62),
		RightElbow = A(2.25, 0, 0),
		LeftShoulder = A(-0.45, 0, -0.35),
		LeftElbow = A(1.15, 0, 0),
	}
	local puffA = {
		Waist = A(-0.28, 0.05, 0),
		Neck = A(0.18, 0, 0),
		RightShoulder = arm(1.35, 0.55),
		RightElbow = A(2.15, 0, 0),
		LeftShoulder = arm(1.45, 0.25),
		LeftElbow = A(0.15, 0, 0),
	}
	local puffB = {
		Waist = A(-0.18, -0.06, 0),
		Neck = A(0.1, 0.04, 0),
		RightShoulder = arm(1.38, 0.58),
		RightElbow = A(2.2, 0, 0),
		LeftShoulder = arm(1.2, 0.15),
		LeftElbow = A(0.35, 0, 0),
	}
	local follow = {
		Waist = A(-0.06, 0, 0),
		Neck = A(0.05, 0, 0),
		RightShoulder = arm(0.55, 0.25),
		RightElbow = A(0.9, 0, 0),
		LeftShoulder = arm(0.65, 0.1),
		LeftElbow = A(0.4, 0, 0),
	}
	local keyframes: { MoveAnimator.Keyframe } = {
		{ time = 0, pose = still },
		{ time = 0.08, pose = seal, ease = Back },
		{ time = 0.16, pose = tiger, ease = Quart },
		{ time = t.Signs - 0.04, pose = inhale },
	}
	local last = t.Signs + (t.Count - 1) * t.Interval
	for i = 0, t.Count - 1 do
		table.insert(keyframes, {
			time = t.Signs + 0.01 + i * t.Interval,
			pose = if i % 2 == 0 then puffA else puffB,
			ease = Quart,
		})
	end
	table.insert(keyframes, { time = last + 0.2, pose = follow })
	Clips.PhoenixFlower = {
		length = last + 0.25,
		keyframes = keyframes,
		fadeOut = 0.3,
	} :: Clip
end

-- 3: Amaterasu. Head bowed, two fingers raised to his eye; the Mangekyo opens with a sharp lift of the
-- head toward the target, a held stare, then the hand sweeps away as the flames erupt.
do
	local t = Tuning.Amaterasu
	local bow = {
		Root = root(0.12, 0.05, 0.12),
		Waist = A(0.02, 0.1, 0),
		Neck = A(0.32, -0.15, 0),
		LeftShoulder = arm(1.3, -0.5),
		LeftElbow = A(2.25, 0, 0),
		RightShoulder = A(-0.12, 0, 0.18),
		RightElbow = A(0.3, 0, 0),
		LeftHip = A(0.41, 0, -0.08),
		LeftKnee = A(-0.59, 0, 0),
		RightHip = A(0.15, 0, 0.08),
		RightKnee = A(-0.57, 0, 0),
	}
	local glare = with(bow, {
		Root = root(0.08, 0, 0.12),
		Waist = A(0, 0.16, 0),
		Neck = A(-0.1, -0.22, 0),
		LeftShoulder = arm(1.35, -0.55),
		LeftElbow = A(2.35, 0, 0),
	})
	local release = with(glare, {
		Waist = A(-0.05, 0.12, 0),
		Neck = A(0.05, -0.18, 0),
		LeftShoulder = arm(0.85, -0.15),
		LeftElbow = A(0.6, 0, 0),
	})
	local opened = t.Cast + t.Mark
	Clips.Amaterasu = {
		length = opened + 0.45,
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = 0.14, pose = bow },
			{ time = t.Cast - 0.06, pose = with(bow, { Neck = A(0.38, -0.15, 0) }), ease = Sine },
			{ time = t.Cast, pose = glare, ease = Back },
			{ time = opened, pose = glare },
			{ time = opened + 0.12, pose = release, ease = Quart },
		},
		fadeOut = 0.35,
	} :: Clip
end

-- 4: Kirin. A wide stance with the right arm thrust at the sky while the storm gathers (it strains as
-- the lightning builds), then the arm whips down at the marked ground the moment Kirin falls.
do
	local t = Tuning.Kirin
	local strike = t.Buildup + t.Anticipation
	local raise = {
		Root = root(0.5, -0.08),
		Waist = A(0.18, 0, 0),
		Neck = A(-0.6, 0, 0),
		RightShoulder = A(2.95, 0, 0.2),
		RightElbow = A(0.08, 0, 0),
		LeftShoulder = A(-0.25, 0, -0.55),
		LeftElbow = A(0.35, 0, 0),
		LeftHip = A(0.65, 0, -0.32),
		LeftKnee = A(-1.17, 0, 0),
		RightHip = A(0.3, 0, 0.32),
		RightKnee = A(-1.15, 0, 0),
	}
	local strain = with(raise, {
		Root = root(0.52, -0.1),
		Waist = A(0.22, 0, 0),
		Neck = A(-0.66, 0, 0),
		RightShoulder = A(2.85, 0, 0.28),
	})
	local reach = with(raise, {
		Waist = A(0.16, 0, 0),
		Neck = A(-0.5, 0, 0),
		RightShoulder = A(3.0, 0, 0.16),
	})
	local watch = with(reach, {
		Neck = A(-0.3, 0, 0),
		RightShoulder = A(2.95, 0, 0.18),
	})
	local swing = {
		Root = root(0.7, 0.35, 0.1),
		Waist = A(-0.15, 0.25, 0),
		Neck = A(0.25, -0.25, 0),
		RightShoulder = arm(1.25, 0.15),
		RightElbow = A(0.05, 0, 0),
		LeftShoulder = A(-0.7, 0, -0.45),
		LeftElbow = A(0.5, 0, 0),
		LeftHip = A(1.42, 0, -0.15),
		LeftKnee = A(-0.7, 0, 0),
		RightHip = A(0.4, 0, 0.15),
		RightKnee = A(-1.19, 0, 0),
	}
	local settle = with(swing, {
		Root = root(0.62, 0.25, 0.08),
		Neck = A(0.18, -0.2, 0),
		RightShoulder = arm(1.05, 0.12),
	})
	Clips.Kirin = {
		length = strike + 0.5,
		keyframes = {
			{ time = 0, pose = NEUTRAL },
			{ time = 0.22, pose = raise, ease = Back },
			{ time = 0.6, pose = strain, ease = Sine },
			{ time = t.Buildup, pose = reach, ease = Sine },
			{ time = strike - 0.2, pose = watch, ease = Sine },
			{ time = strike - 0.04, pose = swing, ease = Quart },
			{ time = strike + 0.12, pose = settle },
		},
		fadeIn = 0.08,
		fadeOut = 0.4,
	} :: Clip
end

return Clips
