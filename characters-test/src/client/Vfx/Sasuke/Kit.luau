--!strict
-- What Sasuke's four moves share on screen: the palette, particle textures, sounds and small helpers.
-- Palette: obsidian black, violet and electric purple, blue-white lightning, crimson for the Mangekyo.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent.Parent
local Util = Client:WaitForChild("Util")
local AnimeFx = require(Util:WaitForChild("AnimeFx"))
local Rig = require(Util:WaitForChild("Rig"))
local Sfx = require(Util:WaitForChild("Sfx"))
local VfxUtil = require(Util:WaitForChild("VfxUtil"))
local MoveAnimator = require(Client:WaitForChild("Controllers"):WaitForChild("MoveAnimator"))
local SasukeData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Characters"):WaitForChild("Sasuke"))

local Kit = {}

Kit.Data = SasukeData

Kit.Colors = {
	Obsidian = Color3.fromRGB(12, 9, 18),
	Violet = Color3.fromRGB(88, 32, 170),
	Purple = Color3.fromRGB(160, 90, 255),
	Electric = Color3.fromRGB(110, 185, 255),
	Core = Color3.fromRGB(228, 242, 255),
	Crimson = Color3.fromRGB(215, 25, 50),
	FlameCore = Color3.fromRGB(255, 244, 205),
	Flame = Color3.fromRGB(255, 150, 40),
	FlameRed = Color3.fromRGB(205, 45, 12),
	Smoke = Color3.fromRGB(46, 40, 42),
	BlackFlame = Color3.fromRGB(8, 4, 12),
	Stone = Color3.fromRGB(95, 90, 88),
}

-- Particle textures that ship with every Roblox client.
Kit.Textures = {
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
	Glow = "rbxasset://textures/particles/forcefield_glow_main.dds",
	Vortex = "rbxasset://textures/particles/forcefield_vortex_main.dds",
	Fire = "rbxasset://textures/particles/fire_main.dds",
	Embers = "rbxasset://textures/particles/fire_sparks_main.dds",
	Smoke = "rbxasset://textures/particles/smoke_main.dds",
	BlastCore = "rbxasset://textures/particles/explosion01_core_main.dds",
	BlastRing = "rbxasset://textures/particles/explosion01_shockwave_main.dds",
	Implosion = "rbxasset://textures/particles/explosion01_implosion_main.dds",
}

Kit.NEAR = 120 -- impact frames and big shakes only for players this close
Kit.SKY_RANGE = 300 -- the sky turns stormy for players this close

-- Your own effects (Sine VFX or any VFX plugin): put an effect in ReplicatedStorage > Assets > VFX named
-- after one of these slots and it plays at that moment of the move, next to the built-in one.
-- Set REPLACE_BUILT_IN to true to hide the built-in effect for every slot you've filled.
--   Sasuke_ChidoriHand (follows his hand)   Sasuke_ChidoriImpact
--   Sasuke_Fireball (follows each fireball)   Sasuke_FireballImpact
--   Sasuke_AmaterasuMark   Sasuke_AmaterasuFlames (follows a burning target)   Sasuke_AmaterasuPatch
--   Sasuke_KirinStorm (above the strike point)   Sasuke_KirinImpact
Kit.REPLACE_BUILT_IN = false

