--!strict
-- Sasuke's moves on the server: timing, movement, targeting, hitboxes and damage.
-- Visuals are in StarterPlayerScripts > Client > Vfx > Sasuke. Numbers are in Shared.Characters.Sasuke.
-- Nothing here takes the client's word for anything: targets, dash paths and strike points are picked
-- from the server's own view of the world, and every hit is checked where the attack really is.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local SasukeData = require(ReplicatedStorage.Shared.Characters.Sasuke)
local Animations = require(script.Parent.Parent.Combat.Animations)
local CombatTypes = require(script.Parent.Parent.Combat.CombatTypes)
local Damage = require(script.Parent.Parent.Combat.Damage)
local Hitbox = require(script.Parent.Parent.Combat.Hitbox)
local Movement = require(script.Parent.Parent.Combat.Movement)
local Vfx = require(script.Parent.Parent.Combat.Vfx)
local Outfit = require(script.Outfit)

type MoveContext = CombatTypes.MoveContext

-- One Amaterasu fire on one character (os.clock() times).
type Burn = {
	endsAt: number,
	startedAt: number,
}

local Tuning = SasukeData.Tuning
-- Server time a character stops burning. Clients draw the black flames until then.
local BURN_ATTRIBUTE = "AmaterasuUntil"

local burns: { [Model]: Burn } = {}

local function animationFor(slot: number): string
	for _, move in SasukeData.Info.Moves do
		if move.Slot == slot then
			return move.AnimationId
		end
	end
	return ""
end

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function flatLook(part: BasePart): Vector3
	local flat = flatten(part.CFrame.LookVector)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

local function ignoreList(ctx: MoveContext): { Instance }
	return { ctx.character }
end

local function launch(direction: Vector3, strength: number, lift: number): Vector3
	return direction * strength + Vector3.new(0, strength * lift, 0)
end

local function faceToward(ctx: MoveContext, position: Vector3)
	local flat = Vector3.new(position.X, ctx.root.Position.Y, position.Z)
	if (flat - ctx.root.Position).Magnitude > 0.1 then
		ctx.root.CFrame = CFrame.lookAt(ctx.root.Position, flat)
	end
end

local function isStunned(character: Model): boolean
	local untilTime = character:GetAttribute("StunnedUntil")
	return typeof(untilTime) == "number" and untilTime > os.clock()
end

-- Holds him still for `duration`, giving up early (false) if he dies or gets hit: a hit cancels a
-- move while it's still forming.
local function channel(ctx: MoveContext, duration: number): boolean
	local stopAt = os.clock() + duration
	while os.clock() < stopAt do
		if not ctx.isActive() or isStunned(ctx.character) then
			return false
		end
		Movement.freeze(ctx.humanoid, 0.12)
		task.wait(0.05)
	end
	return ctx.isActive() and not isStunned(ctx.character)
end

local function headOf(ctx: MoveContext): BasePart?
	local head = ctx.character:FindFirstChild("Head")
	return if head and head:IsA("BasePart") then head else nil
end

local function eyePosition(ctx: MoveContext): Vector3
	local head = headOf(ctx)
	return if head then head.Position else ctx.root.Position + Vector3.new(0, 1.5, 0)
end

-- The ground under a point, or the point lowered to foot height if there's nothing under it.
local function groundBelow(position: Vector3, ignore: { Instance }): Vector3
	local hit = Hitbox.raycastMap(position + Vector3.new(0, 8, 0), Vector3.new(0, -80, 0), ignore)
	return if hit then hit.Position else position - Vector3.new(0, 3, 0)
end

-- A spot on the ground straight ahead, pulled in so it never ends up behind a wall.
local function aheadSpot(ctx: MoveContext, distance: number): Vector3
	local look = flatLook(ctx.root)
	local from = ctx.root.Position
	local wall = Hitbox.raycastMap(from, look * distance, ignoreList(ctx))
	local reach = if wall then math.max(wall.Distance - 2, 0) else distance
	return groundBelow(from + look * reach, ignoreList(ctx))
end

