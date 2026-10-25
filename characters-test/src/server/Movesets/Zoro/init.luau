--!strict
-- Zoro's moves on the server: timing, movement, hitboxes and damage.
-- Visuals are in StarterPlayerScripts > Client > Vfx > Zoro. Numbers are in Shared.Characters.Zoro.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ZoroData = require(ReplicatedStorage.Shared.Characters.Zoro)
local Animations = require(script.Parent.Parent.Combat.Animations)
local CombatTypes = require(script.Parent.Parent.Combat.CombatTypes)
local Damage = require(script.Parent.Parent.Combat.Damage)
local Hitbox = require(script.Parent.Parent.Combat.Hitbox)
local Movement = require(script.Parent.Parent.Combat.Movement)
local Vfx = require(script.Parent.Parent.Combat.Vfx)
local Outfit = require(script.Outfit)

type MoveContext = CombatTypes.MoveContext
type Stance = "Sheathed" | "One" | "Three" | "Asura"

local Tuning = ZoroData.Tuning

local sheatheTokens: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

local function animationFor(slot: number): string
	for _, move in ZoroData.Info.Moves do
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

-- Draws the swords (clients read the "Stance" attribute) and cancels any pending sheathe.
local function draw(ctx: MoveContext, stance: Stance)
	sheatheTokens[ctx.character] = (sheatheTokens[ctx.character] or 0) + 1
	ctx.character:SetAttribute("Stance", stance)
end

local function sheatheLater(ctx: MoveContext)
	local character = ctx.character
	local token = (sheatheTokens[character] or 0) + 1
	sheatheTokens[character] = token
	task.delay(Tuning.StanceLinger, function()
		if sheatheTokens[character] == token then
			character:SetAttribute("Stance", "Sheathed")
		end
	end)
end

-- Wraps a move so the swords come out for it and go back a little after.
local function withSwords(stance: Stance, move: (MoveContext) -> ()): (MoveContext) -> ()
	return function(ctx: MoveContext)
		draw(ctx, stance)
		move(ctx)
		sheatheLater(ctx)
	end
end

-- Everything in a box stretched along a dash from `from` to `to`.
local function alongPath(from: Vector3, to: Vector3, width: number, ignore: { Instance }): { Model }
	local offset = to - from
	if offset.Magnitude < 0.5 then
		return Hitbox.sphere(to, width / 2, ignore)
	end
	local center = (from + to) / 2
	return Hitbox.box(CFrame.lookAt(center, to), Vector3.new(width, 8, offset.Magnitude + 4), ignore)
end

-- The nearest enemy in range, preferring ones in front.
local function frontTarget(ctx: MoveContext, range: number): Model?
	local look = flatLook(ctx.root)
	local best: Model? = nil
	local bestScore = math.huge
	for _, model in Hitbox.sphere(ctx.root.Position, range, ignoreList(ctx)) do
		local offset = flatten(model:GetPivot().Position - ctx.root.Position)
		local inFront = offset.Magnitude < 1e-3 or offset.Unit:Dot(look) > 0.2
		local score = offset.Magnitude + (if inFront then 0 else range)
		if score < bestScore then
			best, bestScore = model, score
		end
	end
	return best
end

-- Holds a target completely still (for ults). Returns a function that lets go early.
local function pin(target: Model, duration: number): () -> ()
	Damage.stun(target, duration)
	local root = Hitbox.rootOf(target)
	if not root then
		return function() end
	end
	return Movement.anchor(root, duration)
end

local function faceToward(ctx: MoveContext, position: Vector3)
	local flat = Vector3.new(position.X, ctx.root.Position.Y, position.Z)
	if (flat - ctx.root.Position).Magnitude > 0.1 then
		ctx.root.CFrame = CFrame.lookAt(ctx.root.Position, flat)
	end
end

local function addUnique(list: { Model }, seen: { [Model]: boolean }, models: { Model })
	for _, model in models do
		if not seen[model] then
			seen[model] = true
			table.insert(list, model)
		end
	end
end

local function positionsOf(models: { Model }): { Vector3 }
	local positions = {}
	for _, model in models do
		table.insert(positions, model:GetPivot().Position)
	end
	return positions
