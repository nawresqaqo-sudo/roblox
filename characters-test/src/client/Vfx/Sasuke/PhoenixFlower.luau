--!strict
-- 2: Fire Style: Phoenix Flower. Two quick hand signs, a flare of flame at his mouth, then a fan of
-- fireballs: each a small white-hot core wrapped in orange and deep-red flame with a shuriken spinning
-- inside, trailing embers and dark smoke. They burst into fire on whatever they hit and leave small
-- flames and a scorch mark on walls and floors.
local Kit = require(script.Parent.Kit)

local Client = script.Parent.Parent.Parent
local Util = Client:WaitForChild("Util")
local AnimeFx = require(Util:WaitForChild("AnimeFx"))
local Rig = require(Util:WaitForChild("Rig"))
local VfxUtil = require(Util:WaitForChild("VfxUtil"))
local Clips = require(Client:WaitForChild("Animations"):WaitForChild("Sasuke"))

local C = Kit.Colors
local T = Kit.Textures
local METAL = Color3.fromRGB(58, 60, 70)

local PhoenixFlower: { [string]: VfxUtil.Handler } = {}

-- Fireballs in the air, by id, so the server's impact message can end the right one.
local fireballs: { [string]: (impact: boolean) -> () } = {}

local function fireColors(): ColorSequence
	return ColorSequence.new({
		ColorSequenceKeypoint.new(0, C.FlameCore),
		ColorSequenceKeypoint.new(0.3, C.Flame),
		ColorSequenceKeypoint.new(1, C.FlameRed),
	})
end

local function mouth(character: Model): Vector3?
	local head = Rig.part(character, { "Head" })
	return if head then (head.CFrame * CFrame.new(0, -0.25, -0.9)).Position else nil
end