-- The enemy he's facing: inside a cone in front of him and in range (and, if `needsSight`, with no
-- wall in between). Closest to the middle of his view wins; distance breaks ties.
local function pickTarget(ctx: MoveContext, range: number, coneDegrees: number, needsSight: boolean): Model?
	local look = flatLook(ctx.root)
	local eye = eyePosition(ctx)
	local minDot = math.cos(math.rad(coneDegrees))
	local best: Model? = nil
	local bestScore = math.huge
	for _, model in Hitbox.sphere(ctx.root.Position, range, ignoreList(ctx)) do
		local offset = flatten(model:GetPivot().Position - ctx.root.Position)
		local distance = offset.Magnitude
		local dot = if distance > 1e-3 then offset.Unit:Dot(look) else 1
		if dot < minDot or (needsSight and not Hitbox.canSee(eye, model, ignoreList(ctx))) then
			continue
		end
		local score = (1 - dot) * range * 2 + distance
		if score < bestScore then
			best, bestScore = model, score
		end
	end
	return best
end

-- 1: Chidori: Lightning Assault ---------------------------------------------------------------------

local function chidori(ctx: MoveContext)
	local t = Tuning.Chidori
	local id = Vfx.newId()
	Animations.play(ctx.humanoid, animationFor(1))
	Vfx.play("Sasuke.Chidori", { id = id, caster = ctx.character, charge = t.Charge })
	if not channel(ctx, t.Charge) then
		Vfx.stop(id) -- snuffed out before it was ready
		return
	end

	-- The path is decided here: straight ahead, stopping short of walls and of the first enemy on it.
	local ignore = ignoreList(ctx)
	local direction = flatLook(ctx.root)
	local from = ctx.root.Position
	local distance = t.DashSpeed * t.MaxDashTime
	local wall = Hitbox.raycastMap(from, direction * (distance + 2), ignore)
	if wall then
		distance = math.max(wall.Distance - 2, 0)
	end
	local aimed, along = Hitbox.firstAlong(from, direction, distance + t.StopShort, t.HitWidth, ignore)
	if aimed then
		distance = math.clamp(along - t.StopShort, 0, distance)
	end
	local dashTime = math.max(distance / t.DashSpeed, 0.05)

	Vfx.play("Sasuke.ChidoriDash", { caster = ctx.character, time = dashTime, direction = direction })
	Movement.freeze(ctx.humanoid, dashTime + t.Recovery)
	if distance > 0.5 then
		Movement.dash(ctx.root, direction * t.DashSpeed, dashTime)
	end
	task.wait(dashTime)
	Movement.push(ctx.root, Vector3.zero, 0.06) -- brake, so he stops in front of them instead of sliding on
	if not ctx.isActive() then
		Vfx.stop(id)
		return
	end

	-- The thrust lands on whoever is still where the dash ends: they can sidestep it.
	local thrust = from + direction * (distance + t.StopShort)
	local victim = Hitbox.nearest(thrust, t.HitRadius, ignore)
	if not victim then
		Vfx.stop(id)
		task.wait(t.Recovery)
		return
	end
	local victimRoot = Hitbox.rootOf(victim)
	Vfx.play("Sasuke.ChidoriHit", {
		caster = ctx.character,
		target = victim,
		position = if victimRoot then victimRoot.Position else thrust,
		direction = direction,
	})
	Damage.deal(victim, t.Damage, { knockback = launch(direction, t.Knockback, t.Lift), stun = t.Stun })
	task.wait(t.Recovery)
end

-- 2: Fire Style: Phoenix Flower ----------------------------------------------------------------------

local function mouthOf(ctx: MoveContext): Vector3
	local head = headOf(ctx)
	if head then
		return (head.CFrame * CFrame.new(0, -0.25, -0.9)).Position
	end
	return (ctx.root.CFrame * CFrame.new(0, 1.3, -1.2)).Position
end