end

-- 1: Three Sword Style: Onigiri ----------------------------------------------------------------------

local function onigiri(ctx: MoveContext)
	local t = Tuning.Onigiri
	Animations.play(ctx.humanoid, animationFor(1))
	Vfx.play("Zoro.Onigiri", { caster = ctx.character, windup = t.Windup, dashTime = t.DashTime })
	Movement.freeze(ctx.humanoid, t.Windup + t.DashTime)
	task.wait(t.Windup)
	if not ctx.isActive() then
		return
	end

	local direction = flatLook(ctx.root)
	local from = ctx.root.Position
	local ignore = ignoreList(ctx)
	local victims: { Model } = {}
	local seen: { [Model]: boolean } = {}
	Movement.dash(ctx.root, direction * t.DashSpeed, t.DashTime)
	local start = os.clock()
	while os.clock() - start < t.DashTime and ctx.isActive() do
		-- Everyone Zoro passes through freezes on the spot; the cut lands after he's gone by.
		local passed = Hitbox.inFront(ctx.root, Vector3.new(t.HitWidth, 8, 6), ignore)
		for _, target in passed do
			if not seen[target] then
				Damage.stun(target, t.CutDelay + 0.2)
			end
		end
		addUnique(victims, seen, passed)
		RunService.Heartbeat:Wait()
	end
	addUnique(victims, seen, alongPath(from, ctx.root.Position, t.HitWidth, ignore))

	task.wait(t.CutDelay)
	Vfx.play("Zoro.OnigiriCut", { caster = ctx.character, positions = positionsOf(victims), direction = direction })
	for _, target in victims do
		Damage.deal(target, t.Damage, { knockback = launch(direction, t.Knockback, 0.4), stun = t.Stun })
	end
end

-- 2: One Sword Style: Bird Dance ---------------------------------------------------------------------

local function flyBirdDance(ctx: MoveContext, id: string, origin: Vector3, direction: Vector3)
	local t = Tuning.BirdDance
	local ignore = ignoreList(ctx)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
	local hit: { [Model]: boolean } = {}
	local start = os.clock()
	local position = origin
	while true do
		local elapsed = os.clock() - start
		local nextPosition = origin + direction * t.Speed * math.min(elapsed, t.MaxFlightTime)
		local step = nextPosition - position
		local wall = if step.Magnitude > 0 then workspace:Raycast(position, step, rayParams) else nil
		local wallModel = if wall then wall.Instance:FindFirstAncestorOfClass("Model") else nil
		if wall and not (wallModel and wallModel:FindFirstChildOfClass("Humanoid")) then
			break -- it cuts through people but carves into walls and stops
		end
		position = nextPosition
		-- It cuts through everyone in its path.
		for _, target in Hitbox.sphere(position, t.HitRadius, ignore) do
			if not hit[target] then
				hit[target] = true
				Damage.deal(target, t.Damage, { knockback = launch(direction, t.Knockback, 0.3), stun = t.Stun })
				Vfx.play("Common.Impact", {
					position = target:GetPivot().Position,
					color = Color3.fromRGB(255, 70, 90),
					scale = 1.4,
				})
			end
		end
		if elapsed >= t.MaxFlightTime then
			break
		end
		RunService.Heartbeat:Wait()
	end
	Vfx.stop(id)
end

local function birdDance(ctx: MoveContext)
	local t = Tuning.BirdDance
	Animations.play(ctx.humanoid, animationFor(2))
	Vfx.play("Zoro.BirdDance", { caster = ctx.character, windup = t.Windup })
	Movement.freeze(ctx.humanoid, t.Windup + 0.2)
	task.wait(t.Windup)
	if not ctx.isActive() then
		return
	end
	local direction = flatLook(ctx.root)
	local origin = (ctx.root.CFrame * CFrame.new(0, 0.5, -3)).Position
	local id = Vfx.newId()
	Vfx.play("Zoro.BirdDanceSlash", {
		id = id,
		origin = origin,
		direction = direction,
		speed = t.Speed,
		maxTime = t.MaxFlightTime,
	})
	task.spawn(flyBirdDance, ctx, id, origin, direction)