function PhoenixFlower.PhoenixFlower(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = Kit.casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local signs = payload.signs :: number
	Kit.animate(character, 2, Clips.PhoenixFlower)

	-- Each hand sign snaps with a little flare of chakra between the hands.
	for _, at in { 0.08, 0.16 } do
		task.delay(at, function()
			if not rootPart.Parent then
				return
			end
			Kit.sound("PhoenixSigns", rootPart)
			local left, right = Rig.hand(character, "Left"), Rig.hand(character, "Right")
			if left and right then
				AnimeFx.flash((left.Position + right.Position) / 2, C.Flame, 1.4, 0.12)
			end
		end)
	end
	-- He breathes out and the flame catches at his lips.
	task.delay(signs, function()
		local lips = mouth(character)
		if not lips or not rootPart.Parent then
			return
		end
		Kit.sound("PhoenixIgnite", rootPart)
		AnimeFx.flash(lips, C.Flame, 3.2, 0.2)
		VfxUtil.burst(CFrame.lookAt(lips, lips + rootPart.CFrame.LookVector) * CFrame.Angles(-math.pi / 2, 0, 0), {
			texture = T.Fire,
			color = fireColors(),
			size = NumberSequence.new(1.4, 0.3),
			lifetime = NumberRange.new(0.15, 0.3),
			speed = NumberRange.new(10, 18),
			spread = Vector2.new(25, 25),
			lightEmission = 0.8,
			rotSpeed = NumberRange.new(-180, 180),
		}, 18)
	end)
	return nil
end

-- One fireball, flown along the same path the server checks hits on.
function PhoenixFlower.Fireball(payload: VfxUtil.Payload): (() -> ())?
	local id = payload.id :: string
	local origin = payload.origin :: Vector3
	local direction = payload.direction :: Vector3
	local bend = payload.bend :: number
	local rise = payload.rise :: number
	local maxTime = Kit.Data.Tuning.PhoenixFlower.MaxFlightTime
	local positionAt = Kit.Data.fireballPosition

	AnimeFx.flash(origin, C.Flame, 2.2, 0.14)
	Kit.sound("PhoenixLaunch", origin)

	local carrier = Kit.holder(CFrame.lookAt(origin, origin + direction), Vector3.one * 0.6)
	local core = VfxUtil.part({ size = Vector3.one * 0.55, color = C.FlameCore, shape = Enum.PartType.Ball })
	local light = Instance.new("PointLight")
	light.Color = C.Flame
	light.Brightness = 2.5
	light.Range = 9
	light.Parent = carrier
	-- Flame body, hot center, embers and smoke, each its own layer.
	VfxUtil.emitter(carrier, {
		texture = T.Fire,
		color = fireColors(),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.7),
			NumberSequenceKeypoint.new(0.4, 1.3),
			NumberSequenceKeypoint.new(1, 0.4),
		}),
		transparency = NumberSequence.new(0.1, 1),
		lifetime = NumberRange.new(0.16, 0.3),
		speed = NumberRange.new(0.5, 2),
		rate = 90,
		lightEmission = 0.85,
		rotSpeed = NumberRange.new(-200, 200),
		zOffset = 0.3,
	})
	VfxUtil.emitter(carrier, {
		texture = T.Glow,
		color = ColorSequence.new(C.FlameCore, C.Flame),
		size = NumberSequence.new(1.3, 0.8),
		transparency = NumberSequence.new(0.2, 1),
		lifetime = NumberRange.new(0.06, 0.1),
		rate = 40,
		lightEmission = 1,
		lockedToPart = true,
		zOffset = 0.5,
	})
	VfxUtil.emitter(carrier, {
		texture = T.Embers,
		color = ColorSequence.new(C.Flame, C.FlameRed),
		size = NumberSequence.new(0.28, 0),
		lifetime = NumberRange.new(0.3, 0.6),
		speed = NumberRange.new(2, 5),
		acceleration = Vector3.new(0, 4, 0),
		rate = 25,
		lightEmission = 1,
	})
	VfxUtil.emitter(carrier, {
		texture = T.Smoke,
		color = ColorSequence.new(C.Smoke),
		size = NumberSequence.new(0.8, 2.2),
		transparency = NumberSequence.new(0.55, 1),
		lifetime = NumberRange.new(0.4, 0.7),
		speed = NumberRange.new(0.5, 1.5),
		acceleration = Vector3.new(0, 3, 0),
		rate = 12,
		rotSpeed = NumberRange.new(-60, 60),
		zOffset = -0.5,
	})
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.3, 0)
	top.Parent = carrier
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.3, 0)
	bottom.Parent = carrier
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = fireColors()
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0)
	trail.Lifetime = 0.12
	trail.LightEmission = 0.8
	trail.LightInfluence = 0
	trail.FaceCamera = true
	trail.Parent = carrier
	-- The shuriken hidden in the flame: two crossed blades, spinning flat.
	local blades = {
		VfxUtil.part({ size = Vector3.new(1, 0.05, 0.2), color = METAL, material = Enum.Material.Metal }),
		VfxUtil.part({ size = Vector3.new(0.2, 0.05, 1), color = METAL, material = Enum.Material.Metal }),
	}
	if Kit.slotOn("Sasuke_Fireball", carrier, maxTime) then
		-- Your own fireball follows the carrier; hide the built-in one.
		Kit.quiet(carrier)
		core.Transparency = 1
		for _, blade in blades do
			blade.Transparency = 1
		end
	end
	local stopFlight = Kit.loop("PhoenixFlight", carrier)

	local finished = false
	local stopMove: () -> () = function() end
	local function finish(impact: boolean)
		if finished then
			return
		end
		finished = true
		fireballs[id] = nil
		stopMove()
		stopFlight()
		if not impact then
			-- Burnt out in the air: a puff of smoke where it was.
			VfxUtil.burst(carrier.CFrame, {
				texture = T.Smoke,
				color = ColorSequence.new(C.Smoke),
				size = NumberSequence.new(1, 2.6),
				transparency = NumberSequence.new(0.4, 1),
				lifetime = NumberRange.new(0.4, 0.7),
				speed = NumberRange.new(1, 3),
			}, 5)
		end
		core:Destroy()
		for _, blade in blades do
			blade:Destroy()
		end
		Kit.retire(carrier, 0.8)
	end
	stopMove = VfxUtil.everyFrame(maxTime, function(t)
		local position = positionAt(origin, direction, bend, rise, t)
		local ahead = positionAt(origin, direction, bend, rise, t + 0.02)
		carrier.CFrame = CFrame.lookAt(position, ahead)
		core.CFrame = CFrame.new(position)
		local spin = CFrame.new(position) * CFrame.Angles(0, t * 40, 0)
		blades[1].CFrame = spin
		blades[2].CFrame = spin
		return true
	end, function()
		finish(false)
	end)
	fireballs[id] = finish
	return function()
		finish(false)
	end
