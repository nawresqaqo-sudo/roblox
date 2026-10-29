--!strict
-- 1: Chidori: Lightning Assault. Lightning forms in his right hand (a pulsing blue-white core in a purple
-- glow, arcs chirping out of it and crawling up his arm, sparks dragging on the ground), a blinding dash
-- that leaves a jagged lightning ribbon and electric afterimages, then the thrust: a white flash, a ring
-- of forked bolts, sparks, a small shockwave and electricity crawling over whoever it hit.
local Kit = require(script.Parent.Kit)

local Client = script.Parent.Parent.Parent
local Util = Client:WaitForChild("Util")
local AnimeFx = require(Util:WaitForChild("AnimeFx"))
local Rig = require(Util:WaitForChild("Rig"))
local VfxUtil = require(Util:WaitForChild("VfxUtil"))
local MoveAnimator = require(Client:WaitForChild("Controllers"):WaitForChild("MoveAnimator"))
local Clips = require(Client:WaitForChild("Animations"):WaitForChild("Sasuke"))

local C = Kit.Colors
local T = Kit.Textures

type Hand = {
	core: BasePart,
	sparks: ParticleEmitter,
	trail: Trail,
	slotted: boolean, -- a custom effect replaces the built-in one
	-- Ends the Chidori: `hit` means it discharged into someone (the impact effect takes over).
	stop: (hit: boolean) -> (),
}

-- The Chidori lit in each character's hand right now.
local hands: { [Model]: Hand } = {}

local Chidori: { [string]: VfxUtil.Handler } = {}

local function keypoints(...: Color3): ColorSequence
	local colors = { ... }
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

