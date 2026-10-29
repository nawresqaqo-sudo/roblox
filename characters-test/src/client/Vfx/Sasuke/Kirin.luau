--!strict
-- 4: Kirin: Heavenly Lightning Devastation. He thrusts his arm at the sky: lightning crawls over him,
-- sparks and wind spiral up around him and the sky turns stormy and blue-violet. A warning circle marks
-- the ground where it will land (a bright ring closing in on the middle counts down to the strike)
-- while a storm cloud gathers above it, flickering and throwing small strikes. Then Kirin falls: a huge
-- blue-white bolt drawn from the sky to the ground with purple forks and two obsidian coils wrapped
-- around it, a blinding flash, an expanding dome, shockwaves, glowing cracks, a crater, debris, dust
-- and electricity crackling over the ground for a moment after.
local Kit = require(script.Parent.Kit)

local Client = script.Parent.Parent.Parent
local Util = Client:WaitForChild("Util")
local AnimeFx = require(Util:WaitForChild("AnimeFx"))
local Cutscene = require(Util:WaitForChild("Cutscene"))
local VfxUtil = require(Util:WaitForChild("VfxUtil"))
local MoveAnimator = require(Client:WaitForChild("Controllers"):WaitForChild("MoveAnimator"))
local Clips = require(Client:WaitForChild("Animations"):WaitForChild("Sasuke"))

local C = Kit.Colors
local T = Kit.Textures
local STORM_HEIGHT = 80
local CLOUD = Color3.fromRGB(34, 32, 54)

local Kirin: { [string]: VfxUtil.Handler } = {}

type Storm = {
	clear: (fast: boolean) -> (), -- removes the buildup, the warning circle and the storm
}

-- The Kirin being summoned by each caster right now.
local active: { [Model]: Storm } = {}

local function keypoints(...: Color3): ColorSequence
	local colors = { ... }
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(points)
end