end

-- 3: Three Sword Style: Black Rope Dragon Twister ----------------------------------------------------

local function dragonTwister(ctx: MoveContext)
	local t = Tuning.DragonTwister
	Animations.play(ctx.humanoid, animationFor(3))
	Vfx.play("Zoro.DragonTwister", {
		caster = ctx.character,
		windup = t.Windup,
		duration = t.Duration,
		radius = t.Radius,
	})
	Movement.freeze(ctx.humanoid, t.Windup + t.Duration)
	task.wait(t.Windup)

	local ignore = ignoreList(ctx)
	local interval = t.Duration / t.Ticks
	for _ = 1, t.Ticks do
		if not ctx.isActive() then
			return
		end
		for _, target in Hitbox.sphere(ctx.root.Position, t.Radius, ignore) do
			Damage.deal(target, t.TickDamage, { stun = interval + 0.25 })
			local root = Hitbox.rootOf(target)
			if root then
				-- Drag them into the twister and lift them off the ground.
				local toward = flatten(ctx.root.Position - root.Position)
				Movement.push(root, toward * 2.5 + Vector3.new(0, 14, 0), interval)
			end
		end
		task.wait(interval)
	end

	for _, target in Hitbox.sphere(ctx.root.Position, t.Radius + 2, ignore) do
		local away = flatten(target:GetPivot().Position - ctx.root.Position)
		local outward = if away.Magnitude > 0.1 then away.Unit * 25 else Vector3.zero
		Damage.deal(target, t.FinalDamage, { knockback = Vector3.new(0, t.Launch, 0) + outward, stun = t.Stun })
	end
	Vfx.play("Common.Shake", { position = ctx.root.Position, intensity = 0.7, duration = 0.4 })
end

-- 4: King of Hell Three Sword Style: 103 Mercies Dragon Damnation (ult) ------------------------------

local function dragonDamnation(ctx: MoveContext)
	local t = Tuning.DragonDamnation
	Animations.play(ctx.humanoid, animationFor(4))
	local target = frontTarget(ctx, t.LockRange)
	local targetRoot = if target then Hitbox.rootOf(target) else nil
	local releaseTarget = if target then pin(target, t.Charge + t.RiseTime + t.Hover + t.MaxDiveTime + 0.5) else nil
	local releaseSelf = Movement.anchor(ctx.root, t.Charge + 0.5)
	if targetRoot then
		faceToward(ctx, targetRoot.Position)
	end
	Vfx.play("Zoro.DragonDamnation", {
		caster = ctx.character,
		target = target,
		charge = t.Charge,
		rise = t.RiseTime,
		hover = t.Hover,
		skyTime = t.SkyTime,
	})
	task.wait(t.Charge)
	releaseSelf()
	if not ctx.isActive() then
		if releaseTarget then
			releaseTarget()
		end
		return
	end

	-- Up into the sky, hang there while the dragon forms, then dive.
	Movement.push(ctx.root, Vector3.new(0, t.RiseSpeed, 0), t.RiseTime)
	task.wait(t.RiseTime)
	Movement.push(ctx.root, Vector3.zero, t.Hover)
	task.wait(t.Hover)
	if not ctx.isActive() then
		if releaseTarget then
			releaseTarget()
		end
		return
	end

	local aim: Vector3
	if targetRoot and targetRoot.Parent then
		local toTarget = flatten(targetRoot.Position - ctx.root.Position)
		local back = if toTarget.Magnitude > 0.1 then toTarget.Unit * 3 else Vector3.zero
		aim = targetRoot.Position - back
	else
		-- No target: slam the ground a little way ahead.
		local ahead = ctx.root.Position + flatLook(ctx.root) * 25
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = ignoreList(ctx)
		local ground = workspace:Raycast(ahead, Vector3.new(0, -200, 0), params)
		aim = if ground then ground.Position + Vector3.new(0, 3, 0) else ahead - Vector3.new(0, 45, 0)
	end
	local offset = aim - ctx.root.Position
	local diveTime = math.clamp(offset.Magnitude / t.DiveSpeed, 0.1, t.MaxDiveTime)
	Vfx.play("Zoro.DragonDamnationDive", { caster = ctx.character, to = aim, time = diveTime })
	Movement.push(ctx.root, offset.Unit * (offset.Magnitude / diveTime), diveTime)
	task.wait(diveTime)
	Movement.push(ctx.root, Vector3.zero, 0.15)

	if releaseTarget then
		releaseTarget()
	end
	local direction = if flatten(offset).Magnitude > 0.1 then flatten(offset).Unit else flatLook(ctx.root)
	Animations.play(ctx.humanoid, t.LandAnimationId)
	Vfx.play("Zoro.DragonDamnationImpact", { caster = ctx.character, position = aim, direction = direction })
	for _, victim in Hitbox.sphere(aim, t.Radius, ignoreList(ctx)) do
		local away = flatten(victim:GetPivot().Position - aim)
		local push = if away.Magnitude > 0.5 then away.Unit else direction
		Damage.deal(victim, t.Damage, { knockback = launch(push, t.Knockback, 0.5), stun = t.Stun })
	end
