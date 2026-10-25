--!strict
-- Naruto's visuals. Every effect has a built-in look made of parts. To use an effect made in a VFX
-- plugin instead, put it in ReplicatedStorage > Assets > VFX with the same name:
--   Rasengan, GiantRasengan, Rasenshuriken (held / flying), RasenshurikenExplosion (burst)
local Players = game:GetService("Players")

local Cutscene = require(script.Parent.Parent.Util.Cutscene)
local VfxUtil = require(script.Parent.Parent.Util.VfxUtil)

-- Where held effects sit. Tweak these once your animations put the hand somewhere else.
local SHURIKEN_OFFSET = Vector3.new(1.4, 4.2, 0) -- Rasenshuriken, relative to the HumanoidRootPart
local GIANT_GAP = 1.5 -- studs between the HumanoidRootPart and the Giant Rasengan's surface

local BLUE = Color3.fromRGB(70, 170, 255)
local LIGHT_BLUE = Color3.fromRGB(185, 235, 255)
local WHITE = Color3.fromRGB(245, 250, 255)
local SPARKS_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

-- A held or flying effect that gets moved every frame.
type Effect = {
	update: (cframe: CFrame, t: number, scale: number) -> (),
	destroy: () -> (),
}

local function customEffect(name: string): Effect?
	local custom = VfxUtil.asset(name)
	if not custom then
		return nil
	end
	return {
		update = function(cframe: CFrame, _t: number, _scale: number)
			VfxUtil.pivot(custom, cframe)
		end,
		destroy = function()
			custom:Destroy()
		end,
	}
end

local function builtInRasengan(): Effect
	local core = VfxUtil.part({ size = Vector3.one, color = LIGHT_BLUE, shape = Enum.PartType.Ball })
	local shell = VfxUtil.part({
		size = Vector3.one,
		color = BLUE,
		shape = Enum.PartType.Ball,
		material = Enum.Material.ForceField,
	})
	local ringA = VfxUtil.part({
		size = Vector3.new(0.05, 1, 1),
		color = WHITE,
		shape = Enum.PartType.Cylinder,
		transparency = 0.5,
	})
	local ringB = VfxUtil.part({
		size = Vector3.new(0.05, 1, 1),
		color = BLUE,
		shape = Enum.PartType.Cylinder,
		transparency = 0.4,
	})

	local light = Instance.new("PointLight")
	light.Color = BLUE
	light.Brightness = 3
	light.Parent = core

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARKS_TEXTURE
	sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(WHITE, BLUE)
	sparks.Size = NumberSequence.new(0.35, 0)
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Rate = 60
	sparks.Speed = NumberRange.new(3, 6)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.RotSpeed = NumberRange.new(-360, 360)
	sparks.Parent = core

	return {
		update = function(cframe: CFrame, t: number, scale: number)
			core.Size = Vector3.one * scale * 0.55
			core.CFrame = cframe
			shell.Size = Vector3.one * scale
			shell.CFrame = cframe * CFrame.Angles(t * 3, t * 5, 0)
			ringA.Size = Vector3.new(0.05, scale * 1.15, scale * 1.15)
			ringA.CFrame = cframe * CFrame.Angles(t * 14, t * 9, 0)
			ringB.Size = Vector3.new(0.05, scale * 1.05, scale * 1.05)
			ringB.CFrame = cframe * CFrame.Angles(0, t * 11, t * 13)
			light.Range = scale * 6
		end,
		destroy = function()
			sparks.Enabled = false
			VfxUtil.fadeOut({ core, shell, ringA, ringB }, 0.15, 0.2)
		end,
	}
end