-- The Chidori in his hand. Lives until stop() is called, or `life` seconds as a safety net.
local function lightHand(character: Model, life: number): Hand?
	local part, offset = Kit.hand(character, "Right")
	if not part then
		return nil
	end
	local hand: BasePart = part
	local started = os.clock()
	local function strength(): number
		return math.min((os.clock() - started) / 0.3, 1)
	end

	local core = VfxUtil.part({ size = Vector3.one * 0.4, color = C.Core, shape = Enum.PartType.Ball })
	core.CFrame = hand.CFrame * offset
	local light = Instance.new("PointLight")
	light.Color = C.Electric
	light.Brightness = 2
	light.Range = 8
	light.Parent = core
	local sparks = VfxUtil.emitter(core, {
		texture = T.Spark,
		color = keypoints(C.Core, C.Electric),
		size = NumberSequence.new(0.45, 0),
		lifetime = NumberRange.new(0.08, 0.22),
		speed = NumberRange.new(8, 16),
		drag = 4,
		rate = 70,
		lightEmission = 1,
		brightness = 2,
	})
	VfxUtil.emitter(core, {
		texture = T.Glow,
		color = keypoints(C.Purple, C.Violet),
		size = NumberSequence.new(2.4, 3.4),
		transparency = NumberSequence.new(0.35, 1),
		lifetime = NumberRange.new(0.12, 0.2),
		rate = 30,
		lightEmission = 1,
		lockedToPart = true,
	})
	-- The ribbon he drags through the air while dashing.
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 0.55, 0)
	top.Parent = core
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -0.55, 0)
	bottom.Parent = core
	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = keypoints(C.Core, C.Electric, C.Purple)
	trail.Transparency = NumberSequence.new(0.05, 1)
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.Lifetime = 0.22
	trail.MinLength = 0.05
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Brightness = 2
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = core

	local function fist(): CFrame?
		return if hand.Parent then hand.CFrame * offset else nil
	end
	-- Arcs chirping out of the fist, longer as it charges.
	local stopChirps = AnimeFx.crackle(fist, function()
		local reach = 0.8 + strength() * (1 + math.random() * 1.8)
		return Vector3.zero, VfxUtil.randomDirection() * reach
	end, {
		duration = life,
		count = 5,
		segments = 4,
		width = 0.09,
		color = C.Electric,
		altColor = C.Purple,
		core = C.Core,
		flicker = 26,
		chance = 0.75,
	})
	-- Lightning crawling up the arm, from the fist toward the shoulder.
	local arm = Rig.armParts(character, "Right")
	local stopCrawl = AnimeFx.crackle(fist, function()
		local frame = fist() or CFrame.identity
		local a = arm[math.random(1, math.max(#arm, 1))]
		local b = arm[math.random(1, math.max(#arm, 1))]
		if not a or not b then
			return Vector3.zero, Vector3.zero
		end
		return frame:PointToObjectSpace(Kit.pointOn(a)), frame:PointToObjectSpace(Kit.pointOn(b))
	end, {
		duration = life,
		count = 3,
		segments = 4,
		width = 0.06,
		color = C.Purple,
		core = C.Core,
		flicker = 20,
		chance = 0.6,
	})
	local slotted = Kit.slotOn("Sasuke_ChidoriHand", core, life)
	if slotted then
		Kit.quiet(core)
		core.Transparency = 1
	end
	local stopCrackle = Kit.loop("ChidoriCrackle", core)

	local done = false
	local stopFollow: () -> () = function() end
	local result: Hand
	local function stop(hit: boolean)
		if done then
			return
		end
		done = true
		if hands[character] == result then
			hands[character] = nil
		end
		stopFollow()
		stopChirps()
		stopCrawl()
		stopCrackle()
		-- A miss fizzles: the sparks drop and the core shrinks away with a last crackle.
		if not hit then
			VfxUtil.burst(core.CFrame, {
				texture = T.Spark,
				color = keypoints(C.Core, C.Electric),
				size = NumberSequence.new(0.35, 0),
				lifetime = NumberRange.new(0.25, 0.5),
				speed = NumberRange.new(4, 10),
				acceleration = Vector3.new(0, -40, 0),
				lightEmission = 1,
			}, 18)
			Kit.sound("ChidoriResidual", core.Position)
		end
		VfxUtil.tween(core, 0.18, { Size = Vector3.one * 0.05, Transparency = 1 })
		VfxUtil.tween(light, 0.25, { Brightness = 0 })
		Kit.retire(core, 0.5)
	end
	stopFollow = VfxUtil.everyFrame(life, function(t)
		local frame = fist()
		if not frame then
			return false
		end
		local s = strength()
		local pulse = 1 + math.sin(t * 38) * 0.12
		core.CFrame = frame
		if not slotted then
			core.Size = Vector3.one * (0.35 + 0.5 * s) * pulse
		end
		light.Brightness = 2 + 6 * s * pulse
		light.Range = 8 + 8 * s
		return true
	end, function()
		stop(false)
	end)
	result = { core = core, sparks = sparks, trail = trail, slotted = slotted, stop = stop }
	return result
end

function Chidori.Chidori(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = Kit.casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local charge = payload.charge :: number
	Kit.animate(character, 1, Clips.ChidoriCharge)

	local old = hands[character]
	if old then
		old.stop(true)
	end
	local tuning = Kit.Data.Tuning.Chidori
	local hand = lightHand(character, charge + tuning.MaxDashTime + 1.2)
	if not hand then
		return nil
	end
	hands[character] = hand
	local core = hand.core
	-- The first spark of it: a sharp blue-white flash in his palm.
	task.delay(0.05, function()
		if core.Parent then
			AnimeFx.flash(core.Position, C.Electric, 2.6, 0.16)
		end
	end)
	local charging = Kit.sound("ChidoriCharge", rootPart)
	VfxUtil.tween(charging, charge, { PlaybackSpeed = charging.PlaybackSpeed * 1.5 }, Enum.EasingStyle.Sine)
	-- Sparks spitting off the ground under the hand as it drags.
	for i = 1, 3 do
		task.delay(i * charge / 4, function()
			if core.Parent and rootPart.Parent then
				local ground = Vector3.new(core.Position.X, Kit.feet(rootPart).Y + 0.2, core.Position.Z)
				VfxUtil.burst(CFrame.new(ground), {
					texture = T.Spark,
					color = keypoints(C.Core, C.Purple),
					size = NumberSequence.new(0.3, 0),
					lifetime = NumberRange.new(0.15, 0.3),
					speed = NumberRange.new(6, 12),
					spread = Vector2.new(70, 70),
					acceleration = Vector3.new(0, -30, 0),
					lightEmission = 1,
				}, 8)
			end
		end)
	end
	return function()
		hand.stop(false)
		if not MoveAnimator.isPlaying(character, Clips.ChidoriThrust) then
			Kit.animate(character, 1, Clips.ChidoriFizzle)
		end
	end
end

function Chidori.ChidoriDash(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = Kit.casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local time = payload.time :: number
	local start = rootPart.Position
	Kit.animate(character, 1, Clips.ChidoriDash)
	Kit.sound("ChidoriDash", rootPart)

	-- A burst of dust and a ring kicked off the ground where he launches.
	AnimeFx.ring(CFrame.new(Kit.feet(rootPart) + Vector3.new(0, 0.15, 0)), {
		from = 1,
		to = 9,
		color = C.Electric,
		thickness = 0.7,
		duration = 0.3,
		transparency = 0.15,
	})
	VfxUtil.burst(CFrame.new(Kit.feet(rootPart)), {
		texture = T.Smoke,
		color = ColorSequence.new(Color3.fromRGB(150, 145, 160)),
		size = NumberSequence.new(1.2, 3),
		transparency = NumberSequence.new(0.5, 1),
		lifetime = NumberRange.new(0.35, 0.6),
		speed = NumberRange.new(6, 12),
		spread = Vector2.new(80, 80),
		drag = 4,
	}, 10)

	local hand = hands[character]
	if hand and not hand.slotted then
		hand.trail.Enabled = true
		hand.sparks.Rate = 140
	end
	-- The jagged ribbon: a bolt from where the hand was a moment ago to where it is now, every frame.
	local last: Vector3? = if hand then hand.core.Position else nil
	local lastImage = -1
	VfxUtil.everyFrame(time + 0.05, function(t)
		local current = hands[character]
		if current and not current.slotted then
			local now = current.core.Position
			if last and (now - last).Magnitude > 0.8 then
				AnimeFx.bolt(last, now, {
					color = if math.random() < 0.5 then C.Electric else C.Purple,
					core = C.Core,
					width = 0.16,
					segments = 3,
					jitter = 0.3,
					duration = 0.22,
					flicker = 20,
				})
			end
			last = now
		end
		if t - lastImage >= 0.06 and character.Parent then
			lastImage = t
			AnimeFx.afterimage(character, if math.random() < 0.5 then C.Electric else C.Violet, 0.25, 0.6)
		end
		return true
	end, function()
		local current = hands[character]
		if current and not current.slotted then
			current.trail.Enabled = false
			current.sparks.Rate = 70
		end
		if rootPart.Parent and (rootPart.Position - start).Magnitude > 2 then
			AnimeFx.streak(start + Vector3.new(0, 0.5, 0), rootPart.Position, C.Purple, 1.1, 0.35)
		end
	end)
	if Kit.isLocal(character) then
		AnimeFx.speedLines(time + 0.25, Color3.fromRGB(200, 225, 255))
	end
	return nil
end

-- The thrust connects: a white flash in a purple burst, forked bolts in a ring, sparks, a shockwave
-- across the blow, a moment of hit-stop and electricity crawling over the target.
function Chidori.ChidoriHit(payload: VfxUtil.Payload): (() -> ())?
	local caster = Kit.casterOf(payload)
	local target = Kit.modelOf(payload.target)
	local position = payload.position :: Vector3
	local direction = payload.direction :: Vector3
	if caster then
		local hand = hands[caster]
		if hand then
			hand.stop(true)
		end
		Kit.animate(caster, 1, Clips.ChidoriThrust)
		local hitStopped: Model = caster
		task.delay(0.05, function()
			MoveAnimator.hold(hitStopped, 0.07)
			if target then
				MoveAnimator.hold(target, 0.07)
			end
		end)
	end
	Kit.sound("ChidoriImpact", position)

	if not Kit.slot("Sasuke_ChidoriImpact", CFrame.lookAt(position, position + direction)) then
		AnimeFx.flash(position, C.Purple, 10, 0.32)
		AnimeFx.flash(position, C.Electric, 5.5, 0.2)
		AnimeFx.ring(Kit.across(position, direction), {
			from = 1,
			to = 9,
			color = C.Core,
			thickness = 0.8,
			duration = 0.3,
			transparency = 0.1,
		})
		AnimeFx.shockwave(Kit.across(position, direction), C.Purple, 14, 0.35)
		for i = 1, 7 do
			local spray = (direction * 0.8 + VfxUtil.randomDirection()).Unit
			AnimeFx.bolt(position, position + spray * (4 + math.random() * 5), {
				color = if i % 2 == 0 then C.Purple else C.Electric,
				core = C.Core,
				width = 0.18 + math.random() * 0.12,
				segments = 5,
				branches = 1,
				jitter = 0.18,
				duration = 0.18 + math.random() * 0.12,
				flicker = 30,
			})
		end
		VfxUtil.burst(CFrame.lookAt(position, position + direction), {
			texture = T.Spark,
			color = keypoints(C.Core, C.Electric, C.Purple),
			size = NumberSequence.new(0.5, 0),
			lifetime = NumberRange.new(0.15, 0.4),
			speed = NumberRange.new(14, 32),
			drag = 3,
			lightEmission = 1,
			brightness = 2,
		}, 40)
	end

	-- Electricity keeps crawling over them for a moment after the hit.
	if target then
		local body = Kit.bodyParts(target)
		local targetRoot = Rig.part(target, { "HumanoidRootPart" })
		if targetRoot and #body > 0 then
			local anchor: BasePart = targetRoot
			AnimeFx.crackle(function()
				return if anchor.Parent then anchor.CFrame else nil
			end, function()
				local a, b = body[math.random(1, #body)], body[math.random(1, #body)]
				return anchor.CFrame:PointToObjectSpace(Kit.pointOn(a)),
					anchor.CFrame:PointToObjectSpace(Kit.pointOn(b))
			end, {
				duration = 0.6,
				count = 3,
				width = 0.07,
				color = C.Electric,
				altColor = C.Purple,
				core = C.Core,
				flicker = 18,
				chance = 0.65,
			})
			Kit.sound("ChidoriResidual", anchor)
		end
	end

	local near = Kit.isLocal(caster) or Kit.isLocal(target) or Kit.nearCamera(position, 40)
	if near then
		VfxUtil.shake(0.45, 0.25)
	end
	return nil
end

return Chidori