-- One fireball, flown on the server along the same path every client draws. It burns the first
-- character it reaches (once) or bursts on the first wall.
local function flyFireball(
	ctx: MoveContext,
	id: string,
	origin: Vector3,
	direction: Vector3,
	bend: number,
	rise: number
)
	local t = Tuning.PhoenixFlower
	local ignore = ignoreList(ctx)
	local start = os.clock()
	local position = origin
	while true do
		local elapsed = math.min(os.clock() - start, t.MaxFlightTime)
		local nextPosition = SasukeData.fireballPosition(origin, direction, bend, rise, elapsed)
		local step = nextPosition - position
		local wall = if step.Magnitude > 1e-3 then Hitbox.raycastMap(position, step, ignore) else nil
		local reached = if wall then wall.Position else nextPosition
		local victim = Hitbox.nearest(reached, t.HitRadius, ignore)
		if victim then
			local root = Hitbox.rootOf(victim)
			Vfx.play("Sasuke.FireballImpact", {
				id = id,
				position = if root then root.Position else reached,
				character = true,
			})
			Damage.deal(victim, t.Damage, { knockback = launch(direction, t.Knockback, 0.25), stun = t.Stun })
			return
		end
		if wall then
			Vfx.play("Sasuke.FireballImpact", { id = id, position = wall.Position, normal = wall.Normal })
			return
		end
		if elapsed >= t.MaxFlightTime then
			return -- burns out in the air; clients fade it on their own
		end
		position = nextPosition
		RunService.Heartbeat:Wait()
	end
end

local function phoenixFlower(ctx: MoveContext)
	local t = Tuning.PhoenixFlower
	Animations.play(ctx.humanoid, animationFor(2))
	Vfx.play("Sasuke.PhoenixFlower", { caster = ctx.character, signs = t.Signs, interval = t.Interval })
	if not channel(ctx, t.Signs) then
		return
	end
	-- He can walk again while he breathes the fireballs out; each one leaves where he's facing then.
	for i = 1, t.Count do
		if not ctx.isActive() or isStunned(ctx.character) then
			return
		end
		local yaw = math.rad((t.Spread[i] or 0) + (math.random() - 0.5) * 3)
		local direction = CFrame.fromAxisAngle(Vector3.yAxis, yaw):VectorToWorldSpace(flatLook(ctx.root))
		local bend = (t.Bend[i] or 0) * (0.8 + math.random() * 0.4)
		local rise = t.Rise[i] or 0
		local origin = mouthOf(ctx)
		local id = Vfx.newId()
		Vfx.play("Sasuke.Fireball", {
			id = id,
			caster = ctx.character,
			origin = origin,
			direction = direction,
			bend = bend,
			rise = rise,
		})
		task.spawn(flyFireball, ctx, id, origin, direction, bend, rise)
		task.wait(t.Interval)
	end
end

-- 3: Amaterasu: Black Flame Curse --------------------------------------------------------------------

local function setBurnAttribute(target: Model, burn: Burn)
	target:SetAttribute(BURN_ATTRIBUTE, workspace:GetServerTimeNow() + (burn.endsAt - os.clock()))
end

-- Sets a character on fire, or keeps its fire going. One fire per character: catching fire again
-- only refreshes it (it never stacks), and no fire outlives MaxBurnTime.
local function ignite(target: Model)
	local t = Tuning.Amaterasu
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local existing = burns[target]
	if existing then
		existing.endsAt = math.min(math.max(existing.endsAt, now + t.BurnTime), existing.startedAt + t.MaxBurnTime)
		setBurnAttribute(target, existing)
		return
	end

	local burn: Burn = { endsAt = now + t.BurnTime, startedAt = now }
	burns[target] = burn
	setBurnAttribute(target, burn)
	Vfx.play("Sasuke.Burn", { target = target })
	task.spawn(function()
		local nextTick = now + t.TickInterval
		while target.Parent and humanoid.Health > 0 and os.clock() < burn.endsAt do
			task.wait(math.max(nextTick - os.clock(), 0))
			nextTick += t.TickInterval
			if not target.Parent or humanoid.Health <= 0 or os.clock() > burn.endsAt + 0.05 then
				break
			end
			Damage.deal(target, t.TickDamage)
		end
		burns[target] = nil
		if target.Parent then
			target:SetAttribute(BURN_ATTRIBUTE, nil)
		end
	end)
end

-- The ground where the flames erupted keeps burning: anyone who walks into it catches fire.
local function burnPatch(caster: Model, center: Vector3)
	local t = Tuning.Amaterasu
	local stopAt = os.clock() + t.PatchTime
	while os.clock() < stopAt do
		task.wait(0.2)
		for _, victim in Hitbox.cylinder(center, t.PatchRadius, 5, { caster }) do
			ignite(victim)
		end
	end