local function builtInShuriken(): Effect
	local center = builtInRasengan()
	local disk = VfxUtil.part({
		size = Vector3.new(0.08, 1, 1),
		color = WHITE,
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.ForceField,
	})
	local blades: { BasePart } = {}
	for i = 1, 4 do
		blades[i] = VfxUtil.part({ size = Vector3.one, color = WHITE, wedge = true, transparency = 0.2 })
	end

	return {
		update = function(cframe: CFrame, t: number, scale: number)
			center.update(cframe, t, scale * 1.3)
			local spin = cframe * CFrame.Angles(0, t * 22, 0)
			disk.Size = Vector3.new(0.08, scale * 6.5, scale * 6.5)
			disk.CFrame = spin * CFrame.Angles(0, 0, math.pi / 2)
			for i, blade in blades do
				blade.Size = Vector3.new(scale * 0.06, scale * 1.1, scale * 3)
				blade.CFrame = spin
					* CFrame.Angles(0, (i - 1) * math.pi / 2, 0)
					* CFrame.new(0, 0, -scale * 2.1)
					* CFrame.Angles(0, 0, math.pi / 2)
			end
		end,
		destroy = function()
			center.destroy()
			local parts = table.clone(blades)
			table.insert(parts, disk)
			VfxUtil.fadeOut(parts, 0.2, 1.3)
		end,
	}
end

local function rasenganEffect(assetName: string): Effect
	return customEffect(assetName) or builtInRasengan()
end

local function shurikenEffect(): Effect
	return customEffect("Rasenshuriken") or builtInShuriken()
end

-- Camera shots for the caster while the Rasenshuriken forms. Offsets are relative to the HumanoidRootPart.
local function playRasenshurikenCutscene(root: BasePart, duration: number)
	local function shot(cameraOffset: Vector3, lookOffset: Vector3): () -> CFrame
		return function()
			local cf = root.CFrame
			return CFrame.lookAt(cf:PointToWorldSpace(cameraOffset), cf:PointToWorldSpace(lookOffset))
		end
	end
	local face = Vector3.new(0, 1.5, 0)
	local ahead = Vector3.new(0, 2, -30)
	local first = duration * 0.4
	local second = duration * 0.4
	Cutscene.play({
		{
			duration = first,
			from = shot(Vector3.new(0, 1.6, -5), face),
			to = shot(Vector3.new(0, 1.6, -3.2), face),
			fov = 50,
		},
		{
			duration = second,
			from = shot(Vector3.new(6, 0, -4), SHURIKEN_OFFSET),
			to = shot(Vector3.new(4, -0.5, -6), SHURIKEN_OFFSET),
			fov = 60,
		},
		{
			duration = duration - first - second,
			from = shot(Vector3.new(2.5, 3, 7), ahead),
			to = shot(Vector3.new(2, 2.5, 5), ahead),
			fov = 70,
		},
	}, "RASENSHURIKEN!")
end

local Naruto: { [string]: VfxUtil.Handler } = {}

-- Rasengan in the right hand of `caster` (the player or a clone).
function Naruto.Rasengan(payload: VfxUtil.Payload): (() -> ())?
	local hand = VfxUtil.bodyPart(payload.caster, { "RightHand", "Right Arm" })
	if not hand then
		return nil
	end
	local duration = payload.duration :: number
	local scale = (payload.scale :: number?) or 1
	local sphere = rasenganEffect("Rasengan")
	return VfxUtil.everyFrame(duration, function(t)
		if not hand.Parent then
			return false
		end
		local size = scale * math.min(t / 0.15, 1)
		local palm = hand.CFrame * CFrame.new(0, -(hand.Size.Y / 2 + size * 0.4), 0)
		sphere.update(CFrame.new(palm.Position), t, size)
		return true
	end, sphere.destroy)
end

-- Huge Rasengan in front of the caster that grows while charging.
function Naruto.GiantRasengan(payload: VfxUtil.Payload): (() -> ())?
	local root = VfxUtil.bodyPart(payload.caster, { "HumanoidRootPart" })
	if not root then
		return nil
	end
	local charge = payload.charge :: number
	local duration = payload.duration :: number
	local scale = payload.scale :: number
	local sphere = rasenganEffect("GiantRasengan")
	return VfxUtil.everyFrame(duration, function(t)
		if not root.Parent then
			return false
		end
		local growth = math.clamp(t / charge, 0, 1)
		local size = scale * (0.15 + 0.85 * (1 - (1 - growth) ^ 2))
		local cf = root.CFrame * CFrame.new(0, 0.5, -(size / 2 + GIANT_GAP))
		sphere.update(CFrame.new(cf.Position), t, size)
		return true
	end, sphere.destroy)