end

-- 5: Nine Sword Style Asura: Blades Drawn, Dance of the Dead (big ult) -------------------------------

local function asura(ctx: MoveContext)
	local t = Tuning.Asura
	Animations.play(ctx.humanoid, animationFor(5))
	local target = frontTarget(ctx, t.LockRange)
	local targetRoot = if target then Hitbox.rootOf(target) else nil
	local releaseTarget = if target then pin(target, t.Charge + t.DashTime + t.CutDelay + 0.6) else nil
	local releaseSelf = Movement.anchor(ctx.root, t.Charge + 0.5)
	if targetRoot then
		faceToward(ctx, targetRoot.Position)
	end
	Vfx.play("Zoro.Asura", {
		caster = ctx.character,
		target = target,
		charge = t.Charge,
		dashTime = t.DashTime,
		cutDelay = t.CutDelay,
	})
	task.wait(t.Charge)
	releaseSelf()
	if not ctx.isActive() then
		if releaseTarget then
			releaseTarget()
		end
		return
	end

	-- Dash straight through, ending up just past the target.
	local direction = flatLook(ctx.root)
	local from = ctx.root.Position
	local dashTime = t.DashTime
	if targetRoot then
		local distance = flatten(targetRoot.Position - from).Magnitude + 8
		dashTime = math.clamp(distance / t.DashSpeed, 0.08, 0.4)
	end
	Vfx.play("Zoro.AsuraDash", { caster = ctx.character, time = dashTime })
	Movement.dash(ctx.root, direction * t.DashSpeed, dashTime)
	task.wait(dashTime)

	local victims: { Model } = {}
	local seen: { [Model]: boolean } = {}
	addUnique(victims, seen, alongPath(from, ctx.root.Position + direction * 2, t.HitWidth, ignoreList(ctx)))
	if target and target.Parent then
		addUnique(victims, seen, { target })
	end
	for _, victim in victims do
		Damage.stun(victim, t.CutDelay + 0.3)
	end

	Vfx.play("Zoro.AsuraCut", {
		caster = ctx.character,
		positions = positionsOf(victims),
		direction = direction,
		slashes = t.Slashes,
		delay = t.CutDelay,
	})
	local interval = t.CutDelay / t.Slashes
	for _ = 1, t.Slashes do
		for _, victim in victims do
			Damage.deal(victim, t.SlashDamage, { stun = interval + 0.3 })
		end
		task.wait(interval)
	end
	if releaseTarget then
		releaseTarget()
	end
	for _, victim in victims do
		Damage.deal(victim, t.FinalDamage, { knockback = launch(direction, t.Knockback, 0.45), stun = t.Stun })
	end
	Vfx.play("Common.Shake", { position = ctx.root.Position, intensity = 1, duration = 0.6 })
end

local moveset: CombatTypes.Moveset = {
	applyOutfit = Outfit.apply,
	moves = {
		[1] = withSwords("Three", onigiri),
		[2] = withSwords("One", birdDance),
		[3] = withSwords("Three", dragonTwister),
		[4] = withSwords("Three", dragonDamnation),
		[5] = withSwords("Asura", asura),
	},
}

return moveset
