--!strict
-- Teen Naruto's moves on the server: timing, hitboxes and damage.
-- Visuals are in StarterPlayerScripts > Client > Vfx > Naruto. Numbers are in Shared.Characters.Naruto.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NarutoData = require(ReplicatedStorage.Shared.Characters.Naruto)
local Animations = require(script.Parent.Parent.Combat.Animations)
local Clones = require(script.Parent.Parent.Combat.Clones)
local CombatTypes = require(script.Parent.Parent.Combat.CombatTypes)
local Damage = require(script.Parent.Parent.Combat.Damage)
local Hitbox = require(script.Parent.Parent.Combat.Hitbox)
local Movement = require(script.Parent.Parent.Combat.Movement)
local Vfx = require(script.Parent.Parent.Combat.Vfx)
local Outfit = require(script.Outfit)

type MoveContext = CombatTypes.MoveContext

local Tuning = NarutoData.Tuning

local CHAKRA_BLUE = Color3.fromRGB(90, 180, 255)
local CLONE_ORANGE = Color3.fromRGB(255, 170, 60)
local DASH_HITBOX = Vector3.new(5, 6, 5)
local CLONE_OFFSETS = {
	CFrame.new(-4, 0, 1),
	CFrame.new(4, 0, 1),
	CFrame.new(0, 0, 4),
	CFrame.new(-6, 0, 4),
	CFrame.new(6, 0, 4),
}

local function animationFor(slot: number): string
	for _, move in NarutoData.Info.Moves do
		if move.Slot == slot then
			return move.AnimationId
		end
	end
	return ""
end

local function flatLook(part: BasePart): Vector3
	local look = part.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

local function ignoreList(ctx: MoveContext): { Instance }
	return { ctx.character, Clones.folder() }
end

local function launch(direction: Vector3, strength: number, lift: number): Vector3
	return direction * strength + Vector3.new(0, strength * lift, 0)
end

-- Calls step every frame for up to `duration` seconds. Stops early when step returns true or the caster dies.
local function eachFrame(ctx: MoveContext, duration: number, step: () -> boolean)
	local start = os.clock()
	while ctx.isActive() and os.clock() - start < duration do
		if step() then
			return
		end
		RunService.Heartbeat:Wait()
	end
end

-- 1: Rasengan --------------------------------------------------------------------------------------

local function rasengan(ctx: MoveContext)
	local t = Tuning.Rasengan
	Animations.play(ctx.humanoid, animationFor(1))
	local fx = Vfx.newId()
	Vfx.play("Naruto.Rasengan", {
		id = fx,
		caster = ctx.character,
		duration = t.Windup + t.DashTime + 0.15,
		scale = t.Scale,
	})
	Movement.freeze(ctx.humanoid, t.Windup)
	task.wait(t.Windup)
	if not ctx.isActive() then
		Vfx.stop(fx)
		return
	end

	local direction = flatLook(ctx.root)
	local stopDash = Movement.dash(ctx.root, direction * t.DashSpeed, t.DashTime)
	local ignore = ignoreList(ctx)
	eachFrame(ctx, t.DashTime, function()
		local target = Hitbox.inFront(ctx.root, DASH_HITBOX, ignore)[1]
		if not target then
			return false
		end
		stopDash()
		Vfx.stop(fx)
		Damage.deal(target, t.Damage, { knockback = launch(direction, t.Knockback, 0.35), stun = t.Stun })
		Vfx.play("Common.Impact", { position = target:GetPivot().Position, color = CHAKRA_BLUE, scale = 1.6 })
		Vfx.play("Common.Shake", { position = ctx.root.Position, intensity = 0.4, duration = 0.25 })
		return true
	end)
end

-- 2: Shadow Clone Jutsu ----------------------------------------------------------------------------

local function runClone(ctx: MoveContext, clone: Model, humanoid: Humanoid, target: Model?, index: number)
	local t = Tuning.ShadowClone
	local root = Hitbox.rootOf(clone)
	if not root then
		Clones.poof(clone)
		return
	end
	humanoid.WalkSpeed = t.RunSpeed
	task.wait(0.1 * index) -- stagger so they don't move in lockstep

	if not target then
		-- Nobody nearby: run forward and vanish.
		humanoid:MoveTo((root.CFrame * CFrame.new(0, 0, -25)).Position)
		task.wait(1.2)
		Clones.poof(clone)
		return
	end

	local deadline = os.clock() + t.Lifetime
	local punches = 0
	local nextPunch = 0
	while clone.Parent and ctx.isActive() and os.clock() < deadline and punches < t.PunchesEach do
		local targetHumanoid = target:FindFirstChildOfClass("Humanoid")
		local targetRoot = Hitbox.rootOf(target)
		if not target.Parent or not targetHumanoid or targetHumanoid.Health <= 0 or not targetRoot then
			break
		end

		local offset = targetRoot.Position - root.Position
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if flat.Magnitude > t.PunchRange then
			humanoid:MoveTo(targetRoot.Position - flat.Unit * (t.PunchRange * 0.6))
		else
			humanoid:MoveTo(root.Position)
			if os.clock() >= nextPunch then
				nextPunch = os.clock() + t.PunchInterval
				punches += 1
				local facing = if flat.Magnitude > 0.05 then flat.Unit else flatLook(root)
				root.CFrame = CFrame.lookAt(root.Position, root.Position + facing)
				Animations.play(humanoid, t.PunchAnimationId)
				Damage.deal(target, t.PunchDamage, { knockback = facing * 6, stun = 0.35 })
				Vfx.play("Common.Impact", { position = targetRoot.Position, color = CLONE_ORANGE, scale = 0.6 })
			end
		end
		task.wait(0.1)
	end
	Clones.poof(clone)