-- Sounds ---------------------------------------------------------------------------------------------
-- Stand-ins used while a cue has no sound id in Shared.Characters.Sasuke.Sounds. Volume and range apply
-- to real sounds too.
local W, L, J = Sfx.WIND, Sfx.LAND, Sfx.JUMP
local STAND_INS: { [string]: Sfx.StandIn } = {
	ChidoriCharge = { sound = W, shape = "Crackle", pitch = 1.8, volume = 0.9, length = 0.5 },
	ChidoriCrackle = { sound = W, shape = "Crackle", pitch = 2.6, volume = 0.45, looped = true },
	ChidoriDash = { sound = W, shape = "Whoosh", pitch = 1.5, volume = 1, length = 0.4 },
	ChidoriImpact = { sound = L, shape = "Boom", pitch = 0.75, volume = 1.4, range = 220 },
	ChidoriResidual = { sound = W, shape = "Crackle", pitch = 3.2, volume = 0.35, length = 0.7 },
	PhoenixSigns = { sound = J, shape = "Whoosh", pitch = 1.7, volume = 0.6, length = 0.25 },
	PhoenixIgnite = { sound = W, shape = "Roar", pitch = 0.8, volume = 1, length = 0.6 },
	PhoenixLaunch = { sound = W, shape = "Roar", pitch = 1.15, volume = 0.6, length = 0.3 },
	PhoenixFlight = { sound = W, shape = "Hiss", pitch = 1.3, volume = 0.3, looped = true, range = 90 },
	PhoenixImpact = { sound = L, shape = "Thud", pitch = 0.9, volume = 0.9 },
	AmaterasuActivate = { sound = J, shape = "Eerie", pitch = 0.55, volume = 0.9, length = 0.8 },
	AmaterasuTone = { sound = W, shape = "Rumble", pitch = 0.32, volume = 1.2, length = 1.4 },
	AmaterasuIgnite = { sound = L, shape = "Boom", pitch = 0.5, volume = 1.2 },
	AmaterasuBurn = { sound = W, shape = "Hiss", pitch = 0.75, volume = 0.5, looped = true, range = 100 },
	AmaterasuEnd = { sound = W, shape = "Whoosh", pitch = 2.2, volume = 0.6, length = 0.35 },
	KirinRumble = { sound = W, shape = "Rumble", pitch = 0.3, volume = 1.5, looped = true, range = 400 },
	KirinTension = { sound = W, shape = "Crackle", pitch = 1.5, volume = 0.7, length = 1.7, range = 300 },
	KirinCue = { sound = W, shape = "Whoosh", pitch = 3.4, volume = 0.8, length = 0.25, range = 300 },
	KirinThunder = { sound = L, shape = "Boom", pitch = 0.38, volume = 2.5, range = 600 },
	KirinShockwave = { sound = W, shape = "Boom", pitch = 0.55, volume = 1.3, length = 1.2, range = 450 },
	KirinResidual = { sound = W, shape = "Crackle", pitch = 2.8, volume = 0.5, length = 1.5, range = 200 },
}

local function cueId(cue: string): string
	local id = (SasukeData.Sounds :: { [string]: string })[cue]
	return if typeof(id) == "string" then id else ""
end

-- Plays one of Sasuke's sound cues once, at a spot or on a part.
function Kit.sound(cue: string, at: Vector3 | BasePart): Sound
	return Sfx.play(cueId(cue), STAND_INS[cue], at)
end

-- Plays one of Sasuke's sound cues on repeat until the returned function is called.
function Kit.loop(cue: string, on: BasePart): () -> ()
	return Sfx.loop(cueId(cue), STAND_INS[cue], on)
end

-- Helpers --------------------------------------------------------------------------------------------

function Kit.modelOf(value: unknown): Model?
	if typeof(value) == "Instance" and value:IsA("Model") then
		return value
	end
	return nil
end

function Kit.casterOf(payload: VfxUtil.Payload): (Model?, BasePart?)
	local caster = Kit.modelOf(payload.caster)
	if not caster then
		return nil, nil
	end
	return caster, Rig.part(caster, { "HumanoidRootPart" })
end

function Kit.isLocal(model: Model?): boolean
	return model ~= nil and model == Players.LocalPlayer.Character
end

function Kit.nearCamera(position: Vector3, range: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.Focus.Position - position).Magnitude < range
end

-- Plays a custom effect for `name` at `cframe` if you made one. True means skip the built-in effect.
function Kit.slot(name: string, cframe: CFrame): boolean
	return AnimeFx.custom(name, cframe) and Kit.REPLACE_BUILT_IN
end

