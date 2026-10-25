--!strict
-- Zoro's three swords, built and moved on every client: Wado Ichimonji (white), Sandai Kitetsu (red)
-- and Enma (purple). They hang at his left hip, or come out into his hands and mouth depending on the
-- "Stance" attribute the server sets during moves. Drawn blades leave glossy swing trails.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Rig = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Rig"))
local MoveAnimator = require(script.Parent.MoveAnimator)

export type SwordKind = "Wado" | "Kitetsu" | "Enma"

type Sword = {
	model: Model,
	blade: BasePart,
	edge: BasePart,
	trail: Trail,
	from: CFrame?,
	changedAt: number,
}

type SwordSet = {
	character: Model,
	folder: Folder,
	swords: { [SwordKind]: Sword },
	scabbards: { [SwordKind]: BasePart },
	stance: string,
	haki: boolean,
}

local KINDS: { SwordKind } = { "Wado", "Kitetsu", "Enma" }
local STYLE: { [SwordKind]: { handle: Color3, scabbard: Color3, guard: Color3 } } = {
	Wado = {
		handle = Color3.fromRGB(240, 240, 245),
		scabbard = Color3.fromRGB(232, 232, 236),
		guard = Color3.fromRGB(210, 175, 70),
	},
	Kitetsu = {
		handle = Color3.fromRGB(175, 30, 38),
		scabbard = Color3.fromRGB(110, 18, 24),
		guard = Color3.fromRGB(60, 60, 64),
	},
	Enma = {
		handle = Color3.fromRGB(80, 34, 120),
		scabbard = Color3.fromRGB(26, 20, 32),
		guard = Color3.fromRGB(195, 160, 70),
	},
}
local BLADE_COLOR = Color3.fromRGB(215, 222, 232)
local EDGE_COLOR = Color3.fromRGB(235, 250, 255)
local HAKI_BLADE = Color3.fromRGB(16, 14, 20)
local HAKI_EDGE = Color3.fromRGB(175, 70, 255)
local BLADE_CENTER = -2.2 -- blades run along -Z from the grip
local DRAW_TIME = 0.12

-- Where each sword hangs, relative to the hips: handles forward-up, blades back-down.
local SHEATHED: { [SwordKind]: CFrame } = {
	Wado = CFrame.new(-1.05, 0, -0.1)
		* CFrame.lookAt(Vector3.zero, Vector3.new(-0.05, -0.42, 0.9))
		* CFrame.new(0, 0, 0.6),
	Kitetsu = CFrame.new(-1.15, -0.12, 0.05)
		* CFrame.lookAt(Vector3.zero, Vector3.new(-0.1, -0.5, 0.86))
		* CFrame.new(0, 0, 0.6),
	Enma = CFrame.new(-0.98, 0.12, -0.2)
		* CFrame.lookAt(Vector3.zero, Vector3.new(0, -0.35, 0.94))
		* CFrame.new(0, 0, 0.6),
}
local GRIP = CFrame.new(0, -0.15, 0) -- from the middle of a fist to a sword's grip
local MOUTH = CFrame.new(0, -0.32, -0.6) * CFrame.Angles(0, -math.pi / 2, 0)

-- Arms forward holding the blades out, used whenever swords are drawn and no move is playing.
local READY_THREE: Rig.Pose = {
	RightShoulder = CFrame.Angles(0.55, 0, 0.25),
	RightElbow = CFrame.Angles(0.8, 0, 0),
	LeftShoulder = CFrame.Angles(0.55, 0, -0.25),
	LeftElbow = CFrame.Angles(0.8, 0, 0),
}
local READY_ONE: Rig.Pose = {
	RightShoulder = CFrame.Angles(0.5, 0, 0.3),
	RightElbow = CFrame.Angles(0.7, 0, 0),
}

local Swords = {}

local sets: { [Model]: SwordSet } = {}

local function piece(
	model: Model,
	shape: Enum.PartType,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Parent = model
	return part
end

-- Builds one katana around its grip point (blade along -Z). Used for Zoro's swords and Asura's extras.
function Swords.build(kind: SwordKind): (Model, BasePart, BasePart)
	local style = STYLE[kind]
	local model = Instance.new("Model")
	model.Name = kind
	local grip =
		piece(model, Enum.PartType.Block, Vector3.one * 0.1, CFrame.identity, style.handle, Enum.Material.Fabric)
	grip.Transparency = 1
	model.PrimaryPart = grip
	piece(
		model,
		Enum.PartType.Block,
		Vector3.new(0.24, 0.24, 1.1),
		CFrame.new(0, 0, 0.25),
		style.handle,
		Enum.Material.Fabric
	)
	piece(
		model,
		Enum.PartType.Cylinder,
		Vector3.new(0.08, 0.6, 0.6),
		CFrame.new(0, 0, -0.34) * CFrame.Angles(0, math.pi / 2, 0),
		style.guard,
		Enum.Material.Metal
	)
	local blade = piece(
		model,
		Enum.PartType.Block,
		Vector3.new(0.07, 0.22, 3.6),
		CFrame.new(0, 0, BLADE_CENTER),
		BLADE_COLOR,
		Enum.Material.Metal
	)
	blade.Reflectance = 0.25
	-- A thin glowing line along the cutting edge: the glossy anime glint.
	local edge = piece(
		model,
		Enum.PartType.Block,
		Vector3.new(0.075, 0.05, 3.6),
		CFrame.new(0, -0.11, BLADE_CENTER),
		EDGE_COLOR,
		Enum.Material.Neon
	)
	edge.Transparency = 0.3
	return model, blade, edge
end

local function makeTrail(blade: BasePart): Trail
	local base = Instance.new("Attachment")
	base.Position = Vector3.new(0, 0, 1.6)
	base.Parent = blade
	local tip = Instance.new("Attachment")
	tip.Position = Vector3.new(0, 0, -1.8)
	tip.Parent = blade
	local trail = Instance.new("Trail")
	trail.Attachment0 = base
	trail.Attachment1 = tip
	trail.Lifetime = 0.16
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 255, 170))
	trail.Transparency = NumberSequence.new(0.15, 1)
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Enabled = false
	trail.Parent = blade
	return trail