end

local function shadowClones(ctx: MoveContext)
	local t = Tuning.ShadowClone
	Animations.play(ctx.humanoid, animationFor(2))
	Movement.freeze(ctx.humanoid, t.SummonTime)

	local origin = ctx.root.CFrame
	local target = Hitbox.nearest(ctx.root.Position, t.SearchRange, ignoreList(ctx))
	for i = 1, t.Count do
		local cframe = origin * CLONE_OFFSETS[(i - 1) % #CLONE_OFFSETS + 1]
		local clone, cloneHumanoid = Clones.spawn(ctx.player, ctx.character, cframe)
		if clone and cloneHumanoid then
			Vfx.play("Common.Smoke", { position = cframe.Position, scale = 1.2 })
			task.spawn(runClone, ctx, clone, cloneHumanoid, target, i)
		end
	end
	task.wait(t.SummonTime)
end

-- 3: Double Rasengan -------------------------------------------------------------------------------

local function doubleRasengan(ctx: MoveContext)
	local t = Tuning.DoubleRasengan
	Animations.play(ctx.humanoid, animationFor(3))
	Movement.freeze(ctx.humanoid, t.Windup)

	local holdTime = t.Windup + t.DashTime + 0.15
	local casterFx = Vfx.newId()
	Vfx.play("Naruto.Rasengan", { id = casterFx, caster = ctx.character, duration = holdTime, scale = t.Scale })

	local cloneCFrame = ctx.root.CFrame * CFrame.new(3, 0, 0)
	local clone, cloneHumanoid = Clones.spawn(ctx.player, ctx.character, cloneCFrame)
	local cloneFx = Vfx.newId()
	if clone and cloneHumanoid then
		cloneHumanoid.WalkSpeed = 0
		Vfx.play("Common.Smoke", { position = cloneCFrame.Position, scale = 1.2 })
		Vfx.play("Naruto.Rasengan", { id = cloneFx, caster = clone, duration = holdTime, scale = t.Scale })
	end

	task.wait(t.Windup)
	if not ctx.isActive() then
		Vfx.stop(casterFx)
		if clone then
			Clones.poof(clone)
		end
		return
	end

	local direction = flatLook(ctx.root)
	local stopCaster = Movement.dash(ctx.root, direction * t.DashSpeed, t.DashTime)
	local cloneRoot = if clone then Hitbox.rootOf(clone) else nil
	local stopClone = if cloneRoot then Movement.dash(cloneRoot, direction * t.DashSpeed, t.DashTime) else nil
	local ignore = ignoreList(ctx)

	eachFrame(ctx, t.DashTime, function()
		local target = Hitbox.inFront(ctx.root, DASH_HITBOX, ignore)[1]
		if not target and cloneRoot then
			target = Hitbox.inFront(cloneRoot, DASH_HITBOX, ignore)[1]
		end
		if not target then
			return false
		end
		stopCaster()
		if stopClone then
			stopClone()
		end
		Vfx.stop(casterFx)
		Vfx.stop(cloneFx)
		for hit = 1, t.Hits do
			local last = hit == t.Hits
			Damage.deal(target, t.HitDamage, {
				knockback = if last then launch(direction, t.Knockback, 0.35) else nil,
				stun = t.Stun,
			})
			Vfx.play("Common.Impact", {
				position = target:GetPivot().Position,
				color = CHAKRA_BLUE,
				scale = if last then 2.2 else 1.4,
			})
			if not last then
				task.wait(0.12)
			end
		end
		Vfx.play("Common.Shake", { position = ctx.root.Position, intensity = 0.6, duration = 0.3 })
		return true
	end)

	task.wait(0.25)
	if clone then
		Clones.poof(clone)
	end
end

-- 4: Giant Rasengan (secondary ult) ----------------------------------------------------------------

local function giantRasengan(ctx: MoveContext)
	local t = Tuning.GiantRasengan
	Animations.play(ctx.humanoid, animationFor(4))
	Movement.freeze(ctx.humanoid, t.Charge)

	-- A clone stands beside the sphere, "helping" form it.
	local spherePosition = (ctx.root.CFrame * CFrame.new(0, 0, -(t.Scale * 0.5 + 1.5))).Position
	local clonePosition = (ctx.root.CFrame * CFrame.new(3, 0, -2)).Position
	local clone = Clones.spawn(ctx.player, ctx.character, CFrame.lookAt(clonePosition, spherePosition))
	if clone then
		Vfx.play("Common.Smoke", { position = clonePosition, scale = 1.2 })
	end

	local fx = Vfx.newId()
	Vfx.play("Naruto.GiantRasengan", {
		id = fx,
		caster = ctx.character,
		charge = t.Charge,
		duration = t.Charge + t.DashTime + 0.2,
		scale = t.Scale,
	})
	task.wait(t.Charge)
	if clone then
		Clones.poof(clone)
	end
	if not ctx.isActive() then
		Vfx.stop(fx)
		return
	end

	local direction = flatLook(ctx.root)
	local stopDash = Movement.dash(ctx.root, direction * t.DashSpeed, t.DashTime)
	local size = Vector3.one * t.HitboxSize
	local ignore = ignoreList(ctx)
	eachFrame(ctx, t.DashTime, function()
		local targets = Hitbox.inFront(ctx.root, size, ignore)
		if #targets == 0 then
			return false
		end
		stopDash()
		Vfx.stop(fx)
		for _, target in targets do
			Damage.deal(target, t.Damage, { knockback = launch(direction, t.Knockback, 0.4), stun = t.Stun })
		end
		local center = ctx.root.Position + direction * (t.Scale * 0.5 + 1.5)
		Vfx.play("Common.Impact", { position = center, color = CHAKRA_BLUE, scale = 4 })
		Vfx.play("Common.Shake", { position = center, intensity = 1, duration = 0.5 })
		return true
	end)
end

-- 5: Rasenshuriken (big ult with cutscene) ---------------------------------------------------------

local function explode(ctx: MoveContext, position: Vector3, direction: Vector3)
	local t = Tuning.Rasenshuriken
	Vfx.play("Naruto.RasenshurikenExplode", {
		position = position,
		radius = t.BlastRadius,
		duration = t.BlastTicks * t.TickInterval + 0.3,
	})
	Vfx.play("Common.Shake", { position = position, intensity = 1.2, duration = 0.8 })

	local ignore = ignoreList(ctx)
	for _ = 1, t.BlastTicks do
		for _, target in Hitbox.sphere(position, t.BlastRadius, ignore) do
			Damage.deal(target, t.TickDamage, { stun = t.TickInterval + 0.15 })
			local root = Hitbox.rootOf(target)
			if root then
				-- Drag them toward the middle so the whole blast connects.
				Movement.push(root, (position - root.Position) * 3, 0.1)
			end
		end
		task.wait(t.TickInterval)
	end

	for _, target in Hitbox.sphere(position, t.BlastRadius, ignore) do
		local root = Hitbox.rootOf(target)
		local away = if root then root.Position - position else direction
		local flat = Vector3.new(away.X, 0, away.Z)
		local push = if flat.Magnitude > 0.1 then flat.Unit else direction
		Damage.deal(target, t.FinalDamage, { knockback = launch(push, t.Knockback, 0.5), stun = 1.2 })
	end
end

local function flyRasenshuriken(ctx: MoveContext, projectileId: string, origin: Vector3, direction: Vector3)
	local t = Tuning.Rasenshuriken
	local ignore = ignoreList(ctx)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore

	local start = os.clock()
	local position = origin
	while true do
		local elapsed = os.clock() - start
		local nextPosition = origin + direction * t.Speed * math.min(elapsed, t.MaxFlightTime)
		local step = nextPosition - position
		local wall = if step.Magnitude > 0 then workspace:Raycast(position, step, rayParams) else nil
		if wall then
			position = wall.Position
			break
		end
		position = nextPosition
		if #Hitbox.sphere(position, t.HitRadius, ignore) > 0 or elapsed >= t.MaxFlightTime then
			break
		end
		RunService.Heartbeat:Wait()
	end

	Vfx.stop(projectileId)
	explode(ctx, position, direction)
end

local function rasenshuriken(ctx: MoveContext)
	local t = Tuning.Rasenshuriken
	Animations.play(ctx.humanoid, animationFor(5))
	local release = Movement.anchor(ctx.root, t.Charge + 1)
	local chargeFx = Vfx.newId()
	-- The caster's client also plays the camera cutscene when it gets this effect.
	Vfx.play("Naruto.RasenshurikenCharge", { id = chargeFx, caster = ctx.character, duration = t.Charge })
	task.wait(t.Charge)
	release()
	Vfx.stop(chargeFx)
	if not ctx.isActive() then
		return
	end

	local direction = flatLook(ctx.root)
	local origin = (ctx.root.CFrame * CFrame.new(0, 1.5, -3)).Position
	local projectileId = Vfx.newId()
	Vfx.play("Naruto.RasenshurikenThrow", {
		id = projectileId,
		origin = origin,
		direction = direction,
		speed = t.Speed,
		maxTime = t.MaxFlightTime,
	})
	task.spawn(flyRasenshuriken, ctx, projectileId, origin, direction)
end

local moveset: CombatTypes.Moveset = {
	applyOutfit = Outfit.apply,
	moves = {
		[1] = rasengan,
		[2] = shadowClones,
		[3] = doubleRasengan,
		[4] = giantRasengan,
		[5] = rasenshuriken,
	},
}

return moveset