-- Phase 1, on Sasuke: lightning crawling over him, sparks rising, three wind ribbons spiralling up,
-- the raised hand glowing and a bolt joining it to the storm. Returns a function that ends it all.
local function chargeUp(character: Model, root: BasePart, storm: Vector3, duration: number): () -> ()
	local stops: { () -> () } = {}
	local stopped = false
	local body = Kit.bodyParts(character)
	if #body > 0 then
		table.insert(
			stops,
			AnimeFx.crackle(function()
				return if root.Parent then root.CFrame else nil
			end, function()
				local a, b = body[math.random(1, #body)], body[math.random(1, #body)]
				return root.CFrame:PointToObjectSpace(Kit.pointOn(a)), root.CFrame:PointToObjectSpace(Kit.pointOn(b))
			end, {
				duration = duration,
				count = 4,
				width = 0.08,
				color = C.Electric,
				altColor = C.Purple,
				core = C.Core,
				flicker = 16,
				chance = 0.6,
			})
		)
	end

	local feet = Kit.holder(CFrame.new(Kit.feet(root) + Vector3.new(0, 0.3, 0)), Vector3.new(9, 0.3, 9))
	VfxUtil.emitter(feet, {
		texture = T.Spark,
		color = keypoints(C.Core, C.Electric, C.Purple),
		size = NumberSequence.new(0.35, 0),
		lifetime = NumberRange.new(0.6, 1),
		speed = NumberRange.new(6, 12),
		spread = Vector2.new(10, 10),
		rate = 40,
		lightEmission = 1,
		brightness = 2,
	})
	table.insert(stops, function()
		Kit.retire(feet, 1)
	end)

	-- Wind ribbons: invisible points circling up around him, each dragging a trail.
	type Ribbon = { part: BasePart, phase: number }
	local ribbons: { Ribbon } = {}
	for i = 1, 3 do
		local part = Kit.holder(root.CFrame)
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25, 0)
		a0.Parent = part
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25, 0)
		a1.Parent = part
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = keypoints(C.Core, C.Electric)
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.Lifetime = 0.4
		trail.LightEmission = 1
		trail.LightInfluence = 0
		trail.FaceCamera = true
		trail.Parent = part
		table.insert(ribbons, { part = part, phase = i / 3 })
	end
	table.insert(
		stops,
		VfxUtil.everyFrame(duration, function(t)
			if not root.Parent then
				return false
			end
			local base = Kit.feet(root)
			local narrow = 1 - 0.35 * math.min(t / duration, 1)
			for _, ribbon in ribbons do
				local cycle = (t * 1.6 + ribbon.phase) % 1
				local angle = (t * 7 + ribbon.phase * math.pi * 2)
				local radius = (4.5 - cycle * 2) * narrow
				ribbon.part.CFrame =
					CFrame.new(base + Vector3.new(math.cos(angle) * radius, cycle * 8, math.sin(angle) * radius))
			end
			return true
		end, function()
			for _, ribbon in ribbons do
				Kit.retire(ribbon.part, 0.5)
			end
		end)
	)

	local handPart, offset = Kit.hand(character, "Right")
	if handPart then
		local hand: BasePart = handPart
		local glow = VfxUtil.part({ size = Vector3.one * 0.8, color = C.Core, shape = Enum.PartType.Ball })
		local light = Instance.new("PointLight")
		light.Color = C.Electric
		light.Brightness = 5
		light.Range = 14
		light.Parent = glow
		local function fist(): Vector3?
			return if hand.Parent then (hand.CFrame * offset).Position else nil
		end
		table.insert(
			stops,
			VfxUtil.everyFrame(duration, function(t)
				local at = fist()
				if not at then
					return false
				end
				glow.CFrame = CFrame.new(at)
				glow.Size = Vector3.one * (0.7 + math.sin(t * 30) * 0.12)
				return true
			end, function()
				VfxUtil.fadeOut({ glow }, 0.2, 0.2)
			end)
		)
		task.delay(0.25, function()
			if hand.Parent and not stopped then
				table.insert(
					stops,
					AnimeFx.bolt(fist, storm, {
						color = C.Electric,
						core = C.Core,
						width = 0.3,
						segments = 12,
						branches = 2,
						jitter = 0.06,
						duration = math.max(duration - 0.25, 0.1),
						flicker = 20,
					})
				)
			end
		end)
	end

	for i = 0, 1 do
		task.delay(i * duration / 2, function()
			if root.Parent then
				AnimeFx.ring(CFrame.new(Kit.feet(root) + Vector3.new(0, 0.15, 0)), {
					from = 1,
					to = 14,
					color = C.Electric,
					thickness = 0.6,
					duration = 0.45,
					transparency = 0.2,
				})
			end
		end)
	end

	return function()
		if stopped then
			return
		end
		stopped = true
		for _, stop in stops do
			stop()
		end
	end
end