end

local function buildSet(character: Model): SwordSet
	local folder = Instance.new("Folder")
	folder.Name = character.Name .. "Swords"
	folder.Parent = workspace

	local swords: { [SwordKind]: Sword } = {}
	local scabbards: { [SwordKind]: BasePart } = {}
	for _, kind: SwordKind in KINDS do
		local model, blade, edge = Swords.build(kind)
		model.Parent = folder
		swords[kind] =
			{ model = model, blade = blade, edge = edge, trail = makeTrail(blade), from = nil, changedAt = 0 }
		local scabbardHolder = Instance.new("Model")
		scabbardHolder.Parent = folder
		scabbards[kind] = piece(
			scabbardHolder,
			Enum.PartType.Block,
			Vector3.new(0.3, 0.36, 3.85),
			CFrame.identity,
			STYLE[kind].scabbard,
			Enum.Material.SmoothPlastic
		)
	end
	return {
		character = character,
		folder = folder,
		swords = swords,
		scabbards = scabbards,
		stance = "Sheathed",
		haki = false,
	}
end

local function destroySet(set: SwordSet)
	set.folder:Destroy()
	MoveAnimator.setIdlePose(set.character, nil)
	sets[set.character] = nil
end

-- Where a sword should be for the current stance, and whether that counts as drawn.
local function swordTarget(set: SwordSet, kind: SwordKind, hip: CFrame): (CFrame?, boolean)
	local character = set.character
	local stance = set.stance
	local drawn = stance == "Three" or stance == "Asura"
	if kind == "Enma" and (drawn or stance == "One") then
		local hand = Rig.hand(character, "Right")
		return if hand then hand * GRIP else nil, true
	elseif kind == "Kitetsu" and drawn then
		local hand = Rig.hand(character, "Left")
		return if hand then hand * GRIP else nil, true
	elseif kind == "Wado" and drawn then
		local head = Rig.part(character, { "Head" })
		return if head then head.CFrame * MOUTH else nil, true
	end
	return hip * SHEATHED[kind], false
end

local function updateSet(set: SwordSet)
	local character = set.character
	local stance = character:GetAttribute("Stance")
	local stanceName = if typeof(stance) == "string" then stance else "Sheathed"
	local now = os.clock()
	if stanceName ~= set.stance then
		set.stance = stanceName
		for _, sword in set.swords do
			sword.from = sword.model:GetPivot()
			sword.changedAt = now
		end
		local drawn = stanceName == "Three" or stanceName == "Asura"
		MoveAnimator.setIdlePose(
			character,
			if drawn then READY_THREE elseif stanceName == "One" then READY_ONE else nil
		)
	end

	local hip = Rig.hip(character)
	if not hip then
		return
	end
	for kind: SwordKind, sword in set.swords do
		set.scabbards[kind].CFrame = hip * SHEATHED[kind] * CFrame.new(0, 0, BLADE_CENTER)
		local target, isDrawn = swordTarget(set, kind, hip)
		if not target then
			continue
		end
		local alpha = math.clamp((now - sword.changedAt) / DRAW_TIME, 0, 1)
		local from = sword.from
		local cframe = if from and alpha < 1 then from:Lerp(target, alpha) else target
		sword.model:PivotTo(cframe)
		sword.trail.Enabled = isDrawn
	end
end

local function isZoro(player: Player): boolean
	return player:GetAttribute("Character") == "Zoro"
end

local function refresh()
	local wanted: { [Model]: boolean } = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character and character.Parent and isZoro(player) then
			wanted[character] = true
			if not sets[character] then
				sets[character] = buildSet(character)
			end
		end
	end
	for character, set in sets do
		if not wanted[character] then
			destroySet(set)
		else
			updateSet(set)
		end
	end
end

-- Haki-coats a character's blades: glossy black with a purple edge. Used during the ultimates.
function Swords.setHaki(character: Model, on: boolean)
	local set = sets[character]
	if not set then
		return
	end
	set.haki = on
	for _, sword in set.swords do
		Swords.coat(sword.blade, sword.edge, on)
	end
end

function Swords.coat(blade: BasePart, edge: BasePart, on: boolean)
	blade.Color = if on then HAKI_BLADE else BLADE_COLOR
	blade.Material = if on then Enum.Material.Glass else Enum.Material.Metal
	blade.Reflectance = if on then 0.45 else 0.25
	edge.Color = if on then HAKI_EDGE else EDGE_COLOR
end

-- Where a sword's grip is right now (nil if the character has no swords).
function Swords.gripCFrame(character: Model, kind: SwordKind): CFrame?
	local set = sets[character]
	return if set then set.swords[kind].model:GetPivot() else nil
end

Swords.GRIP = GRIP

function Swords.start()
	RunService.RenderStepped:Connect(refresh)
end

return Swords