end

local function amaterasu(ctx: MoveContext)
	local t = Tuning.Amaterasu
	local ignore = ignoreList(ctx)
	Animations.play(ctx.humanoid, animationFor(3))
	local target = pickTarget(ctx, t.Range, t.ConeAngle, true)
	local targetRoot = if target then Hitbox.rootOf(target) else nil
	if targetRoot then
		faceToward(ctx, targetRoot.Position)
	end
	Vfx.play("Sasuke.Amaterasu", { caster = ctx.character, target = target, cast = t.Cast, mark = t.Mark })
	if not channel(ctx, t.Cast) then
		return
	end

	-- Whoever he still sees (in range, no wall in between) is where the flames go.
	local function stillSeen(): boolean
		return target ~= nil
			and targetRoot ~= nil
			and targetRoot.Parent ~= nil
			and (targetRoot.Position - ctx.root.Position).Magnitude <= t.Range * 1.15
			and Hitbox.canSee(eyePosition(ctx), target, ignore)
	end
	local spot = if targetRoot and stillSeen()
		then groundBelow(targetRoot.Position, ignore)
		else aheadSpot(ctx, t.AheadDistance)
	Vfx.play("Sasuke.AmaterasuMark", {
		caster = ctx.character,
		position = spot,
		target = if stillSeen() then target else nil,
		time = t.Mark,
	})
	if not channel(ctx, t.Mark) then
		return
	end

	-- They erupt on the target if he can still see it; ducking behind a wall during the mark dodges.
	if targetRoot and stillSeen() then
		spot = groundBelow(targetRoot.Position, ignore)
	end
	Vfx.play("Sasuke.AmaterasuBurst", {
		caster = ctx.character,
		position = spot,
		radius = t.BurstRadius,
		patchRadius = t.PatchRadius,
		patchTime = t.PatchTime,
	})
	for _, victim in Hitbox.cylinder(spot, t.BurstRadius, 8, ignore) do
		Damage.deal(victim, t.BurstDamage, { stun = t.Stun })
		ignite(victim)
	end
	task.spawn(burnPatch, ctx.character, spot)
end

-- 4: Kirin: Heavenly Lightning Devastation (ult) -----------------------------------------------------

local function kirin(ctx: MoveContext)
	local t = Tuning.Kirin
	local ignore = ignoreList(ctx)
	Animations.play(ctx.humanoid, animationFor(4))
	-- The strike point is fixed right away, so the warning circle shows exactly where it will land.
	local target = pickTarget(ctx, t.LockRange, 70, false)
	local targetRoot = if target then Hitbox.rootOf(target) else nil
	local center = if targetRoot then groundBelow(targetRoot.Position, ignore) else aheadSpot(ctx, t.AheadDistance)
	faceToward(ctx, center)
	local id = Vfx.newId()
	Vfx.play("Sasuke.Kirin", {
		id = id,
		caster = ctx.character,
		position = center,
		radius = t.Radius,
		buildup = t.Buildup,
		telegraphAt = t.TelegraphAt,
		anticipation = t.Anticipation,
		skyTime = t.SkyTime,
	})
	-- Getting hit before the strike calls it off.
	if not channel(ctx, t.Buildup + t.Anticipation) then
		Vfx.stop(id)
		return
	end

	Vfx.play("Sasuke.KirinStrike", { caster = ctx.character, position = center, radius = t.Radius })
	Movement.freeze(ctx.humanoid, t.Recovery)
	-- One hit per person per strike, however much of them is inside the circle.
	for _, victim in Hitbox.cylinder(center, t.Radius, t.Height, ignore) do
		local away = flatten(victim:GetPivot().Position - center)
		local push = if away.Magnitude > 0.5 then away.Unit else flatLook(ctx.root)
		Damage.deal(victim, t.Damage, { knockback = launch(push, t.Knockback, t.Lift), stun = t.Stun })
	end
	task.wait(t.Recovery)
end

local moveset: CombatTypes.Moveset = {
	applyOutfit = Outfit.apply,
	moves = {
		[1] = chidori,
		[2] = phoenixFlower,
		[3] = amaterasu,
		[4] = kirin,
	},
}

return moveset
