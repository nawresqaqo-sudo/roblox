--!strict
-- Clips any character can play. Flinches play on whoever gets hit (see Vfx/Common DamageNumber), unless
-- they're in the middle of a move of their own.
local Controllers = script.Parent.Parent:WaitForChild("Controllers")
local MoveAnimator = require(Controllers:WaitForChild("MoveAnimator"))

type Clip = MoveAnimator.Clip

local A = CFrame.Angles
local Quart = Enum.EasingStyle.Quart

local Clips = {}

-- A light hit: the head and chest snap back for a moment.
Clips.Flinch = {
	length = 0.16,
	keyframes = {
		{ time = 0, pose = { Waist = CFrame.identity, Neck = CFrame.identity } },
		{ time = 0.05, pose = { Waist = A(0.18, 0, 0), Neck = A(-0.2, 0, 0) }, ease = Quart },
		{ time = 0.16, pose = { Waist = CFrame.identity, Neck = CFrame.identity } },
	},
	fadeIn = 0.02,
	fadeOut = 0.12,
} :: Clip

-- A real hit: knocked back at the waist with the arms thrown up, held, then recovering.
Clips.FlinchHeavy = {
	length = 0.36,
	keyframes = {
		{
			time = 0,
			pose = {
				Root = CFrame.identity,
				Waist = CFrame.identity,
				Neck = CFrame.identity,
				RightShoulder = CFrame.identity,
				RightElbow = CFrame.identity,
				LeftShoulder = CFrame.identity,
				LeftElbow = CFrame.identity,
			},
		},
		{
			time = 0.06,
			pose = {
				Root = A(0.15, 0, 0),
				Waist = A(0.32, 0, 0),
				Neck = A(-0.35, 0, 0),
				RightShoulder = A(0.6, 0, 0.5),
				RightElbow = A(0.6, 0, 0),
				LeftShoulder = A(0.6, 0, -0.5),
				LeftElbow = A(0.6, 0, 0),
			},
			ease = Quart,
		},
		{
			time = 0.2,
			pose = {
				Root = A(0.1, 0, 0),
				Waist = A(0.25, 0, 0),
				Neck = A(-0.28, 0, 0),
				RightShoulder = A(0.45, 0, 0.4),
				RightElbow = A(0.5, 0, 0),
				LeftShoulder = A(0.45, 0, -0.4),
				LeftElbow = A(0.5, 0, 0),
			},
		},
	},
	fadeIn = 0.02,
	fadeOut = 0.2,
} :: Clip

return Clips
