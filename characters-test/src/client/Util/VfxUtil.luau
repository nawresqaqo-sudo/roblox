--!strict
-- Building blocks for client-side effects. Effects are only visible to this player, which keeps
-- them smooth; the server tells every client to play them (see Controllers/VfxController).
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

export type Payload = { [string]: any }
-- An effect function. Return a stop function if the server may end the effect early.
export type Handler = (payload: Payload) -> (() -> ())?

export type PartProps = {
	size: Vector3,
	color: Color3,
	material: Enum.Material?,
	transparency: number?,
	shape: Enum.PartType?,
	wedge: boolean?,
	cframe: CFrame?,
}

export type EmitterProps = {
	texture: string,
	color: ColorSequence,
	size: NumberSequence,
	lifetime: NumberRange,
	transparency: NumberSequence?,
	speed: NumberRange?,
	rate: number?, -- particles a second; 0 for bursts you Emit() yourself
	spread: Vector2?,
	acceleration: Vector3?,
	drag: number?,
	lightEmission: number?,
	brightness: number?,
	rotation: NumberRange?,
	rotSpeed: NumberRange?,
	zOffset: number?, -- higher draws in front of other emitters
	lockedToPart: boolean?,
	direction: Enum.NormalId?,
	shape: Enum.ParticleEmitterShape?,
	shapeInOut: Enum.ParticleEmitterShapeInOut?,
	orientation: Enum.ParticleOrientation?,
	squash: NumberSequence?,
}

local VfxUtil = {}

local folder: Folder? = nil

function VfxUtil.folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "LocalVfx"
	created.Parent = workspace
	folder = created
	return created
end

function VfxUtil.part(props: PartProps): BasePart
	local part: BasePart
	if props.wedge then
		part = Instance.new("WedgePart")
	else
		local block = Instance.new("Part")
		block.Shape = props.shape or Enum.PartType.Block
		part = block
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Size = props.size
	part.Color = props.color
	part.Material = props.material or Enum.Material.Neon
	part.Transparency = props.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.cframe then
		part.CFrame = props.cframe
	end
	part.Parent = VfxUtil.folder()
	return part
end

function VfxUtil.tween(
	instance: Instance,
	time: number,
	goals: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
): Tween
	local info = TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
	local tween = TweenService:Create(instance, info, goals)
	tween:Play()
	return tween
end

-- A ParticleEmitter that ignores scene lighting, so effects look the same at noon and at night.
function VfxUtil.emitter(parent: Instance, props: EmitterProps): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = props.texture
	emitter.Color = props.color
	emitter.Size = props.size
	emitter.Lifetime = props.lifetime
	emitter.Transparency = props.transparency or NumberSequence.new(0, 1)
	emitter.Speed = props.speed or NumberRange.new(0)
	emitter.Rate = props.rate or 0
	emitter.SpreadAngle = props.spread or Vector2.new(180, 180)
	emitter.Acceleration = props.acceleration or Vector3.zero
	emitter.Drag = props.drag or 0
	emitter.LightEmission = props.lightEmission or 0
	emitter.LightInfluence = 0
	emitter.Brightness = props.brightness or 1
	emitter.Rotation = props.rotation or NumberRange.new(0, 360)
	emitter.RotSpeed = props.rotSpeed or NumberRange.new(0)
	emitter.ZOffset = props.zOffset or 0
	emitter.LockedToPart = props.lockedToPart == true
	emitter.EmissionDirection = props.direction or Enum.NormalId.Top
	emitter.Shape = props.shape or Enum.ParticleEmitterShape.Box
	emitter.ShapeInOut = props.shapeInOut or Enum.ParticleEmitterShapeInOut.Outward
	emitter.Orientation = props.orientation or Enum.ParticleOrientation.FacingCamera
	if props.squash then
		emitter.Squash = props.squash
	end
	emitter.Parent = parent
	return emitter
end

-- Emits `count` particles once from `cframe` (filling `size` if given) and cleans up after them.
function VfxUtil.burst(cframe: CFrame, props: EmitterProps, count: number, size: Vector3?)
	local holder = VfxUtil.part({ size = size or Vector3.one * 0.2, color = Color3.new(1, 1, 1), transparency = 1 })
	holder.CFrame = cframe
	VfxUtil.emitter(holder, props):Emit(count)
	Debris:AddItem(holder, props.lifetime.Max + 0.3)
