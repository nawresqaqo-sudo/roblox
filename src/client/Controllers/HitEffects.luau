--!strict
-- The burst where a slide connects: a shockwave ring plus dust puffs flying the way the victim went.
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))

local LIFETIME = 0.5

local HitEffects = {}

local function effectPart(shape: Enum.PartType, size: Vector3, cframe: CFrame, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = Color3.new(1, 1, 1)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = workspace
	Debris:AddItem(part, LIFETIME)
	return part
end

local function tween(part: Part, time: number, goals: { [string]: any })
	TweenService:Create(part, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals):Play()
end

local function burst(position: Vector3, direction: Vector3)
	local ring = effectPart(
		Enum.PartType.Cylinder,
		Vector3.new(0.2, 2, 2),
		CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2),
		Enum.Material.Neon
	)
	ring.Transparency = 0.2
	tween(ring, 0.35, { Size = Vector3.new(0.1, 14, 14), Transparency = 1 })

	for _ = 1, 6 do
		local spread = Vector3.new(math.random() - 0.5, math.random() * 0.6, math.random() - 0.5) * 4
		local puff =
			effectPart(Enum.PartType.Ball, Vector3.one * 1.2, CFrame.new(position), Enum.Material.SmoothPlastic)
		puff.Transparency = 0.15
		tween(puff, 0.45, {
			Position = position + direction * (3 + math.random() * 4) + spread,
			Size = Vector3.one * 3,
			Transparency = 1,
		})
	end
end

function HitEffects.start()
	Net.remote("SlideImpact").OnClientEvent:Connect(function(position: unknown, direction: unknown)
		if typeof(position) == "Vector3" and typeof(direction) == "Vector3" then
			burst(position, direction)
		end
	end)
end

return HitEffects
