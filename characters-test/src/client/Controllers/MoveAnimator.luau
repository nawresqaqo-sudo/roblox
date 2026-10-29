--!strict
-- Plays animation clips made in code: keyframed poses blended over Roblox's own animations.
-- Every client plays clips on every character, so everyone sees them. Clips live in Client/Animations.
-- A clip that starts while another is still on screen blends out of that pose instead of snapping.
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
	-- The pose on screen when this clip took over; it blends out of it during its fade-in.
	from: { [string]: CFrame }?,
	-- Hit-stop: the clip stays frozen at `heldAt` until `heldUntil`.
	heldAt: number?,
	heldUntil: number?,
}

-- A clip that was stopped early, easing back into Roblox's own animations.
type Fading = {
	from: { [string]: CFrame },
	start: number,
	time: number,
}

type Track = {
	joints: { [string]: Rig.Joint },
	playing: Playing?,
	fading: Fading?,
	idle: Rig.Pose?,
	idleWeight: number,
	-- What every joint was set to last frame, while anything is being drawn.
	output: { [string]: CFrame },
	drawing: boolean,
}

local DEFAULT_FADE_IN = 0.06
local DEFAULT_FADE_OUT = 0.18
local DEFAULT_STOP_FADE = 0.15
local IDENTITY = CFrame.identity

local MoveAnimator = {}

local tracks: { [Model]: Track } = {}

local function getTrack(character: Model): Track
	local track = tracks[character]
	if not track then
		track = {
			joints = Rig.findJoints(character),
			playing = nil,
			fading = nil,
			idle = nil,
			idleWeight = 0,
			output = {},
			drawing = false,
		}
		tracks[character] = track
	end
	return track
end

-- The pose on screen right now, if a clip or held pose is showing.
local function snapshot(track: Track): { [string]: CFrame }?
	return if track.drawing then table.clone(track.output) else nil
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
	local track = getTrack(character)
	track.playing = {
		clip = clip,
		start = os.clock(),
		speed = speed or 1,
		joints = joints,
		from = snapshot(track),
	}
	track.fading = nil
end

-- True while `clip` is the clip playing on this character.
function MoveAnimator.isPlaying(character: Model, clip: Clip): boolean
	local track = tracks[character]
	return track ~= nil and track.playing ~= nil and track.playing.clip == clip
end

-- True while any clip is playing on this character.
function MoveAnimator.isBusy(character: Model): boolean
	local track = tracks[character]
	return track ~= nil and track.playing ~= nil
end

-- Ends the clip early, easing back into Roblox's own animations over `fadeTime` instead of snapping.
function MoveAnimator.stop(character: Model, fadeTime: number?)
	local track = tracks[character]
	if not track or not track.playing then
		return
	end
	track.playing = nil
	local from = snapshot(track)
	track.fading = if from then { from = from, start = os.clock(), time = fadeTime or DEFAULT_STOP_FADE } else nil
end

-- Hit-stop: freezes the playing clip for `duration`, then carries on from where it froze.
function MoveAnimator.hold(character: Model, duration: number)
	local track = tracks[character]
	local playing = if track then track.playing else nil
	if not playing then
		return
	end
	local now = os.clock()
	if playing.heldUntil and now < playing.heldUntil then
		return
	end
	playing.heldAt = (now - playing.start) * playing.speed
	playing.heldUntil = now + duration
	playing.start += duration
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

local function elapsedOf(playing: Playing, now: number): number
	local heldUntil = playing.heldUntil
	if heldUntil and now < heldUntil then
		return playing.heldAt or 0
	end
	return (now - playing.start) * playing.speed
end

local function update(dt: number)
	local now = os.clock()
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
			elapsed = elapsedOf(playing, now)
			weight = clipWeight(playing, elapsed)
			if weight <= 0 then
				track.playing = nil
				playing = nil
			end
		end
		local fading = track.fading
		local fadeAlpha = 1
		if fading then
			fadeAlpha = math.clamp((now - fading.start) / fading.time, 0, 1)
			if fadeAlpha >= 1 then
				track.fading = nil
				fading = nil
			end
		end
		local idleGoal = if track.idle and not playing then 1 else 0
		track.idleWeight += (idleGoal - track.idleWeight) * math.min(1, dt * 12)
		if not playing and not fading and track.idleWeight < 0.01 then
			track.drawing = false
			continue
		end

		local clip = if playing then playing.clip else nil
		local t = if clip then math.min(elapsed, clip.length) else 0
		local fadeIn = if clip then clip.fadeIn or DEFAULT_FADE_IN else 0
		-- While a clip fades in, it blends from the pose that was on screen when it took over.
		local from = if playing and elapsed < fadeIn then playing.from else nil
		local blend = if fadeIn > 0 then math.clamp(elapsed / fadeIn, 0, 1) else 1
		for name, joint in track.joints do
			local transform = joint.motor.Transform
			local idlePose = track.idle and track.idle[name]
			if idlePose and track.idleWeight > 0.01 then
				transform = transform:Lerp(Rig.toJointSpace(joint, idlePose), track.idleWeight)
			end
			local previous = if from then from[name] else nil
			if clip and playing and playing.joints[name] and weight > 0 then
				local pose = MoveAnimator.sample(clip, t, name)
				local spin = clip.spin
				if name == "Root" and spin then
					pose = CFrame.Angles(0, spin.rate * math.clamp(t - spin.from, 0, spin.to - spin.from), 0) * pose
				end
				local target = Rig.toJointSpace(joint, pose)
				transform = if previous
					then previous:Lerp(target, blend)
					else transform:Lerp(target, math.min(weight, 1))
			elseif previous then
				-- A joint the last clip moved but this one doesn't: ease it back instead of snapping.
				transform = previous:Lerp(transform, blend)
			elseif fading and fading.from[name] then
				transform = fading.from[name]:Lerp(transform, fadeAlpha)
			end
			joint.motor.Transform = transform
			track.output[name] = transform
		end
		track.drawing = true
	end
end

function MoveAnimator.start()
	-- Stepped runs after Roblox's animations each frame, so what we write here is what gets drawn.
	RunService.Stepped:Connect(function(_time: number, dt: number)
		update(dt)
	end)
end

return MoveAnimator