end

-- Rasenshuriken forming over the caster's shoulder. The caster also gets the cutscene.
function Naruto.RasenshurikenCharge(payload: VfxUtil.Payload): (() -> ())?
	local caster = payload.caster :: Model?
	local root = VfxUtil.bodyPart(caster, { "HumanoidRootPart" })
	if not caster or not root then
		return nil
	end
	local duration = payload.duration :: number
	local shuriken = shurikenEffect()
	local stop = VfxUtil.everyFrame(duration + 0.1, function(t)
		if not root.Parent then
			return false
		end
		local growth = math.clamp(t / (duration * 0.6), 0.1, 1)
		shuriken.update(CFrame.new(root.CFrame:PointToWorldSpace(SHURIKEN_OFFSET)), t, growth)
		return true
	end, shuriken.destroy)
	if caster == Players.LocalPlayer.Character then
		playRasenshurikenCutscene(root, duration)
	end
	return stop
end

-- Flying Rasenshuriken. Follows the same straight path the server uses for hit detection.
function Naruto.RasenshurikenThrow(payload: VfxUtil.Payload): (() -> ())?
	local origin = payload.origin :: Vector3
	local direction = payload.direction :: Vector3
	local speed = payload.speed :: number
	local maxTime = payload.maxTime :: number
	local shuriken = shurikenEffect()
	return VfxUtil.everyFrame(maxTime + 0.3, function(t)
		local position = origin + direction * speed * math.min(t, maxTime)
		shuriken.update(CFrame.lookAt(position, position + direction), t, 1)
		return true
	end, shuriken.destroy)
end

-- The shredding wind dome when the Rasenshuriken hits.
function Naruto.RasenshurikenExplode(payload: VfxUtil.Payload): (() -> ())?
	local position = payload.position :: Vector3
	local radius = payload.radius :: number
	local duration = payload.duration :: number
	if VfxUtil.burstAsset("RasenshurikenExplosion", CFrame.new(position), duration + 2) then
		return nil
	end

	local dome = VfxUtil.part({
		size = Vector3.one,
		color = WHITE,
		shape = Enum.PartType.Ball,
		material = Enum.Material.ForceField,
	})
	local inner = VfxUtil.part({
		size = Vector3.one,
		color = LIGHT_BLUE,
		shape = Enum.PartType.Ball,
		transparency = 0.35,
		cframe = CFrame.new(position),
	})
	local light = Instance.new("PointLight")
	light.Color = LIGHT_BLUE
	light.Brightness = 5
	light.Range = 40
	light.Parent = inner

	local blades: { BasePart } = {}
	for i = 1, 6 do
		blades[i] = VfxUtil.part({ size = Vector3.one, color = WHITE, transparency = 0.3 })
	end

	VfxUtil.everyFrame(duration, function(t)
		local diameter = radius * 2 * math.min(t / 0.15, 1)
		dome.Size = Vector3.one * diameter
		dome.CFrame = CFrame.new(position) * CFrame.Angles(0, t * 4, 0)
		inner.Size = Vector3.one * diameter * 0.55
		for i, blade in blades do
			blade.Size = Vector3.new(0.35, 0.35, diameter * 1.05)
			blade.CFrame = CFrame.new(position) * CFrame.Angles(0, t * 18 + i * math.pi / 3, math.sin(t * 6 + i) * 0.4)
		end
		return true
	end, function()
		local parts = table.clone(blades)
		table.insert(parts, dome)
		table.insert(parts, inner)
		VfxUtil.fadeOut(parts, 0.35, 1.15)
	end)
	return nil
end

return Naruto
