--!strict
-- Effects any character can use: smoke poofs, hit bursts, camera shake, damage numbers and flinches.
-- Each one can be replaced by a custom effect named Smoke / Impact in ReplicatedStorage > Assets > VFX.
local Debris = game:GetService("Debris")

local Ui = require(script.Parent.Parent.Util.Ui)
local VfxUtil = require(script.Parent.Parent.Util.VfxUtil)
local MoveAnimator = require(script.Parent.Parent.Controllers.MoveAnimator)
local Clips = require(script.Parent.Parent.Animations.Common)

local SMOKE_LIGHT = Color3.fromRGB(240, 240, 240)
local SMOKE_DARK = Color3.fromRGB(185, 185, 190)

local Common: { [string]: VfxUtil.Handler } = {}

function Common.Smoke(payload: VfxUtil.Payload): (() -> ())?
	local position = payload.position :: Vector3
	local scale = (payload.scale :: number?) or 1
	if VfxUtil.burstAsset("Smoke", CFrame.new(position), 2) then
		return nil
	end
	for _ = 1, 9 do
		local size = (1.4 + math.random() * 1.4) * scale
		local spread = Vector3.new(math.random() - 0.5, math.random() * 0.8 - 0.2, math.random() - 0.5) * 3 * scale
		local puff = VfxUtil.part({
			size = Vector3.one * size,
			color = SMOKE_LIGHT:Lerp(SMOKE_DARK, math.random()),
			material = Enum.Material.SmoothPlastic,
			transparency = 0.1,
			shape = Enum.PartType.Ball,
			cframe = CFrame.new(position + spread * 0.3),
		})
		VfxUtil.tween(puff, 0.25, { Position = position + spread, Size = Vector3.one * size * 1.6 })
		task.delay(0.15, function()
			VfxUtil.tween(puff, 0.35, { Transparency = 1, Size = Vector3.one * size * 2 })
		end)
		Debris:AddItem(puff, 0.6)
	end
	return nil
end

function Common.Impact(payload: VfxUtil.Payload): (() -> ())?
	local position = payload.position :: Vector3
	local color = (payload.color :: Color3?) or Color3.new(1, 1, 1)
	local scale = (payload.scale :: number?) or 1
	if VfxUtil.burstAsset("Impact", CFrame.new(position), 2) then
		return nil
	end

	local flash = VfxUtil.part({
		size = Vector3.one * 1.5 * scale,
		color = color,
		shape = Enum.PartType.Ball,
		transparency = 0.1,
		cframe = CFrame.new(position),
	})
	VfxUtil.tween(flash, 0.25, { Size = Vector3.one * 5 * scale, Transparency = 1 })

	local ring = VfxUtil.part({
		size = Vector3.new(0.15, 2 * scale, 2 * scale),
		color = Color3.new(1, 1, 1),
		shape = Enum.PartType.Cylinder,
		transparency = 0.3,
		cframe = CFrame.new(position) * CFrame.Angles(math.random() * 0.6, 0, math.rad(90)),
	})
	VfxUtil.tween(ring, 0.35, { Size = Vector3.new(0.05, 9 * scale, 9 * scale), Transparency = 1 })

	local parts: { BasePart } = { flash, ring }
	for _ = 1, 6 do
		local direction = VfxUtil.randomDirection()
		local spark = VfxUtil.part({
			size = Vector3.new(0.15, 0.15, 1.2) * scale,
			color = color,
			cframe = CFrame.lookAt(position, position + direction),
		})
		VfxUtil.tween(spark, 0.3, {
			Position = position + direction * 4 * scale,
			Size = Vector3.new(0.05, 0.05, 0.3),
			Transparency = 1,
		})
		table.insert(parts, spark)
	end
	for _, part in parts do
		Debris:AddItem(part, 0.45)
	end
	return nil
end

function Common.Shake(payload: VfxUtil.Payload): (() -> ())?
	local position = payload.position :: Vector3
	local intensity = (payload.intensity :: number?) or 0.5
	local duration = (payload.duration :: number?) or 0.3
	local distance = (workspace.CurrentCamera.CFrame.Position - position).Magnitude
	local falloff = math.clamp(1 - distance / 80, 0, 1)
	if falloff > 0 then
		VfxUtil.shake(intensity * falloff, duration)
	end
	return nil
end

function Common.DamageNumber(payload: VfxUtil.Payload): (() -> ())?
	local position = payload.position :: Vector3
	local amount = payload.amount :: number
	-- Whoever got hit flinches (harder if the hit stunned or launched them), unless they're mid-move.
	local target = payload.target
	if typeof(target) == "Instance" and target:IsA("Model") and not MoveAnimator.isBusy(target) then
		MoveAnimator.play(target, if payload.heavy then Clips.FlinchHeavy else Clips.Flinch)
	end
	local start = position + Vector3.new((math.random() - 0.5) * 2, 0, (math.random() - 0.5) * 2)
	local anchor = VfxUtil.part({
		size = Vector3.one * 0.1,
		color = Color3.new(1, 1, 1),
		transparency = 1,
		cframe = CFrame.new(start),
	})
	local gui: BillboardGui = Ui.new("BillboardGui", {
		Size = UDim2.fromOffset(90, 40),
		AlwaysOnTop = true,
		Adornee = anchor,
		Parent = anchor,
	})
	local label = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		Text = tostring(math.floor(amount + 0.5)),
		TextScaled = true,
		TextColor3 = Color3.fromRGB(255, 225, 80),
		TextStrokeTransparency = 0,
		Parent = gui,
	})
	VfxUtil.tween(anchor, 0.7, { Position = start + Vector3.new(0, 2.5, 0) })
	task.delay(0.35, function()
		VfxUtil.tween(label, 0.35, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 0.8)
	return nil
end

return Common