end

-- Fades parts out (optionally scaling them) and deletes them.
function VfxUtil.fadeOut(parts: { BasePart }, time: number, sizeMultiplier: number?)
	for _, part in parts do
		local goals: { [string]: any } = { Transparency = 1 }
		if sizeMultiplier then
			goals.Size = part.Size * sizeMultiplier
		end
		VfxUtil.tween(part, time, goals)
		Debris:AddItem(part, time + 0.05)
	end
end

-- Calls step(t) every frame until it returns false or `duration` passes, then onDone.
-- Returns a stop function that ends it early (safe to call more than once).
function VfxUtil.everyFrame(duration: number, step: (t: number) -> boolean, onDone: (() -> ())?): () -> ()
	local start = os.clock()
	local finished = false
	local connection: RBXScriptConnection? = nil

	local function stop()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		if onDone then
			onDone()
		end
	end

	local function tick(t: number): boolean
		local ok, keepGoing = pcall(step, t)
		if not ok then
			warn(`[Vfx] effect step errored: {keepGoing}`)
			return false
		end
		return keepGoing and t < duration
	end

	if not tick(0) then
		stop()
		return stop
	end
	connection = RunService.RenderStepped:Connect(function()
		if not tick(os.clock() - start) then
			stop()
		end
	end)
	return stop
end

function VfxUtil.bodyPart(model: Instance?, names: { string }): BasePart?
	if not model then
		return nil
	end
	for _, name in names do
		local part = model:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

-- Effects you build in a VFX plugin go in ReplicatedStorage > Assets > VFX, named after the effect
-- (e.g. "Rasengan"). If one exists, a copy is returned and used instead of the built-in parts.
function VfxUtil.asset(name: string): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("VFX")
	local template = library and library:FindFirstChild(name)
	if not template then
		return nil
	end

	local copy = template:Clone()
	local root: Instance = copy
	if copy:IsA("Attachment") then
		-- Attachments need a part to live in.
		local holder = VfxUtil.part({ size = Vector3.one * 0.1, color = Color3.new(1, 1, 1), transparency = 1 })
		copy.Parent = holder
		root = holder
	end
	for _, instance in root:GetDescendants() do
		if instance:IsA("BasePart") then
			instance.Anchored = true
			instance.CanCollide = false
			instance.CanQuery = false
			instance.CanTouch = false
		end
	end
	if root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
		root.CanQuery = false
		root.CanTouch = false
	end
	root.Parent = VfxUtil.folder()
	return root
end

function VfxUtil.pivot(instance: Instance, cframe: CFrame)
	if instance:IsA("PVInstance") then
		instance:PivotTo(cframe)
	end
end

-- Bursts every ParticleEmitter inside. Set an "EmitCount" attribute on an emitter to change its amount.
function VfxUtil.emit(root: Instance)
	for _, instance in root:GetDescendants() do
		if instance:IsA("ParticleEmitter") then
			local count = instance:GetAttribute("EmitCount")
			instance:Emit(if typeof(count) == "number" then count else 20)
		end
	end
end

-- Places a burst-style custom asset, emits it, and cleans it up. Returns false if there is no asset.
function VfxUtil.burstAsset(name: string, cframe: CFrame, lifetime: number): boolean
	local custom = VfxUtil.asset(name)
	if not custom then
		return false
	end
	VfxUtil.pivot(custom, cframe)
	VfxUtil.emit(custom)
	Debris:AddItem(custom, lifetime)
	return true
end

function VfxUtil.randomDirection(): Vector3
	local v = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5)
	if v.Magnitude < 1e-3 then
		return Vector3.yAxis
	end
	return v.Unit
end

local stopShake: (() -> ())? = nil

-- Shakes this player's camera.
function VfxUtil.shake(intensity: number, duration: number)
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if stopShake then
		stopShake()
	end
	stopShake = VfxUtil.everyFrame(duration, function(t)
		local strength = intensity * (1 - t / duration)
		humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
		return true
	end, function()
		humanoid.CameraOffset = Vector3.zero
	end)
end

return VfxUtil
