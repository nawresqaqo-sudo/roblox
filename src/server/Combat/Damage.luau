--!strict
-- Applies damage, stun and knockback, and shows the damage number.
local Hitbox = require(script.Parent.Hitbox)
local Movement = require(script.Parent.Movement)
local Vfx = require(script.Parent.Vfx)

export type HitOptions = {
	knockback: Vector3?,
	-- Seconds the target can't move or use moves.
	stun: number?,
}

local Damage = {}

function Damage.deal(target: Model, amount: number, options: HitOptions?)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	humanoid:TakeDamage(amount)

	local root = Hitbox.rootOf(target)
	local position = if root then root.Position else target:GetPivot().Position
	Vfx.play("Common.DamageNumber", { position = position + Vector3.new(0, 2.5, 0), amount = amount })

	local opts: HitOptions = options or {}
	local stun = opts.stun
	if stun and stun > 0 then
		local current = target:GetAttribute("StunnedUntil")
		local untilTime = math.max(if typeof(current) == "number" then current else 0, os.clock() + stun)
		target:SetAttribute("StunnedUntil", untilTime)
		Movement.freeze(humanoid, stun)
	end
	if opts.knockback and root then
		Movement.push(root, opts.knockback, 0.15)
	end
end

return Damage