-- Phase 2, at the strike point: the warning circle on the ground and the storm gathering over it.
-- Returns a function that clears both (quickly if the summoning was called off).
local function gather(center: Vector3, radius: number, untilStrike: number): (fast: boolean) -> ()
	local stops: { () -> () } = {}
	local ground = center + Vector3.new(0, 0.06, 0)

	-- The warning circle: a dark disc with a purple rim, an inner electric ring, sparks rising off the
	-- rim, and a white ring closing in on the middle that reaches it as Kirin lands.
	local fill = VfxUtil.part({
		size = Vector3.new(0.06, radius * 2, radius * 2),
		color = C.Obsidian,
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.SmoothPlastic,
		transparency = 1,
		cframe = CFrame.new(ground) * CFrame.Angles(0, 0, math.pi / 2),
	})
	VfxUtil.tween(fill, 0.2, { Transparency = 0.35 })
	local rings = {
		AnimeFx.ring(CFrame.new(ground + Vector3.new(0, 0.06, 0)), {
			from = radius,
			to = radius,
			color = C.Purple,
			thickness = 0.55,
			duration = untilStrike + 0.2,
			transparency = 0.05,
			hold = true,
		}),
		AnimeFx.ring(CFrame.new(ground + Vector3.new(0, 0.07, 0)), {
			from = radius * 0.62,
			to = radius * 0.62,
			color = C.Electric,
			thickness = 0.25,
			duration = untilStrike + 0.2,
			transparency = 0.35,
			hold = true,
		}),
		AnimeFx.ring(CFrame.new(ground + Vector3.new(0, 0.08, 0)), {
			from = radius,
			to = 0.3,
			color = C.Core,
			thickness = 0.7,
			duration = untilStrike,
			transparency = 0.1,
			style = Enum.EasingStyle.Linear,
			hold = true,
		}),
	}
	for _, stop in rings do
		table.insert(stops, stop)
	end
	local rim = Kit.holder(CFrame.new(ground + Vector3.new(0, 0.3, 0)))
	for i = 1, 10 do
		local angle = (i / 10) * math.pi * 2
		local spot = Instance.new("Attachment")
		spot.Position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		spot.Parent = rim
		VfxUtil.emitter(spot, {
			texture = T.Spark,
			color = keypoints(C.Electric, C.Purple),
			size = NumberSequence.new(0.4, 0),
			lifetime = NumberRange.new(0.5, 0.9),
			speed = NumberRange.new(4, 9),
			spread = Vector2.new(15, 15),
			rate = 5,
			lightEmission = 1,
		})
	end
	local glow = Instance.new("PointLight")
	glow.Color = C.Violet
	glow.Brightness = 0
	glow.Range = radius * 1.6
	glow.Parent = rim
	VfxUtil.tween(glow, untilStrike, { Brightness = 4, Color = C.Electric })
	local pulsing = true
	task.spawn(function()
		while pulsing and fill.Parent do
			AnimeFx.ring(CFrame.new(ground + Vector3.new(0, 0.09, 0)), {
				from = radius,
				to = radius * 0.55,
				color = C.Purple,
				thickness = 0.4,
				duration = 0.3,
				transparency = 0.3,
			})
			task.wait(0.3)
		end
	end)

	-- The storm: a dark cloud with lightning flickering inside it, a light that flashes, a core of
	-- energy swelling under it and small strikes hitting the ground around the circle.
	local sky = center + Vector3.new(0, STORM_HEIGHT, 0)
	local cloud = Kit.holder(CFrame.new(sky), Vector3.new(radius * 3, 6, radius * 3))
	VfxUtil.emitter(cloud, {
		texture = T.Smoke,
		color = ColorSequence.new(CLOUD, Color3.fromRGB(18, 16, 30)),
		size = NumberSequence.new(22, 32),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(1.6, 2.2),
		speed = NumberRange.new(0.5, 2),
		rate = 28,
		rotSpeed = NumberRange.new(-15, 15),
	}):Emit(14)
	local flicker = Instance.new("PointLight")
	flicker.Color = C.Electric
	flicker.Range = 80
	flicker.Brightness = 0
	flicker.Parent = cloud
	local half = Vector3.new(radius * 1.4, 2, radius * 1.4)
	local function inCloud(): Vector3
		return Vector3.new(
			(math.random() * 2 - 1) * half.X,
			(math.random() * 2 - 1) * half.Y,
			(math.random() * 2 - 1) * half.Z
		)
	end
	table.insert(
		stops,
		AnimeFx.crackle(function()
			return CFrame.new(sky)
		end, function()
			local a = inCloud()
			return a, a + VfxUtil.randomDirection() * (6 + math.random() * 10)
		end, {
			duration = untilStrike + 0.2,
			count = 4,
			width = 0.5,
			color = C.Electric,
			altColor = C.Purple,
			core = C.Core,
			flicker = 10,
			chance = 0.5,
		})
	)
	local core = VfxUtil.part({
		size = Vector3.one * 0.5,
		color = C.Core,
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(sky - Vector3.new(0, 5, 0)),
	})
	local shell = VfxUtil.part({
		size = Vector3.one * 0.9,
		color = C.Purple,
		shape = Enum.PartType.Ball,
		material = Enum.Material.ForceField,
		cframe = CFrame.new(sky - Vector3.new(0, 5, 0)),
	})
	VfxUtil.tween(core, untilStrike, { Size = Vector3.one * 7 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	VfxUtil.tween(shell, untilStrike, { Size = Vector3.one * 13 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	table.insert(
		stops,
		VfxUtil.everyFrame(untilStrike + 0.2, function(t)
			flicker.Brightness = if math.random() < 0.3 then 4 + math.random() * 8 else flicker.Brightness * 0.8
			-- Small strikes around the circle, more of them as it builds.
			if math.random() < 0.02 + 0.06 * math.min(t / untilStrike, 1) then
				local angle = math.random() * math.pi * 2
				local distance = radius * (1.2 + math.random() * 1.2)
				local hit = center + Vector3.new(math.cos(angle) * distance, 0.2, math.sin(angle) * distance)
				AnimeFx.bolt(sky + inCloud(), hit, {
					color = if math.random() < 0.5 then C.Electric else C.Purple,
					core = C.Core,
					width = 0.35,
					segments = 9,
					branches = 2,
					jitter = 0.08,
					duration = 0.15,
					flicker = 25,
				})
				AnimeFx.flash(hit, C.Electric, 3, 0.15)
			end
			return true
		end)
	)
	Kit.slotOn("Sasuke_KirinStorm", cloud, untilStrike)

	local cleared = false
	return function(fast: boolean)
		if cleared then
			return
		end
		cleared = true
		pulsing = false
		for _, stop in stops do
			stop()
		end
		VfxUtil.fadeOut({ fill }, if fast then 0.25 else 0.1)
		Kit.retire(rim, 1)
		Kit.retire(cloud, 2.4)
		if fast then
			VfxUtil.fadeOut({ core, shell }, 0.3, 0.3)
		else
			core:Destroy()
			shell:Destroy()
		end
	end
end

-- Caster's camera: low on him as he raises his arm, over his shoulder at the storm gathering, then
-- wide on the circle as Kirin comes down (shaking when it lands).
local function playCutscene(root: BasePart, center: Vector3, buildup: number, anticipation: number, strikeAt: number)
	local toCenter = Vector3.new(center.X - root.Position.X, 0, center.Z - root.Position.Z)
	local forward = if toCenter.Magnitude > 1 then toCenter.Unit else root.CFrame.LookVector
	local side = forward:Cross(Vector3.yAxis).Unit
	local wideAt = center - forward * 6 + side * 46 + Vector3.new(0, 26, 0)
	local wideLook = center + Vector3.new(0, 22, 0)
	local function wide(): CFrame
		local cframe = CFrame.lookAt(wideAt, wideLook)
		local since = os.clock() - strikeAt
		if since > 0 and since < 0.5 then
			local strength = 1.4 * (1 - since / 0.5)
			cframe *= CFrame.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
		end
		return cframe
	end
	Cutscene.play({
		{
			duration = buildup * 0.55,
			from = Kit.shot(root, Vector3.new(2.2, -1.5, -6), Vector3.new(0, 3.5, 0)),
			to = Kit.shot(root, Vector3.new(1.6, -1.6, -4.6), Vector3.new(0, 4.5, 0)),
			fov = 55,
		},
		{
			duration = buildup * 0.45 + anticipation * 0.55,
			from = Kit.shot(root, Vector3.new(3, 3, 7), Vector3.new(0, 14, -20)),
			to = Kit.shot(root, Vector3.new(2.5, 4, 9), Vector3.new(0, 10, -24)),
			fov = 70,
		},
		{ duration = anticipation * 0.45 + 0.55, from = wide, to = wide, fov = 78 },
	}, "KIRIN")
end

function Kirin.Kirin(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = Kit.casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local center = payload.position :: Vector3
	local radius = payload.radius :: number
	local buildup = payload.buildup :: number
	local telegraphAt = payload.telegraphAt :: number
	local anticipation = payload.anticipation :: number
	local skyTime = payload.skyTime :: number
	local untilStrike = buildup + anticipation
	local strikeAt = os.clock() + untilStrike
	local sky = center + Vector3.new(0, STORM_HEIGHT - 5, 0)
	Kit.animate(character, 4, Clips.Kirin)

	local previous = active[character]
	if previous then
		previous.clear(true)
	end

	-- The air charges: stormy blue-violet sky, a faint flash, a deep rumble and rising electricity.
	if Kit.nearCamera(rootPart.Position, Kit.SKY_RANGE) or Kit.nearCamera(center, Kit.SKY_RANGE) then
		AnimeFx.darkSky(skyTime, Color3.fromRGB(205, 212, 255), Color3.fromRGB(48, 40, 120), Color3.fromRGB(24, 20, 60))
		AnimeFx.screenFlash(C.Electric, 0.25, 0.8)
	end
	local rumbleAt = Kit.holder(CFrame.new(center + Vector3.new(0, 6, 0)))
	local stopRumble = Kit.loop("KirinRumble", rumbleAt)
	local tension = Kit.sound("KirinTension", rootPart)
	VfxUtil.tween(
		tension,
		untilStrike,
		{ PlaybackSpeed = tension.PlaybackSpeed * 2 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	local stopCharge = chargeUp(character, rootPart, sky, untilStrike)

	local clearGather: ((fast: boolean) -> ())? = nil
	local cancelled = false
	task.delay(telegraphAt, function()
		if not cancelled then
			clearGather = gather(center, radius, untilStrike - telegraphAt)
		end
	end)
	task.delay(untilStrike - 0.25, function()
		if not cancelled then
			Kit.sound("KirinCue", center + Vector3.new(0, 5, 0))
		end
	end)
	task.delay(untilStrike - 0.06, function()
		if not cancelled then
			AnimeFx.flash(sky, C.Core, 14, 0.15)
		end
	end)
	if Kit.isLocal(character) then
		playCutscene(rootPart, center, buildup, anticipation, strikeAt)
	end

	local storm: Storm
	storm = {
		clear = function(fast: boolean)
			if active[character] == storm then
				active[character] = nil
			end
			cancelled = true
			stopCharge()
			stopRumble()
			Kit.retire(rumbleAt, 0.5)
			if clearGather then
				clearGather(fast)
			end
		end,
	}
	active[character] = storm
	-- Safety net: never leave the circle and storm behind if the strike never arrives.
	task.delay(untilStrike + 1.5, function()
		if active[character] == storm then
			storm.clear(true)
		end
	end)

	-- Called off (he was hit, or died): everything fades and the camera comes back.
	return function()
		storm.clear(true)
		if Kit.isLocal(character) then
			Cutscene.stop()
		end
		if MoveAnimator.isPlaying(character, Clips.Kirin) then
			MoveAnimator.stop(character, 0.25)
		end
	end
end

-- Glowing cracks spreading out from the impact; the light in them dies down, then they fade.
local function cracks(center: Vector3, radius: number)
	local lasting: { BasePart } = {}
	for i = 1, 9 do
		local heading = (i / 9) * math.pi * 2 + (math.random() - 0.5) * 0.4
		local steps = 5
		local step = radius * (0.7 + math.random() * 0.6) / steps
		local point = center + Vector3.new(0, 0.05, 0)
		for _ = 1, steps do
			heading += (math.random() - 0.5) * 0.7
			local nextPoint = point + Vector3.new(math.cos(heading) * step, 0, math.sin(heading) * step)
			local cframe = CFrame.lookAt((point + nextPoint) / 2, nextPoint)
			table.insert(
				lasting,
				VfxUtil.part({
					size = Vector3.new(0.55, 0.1, step + 0.3),
					color = Color3.fromRGB(20, 18, 26),
					material = Enum.Material.Slate,
					cframe = cframe,
				})
			)
			local light = VfxUtil.part({
				size = Vector3.new(0.18, 0.12, step + 0.2),
				color = C.Electric,
				cframe = cframe * CFrame.new(0, 0.02, 0),
			})
			VfxUtil.tween(light, 1.4, { Color = C.Violet, Transparency = 1 })
			task.delay(1.5, function()
				light:Destroy()
			end)
			point = nextPoint
		end
	end
	task.delay(3.5, function()
		VfxUtil.fadeOut(lasting, 1)
	end)
end

-- Kirin lands: the bolt is drawn from the sky to the ground, then the impact.
function Kirin.KirinStrike(payload: VfxUtil.Payload): (() -> ())?
	local caster = Kit.casterOf(payload)
	local center = payload.position :: Vector3
	local radius = payload.radius :: number
	if caster then
		local storm = active[caster]
		if storm then
			storm.clear(false)
		end
	end
	local sky = center + Vector3.new(0, STORM_HEIGHT + 10, 0)
	local ground = center + Vector3.new(0, 0.2, 0)
	Kit.sound("KirinThunder", center + Vector3.new(0, 4, 0))
	Kit.sound("KirinShockwave", center + Vector3.new(0, 2, 0))

	-- The descent: one huge bolt with a clear top-to-bottom direction, a thinner purple one beside it,
	-- and two obsidian coils spiralling down around them like the dragon's body.
	AnimeFx.bolt(sky, ground, {
		color = C.Electric,
		core = C.Core,
		width = 2.2,
		segments = 10,
		branches = 6,
		jitter = 0.07,
		duration = 0.6,
		flicker = 22,
		draw = 0.08,
	})
	AnimeFx.bolt(sky + Vector3.new(3, 0, -2), ground, {
		color = C.Purple,
		core = C.Core,
		width = 1.1,
		segments = 9,
		branches = 3,
		jitter = 0.1,
		duration = 0.45,
		flicker = 25,
		draw = 0.1,
	})
	for coil = 0, 1 do
		local points: { Vector3 } = {}
		for i = 0, 24 do
			local f = i / 24
			local angle = f * math.pi * 4 + coil * math.pi
			local reach = 5 * (1 - f * 0.6)
			table.insert(points, sky:Lerp(ground, f) + Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach))
		end
		AnimeFx.path(points, { dark = true, color = C.Violet, width = 1, duration = 0.5, draw = 0.12 })
	end

	task.delay(0.08, function()
		if Kit.nearCamera(center, Kit.NEAR) then
			AnimeFx.screenFlash(C.Core, 0.18, 0.35)
			AnimeFx.impactFrame(1.1)
			VfxUtil.shake(1.3, 0.55)
		end
		if Kit.slot("Sasuke_KirinImpact", CFrame.new(center)) then
			return
		end
		AnimeFx.flash(ground + Vector3.new(0, 3, 0), C.Purple, 44, 0.6)
		AnimeFx.flash(ground + Vector3.new(0, 3, 0), C.Electric, 30, 0.45)
		AnimeFx.flash(ground + Vector3.new(0, 3, 0), C.Core, 16, 0.25)
		local dome = VfxUtil.part({
			size = Vector3.one * 6,
			color = C.Purple,
			shape = Enum.PartType.Ball,
			material = Enum.Material.ForceField,
			cframe = CFrame.new(ground),
		})
		VfxUtil.tween(dome, 0.7, { Size = Vector3.one * radius * 2.6, Transparency = 1 })
		task.delay(0.75, function()
			dome:Destroy()
		end)
		AnimeFx.ring(
			CFrame.new(ground),
			{ from = 0.5, to = radius * 2.2, color = C.Core, thickness = 2, duration = 0.45 }
		)
		AnimeFx.ring(CFrame.new(ground + Vector3.new(0, 0.05, 0)), {
			from = 0.5,
			to = radius * 3,
			color = C.Purple,
			thickness = 3.5,
			duration = 0.75,
			transparency = 0.1,
		})
		AnimeFx.ring(CFrame.new(ground + Vector3.new(0, 0.1, 0)), {
			from = 0.5,
			to = radius * 1.8,
			color = C.Obsidian,
			thickness = 1.2,
			duration = 0.6,
		})
		AnimeFx.shockwave(CFrame.new(ground), C.Electric, radius * 3.2, 0.6)
		VfxUtil.burst(CFrame.new(ground + Vector3.new(0, 3, 0)), {
			texture = T.BlastCore,
			color = keypoints(C.Core, C.Electric),
			size = NumberSequence.new(26, 40),
			transparency = NumberSequence.new(0.1, 1),
			lifetime = NumberRange.new(0.25, 0.3),
			lightEmission = 1,
		}, 2)
		VfxUtil.burst(CFrame.new(ground + Vector3.new(0, 1, 0)), {
			texture = T.Spark,
			color = keypoints(C.Core, C.Electric, C.Purple),
			size = NumberSequence.new(0.7, 0),
			lifetime = NumberRange.new(0.3, 0.7),
			speed = NumberRange.new(30, 70),
			drag = 2,
			lightEmission = 1,
			brightness = 2,
		}, 70)
		VfxUtil.burst(CFrame.new(ground + Vector3.new(0, 1, 0)), {
			texture = T.Smoke,
			color = ColorSequence.new(Color3.fromRGB(120, 118, 140)),
			size = NumberSequence.new(5, 12),
			transparency = NumberSequence.new(0.45, 1),
			lifetime = NumberRange.new(1, 1.8),
			speed = NumberRange.new(25, 40),
			spread = Vector2.new(85, 85),
			drag = 3,
			rotSpeed = NumberRange.new(-30, 30),
		}, 24, Vector3.new(radius, 1, radius))
		AnimeFx.debris(ground + Vector3.new(0, 1, 0), 22, C.Stone, 60)
		for i = 1, 8 do
			local angle = (i / 8) * math.pi * 2 + math.random() * 0.4
			local reach = radius * (0.8 + math.random() * 0.4)
			AnimeFx.bolt(
				ground + Vector3.new(0, 0.5, 0),
				ground + Vector3.new(math.cos(angle) * reach, 0.3, math.sin(angle) * reach),
				{
					color = if i % 2 == 0 then C.Purple else C.Electric,
					core = C.Core,
					width = 0.4,
					segments = 7,
					branches = 2,
					jitter = 0.1,
					duration = 0.3,
					flicker = 25,
				}
			)
		end
		cracks(center, radius)
		local crater = VfxUtil.part({
			size = Vector3.new(0.08, radius * 1.1, radius * 1.1),
			color = Color3.fromRGB(30, 28, 34),
			shape = Enum.PartType.Cylinder,
			material = Enum.Material.Slate,
			cframe = CFrame.new(center + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		})
		task.delay(4, function()
			VfxUtil.fadeOut({ crater }, 1)
		end)

		-- The aftermath: a fading glow over the circle and electricity crackling across the ground.
		local field = VfxUtil.part({
			size = Vector3.new(0.05, radius * 2, radius * 2),
			color = C.Violet,
			shape = Enum.PartType.Cylinder,
			transparency = 0.55,
			cframe = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		})
		VfxUtil.fadeOut({ field }, 1.2)
		local afterglow = Kit.holder(CFrame.new(center + Vector3.new(0, 4, 0)))
		local light = Instance.new("PointLight")
		light.Color = C.Electric
		light.Brightness = 10
		light.Range = math.min(radius * 2, 60)
		light.Parent = afterglow
		VfxUtil.tween(light, 1.2, { Brightness = 0 })
		task.delay(1.3, function()
			afterglow:Destroy()
		end)
		AnimeFx.crackle(function()
			return CFrame.new(center)
		end, function()
			local angle = math.random() * math.pi * 2
			local distance = math.random() * radius
			local a = Vector3.new(math.cos(angle) * distance, 0.3 + math.random(), math.sin(angle) * distance)
			return a, a + Vector3.new((math.random() - 0.5) * 8, 0, (math.random() - 0.5) * 8)
		end, {
			duration = 1.6,
			count = 4,
			width = 0.18,
			color = C.Electric,
			altColor = C.Purple,
			core = C.Core,
			flicker = 12,
			chance = 0.6,
		})
		Kit.sound("KirinResidual", center + Vector3.new(0, 1, 0))
	end)
	return nil
end

return Kirin
