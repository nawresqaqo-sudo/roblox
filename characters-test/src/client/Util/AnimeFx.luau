--!strict
-- Anime-style effect pieces: bright, glossy and sharp instead of chunky. Crescent slashes with a white
-- core and a colored glow, speed streaks, glossy flashes, shockwaves and rings, lightning and crackling
-- bolts, impact frames, a blacked-out sky, afterimages, outlines, haki auras, screen speed lines and
-- flying debris. Everything is built on this client only.
local Debris = game:GetService("Debris")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local VfxUtil = require(script.Parent.VfxUtil)

local WHITE = Color3.new(1, 1, 1)
local FIRE_TEXTURE = "rbxasset://textures/particles/fire_main.dds"
local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local ARC_HANDLE = 0.5523 -- bezier handle length that makes a quarter circle

local AnimeFx = {}

local function tween(instance: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
		:Play()
end

local function beam(a0: Attachment, a1: Attachment, color: Color3, glowing: boolean): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.FaceCamera = true
	b.Segments = 24
	b.LightEmission = if glowing then 1 else 0
	b.LightInfluence = 0
	b.Color = ColorSequence.new(color)
	b.Parent = a0
	return b
end

local function worldAttachment(): Attachment
	local attachment = Instance.new("Attachment")
	attachment.Parent = workspace.Terrain
	return attachment
end

-- Slashes -------------------------------------------------------------------------------------------

export type SlashOptions = {
	width: number?, -- thickness at the middle of the crescent
	duration: number?,
	color: Color3?, -- the glow around the core
	core: Color3?,
	dark: boolean?, -- a black core (haki) instead of a glowing white one
	grow: number?, -- how much it expands while fading
}

type Crescent = {
	place: (cframe: CFrame, radius: number, widthScale: number, fade: number) -> (),
	destroy: () -> (),
}

-- A crescent made of four beams (glow + core, two halves each) that is thick in the middle and sharp
-- at the tips. It lies in the cframe's X/Y plane, curving from -X through +Y to +X.
local function crescent(width: number, color: Color3, core: Color3, dark: boolean): Crescent
	local points = { worldAttachment(), worldAttachment(), worldAttachment() }
	local glowA = beam(points[1], points[2], color, true)
	local glowB = beam(points[2], points[3], color, true)
	local coreA = beam(points[1], points[2], core, not dark)
	local coreB = beam(points[2], points[3], core, not dark)
	local layers = {
		{ beam = glowA, width = width * 2.4, rising = true, base = 0.35 },
		{ beam = glowB, width = width * 2.4, rising = false, base = 0.35 },
		{ beam = coreA, width = width, rising = true, base = 0 },
		{ beam = coreB, width = width, rising = false, base = 0 },
	}
	return {
		place = function(cframe: CFrame, radius: number, widthScale: number, fade: number)
			local c, up, right, look = cframe.Position, cframe.UpVector, cframe.RightVector, cframe.LookVector
			points[1].WorldCFrame = CFrame.fromMatrix(c - right * radius, up, look)
			points[2].WorldCFrame = CFrame.fromMatrix(c + up * radius, right, look)
			points[3].WorldCFrame = CFrame.fromMatrix(c + right * radius, -up, look)
			local handle = radius * ARC_HANDLE
			for _, layer in layers do
				local b = layer.beam
				b.CurveSize0 = handle
				b.CurveSize1 = handle
				local thick = layer.width * widthScale
				b.Width0 = if layer.rising then thick * 0.05 else thick
				b.Width1 = if layer.rising then thick else thick * 0.05
				b.Transparency = NumberSequence.new(layer.base + (1 - layer.base) * fade)
			end
		end,
		destroy = function()
			for _, point in points do
				point:Destroy()
			end
		end,
	}
end

-- A slash that pops in, then expands and fades.
function AnimeFx.slash(cframe: CFrame, radius: number, options: SlashOptions?)
	local opts: SlashOptions = options or {}
	local duration = opts.duration or 0.35
	local grow = opts.grow or 1.15
	local arc = crescent(
		opts.width or radius * 0.16,
		opts.color or Color3.fromRGB(110, 255, 170),
		opts.core or (if opts.dark then Color3.fromRGB(14, 12, 18) else WHITE),
		opts.dark == true
	)
	VfxUtil.everyFrame(duration, function(t)
		local pop = math.min(t / 0.05, 1)
		local fade = math.clamp((t - 0.05) / math.max(duration - 0.05, 0.01), 0, 1)
		arc.place(cframe, radius * (0.75 + 0.25 * pop + (grow - 1) * fade), pop * (1 - 0.65 * fade), fade)
		return true
	end, arc.destroy)
end

-- A crescent that flies along a straight line until stop() is called or `maxTime` passes.
-- It curves forward, like a flying slash. Leaves fading copies behind it.
function AnimeFx.flyingSlash(
	origin: Vector3,
	direction: Vector3,
	speed: number,
	maxTime: number,
	radius: number,
	options: SlashOptions?
): () -> ()
	local opts: SlashOptions = options or {}
	local color = opts.color or Color3.fromRGB(110, 255, 170)
	local arc = crescent(opts.width or radius * 0.2, color, opts.core or WHITE, opts.dark == true)
	local right = direction:Cross(Vector3.yAxis)
	right = if right.Magnitude > 1e-3 then right.Unit else Vector3.xAxis
	local lastCopy = 0
	return VfxUtil.everyFrame(maxTime + 0.1, function(t)
		local position = origin + direction * speed * math.min(t, maxTime)
		local cframe = CFrame.fromMatrix(position, right, direction)
		arc.place(cframe, radius * math.min(1, 0.6 + t * 4), 1, 0)
		if t - lastCopy > 0.04 then
			lastCopy = t
			AnimeFx.slash(cframe, radius, { color = color, duration = 0.18, width = radius * 0.1, grow = 1.05 })
		end
		return true
	end, function()
		arc.destroy()
	end)
end

-- A straight glossy speed streak between two points.
function AnimeFx.streak(from: Vector3, to: Vector3, color: Color3, width: number, duration: number)
	local a0, a1 = worldAttachment(), worldAttachment()
	a0.WorldPosition = from
	a1.WorldPosition = to
	local glow = beam(a0, a1, color, true)
	local core = beam(a0, a1, WHITE, true)
	VfxUtil.everyFrame(duration, function(t)
		local fade = t / duration
		local thin = 1 - fade
		glow.Width0, glow.Width1 = width * 2 * thin, width * 0.6 * thin
		core.Width0, core.Width1 = width * thin, width * 0.2 * thin
		glow.Transparency = NumberSequence.new(0.3 + 0.7 * fade)
		core.Transparency = NumberSequence.new(fade)
		return true
	end, function()
		a0:Destroy()
		a1:Destroy()
	end)
end

-- Flashes and shockwaves --------------------------------------------------------------------------

-- A glossy burst: a white core popping inside a colored glow, with a quick light.
function AnimeFx.flash(position: Vector3, color: Color3, size: number, duration: number?)
	local d = duration or 0.25
	local core = VfxUtil.part({
		size = Vector3.one * size * 0.45,
		color = WHITE,
		shape = Enum.PartType.Ball,
		cframe = CFrame.new(position),
	})
	local glow = VfxUtil.part({
		size = Vector3.one * size * 0.7,
		color = color,
		shape = Enum.PartType.Ball,
		transparency = 0.35,
		cframe = CFrame.new(position),
	})
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 8
	light.Range = math.min(size * 4, 60)
	light.Parent = core
	tween(core, d * 0.6, { Size = Vector3.one * size, Transparency = 1 })
	tween(glow, d, { Size = Vector3.one * size * 1.8, Transparency = 1 })
	tween(light, d, { Brightness = 0 })
	Debris:AddItem(core, d + 0.1)
	Debris:AddItem(glow, d + 0.1)
end

-- An expanding glossy ring on the plane whose normal is the cframe's Y axis.
function AnimeFx.shockwave(cframe: CFrame, color: Color3, size: number, duration: number?)
	local d = duration or 0.45
	local flat = cframe * CFrame.Angles(0, 0, math.pi / 2) -- cylinders point along X; turn X into the normal
	local disk = VfxUtil.part({
		size = Vector3.new(0.3, size * 0.2, size * 0.2),
		color = color,
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.ForceField,
		cframe = flat,
	})
	local rim = VfxUtil.part({
		size = Vector3.new(0.15, size * 0.2, size * 0.2),
		color = WHITE,
		shape = Enum.PartType.Cylinder,
		transparency = 0.45,
		cframe = flat,
	})
	tween(disk, d, { Size = Vector3.new(0.05, size, size), Transparency = 1 })
	tween(rim, d * 0.7, { Size = Vector3.new(0.02, size * 0.85, size * 0.85), Transparency = 1 })
	Debris:AddItem(disk, d + 0.1)
	Debris:AddItem(rim, d + 0.1)
end

export type RingOptions = {
	from: number, -- radius when it starts
	to: number, -- radius when it ends
	color: Color3?,
	thickness: number?, -- how wide the band is
	duration: number?,
	transparency: number?, -- how see-through it starts
	style: Enum.EasingStyle?,
	hold: boolean?, -- stay as it started instead of fading out
}

-- A flat band with a hole in the middle that grows (or shrinks to a point) and fades. The cframe's Y axis
-- is the ring's normal. Returns a function that removes it early.
function AnimeFx.ring(cframe: CFrame, options: RingOptions): () -> ()
	local duration = options.duration or 0.4
	local thickness = options.thickness or 0.6
	local start = options.transparency or 0
	local style = options.style or Enum.EasingStyle.Quad
	local anchor = VfxUtil.part({ size = Vector3.one * 0.2, color = WHITE, transparency = 1, cframe = cframe })
	local band = Instance.new("CylinderHandleAdornment")
	band.Adornee = anchor
	band.CFrame = CFrame.Angles(math.pi / 2, 0, 0) -- adornment cylinders run along Z; this lays it flat
	band.Height = 0.08
	band.Color3 = options.color or WHITE
	band.Transparency = start
	band.Parent = anchor
	return VfxUtil.everyFrame(duration, function(t)
		local alpha = TweenService:GetValue(math.min(t / duration, 1), style, Enum.EasingDirection.Out)
		local radius = math.max(options.from + (options.to - options.from) * alpha, 0.05)
		band.Radius = radius
		band.InnerRadius = math.max(radius - thickness, 0)
		band.Transparency = if options.hold then start else start + (1 - start) * math.min(t / duration, 1) ^ 1.5
		return true
	end, function()
		anchor:Destroy()
	end)
end

-- A jagged bolt from `from` to `to` with a white core.
function AnimeFx.lightning(from: Vector3, to: Vector3, color: Color3, width: number?, duration: number?)
	local w = width or 0.4
	local d = duration or 0.2
	local offset = to - from
	local length = offset.Magnitude
	if length < 0.5 then
		return
	end
	local segments = math.clamp(math.floor(length / 4), 4, 16)
	local points = { from }
	for i = 1, segments - 1 do
		table.insert(points, from + offset * (i / segments) + VfxUtil.randomDirection() * length * 0.07)
	end
	table.insert(points, to)
	local parts: { BasePart } = {}
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local cframe = CFrame.lookAt((a + b) / 2, b)
		local segment = (b - a).Magnitude
		table.insert(
			parts,
			VfxUtil.part({ size = Vector3.new(w * 0.35, w * 0.35, segment), color = WHITE, cframe = cframe })
		)
		table.insert(
			parts,
			VfxUtil.part({
				size = Vector3.new(w, w, segment + w * 0.5),
				color = color,
				transparency = 0.3,
				cframe = cframe,
			})
		)
	end
	VfxUtil.fadeOut(parts, d)
end

-- Crackling electricity ----------------------------------------------------------------------------

-- A fixed point, or a function giving a point that moves (nil ends the bolt).
export type BoltPoint = Vector3 | () -> Vector3?

export type BoltOptions = {
	color: Color3?, -- the glow around the core
	core: Color3?,
	width: number?, -- core width; the glow is three times as wide
	jitter: number?, -- how far it wanders sideways, as a fraction of its length
	segments: number?,
	branches: number?, -- short forks off the main bolt
	duration: number?,
	flicker: number?, -- times a second it changes shape (0 keeps one shape)
	draw: number?, -- seconds to draw it from start to end instead of appearing all at once
	dark: boolean?, -- a black core with a colored edge
}

local ELECTRIC = Color3.fromRGB(110, 185, 255)
local OBSIDIAN = Color3.fromRGB(12, 9, 18)

-- A line of beams through a list of points: a core inside a glow three times as wide, tapering to a tip.
type Strand = {
	set: (points: { Vector3 }) -> (),
	style: (fade: number, thin: number, shown: number) -> (),
	destroy: () -> (),
}

local function strand(count: number, width: number, color: Color3, core: Color3, dark: boolean): Strand
	local attachments: { Attachment } = {}
	for i = 1, count do
		attachments[i] = worldAttachment()
	end
	local glows: { Beam } = {}
	local cores: { Beam } = {}
	for i = 1, count - 1 do
		local glow = beam(attachments[i], attachments[i + 1], color, true)
		glow.Segments = 1
		local inner = beam(attachments[i], attachments[i + 1], core, not dark)
		inner.Segments = 1
		inner.ZOffset = 0.2 -- drawn over the glow
		inner.Brightness = if dark then 1 else 2
		glows[i] = glow
		cores[i] = inner
	end
	local segments = count - 1
	-- Full width for the first 60%, then narrowing to a point.
	local function taper(f: number): number
		return 1 - math.max(0, f - 0.6) / 0.4 * 0.85
	end
	return {
		set = function(points: { Vector3 })
			for i, attachment in attachments do
				attachment.WorldPosition = points[i] or attachment.WorldPosition
			end
		end,
		style = function(fade: number, thin: number, shown: number)
			local glowFade = NumberSequence.new(0.45 + 0.55 * fade)
			local coreFade = NumberSequence.new(fade)
			for i = 1, segments do
				local a, b = taper((i - 1) / segments) * thin, taper(i / segments) * thin
				local glow, inner = glows[i], cores[i]
				glow.Enabled = i <= shown
				inner.Enabled = i <= shown
				glow.Width0, glow.Width1 = width * 3 * a, width * 3 * b
				inner.Width0, inner.Width1 = width * a, width * b
				glow.Transparency = glowFade
				inner.Transparency = coreFade
			end
		end,
		destroy = function()
			for _, attachment in attachments do
				attachment:Destroy()
			end
		end,
	}
end

local function resolve(point: BoltPoint): Vector3?
	if typeof(point) == "Vector3" then
		return point
	end
	return (point :: () -> Vector3?)()
end

-- Two directions at right angles to `axis` (and to each other).
local function perpendiculars(axis: Vector3): (Vector3, Vector3)
	local side = axis:Cross(if math.abs(axis.Y) < 0.95 then Vector3.yAxis else Vector3.xAxis).Unit
	return side, side:Cross(axis)
end

-- How far each inner point of a jagged line strays sideways (as fractions of the line's length).
local function wander(count: number, jitter: number): { Vector2 }
	local offsets: { Vector2 } = {}
	for i = 1, count - 2 do
		local angle = math.random() * math.pi * 2
		local reach = jitter * (0.35 + math.random() * 0.65) * math.min(1, math.sin(i / (count - 1) * math.pi) * 1.6)
		offsets[i] = Vector2.new(math.cos(angle), math.sin(angle)) * reach
	end
	return offsets
end

-- Lays the points of a jagged line from `a` to `b` into `out` (#out points), using `offsets` from wander.
local function layout(
	a: Vector3,
	b: Vector3,
	offsets: { Vector2 },
	out: { Vector3 }
): (Vector3, Vector3, Vector3, number)
	local count = #out
	local offset = b - a
	local length = offset.Magnitude
	local axis = if length > 1e-3 then offset / length else Vector3.yAxis
	local side, up = perpendiculars(axis)
	for i = 1, count do
		local o = offsets[i - 1]
		local straight = a + offset * ((i - 1) / (count - 1))
		out[i] = if o and i < count then straight + (side * o.X + up * o.Y) * length else straight
	end
	return axis, side, up, length
end

local function boltFade(t: number, duration: number): number
	return math.clamp((t / duration - 0.45) / 0.55, 0, 1)
end

local function boltShown(t: number, draw: number, segments: number): number
	return if draw > 0 then math.clamp(math.ceil(t / draw * segments), 1, segments) else segments
end

-- A crackling bolt: a bright core inside a colored glow, with forks, changing shape many times a second
-- like real electricity. The ends can be functions so it stays attached to moving things.
-- Returns a function that ends it early.
function AnimeFx.bolt(from: BoltPoint, to: BoltPoint, options: BoltOptions?): () -> ()
	local opts: BoltOptions = options or {}
	local count = math.max(opts.segments or 7, 3) + 1
	local width = opts.width or 0.3
	local jitter = opts.jitter or 0.12
	local duration = opts.duration or 0.2
	local flicker = opts.flicker or 18
	local draw = opts.draw or 0
	local dark = opts.dark == true
	local color = opts.color or ELECTRIC
	local core = opts.core or (if dark then OBSIDIAN else WHITE)

	type Fork = { at: number, angle: number, spin: number, reach: number, line: Strand, offsets: { Vector2 } }
	local main = strand(count, width, color, core, dark)
	local offsets = wander(count, jitter)
	local forks: { Fork } = {}
	for _ = 1, opts.branches or 0 do
		table.insert(forks, {
			at = math.random(2, count - 1),
			angle = math.rad(25 + math.random() * 35),
			spin = math.random() * math.pi * 2,
			reach = 0.2 + math.random() * 0.25,
			line = strand(4, width * 0.55, color, core, dark),
			offsets = wander(4, jitter * 1.4),
		})
	end

	local lastShape = 0
	local points: { Vector3 } = table.create(count, Vector3.zero)
	local forkPoints: { Vector3 } = table.create(4, Vector3.zero)
	return VfxUtil.everyFrame(duration, function(t)
		local a, b = resolve(from), resolve(to)
		if not a or not b then
			return false
		end
		if flicker > 0 and t - lastShape >= 1 / flicker then
			lastShape = t
			offsets = wander(count, jitter)
			for _, fork in forks do
				fork.offsets = wander(4, jitter * 1.4)
				fork.spin = math.random() * math.pi * 2
			end
		end
		local axis, side, up, length = layout(a, b, offsets, points)
		main.set(points)

		local fade = boltFade(t, duration)
		local shown = boltShown(t, draw, count - 1)
		main.style(fade, 1 - 0.5 * fade, shown)
		for _, fork in forks do
			local start = points[fork.at]
			local direction = axis * math.cos(fork.angle)
				+ (side * math.cos(fork.spin) + up * math.sin(fork.spin)) * math.sin(fork.angle)
			layout(start, start + direction * length * fork.reach, fork.offsets, forkPoints)
			fork.line.set(forkPoints)
			fork.line.style(fade, 1 - 0.5 * fade, if fork.at <= shown then 3 else 0)
		end
		return true
	end, function()
		main.destroy()
		for _, fork in forks do
			fork.line.destroy()
		end
	end)
end

export type CrackleOptions = {
	duration: number,
	count: number?, -- how many arcs at once
	segments: number?,
	width: number?,
	color: Color3?, -- glow
	altColor: Color3?, -- every other arc glows this color instead
	core: Color3?,
	flicker: number?, -- times a second the arcs jump to new places
	chance: number?, -- how likely each arc is to be lit after a jump (0-1)
}

-- Short arcs that keep jumping to new places around a moving frame of reference: lightning in a fist,
-- electricity crawling over a body, flickers inside a storm cloud. `space` says where that frame is
-- (nil ends it) and `pick` chooses where the next arc runs, in that frame's space. The same few bolts
-- are reused the whole time, so it stays cheap. Returns a function that ends it early.
function AnimeFx.crackle(space: () -> CFrame?, pick: () -> (Vector3, Vector3), options: CrackleOptions): () -> ()
	local count = options.count or 4
	local segments = options.segments or 4
	local flicker = options.flicker or 24
	local chance = options.chance or 0.7
	local duration = options.duration
	type Arc = { line: Strand, from: Vector3, to: Vector3, offsets: { Vector2 }, lit: boolean }
	local arcs: { Arc } = {}
	for i = 1, count do
		local color = if options.altColor and i % 2 == 0 then options.altColor else options.color or ELECTRIC
		table.insert(arcs, {
			line = strand(segments + 1, options.width or 0.1, color, options.core or WHITE, false),
			from = Vector3.zero,
			to = Vector3.zero,
			offsets = {},
			lit = false,
		})
	end
	local points: { Vector3 } = table.create(segments + 1, Vector3.zero)
	local nextJump = 0
	return VfxUtil.everyFrame(duration, function(t)
		local frame = space()
		if not frame then
			return false
		end
		if t >= nextJump then
			nextJump = t + 1 / flicker
			for _, arc in arcs do
				arc.lit = math.random() < chance
				arc.from, arc.to = pick()
				arc.offsets = wander(segments + 1, 0.22)
			end
		end
		local fade = 1 - math.clamp((duration - t) / 0.15, 0, 1)
		for _, arc in arcs do
			layout(frame:PointToWorldSpace(arc.from), frame:PointToWorldSpace(arc.to), arc.offsets, points)
			arc.line.set(points)
			arc.line.style(fade, 1, if arc.lit then segments else 0)
		end
		return true
	end, function()
		for _, arc in arcs do
			arc.line.destroy()
		end
	end)
end

-- A glowing line through exactly these points (spirals, glowing cracks): the same look as a bolt, but
-- it keeps the shape it's given. Returns a function that ends it early.
function AnimeFx.path(points: { Vector3 }, options: BoltOptions?): () -> ()
	local opts: BoltOptions = options or {}
	local count = #points
	if count < 2 then
		return function() end
	end
	local duration = opts.duration or 0.3
	local draw = opts.draw or 0
	local dark = opts.dark == true
	local line =
		strand(count, opts.width or 0.3, opts.color or ELECTRIC, opts.core or (if dark then OBSIDIAN else WHITE), dark)
	line.set(points)
	return VfxUtil.everyFrame(duration, function(t)
		local fade = boltFade(t, duration)
		line.style(fade, 1 - 0.5 * fade, boltShown(t, draw, count - 1))
		return true
	end, line.destroy)
end

-- Screen effects -----------------------------------------------------------------------------------

local function screen(name: string): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 60
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

-- A full-screen flash of color.
function AnimeFx.screenFlash(color: Color3, duration: number, startTransparency: number?)
	local gui = screen("ScreenFlash")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = startTransparency or 0
	frame.Parent = gui
	tween(frame, duration, { BackgroundTransparency = 1 })
	Debris:AddItem(gui, duration + 0.05)
end

-- Anime impact frames: two frames of harsh black-and-white, then a red-black one, then back.
function AnimeFx.impactFrame(strength: number?)
	local s = strength or 1
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Saturation = -1
	effect.Contrast = 2.2 * s
	effect.Brightness = 0.3 * s
	effect.Parent = Lighting
	AnimeFx.screenFlash(WHITE, 0.08, 0.2)
	task.delay(0.06, function()
		effect.Brightness = -0.45 * s
		effect.TintColor = Color3.fromRGB(255, 70, 70)
	end)
	task.delay(0.13, function()
		effect:Destroy()
	end)
end

-- Anime speed lines rushing in from the edges of the screen.
function AnimeFx.speedLines(duration: number, color: Color3?)
	local gui = screen("SpeedLines")
	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.Parent = gui
	local lines = {}
	for _ = 1, 28 do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = color or WHITE
		frame.Parent = holder
		table.insert(lines, { frame = frame, angle = math.random() * math.pi * 2, phase = math.random() })
	end
	VfxUtil.everyFrame(duration, function(t)
		local size = holder.AbsoluteSize
		local center = size / 2
		local radius = math.max(size.X, size.Y) / 2
		local fade = math.clamp((t - duration * 0.7) / (duration * 0.3), 0, 1)
		for _, line in lines do
			local cycle = (t * 4 + line.phase) % 1
			local distance = radius * (1.05 - cycle * 0.4)
			local direction = Vector2.new(math.cos(line.angle), math.sin(line.angle))
			local spot = center + direction * distance
			line.frame.Position = UDim2.fromOffset(spot.X, spot.Y)
			line.frame.Size = UDim2.fromOffset(radius * 0.35, 3)
			line.frame.Rotation = math.deg(line.angle)
			line.frame.BackgroundTransparency = 0.25 + 0.75 * math.max(fade, 1 - math.sin(cycle * math.pi))
		end
		return true
	end, function()
		gui:Destroy()
	end)
end

-- The sky ------------------------------------------------------------------------------------------

type SkyState = {
	untilTime: number,
	restore: () -> (),
}

local skyState: SkyState? = nil

-- Turns the sky black and lights the world with `glow` (dark red by default) for `duration` seconds,
-- only on this client. `haze` colors the air (dark red by default). Calling it again while it's dark
-- just keeps it dark longer.
function AnimeFx.darkSky(duration: number, tint: Color3, glow: Color3?, haze: Color3?)
	local now = os.clock()
	if skyState then
		skyState.untilTime = math.max(skyState.untilTime, now + duration)
		return
	end

	local saved = {
		ClockTime = Lighting.ClockTime,
		Brightness = Lighting.Brightness,
		Ambient = Lighting.Ambient,
		OutdoorAmbient = Lighting.OutdoorAmbient,
		ExposureCompensation = Lighting.ExposureCompensation,
	}
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	local savedAtmosphere = if atmosphere
		then { Density = atmosphere.Density, Color = atmosphere.Color, Decay = atmosphere.Decay, Haze = atmosphere.Haze }
		else nil
	local sky = Lighting:FindFirstChildOfClass("Sky")
	local savedSky = if sky then { CelestialBodiesShown = sky.CelestialBodiesShown, StarCount = sky.StarCount } else nil

	local effect = Instance.new("ColorCorrectionEffect")
	effect.TintColor = tint
	effect.Contrast = 0.35
	effect.Saturation = -0.15
	effect.Parent = Lighting

	Lighting.ClockTime = 0
	Lighting.Brightness = 0.2
	local light = glow or Color3.fromRGB(90, 16, 20)
	Lighting.Ambient = light:Lerp(Color3.new(0, 0, 0), 0.25)
	Lighting.OutdoorAmbient = light
	Lighting.ExposureCompensation = -0.3
	if sky then
		sky.CelestialBodiesShown = false
		sky.StarCount = 0
	end
	if atmosphere then
		atmosphere.Density = 0.45
		atmosphere.Color = haze or Color3.fromRGB(40, 6, 10)
		atmosphere.Decay = if haze then haze:Lerp(Color3.new(0, 0, 0), 0.5) else Color3.fromRGB(20, 0, 4)
		atmosphere.Haze = 0
	end

	local state: SkyState = {
		untilTime = now + duration,
		restore = function()
			Lighting.ClockTime = saved.ClockTime
			Lighting.Ambient = saved.Ambient
			Lighting.OutdoorAmbient = saved.OutdoorAmbient
			tween(Lighting, 0.6, { Brightness = saved.Brightness, ExposureCompensation = saved.ExposureCompensation })
			tween(effect, 0.6, { Contrast = 0, Saturation = 0, TintColor = WHITE })
			Debris:AddItem(effect, 0.7)
			if sky and savedSky then
				sky.CelestialBodiesShown = savedSky.CelestialBodiesShown
				sky.StarCount = savedSky.StarCount
			end
			if atmosphere and savedAtmosphere then
				for key, value in savedAtmosphere do
					(atmosphere :: any)[key] = value
				end
			end
		end,
	}
	skyState = state
	task.spawn(function()
		while os.clock() < state.untilTime do
			task.wait(0.1)
		end
		skyState = nil
		state.restore()
	end)
end

-- Your own effects ---------------------------------------------------------------------------------
-- Effects made in Sine VFX or any VFX plugin live in ReplicatedStorage > Assets > VFX. Bursts (emitters
-- with Rate 0) are emitted once; set an "EmitCount" attribute on an emitter to change the amount.

-- Plays the custom effect called `name` at `cframe`. False if there isn't one.
function AnimeFx.custom(name: string, cframe: CFrame, lifetime: number?): boolean
	return VfxUtil.burstAsset(name, cframe, lifetime or 3)
end

-- Plays the custom effect called `name`, moving it to getCFrame() every frame for `duration` seconds.
-- Returns a stop function, or nil if there's no such effect.
function AnimeFx.customFollow(name: string, getCFrame: () -> CFrame?, duration: number): (() -> ())?
	local copy = VfxUtil.asset(name)
	if not copy then
		return nil
	end
	local first = getCFrame()
	if first then
		VfxUtil.pivot(copy, first)
	end
	VfxUtil.emit(copy)
	return VfxUtil.everyFrame(duration, function()
		local cframe = getCFrame()
		if not cframe then
			return false
		end
		VfxUtil.pivot(copy, cframe)
		return true
	end, function()
		for _, instance in copy:GetDescendants() do
			if instance:IsA("ParticleEmitter") then
				instance.Enabled = false
			elseif instance:IsA("Beam") then
				instance.Enabled = false
			elseif instance:IsA("Trail") then
				instance.Enabled = false
			end
		end
		Debris:AddItem(copy, 2)
	end)
end

-- On characters ------------------------------------------------------------------------------------

-- A glowing ghost copy of the character that fades where it stands (dash smears).
function AnimeFx.afterimage(character: Model, color: Color3, duration: number?, transparency: number?)
	local ghosts: { BasePart } = {}
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.Transparency < 1 and part.Name ~= "HumanoidRootPart" then
			local ok, copy = pcall(part.Clone, part)
			if ok and copy and copy:IsA("BasePart") then
				copy:ClearAllChildren()
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.CastShadow = false
				copy.Material = Enum.Material.Neon
				copy.Color = color
				copy.Transparency = transparency or 0.5
				copy.CFrame = part.CFrame
				copy.Parent = VfxUtil.folder()
				table.insert(ghosts, copy)
			end
		end
	end
	VfxUtil.fadeOut(ghosts, duration or 0.35)
end

-- A bright outline around the character (seen through walls). Returns a function that removes it.
function AnimeFx.outline(character: Model, color: Color3, duration: number, fill: Color3?): () -> ()
	local highlight = Instance.new("Highlight")
	highlight.OutlineColor = color
	highlight.OutlineTransparency = 0
	highlight.FillColor = fill or color
	highlight.FillTransparency = if fill then 0.75 else 1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Adornee = character
	highlight.Parent = VfxUtil.folder()
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		tween(highlight, 0.25, { OutlineTransparency = 1, FillTransparency = 1 })
		Debris:AddItem(highlight, 0.3)
	end
	task.delay(duration, stop)
	return stop
end

-- Haki flames rising off a part, with crackling sparks. Returns a function that stops it.
function AnimeFx.aura(part: BasePart, flame: Color3, spark: Color3, duration: number, size: number?): () -> ()
	local s = size or 2.2
	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local flames = Instance.new("ParticleEmitter")
	flames.Texture = FIRE_TEXTURE
	flames.Color = ColorSequence.new(flame, Color3.fromRGB(10, 8, 14))
	flames.LightEmission = 0.3
	flames.Transparency = NumberSequence.new(0.15, 1)
	flames.Size = NumberSequence.new(s, s * 0.3)
	flames.Lifetime = NumberRange.new(0.4, 0.7)
	flames.Rate = 70
	flames.Speed = NumberRange.new(4, 9)
	flames.SpreadAngle = Vector2.new(35, 35)
	flames.EmissionDirection = Enum.NormalId.Top
	flames.Acceleration = Vector3.new(0, 8, 0)
	flames.RotSpeed = NumberRange.new(-90, 90)
	flames.Parent = attachment

	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = SPARK_TEXTURE
	sparks.Color = ColorSequence.new(spark)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.7, 0)
	sparks.Lifetime = NumberRange.new(0.15, 0.3)
	sparks.Rate = 30
	sparks.Speed = NumberRange.new(10, 16)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Parent = attachment

	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		flames.Enabled = false
		sparks.Enabled = false
		Debris:AddItem(attachment, 1)
	end
	task.delay(duration, stop)
	return stop
end

-- Rock chunks thrown out of an impact, arcing and bouncing to a stop on the ground.
function AnimeFx.debris(position: Vector3, count: number, color: Color3, power: number)
	for _ = 1, count do
		local size = 0.6 + math.random() * 1.6
		local rock = VfxUtil.part({
			size = Vector3.new(size, size * 0.7, size * 0.9),
			color = color,
			material = Enum.Material.Slate,
			cframe = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
		})
		rock.CastShadow = true
		local outward = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		outward = if outward.Magnitude > 1e-3 then outward.Unit else Vector3.xAxis
		local velocity = outward * power * (0.4 + math.random() * 0.6)
			+ Vector3.new(0, power * (0.6 + math.random()), 0)
		local spin = CFrame.Angles(math.random() * 0.3, math.random() * 0.3, math.random() * 0.3)
		local floor = position.Y - 2.5
		local current = rock.CFrame
		local lastT = 0
		VfxUtil.everyFrame(2.2, function(t)
			local dt = t - lastT
			lastT = t
			velocity += Vector3.new(0, -196 * dt, 0)
			local nextPosition = current.Position + velocity * dt
			if nextPosition.Y < floor then
				nextPosition = Vector3.new(nextPosition.X, floor, nextPosition.Z)
				velocity = Vector3.new(velocity.X * 0.5, -velocity.Y * 0.3, velocity.Z * 0.5)
			end
			current = CFrame.new(nextPosition) * (current.Rotation * spin)
			rock.CFrame = current
			if t > 1.6 then
				rock.Transparency = (t - 1.6) / 0.6
			end
			return true
		end, function()
			rock:Destroy()
		end)
	end
end

return AnimeFx
