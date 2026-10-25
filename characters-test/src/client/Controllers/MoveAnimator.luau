--!strict
-- Plays animation clips made in code: keyframed poses blended over Roblox's own animations.
-- Every client plays clips on every character, so everyone sees them. Clips live in Client/Animations.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Rig = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Rig"))

export type Keyframe = {
	time: number,
	pose: Rig.Pose,
	-- How the motion INTO this keyframe eases (default Quad). Quart/Back give snappy anime hits.
	ease: Enum.EasingStyle?,
}

export type Clip = {
	length: number, -- the last pose is held until this time, then fades out
	keyframes: { Keyframe },
	fadeIn: number?,
	fadeOut: number?,
	-- Spins the whole body around (radians per second) between two times.
	spin: { rate: number, from: number, to: number }?,
}

type Playing = {
	clip: Clip,
	start: number,
	speed: number,
	joints: { [string]: boolean },
}

type Track = {
	joints: { [string]: Rig.Joint },
	playing: Playing?,
	idle: Rig.Pose?,
	idleWeight: number,
}

local DEFAULT_FADE_IN = 0.06
local DEFAULT_FADE_OUT = 0.18
local IDENTITY = CFrame.identity

local MoveAnimator = {}

local tracks: { [Model]: Track } = {}

local function getTrack(character: Model): Track
	local track = tracks[character]
	if not track then
		track = { joints = Rig.findJoints(character), playing = nil, idle = nil, idleWeight = 0 }
		tracks[character] = track
	end
	return track
end

function MoveAnimator.play(character: Model, clip: Clip, speed: number?)
	local joints: { [string]: boolean } = {}
	for _, keyframe in clip.keyframes do
		for name in keyframe.pose do
			joints[name] = true
		end
	end
	if clip.spin then
		joints.Root = true
	end
	getTrack(character).playing = { clip = clip, start = os.clock(), speed = speed or 1, joints = joints }
end

-- True while `clip` is the clip playing on this character.
function MoveAnimator.isPlaying(character: Model, clip: Clip): boolean
	local track = tracks[character]
	return track ~= nil and track.playing ~= nil and track.playing.clip == clip
end

function MoveAnimator.stop(character: Model)
	local track = tracks[character]
	if track then
		track.playing = nil
	end
end

-- A pose held whenever no clip is playing (e.g. holding swords ready). nil clears it.
function MoveAnimator.setIdlePose(character: Model, pose: Rig.Pose?)
	getTrack(character).idle = pose
end

-- A joint's pose in `clip` at time `t` (used for playback and by the animation exporter).
function MoveAnimator.sample(clip: Clip, t: number, name: string): CFrame
	local frames = clip.keyframes
	local previous = frames[1]
	if t <= previous.time then
		return previous.pose[name] or IDENTITY
	end
	for i = 2, #frames do
		local nextFrame = frames[i]
		if t < nextFrame.time then
			local alpha = (t - previous.time) / (nextFrame.time - previous.time)
			local eased =
				TweenService:GetValue(alpha, nextFrame.ease or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			return (previous.pose[name] or IDENTITY):Lerp(nextFrame.pose[name] or IDENTITY, eased)
		end
		previous = nextFrame
	end
	return previous.pose[name] or IDENTITY
end

local function clipWeight(playing: Playing, elapsed: number): number
	local clip = playing.clip
	local fadeIn = clip.fadeIn or DEFAULT_FADE_IN
	local fadeOut = clip.fadeOut or DEFAULT_FADE_OUT
	if elapsed < fadeIn then
		return elapsed / fadeIn
	elseif elapsed > clip.length then
		return 1 - (elapsed - clip.length) / fadeOut
	end
	return 1
end

local function update(dt: number)
	for character, track in tracks do
		if not character.Parent then
			tracks[character] = nil
			continue
		end
		if Rig.isStale(track.joints) then
			track.joints = Rig.findJoints(character)
		end

		local playing = track.playing
		local weight, elapsed = 0, 0
		if playing then
			elapsed = (os.clock() - playing.start) * playing.speed
			weight = clipWeight(playing, elapsed)
			if weight <= 0 then
				track.playing = nil
				playing = nil
			end
		end
		local idleGoal = if track.idle and not playing then 1 else 0
		track.idleWeight += (idleGoal - track.idleWeight) * math.min(1, dt * 12)
		if not playing and track.idleWeight < 0.01 then
			continue
		end

		local clip = if playing then playing.clip else nil
		local t = if clip then math.min(elapsed, clip.length) else 0
		for name, joint in track.joints do
			local transform = joint.motor.Transform
			local idlePose = track.idle and track.idle[name]
			if idlePose and track.idleWeight > 0.01 then
				transform = transform:Lerp(Rig.toJointSpace(joint, idlePose), track.idleWeight)
			end
			if clip and playing and playing.joints[name] and weight > 0 then
				local pose = MoveAnimator.sample(clip, t, name)
				local spin = clip.spin
				if name == "Root" and spin then
					pose = CFrame.Angles(0, spin.rate * math.clamp(t - spin.from, 0, spin.to - spin.from), 0) * pose
				end
				transform = transform:Lerp(Rig.toJointSpace(joint, pose), math.min(weight, 1))
			end
			joint.motor.Transform = transform
		end
	end
end

function MoveAnimator.start()
	-- Stepped runs after Roblox's animations each frame, so what we write here is what gets drawn.
	RunService.Stepped:Connect(function(_time: number, dt: number)
		update(dt)
	end)
end

return MoveAnimator