-- Like slot, but the custom effect follows `part` for `duration` seconds.
function Kit.slotOn(name: string, part: BasePart, duration: number): boolean
	local stop = AnimeFx.customFollow(name, function()
		return if part.Parent then part.CFrame else nil
	end, duration)
	return stop ~= nil and Kit.REPLACE_BUILT_IN
end

-- Plays a coded clip unless a real animation id was set for that move.
function Kit.animate(caster: Model, slot: number, clip: MoveAnimator.Clip)
	for _, move in SasukeData.Info.Moves do
		if move.Slot == slot and move.AnimationId ~= "" then
			return
		end
	end
	MoveAnimator.play(caster, clip)
end

function Kit.feet(root: BasePart): Vector3
	return root.Position - Vector3.new(0, 2.7, 0)
end

-- A cframe looking along `direction`, with Y as the normal: for rings standing up across a hit.
function Kit.across(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- A camera shot following a part: camera and look-at points are offsets in the part's space.
function Kit.shot(root: BasePart, cameraOffset: Vector3, lookOffset: Vector3): () -> CFrame
	return function()
		local cf = root.CFrame
		return CFrame.lookAt(cf:PointToWorldSpace(cameraOffset), cf:PointToWorldSpace(lookOffset))
	end
end

-- The part a hand effect rides on, and the offset from it to the middle of the fist.
function Kit.hand(character: Model, side: "Left" | "Right"): (BasePart?, CFrame)
	local hand = Rig.part(character, { side .. "Hand" })
	if hand then
		return hand, CFrame.identity
	end
	local arm = Rig.part(character, { side .. " Arm" })
	if arm then
		return arm, CFrame.new(0, -arm.Size.Y / 2, 0)
	end
	return nil, CFrame.identity
end

-- The visible body parts of a character (for electricity crawling over it).
function Kit.bodyParts(character: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, child in character:GetChildren() do
		if child:IsA("BasePart") and child.Transparency < 1 and child.Name ~= "HumanoidRootPart" then
			table.insert(parts, child)
		end
	end
	return parts
end

-- A random spot on (or just inside) a part.
function Kit.pointOn(part: BasePart): Vector3
	local s = part.Size
	return (part.CFrame * CFrame.new(
		(math.random() - 0.5) * s.X,
		(math.random() - 0.5) * s.Y,
		(math.random() - 0.5) * s.Z
	)).Position
end

-- A point glued to a part, as a function: bolts drawn with it ride along with a running character.
function Kit.stuck(part: BasePart, point: Vector3): () -> Vector3?
	local localPoint = part.CFrame:PointToObjectSpace(point)
	return function()
		return if part.Parent then part.CFrame:PointToWorldSpace(localPoint) else nil
	end
end

-- An invisible anchored part to hang emitters, lights and sounds on.
function Kit.holder(cframe: CFrame, size: Vector3?): BasePart
	local part = VfxUtil.part({ size = size or Vector3.one * 0.2, color = Color3.new(1, 1, 1), transparency = 1 })
	part.CFrame = cframe
	return part
end

-- Turns off every emitter, trail, beam and light under `root` (what's already in the air finishes).
function Kit.quiet(root: Instance)
	for _, child in root:GetDescendants() do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("Trail") then
			child.Enabled = false
		elseif child:IsA("Beam") then
			child.Enabled = false
		elseif child:IsA("Light") then
			child.Enabled = false
		end
	end
end

-- Quiets `root`, then deletes it once its particles have faded.
function Kit.retire(root: Instance, linger: number?)
	Kit.quiet(root)
	task.delay(linger or 1.2, function()
		root:Destroy()
	end)
end

-- A quick darkening of this player's screen (the Mangekyo's pulse).
function Kit.darkPulse(duration: number)
	local Lighting = game:GetService("Lighting")
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Saturation = -0.55
	effect.Brightness = -0.08
	effect.Contrast = 0.2
	effect.TintColor = Color3.fromRGB(235, 215, 255)
	effect.Parent = Lighting
	VfxUtil.tween(effect, duration, { Saturation = 0, Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
	task.delay(duration + 0.05, function()
		effect:Destroy()
	end)
end

return Kit
