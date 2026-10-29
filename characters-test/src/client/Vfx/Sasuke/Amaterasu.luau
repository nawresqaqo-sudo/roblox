--!strict
-- 3: Amaterasu: Black Flame Curse. His Mangekyo opens: the eyes turn red with a glint and a thin line of
-- blood, a dark pulse runs through the air and the eye pattern spins across his own screen. A
-- black-purple ripple marks the spot he stares at, then black flames erupt there: nearly black at the
-- heart with purple and crimson edges, purple embers and dark smoke. Whoever caught fire burns until
-- the server says it's over, guttering as the end nears and collapsing inward when it comes. The ground
-- keeps burning for a few seconds.
local Players = game:GetService("Players")

local Kit = require(script.Parent.Kit)

local Client = script.Parent.Parent.Parent
local Util = Client:WaitForChild("Util")
local AnimeFx = require(Util:WaitForChild("AnimeFx"))
local Rig = require(Util:WaitForChild("Rig"))
local VfxUtil = require(Util:WaitForChild("VfxUtil"))
local Clips = require(Client:WaitForChild("Animations"):WaitForChild("Sasuke"))

local C = Kit.Colors
local T = Kit.Textures
local BURN_ATTRIBUTE = "AmaterasuUntil" -- set by the server: when a character stops burning (server time)
local ENDING = 0.8 -- flames start guttering this long before they go out
local BLOOD = Color3.fromRGB(150, 0, 20)

local Amaterasu: { [string]: VfxUtil.Handler } = {}

type Flames = {
	emitters: { ParticleEmitter },
	rates: { number },
}

-- Black flames on `parent`: near-black tongues in front with a purple-and-crimson edge glowing behind
-- them, plus (if `extras`) purple embers and dark smoke. `scale` sizes them, `rate` is the main density.
local function blackFlames(parent: Instance, scale: number, rate: number, extras: boolean): Flames
	local flames: Flames = { emitters = {}, rates = {} }
	local function add(emitter: ParticleEmitter)
		table.insert(flames.emitters, emitter)
		table.insert(flames.rates, emitter.Rate)
	end
	add(VfxUtil.emitter(parent, {
		texture = T.Fire,
		color = ColorSequence.new(C.BlackFlame, Color3.fromRGB(34, 8, 26)),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.0 * scale),
			NumberSequenceKeypoint.new(0.4, 1.2 * scale),
			NumberSequenceKeypoint.new(1, 0.3 * scale),
		}),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(0.7, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.45, 0.8),
		speed = NumberRange.new(2.5 * scale, 5.5 * scale),
		spread = Vector2.new(18, 18),
		acceleration = Vector3.new(0, 5 * scale, 0),
		rate = rate,
		rotation = NumberRange.new(-25, 25),
		rotSpeed = NumberRange.new(-70, 70),
		zOffset = 0.4,
	}))
	add(VfxUtil.emitter(parent, {
		texture = T.Fire,
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, C.Purple),
			ColorSequenceKeypoint.new(0.5, C.Crimson),
			ColorSequenceKeypoint.new(1, C.Violet),
		}),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.25 * scale),
			NumberSequenceKeypoint.new(0.4, 1.45 * scale),
			NumberSequenceKeypoint.new(1, 0.4 * scale),
		}),
		transparency = NumberSequence.new(0.45, 1),
		lifetime = NumberRange.new(0.4, 0.7),
		speed = NumberRange.new(2.5 * scale, 5.5 * scale),
		spread = Vector2.new(22, 22),
		acceleration = Vector3.new(0, 5 * scale, 0),
		rate = rate * 0.75,
		rotation = NumberRange.new(-25, 25),
		rotSpeed = NumberRange.new(-70, 70),
		lightEmission = 0.6,
		zOffset = 0.1,
	}))
	if extras then
		add(VfxUtil.emitter(parent, {
			texture = T.Embers,
			color = ColorSequence.new(C.Purple, C.Crimson),
			size = NumberSequence.new(0.3 * scale, 0),
			lifetime = NumberRange.new(0.6, 1.1),
			speed = NumberRange.new(2, 6),
			acceleration = Vector3.new(0, 6, 0),
			rate = rate * 0.35,
			lightEmission = 1,
		}))
		add(VfxUtil.emitter(parent, {
			texture = T.Smoke,
			color = ColorSequence.new(Color3.fromRGB(26, 16, 34)),
			size = NumberSequence.new(1.6 * scale, 3.4 * scale),
			transparency = NumberSequence.new(0.5, 1),
			lifetime = NumberRange.new(0.9, 1.5),
			speed = NumberRange.new(1, 3),
			acceleration = Vector3.new(0, 3, 0),
			rate = rate * 0.15,
			rotSpeed = NumberRange.new(-30, 30),
			zOffset = -0.4,
		}))
	end
	return flames
