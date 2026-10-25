--!strict
-- Plays animations made in Eclipse/Moon Animator. Empty ids are skipped so moves work without them.
local Animations = {}

local cache: { [Animator]: { [string]: AnimationTrack } } = setmetatable({}, { __mode = "k" }) :: any

local function normalize(animationId: string): string
	if string.match(animationId, "^%d+$") then
		return "rbxassetid://" .. animationId
	end
	return animationId
end

function Animations.play(humanoid: Humanoid, animationId: string, speed: number?): AnimationTrack?
	if animationId == "" then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return nil
	end
	local id = normalize(animationId)
	local tracks = cache[animator]
	if not tracks then
		tracks = {}
		cache[animator] = tracks
	end
	local track = tracks[id]
	if not track then
		local animation = Instance.new("Animation")
		animation.AnimationId = id
		local ok, loaded = pcall(animator.LoadAnimation, animator, animation)
		if not ok then
			warn(`[Animations] couldn't load {id}: {loaded}`)
			return nil
		end
		track = loaded
		tracks[id] = loaded
	end
	track.Priority = Enum.AnimationPriority.Action
	track:Play(0.1, 1, speed or 1)
	return track
end

return Animations
