--!strict
-- Anime-style effect pieces: bright, glossy and sharp instead of chunky. Crescent slashes with a white
-- core and a colored glow, speed streaks, glossy flashes and shockwaves, lightning, impact frames,
-- a blacked-out sky, afterimages, outlines, haki auras, screen speed lines and flying debris.
-- Everything is built on this client only.
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
-- only on this client. Calling it again while it's dark just keeps it dark longer.
function AnimeFx.darkSky(duration: number, tint: Color3, glow: Color3?)
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
		atmosphere.Color = Color3.fromRGB(40, 6, 10)
		atmosphere.Decay = Color3.fromRGB(20, 0, 4)
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
