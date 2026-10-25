--!strict
-- What a slide hit looks and sounds like: shockwave ring, sparks, dust puffs flying the way the victim
-- went, a comic-book word, a thud, and screen shake if it happened near you. Clashes get a bigger burst.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Sfx = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Sfx"))
local CameraFx = require(script.Parent.CameraFx)

local LIFETIME = 0.7
local SHAKE_RANGE = 50
local HIT_WORDS = { "POW!", "BAM!", "WHAM!", "SMACK!", "BONK!", "YEET!" }
local HIT_COLOR = Color3.fromRGB(255, 225, 70)
local CLASH_COLOR = Color3.fromRGB(110, 210, 255)

local HitEffects = {}

local function effectPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	Debris:AddItem(part, LIFETIME)
	return part
end

local function tween(instance: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(instance, info, goals):Play()
end

local function comicWord(position: Vector3, text: string, color: Color3, scale: number)
	local anchor = effectPart(Enum.PartType.Block, Vector3.one * 0.1, CFrame.new(position), color)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(180 * scale, 70 * scale)
	gui.AlwaysOnTop = true
	gui.Adornee = anchor
	gui.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.Rotation = math.random(-15, 15)
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(25, 20, 30)
	stroke.Parent = label
	local pop = Instance.new("UIScale")
	pop.Scale = 0.2
	pop.Parent = label

	tween(pop, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(anchor, LIFETIME, { Position = position + Vector3.new(0, 3, 0) })
	task.delay(0.35, function()
		tween(label, 0.3, { TextTransparency = 1 })
		tween(stroke, 0.3, { Transparency = 1 })
	end)
end

local function burst(position: Vector3, direction: Vector3, isClash: boolean)
	local color = if isClash then CLASH_COLOR else HIT_COLOR
	local size = if isClash then 1.6 else 1

	local flash = effectPart(Enum.PartType.Ball, Vector3.one * 2 * size, CFrame.new(position), Color3.new(1, 1, 1))
	tween(flash, 0.2, { Size = Vector3.one * 7 * size, Transparency = 1 })

	local ring = effectPart(
		Enum.PartType.Cylinder,
		Vector3.new(0.2, 2, 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		color
	)
	ring.Transparency = 0.1
	tween(ring, 0.4, { Size = Vector3.new(0.1, 16 * size, 16 * size), Transparency = 1 })

	for _ = 1, 8 do
		local spread = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5) * 2
		local heading = (direction + spread).Unit
		local spark = effectPart(
			Enum.PartType.Block,
			Vector3.new(0.2, 0.2, 1.6) * size,
			CFrame.lookAt(position, position + heading),
			color
		)
		tween(spark, 0.35, {
			Position = position + heading * (5 + math.random() * 4) * size,
			Size = Vector3.new(0.05, 0.05, 0.4),
			Transparency = 1,
		})
	end

	for _ = 1, 6 do
		local spread = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5) * 4
		local puff = effectPart(Enum.PartType.Ball, Vector3.one * 1.3, CFrame.new(position), Color3.new(1, 1, 1))
		puff.Material = Enum.Material.SmoothPlastic
		puff.Transparency = 0.15
		tween(puff, 0.5, {
			Position = position + direction * (3 + math.random() * 4) + spread,
			Size = Vector3.one * 3.2,
			Transparency = 1,
		})
	end

	local word = if isClash then "CLASH!" else HIT_WORDS[math.random(#HIT_WORDS)]
	comicWord(position + Vector3.new(0, 2.5, 0), word, color, size)
end

local function onImpact(position: unknown, direction: unknown, kind: unknown)
	if typeof(position) ~= "Vector3" or typeof(direction) ~= "Vector3" then
		return
	end
	local isClash = kind == "Clash"
	burst(position, direction, isClash)
	Sfx.playAt(Config.Sounds.Impact, position, if isClash then 2 else 1.5, if isClash then 0.55 else 0.75)

	local camera = workspace.CurrentCamera
	local distance = if camera then (camera.Focus.Position - position).Magnitude else math.huge
	if distance < SHAKE_RANGE then
		local closeness = 1 - distance / SHAKE_RANGE
		CameraFx.shake((if isClash then 0.7 else 0.5) * closeness)
		CameraFx.punch(6 * closeness)
	end
end

function HitEffects.start()
	Net.remote("SlideImpact").OnClientEvent:Connect(onImpact)
end

return HitEffects
