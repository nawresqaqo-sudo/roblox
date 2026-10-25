--!strict
-- Plays sounds from Config.Sounds. An empty id is skipped, so any sound can be turned off.
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")

local Sfx = {}

function Sfx.make(soundId: string, parent: Instance, volume: number, pitch: number?): Sound?
	if soundId == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = pitch or 1
	sound.RollOffMaxDistance = 150
	sound.Parent = parent
	return sound
end

-- A one-off sound heard from a spot in the world.
function Sfx.playAt(soundId: string, position: Vector3, volume: number, pitch: number?)
	if soundId == "" then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	attachment.WorldPosition = position
	local sound = Sfx.make(soundId, attachment, volume, pitch)
	if sound then
		sound:Play()
	end
	Debris:AddItem(attachment, 4)
end

-- A one-off sound with no position (UI sounds).
function Sfx.play(soundId: string, volume: number, pitch: number?)
	local sound = Sfx.make(soundId, SoundService, volume, pitch)
	if sound then
		sound:Play()
		Debris:AddItem(sound, 4)
	end
end

return Sfx