end

-- Near the end the flames gutter: their density flickers and drops.
local function gutter(flames: Flames, t: number, left: number)
	local strength = if left < ENDING then (left / ENDING) * (0.35 + 0.65 * math.abs(math.sin(t * 22))) else 1
	for i, emitter in flames.emitters do
		emitter.Rate = flames.rates[i] * strength
	end
end

-- The end of the black flames: a dark orb that collapses to a point, a pinprick of purple light and a
-- puff of embers.
local function collapse(position: Vector3, size: number)
	Kit.sound("AmaterasuEnd", position)
	local orb = VfxUtil.part({
		size = Vector3.one * size,
		color = C.Obsidian,
		shape = Enum.PartType.Ball,
		material = Enum.Material.Glass,
		transparency = 0.25,
		cframe = CFrame.new(position),
	})
	VfxUtil.tween(orb, 0.25, { Size = Vector3.one * 0.2 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	VfxUtil.burst(CFrame.new(position), {
		texture = T.Implosion,
		color = ColorSequence.new(C.Violet, C.Purple),
		size = NumberSequence.new(size * 1.2, 0),
		transparency = NumberSequence.new(0.2, 1),
		lifetime = NumberRange.new(0.25, 0.25),
		lightEmission = 0.4,
	}, 1)
	task.delay(0.24, function()
		orb:Destroy()
		AnimeFx.flash(position, C.Purple, 2.5, 0.18)
		VfxUtil.burst(CFrame.new(position), {
			texture = T.Embers,
			color = ColorSequence.new(C.Purple, C.Crimson),
			size = NumberSequence.new(0.3, 0),
			lifetime = NumberRange.new(0.3, 0.6),
			speed = NumberRange.new(6, 14),
			drag = 3,
			lightEmission = 1,
		}, 14)
	end)
end

-- The Mangekyo flashing across this player's screen as it opens: a red eye with a black ring and three
-- tomoe, spinning in and fading out.
local function mangekyoFlash()
	local gui = Instance.new("ScreenGui")
	gui.Name = "Mangekyo"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 61
	local group = Instance.new("CanvasGroup")
	group.AnchorPoint = Vector2.new(0.5, 0.5)
	group.Position = UDim2.fromScale(0.5, 0.5)
	group.Size = UDim2.fromScale(0.5, 0.5)
	group.SizeConstraint = Enum.SizeConstraint.RelativeYY
	group.BackgroundTransparency = 1
	group.GroupTransparency = 0.3
	group.Parent = gui
	local function circle(size: number, color: Color3, position: UDim2?): Frame
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Position = position or UDim2.fromScale(0.5, 0.5)
		frame.Size = UDim2.fromScale(size, size)
		frame.BackgroundColor3 = color
		frame.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = frame
		frame.Parent = group
		return frame
	end
	local black = Color3.new(0, 0, 0)
	local iris = circle(1, C.Crimson)
	local edge = Instance.new("UIStroke")
	edge.Color = black
	edge.Thickness = 4
	edge.Parent = iris
	local ring = circle(0.62, C.Crimson)
	ring.BackgroundTransparency = 1
	local ringLine = Instance.new("UIStroke")
	ringLine.Color = black
	ringLine.Thickness = 3
	ringLine.Parent = ring
	circle(0.18, black)
	for i = 0, 2 do
		local angle = i * math.pi * 2 / 3
		circle(0.13, black, UDim2.fromScale(0.5 + math.cos(angle) * 0.31, 0.5 + math.sin(angle) * 0.31))
		-- The tomoe's tail trailing behind it around the ring.
		circle(0.07, black, UDim2.fromScale(0.5 + math.cos(angle - 0.32) * 0.33, 0.5 + math.sin(angle - 0.32) * 0.33))
	end
	local scale = Instance.new("UIScale")
	scale.Scale = 1.6
	scale.Parent = group
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	VfxUtil.tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	VfxUtil.tween(group, 0.5, { Rotation = 240 }, Enum.EasingStyle.Quart)
	task.delay(0.22, function()
		VfxUtil.tween(group, 0.3, { GroupTransparency = 1 })
	end)
	task.delay(0.6, function()
		gui:Destroy()
	end)
end

-- His eyes turn red: two small glowing points with a cross-shaped glint, and a thin line of blood
-- running down from the left eye.
local function sharinganEyes(character: Model, duration: number)
	local found = Rig.part(character, { "Head" })
	if not found then
		return
	end
	local head: BasePart = found
	local s = head.Size
	type Eye = { part: BasePart, offset: CFrame }
	local eyes: { Eye } = {}
	for _, side in { -1, 1 } do
		table.insert(eyes, {
			part = VfxUtil.part({ size = Vector3.one * 0.13, color = C.Crimson, shape = Enum.PartType.Ball }),
			offset = CFrame.new(side * s.X * 0.17, s.Y * 0.08, -s.Z * 0.5 - 0.03),
		})
	end
	local light = Instance.new("PointLight")
	light.Color = C.Crimson
	light.Brightness = 3
	light.Range = 5
	light.Parent = eyes[1].part
	local tear =
		VfxUtil.part({ size = Vector3.new(0.04, 0.02, 0.02), color = BLOOD, material = Enum.Material.SmoothPlastic })

	-- The glint: a billboard cross that always faces the camera.
	local glint = Instance.new("BillboardGui")
	glint.Size = UDim2.fromScale(2.2, 2.2)
	glint.LightInfluence = 0
	glint.Adornee = eyes[1].part
	glint.Parent = eyes[1].part
	for _, bar in { Vector2.new(1, 0.05), Vector2.new(0.05, 1) } do
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = UDim2.fromScale(bar.X, bar.Y)
		line.BackgroundColor3 = Color3.fromRGB(255, 225, 230)
		line.BorderSizePixel = 0
		line.Parent = glint
		VfxUtil.tween(line, 0.3, { Size = UDim2.fromScale(bar.X * 0.2, bar.Y * 0.2), BackgroundTransparency = 1 })
	end

	VfxUtil.everyFrame(duration, function(t)
		if not head.Parent then
			return false
		end
		for _, eye in eyes do
			eye.part.CFrame = head.CFrame * eye.offset
		end
		local length = 0.02 + 0.28 * math.min(t / 1.2, 1)
		tear.Size = Vector3.new(0.04, length, 0.02)
		tear.CFrame = head.CFrame * CFrame.new(-s.X * 0.17, s.Y * 0.08 - 0.08 - length / 2, -s.Z * 0.5 - 0.03)
		return true
	end, function()
		local parts: { BasePart } = { tear }
		for _, eye in eyes do
			table.insert(parts, eye.part)
		end
		VfxUtil.fadeOut(parts, 0.4)
	end)
end

function Amaterasu.Amaterasu(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = Kit.casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local cast = payload.cast :: number
	local mark = payload.mark :: number
	Kit.animate(character, 3, Clips.Amaterasu)
	Kit.sound("AmaterasuTone", rootPart)

	-- The Mangekyo opens just as his head comes up.
	task.delay(math.max(cast - 0.05, 0), function()
		if not rootPart.Parent then
			return
		end
		local head = Rig.part(character, { "Head" }) or rootPart
		Kit.sound("AmaterasuActivate", head)
		sharinganEyes(character, mark + 1.8)
		local pulse = VfxUtil.part({
			size = Vector3.one * 1.5,
			color = C.Obsidian,
			shape = Enum.PartType.Ball,
			material = Enum.Material.Glass,
			transparency = 0.35,
			cframe = head.CFrame,
		})
		VfxUtil.tween(pulse, 0.45, { Size = Vector3.one * 16, Transparency = 1 })
		task.delay(0.5, function()
			pulse:Destroy()
		end)
		AnimeFx.ring(CFrame.new(Kit.feet(rootPart) + Vector3.new(0, 0.12, 0)), {
			from = 1,
			to = 12,
			color = C.Crimson,
			thickness = 0.5,
			duration = 0.4,
			transparency = 0.2,
		})
		if Kit.isLocal(character) then
			mangekyoFlash()
		end
		if Kit.isLocal(character) or Kit.nearCamera(rootPart.Position, 60) then
			Kit.darkPulse(0.35)
		end
	end)
	return nil
end

-- The spot he stares at: a dark line from his eye, then a black-purple ripple pulling in on itself.
function Amaterasu.AmaterasuMark(payload: VfxUtil.Payload): (() -> ())?
	local caster = Kit.casterOf(payload)
	local target = Kit.modelOf(payload.target)
	local spot = payload.position :: Vector3
	local time = payload.time :: number
	local center = spot + Vector3.new(0, 2.6, 0)

	local head = if caster then Rig.part(caster, { "Head" }) else nil
	if head then
		AnimeFx.bolt(Kit.stuck(head, head.Position), if target then target:GetPivot().Position else center, {
			dark = true,
			color = C.Crimson,
			width = 0.12,
			segments = 6,
			jitter = 0.03,
			duration = 0.22,
			flicker = 0,
		})
	end
	if target then
		AnimeFx.outline(target, C.Crimson, time + 0.3)
	end
	if Kit.slot("Sasuke_AmaterasuMark", CFrame.new(spot)) then
		return nil
	end

	local orb = VfxUtil.part({
		size = Vector3.one * 5,
		color = C.Obsidian,
		shape = Enum.PartType.Ball,
		material = Enum.Material.Glass,
		transparency = 0.6,
		cframe = CFrame.new(center),
	})
	VfxUtil.tween(
		orb,
		time,
		{ Size = Vector3.one * 0.6, Transparency = 0.1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)
	task.delay(time + 0.05, function()
		orb:Destroy()
	end)
	local swirl = Kit.holder(CFrame.new(center))
	VfxUtil.emitter(swirl, {
		texture = T.Vortex,
		color = ColorSequence.new(C.Violet, C.Obsidian),
		size = NumberSequence.new(7, 1),
		transparency = NumberSequence.new(0.3, 1),
		lifetime = NumberRange.new(time, time),
		rate = 10,
		rotSpeed = NumberRange.new(240, 360),
		lightEmission = 0.3,
	}):Emit(2)
	task.delay(time, function()
		Kit.retire(swirl, 0.6)
	end)
	for i = 0, 2 do
		task.delay(i * time / 4, function()
			AnimeFx.ring(CFrame.new(spot + Vector3.new(0, 0.12, 0)), {
				from = 7,
				to = 0.4,
				color = if i % 2 == 0 then C.Crimson else C.Violet,
				thickness = 0.35,
				duration = time * 0.8,
				transparency = 0.2,
				style = Enum.EasingStyle.Sine,
			})
		end)
	end
	return nil
end

-- The ground keeps burning: flame clusters scattered over a scorched circle with a crimson rim.
local function burnPatch(center: Vector3, radius: number, duration: number)
	local ground = center + Vector3.new(0, 0.1, 0)
	local base = Kit.holder(CFrame.new(ground + Vector3.new(0, 0.3, 0)), Vector3.new(radius * 1.3, 0.4, radius * 1.3))
	local scorch = VfxUtil.part({
		size = Vector3.new(0.06, radius * 2, radius * 2),
		color = C.Obsidian,
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.SmoothPlastic,
		transparency = 0.2,
		cframe = CFrame.new(center + Vector3.new(0, 0.04, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	AnimeFx.ring(CFrame.new(center + Vector3.new(0, 0.09, 0)), {
		from = radius,
		to = radius,
		color = C.Crimson,
		thickness = 0.35,
		duration = duration + 0.3,
		transparency = 0.25,
		hold = true,
	})
	local clusters: { Flames } = { blackFlames(base, 1.3, 8, true) }
	for i = 1, 6 do
		local angle = (i / 6) * math.pi * 2 + math.random() * 0.5
		local distance = if i == 1 then 0 else radius * (0.35 + math.random() * 0.45)
		local spot = Instance.new("Attachment")
		spot.Position = Vector3.new(math.cos(angle) * distance, -0.2, math.sin(angle) * distance)
		spot.Parent = base
		table.insert(clusters, blackFlames(spot, 1.1 + math.random() * 0.6, 14, false))
	end
	local light = Instance.new("PointLight")
	light.Color = C.Purple
	light.Brightness = 2
	light.Range = radius * 2
	light.Parent = base
	local stopSound = Kit.loop("AmaterasuBurn", base)

	VfxUtil.everyFrame(duration, function(t)
		for _, flames in clusters do
			gutter(flames, t, duration - t)
		end
		return true
	end, function()
		stopSound()
		Kit.retire(base, 1.6)
		collapse(ground + Vector3.new(0, 1.5, 0), radius * 0.9)
		task.delay(0.6, function()
			VfxUtil.fadeOut({ scorch }, 1.2)
		end)
	end)
end

-- The flames erupt: a dark burst, a crimson ring, a column of black fire and purple embers.
function Amaterasu.AmaterasuBurst(payload: VfxUtil.Payload): (() -> ())?
	local position = payload.position :: Vector3
	local radius = payload.radius :: number
	local patchRadius = payload.patchRadius :: number
	local patchTime = payload.patchTime :: number
	local center = position + Vector3.new(0, 2.5, 0)
	Kit.sound("AmaterasuIgnite", center)
	if Kit.nearCamera(position, 45) then
		VfxUtil.shake(0.45, 0.3)
	end
	if Kit.slot("Sasuke_AmaterasuPatch", CFrame.new(position)) then
		return nil
	end

	local burst = VfxUtil.part({
		size = Vector3.one * 2,
		color = C.Obsidian,
		shape = Enum.PartType.Ball,
		material = Enum.Material.Glass,
		transparency = 0.15,
		cframe = CFrame.new(center),
	})
	VfxUtil.tween(burst, 0.35, { Size = Vector3.one * radius * 2.4, Transparency = 1 })
	task.delay(0.4, function()
		burst:Destroy()
	end)
	AnimeFx.ring(CFrame.new(position + Vector3.new(0, 0.15, 0)), {
		from = 1,
		to = radius * 2.2,
		color = C.Crimson,
		thickness = 1.2,
		duration = 0.4,
		transparency = 0.1,
	})
	AnimeFx.ring(CFrame.new(position + Vector3.new(0, 0.18, 0)), {
		from = 1,
		to = radius * 3,
		color = C.Violet,
		thickness = 0.6,
		duration = 0.6,
		transparency = 0.3,
	})
	local column =
		Kit.holder(CFrame.new(position + Vector3.new(0, 0.5, 0)), Vector3.new(radius * 1.2, 0.5, radius * 1.2))
	local eruption = blackFlames(column, 3, 0, true)
	local counts = { 30, 24, 20, 6 } -- flames, edges, embers, smoke
	for i, emitter in eruption.emitters do
		emitter.Speed = NumberRange.new(12, 24)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter:Emit(counts[i] or 10)
	end
	VfxUtil.burst(CFrame.new(center), {
		texture = T.Embers,
		color = ColorSequence.new(C.Purple, C.Crimson),
		size = NumberSequence.new(0.4, 0),
		lifetime = NumberRange.new(0.5, 1),
		speed = NumberRange.new(10, 24),
		drag = 2,
		acceleration = Vector3.new(0, 4, 0),
		lightEmission = 1,
	}, 40)
	task.delay(1.2, function()
		column:Destroy()
	end)
	burnPatch(position, patchRadius, patchTime)
	return nil
end

-- Flames on a burning character, for as long as the server keeps them burning.
function Amaterasu.Burn(payload: VfxUtil.Payload): (() -> ())?
	local target = Kit.modelOf(payload.target)
	if not target then
		return nil
	end
	local character: Model = target
	local torso = Rig.part(character, { "UpperTorso", "Torso", "HumanoidRootPart" })
	if not torso then
		return nil
	end
	local body: BasePart = torso
	local tuning = Kit.Data.Tuning.Amaterasu
	local upper = Instance.new("Attachment")
	upper.Parent = body
	local clusters: { Flames } = { blackFlames(upper, 1.2, 26, true) }
	local hips = Rig.part(character, { "LowerTorso" })
	local lower: Attachment? = nil
	if hips then
		local attachment = Instance.new("Attachment")
		attachment.Parent = hips
		lower = attachment
		table.insert(clusters, blackFlames(attachment, 0.9, 16, false))
	end
	local stopSound = Kit.loop("AmaterasuBurn", body)
	local stopOutline = AnimeFx.outline(character, C.Crimson, tuning.MaxBurnTime + 1, C.Obsidian)
	if Kit.slotOn("Sasuke_AmaterasuFlames", body, tuning.MaxBurnTime + 1) then
		for _, flames in clusters do
			for _, emitter in flames.emitters do
				emitter.Enabled = false
			end
		end
	end

	VfxUtil.everyFrame(tuning.MaxBurnTime + 1, function(t)
		local untilTime = character:GetAttribute(BURN_ATTRIBUTE)
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if typeof(untilTime) ~= "number" or not body.Parent or not humanoid or humanoid.Health <= 0 then
			return false
		end
		local left = untilTime - workspace:GetServerTimeNow()
		if left < -0.25 then
			return false
		end
		for _, flames in clusters do
			gutter(flames, t, left)
		end
		return true
	end, function()
		stopSound()
		stopOutline()
		for _, flames in clusters do
			for _, emitter in flames.emitters do
				emitter.Enabled = false
			end
		end
		if body.Parent then
			collapse(body.Position, 3)
		end
		task.delay(1.6, function()
			upper:Destroy()
			if lower then
				lower:Destroy()
			end
		end)
	end)
	return nil
end

return Amaterasu
