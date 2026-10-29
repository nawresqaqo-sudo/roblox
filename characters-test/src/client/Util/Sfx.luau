--!strict
-- Sounds for moves. Every cue has a stand-in made from Roblox's own character sounds (they ship with
-- every Roblox client, so they always load) reshaped with sound effects: wind becomes a whoosh, a hiss
-- or a crackle, a landing thud becomes thunder. A real sound id replaces the stand-in and plays as is.
-- Sounds are positioned in the world, so everyone nearby hears them from the right place.
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

-- How a stand-in is reshaped.
export type Shape = "Plain" | "Whoosh" | "Thud" | "Crackle" | "Rumble" | "Boom" | "Roar" | "Hiss" | "Eerie"

export type StandIn = {
	sound: string,
	shape: Shape,
	pitch: number,
	volume: number,
	length: number?, -- cut it off (with a short fade) after this many seconds
	looped: boolean?,
	range: number?, -- how far away it can be heard (studs)
}

local Sfx = {}

-- Roblox's own character sounds: falling wind, landing thud and jump.
Sfx.WIND = "rbxasset://sounds/action_falling.mp3"
Sfx.LAND = "rbxasset://sounds/action_jump_land.mp3"
Sfx.JUMP = "rbxasset://sounds/action_jump.mp3"

local function equalize(sound: Sound, low: number, mid: number, high: number)
	local eq = Instance.new("EqualizerSoundEffect")
	eq.LowGain = low
	eq.MidGain = mid
	eq.HighGain = high
	eq.Parent = sound
end

local function distort(sound: Sound, level: number)
	local effect = Instance.new("DistortionSoundEffect")
	effect.Level = level
	effect.Parent = sound
end

local function tremble(sound: Sound, frequency: number, depth: number)
	local effect = Instance.new("TremoloSoundEffect")
	effect.Frequency = frequency
	effect.Depth = depth
	effect.Duty = 0.5
	effect.Parent = sound
end

local function reverb(sound: Sound, decay: number)
	local effect = Instance.new("ReverbSoundEffect")
	effect.DecayTime = decay
	effect.WetLevel = -4
	effect.DryLevel = 0
	effect.Parent = sound
end

local function shapeSound(sound: Sound, shape: Shape)
	if shape == "Whoosh" then
		equalize(sound, -6, 0, 3)
	elseif shape == "Thud" then
		distort(sound, 0.3)
		equalize(sound, 6, -2, -14)
	elseif shape == "Crackle" then
		distort(sound, 0.85)
		equalize(sound, -30, -4, 6)
		tremble(sound, 10, 1)
	elseif shape == "Rumble" then
		equalize(sound, 8, -18, -40)
		reverb(sound, 3)
	elseif shape == "Boom" then
		distort(sound, 0.55)
		equalize(sound, 9, -2, -12)
		reverb(sound, 2)
	elseif shape == "Roar" then
		distort(sound, 0.5)
		equalize(sound, 4, 1, -16)
		tremble(sound, 7, 0.5)
	elseif shape == "Hiss" then
		distort(sound, 0.7)
		equalize(sound, -24, -6, 3)
		tremble(sound, 9, 0.6)
	elseif shape == "Eerie" then
		local chorus = Instance.new("ChorusSoundEffect")
		chorus.Depth = 0.45
		chorus.Mix = 0.6
		chorus.Rate = 1.5
		chorus.Parent = sound
		equalize(sound, 4, -6, -20)
		reverb(sound, 4)
	end
end

-- Builds the sound for a cue: the real one if `id` is set, otherwise the reshaped stand-in.
local function build(id: string, standIn: StandIn): Sound
	local sound = Instance.new("Sound")
	if id ~= "" then
		sound.SoundId = id
		sound.PlaybackSpeed = 1
	else
		sound.SoundId = standIn.sound
		sound.PlaybackSpeed = standIn.pitch
		shapeSound(sound, standIn.shape)
	end
	sound.Volume = standIn.volume
	sound.Looped = standIn.looped == true
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = standIn.range or 160
	return sound
end

-- Plays a cue once at a spot (or on a part, following it). Returns the Sound so callers can bend its
-- pitch while it plays (a rising charge, for instance).
function Sfx.play(id: string, standIn: StandIn, at: Vector3 | BasePart): Sound
	local sound = build(id, standIn)
	local holder: Instance
	if typeof(at) == "Vector3" then
		local attachment = Instance.new("Attachment")
		attachment.WorldPosition = at
		attachment.Parent = workspace.Terrain
		holder = attachment
	else
		holder = at :: BasePart
	end
	sound.Parent = holder
	sound:Play()

	local length = if id == "" then standIn.length else nil
	if length then
		-- Stand-ins are long sounds cut to size: fade out right at the end instead of clicking off.
		task.delay(math.max(length - 0.1, 0), function()
			if sound.Parent then
				TweenService:Create(sound, TweenInfo.new(0.1), { Volume = 0 }):Play()
			end
		end)
	end
	local lifetime = length or 6
	Debris:AddItem(if holder:IsA("Attachment") then holder else sound, lifetime + 0.2)
	return sound
end

-- Plays a cue on repeat on a part until the returned function is called (it fades out).
function Sfx.loop(id: string, standIn: StandIn, on: BasePart): () -> ()
	local sound = build(id, standIn)
	sound.Looped = true
	sound.Parent = on
	sound:Play()
	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		TweenService:Create(sound, TweenInfo.new(0.3), { Volume = 0 }):Play()
		Debris:AddItem(sound, 0.35)
	end
end

return Sfx