end

-- A fireball bursts: flame and embers thrown off the surface, a ring of heat, smoke, and on walls and
-- floors a small fire that dies down and a scorch mark that fades.
function PhoenixFlower.FireballImpact(payload: VfxUtil.Payload): (() -> ())?
	local id = payload.id :: string
	local position = payload.position :: Vector3
	local normal = payload.normal :: Vector3?
	local finish = fireballs[id]
	if finish then
		finish(true)
	end
	Kit.sound("PhoenixImpact", position)
	local surface = if normal then Kit.across(position, normal) else CFrame.new(position)
	if Kit.slot("Sasuke_FireballImpact", surface) then
		return nil
	end

	AnimeFx.flash(position, C.Flame, 4.5, 0.22)
	AnimeFx.ring(surface, { from = 0.5, to = 5, color = C.Flame, thickness = 0.5, duration = 0.3, transparency = 0.2 })
	VfxUtil.burst(surface, {
		texture = T.Fire,
		color = fireColors(),
		size = NumberSequence.new(1.8, 0.3),
		lifetime = NumberRange.new(0.25, 0.45),
		speed = NumberRange.new(6, 14),
		spread = Vector2.new(65, 65),
		drag = 2,
		lightEmission = 0.8,
		rotSpeed = NumberRange.new(-180, 180),
	}, 22)
	VfxUtil.burst(surface, {
		texture = T.Embers,
		color = ColorSequence.new(C.Flame, C.FlameRed),
		size = NumberSequence.new(0.3, 0),
		lifetime = NumberRange.new(0.4, 0.8),
		speed = NumberRange.new(8, 18),
		spread = Vector2.new(70, 70),
		acceleration = Vector3.new(0, -25, 0),
		lightEmission = 1,
	}, 16)
	VfxUtil.burst(surface, {
		texture = T.Smoke,
		color = ColorSequence.new(C.Smoke),
		size = NumberSequence.new(1.5, 3.5),
		transparency = NumberSequence.new(0.4, 1),
		lifetime = NumberRange.new(0.6, 1),
		speed = NumberRange.new(2, 5),
		acceleration = Vector3.new(0, 4, 0),
		rotSpeed = NumberRange.new(-40, 40),
	}, 6)

	if normal then
		-- A small fire that dies down, and a scorch mark.
		local flames = Kit.holder(surface * CFrame.new(0, 0.2, 0), Vector3.new(1.2, 0.2, 1.2))
		VfxUtil.emitter(flames, {
			texture = T.Fire,
			color = fireColors(),
			size = NumberSequence.new(0.9, 0.2),
			lifetime = NumberRange.new(0.25, 0.45),
			speed = NumberRange.new(1.5, 3.5),
			spread = Vector2.new(15, 15),
			rate = 18,
			lightEmission = 0.8,
			rotSpeed = NumberRange.new(-120, 120),
		})
		task.delay(0.9, function()
			Kit.retire(flames, 0.6)
		end)
		local scorch = VfxUtil.part({
			size = Vector3.new(0.05, 2.4, 2.4),
			color = Color3.fromRGB(26, 22, 22),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.SmoothPlastic,
			transparency = 0.3,
			cframe = surface * CFrame.new(0, 0.03, 0) * CFrame.Angles(0, 0, math.pi / 2),
		})
		task.delay(1.2, function()
			VfxUtil.fadeOut({ scorch }, 1.5)
		end)
	elseif Kit.nearCamera(position, 35) then
		VfxUtil.shake(0.2, 0.12)
	end
	return nil
end

return PhoenixFlower
