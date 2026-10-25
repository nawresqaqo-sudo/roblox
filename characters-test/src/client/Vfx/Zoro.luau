--!strict
-- Zoro's moves on screen: the animations, the anime-style effects and the ultimate cutscenes.
-- Each function runs on every client when the server starts that part of a move.
-- Colors: green for his normal slashes, crimson + purple for King of Hell / Conqueror's Haki.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Client = script.Parent.Parent
local Util = Client:WaitForChild("Util")
local AnimeFx = require(Util:WaitForChild("AnimeFx"))
local Cutscene = require(Util:WaitForChild("Cutscene"))
local Rig = require(Util:WaitForChild("Rig"))
local VfxUtil = require(Util:WaitForChild("VfxUtil"))
local Controllers = Client:WaitForChild("Controllers")
local MoveAnimator = require(Controllers:WaitForChild("MoveAnimator"))
local Swords = require(Controllers:WaitForChild("Swords"))
local Clips = require(Client:WaitForChild("Animations"):WaitForChild("Zoro"))
local ZoroData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Characters"):WaitForChild("Zoro"))

local GREEN = Color3.fromRGB(90, 255, 160)
local MINT = Color3.fromRGB(200, 255, 225)
local CRIMSON = Color3.fromRGB(255, 40, 70)
local PURPLE = Color3.fromRGB(150, 60, 255)
local BLACK = Color3.fromRGB(14, 12, 18)
local SHADOW = Color3.fromRGB(24, 70, 46)
local STONE = Color3.fromRGB(95, 90, 88)
local WHITE = Color3.new(1, 1, 1)
local NEAR = 120 -- impact frames and big shakes only for players this close
local SKY_RANGE = 300 -- the sky goes dark for players this close

local Zoro: { [string]: VfxUtil.Handler } = {}

type Dragon = {
	mode: "Rise" | "Coil" | "Dive",
	diveDirection: Vector3,
	destroy: () -> (),
}

local dragons: { [Model]: Dragon } = {}

-- Helpers -------------------------------------------------------------------------------------------

local function casterOf(payload: VfxUtil.Payload): (Model?, BasePart?)
	local caster = payload.caster
	if typeof(caster) ~= "Instance" or not caster:IsA("Model") then
		return nil, nil
	end
	return caster, Rig.part(caster, { "HumanoidRootPart" })
end

local function isLocal(model: Model?): boolean
	return model ~= nil and model == Players.LocalPlayer.Character
end

local function nearCamera(position: Vector3, range: number): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil and (camera.Focus.Position - position).Magnitude < range
end

-- Plays the coded clip unless a real animation id was set for that move.
local function animate(caster: Model, slot: number, clip: MoveAnimator.Clip)
	for _, move in ZoroData.Info.Moves do
		if move.Slot == slot and move.AnimationId ~= "" then
			return
		end
	end
	MoveAnimator.play(caster, clip)
end

local function feet(root: BasePart): Vector3
	return root.Position - Vector3.new(0, 2.7, 0)
end

-- A cframe looking along `direction`, with Y as the normal: for rings standing up across a cut.
local function across(position: Vector3, direction: Vector3): CFrame
	return CFrame.lookAt(position, position + direction) * CFrame.Angles(-math.pi / 2, 0, 0)
end

-- A camera shot following a part: camera and look-at points are offsets in the part's space.
local function shot(root: BasePart, cameraOffset: Vector3, lookOffset: Vector3): () -> CFrame
	return function()
		local cf = root.CFrame
		return CFrame.lookAt(cf:PointToWorldSpace(cameraOffset), cf:PointToWorldSpace(lookOffset))
	end
end

-- 1: Onigiri -----------------------------------------------------------------------------------------

function Zoro.Onigiri(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local windup = payload.windup :: number
	local dashTime = payload.dashTime :: number
	animate(character, 1, Clips.Onigiri)

	-- A glint across the crossed blades just before he goes.
	task.delay(windup * 0.55, function()
		if rootPart.Parent then
			local front = rootPart.CFrame * CFrame.new(0, 0.8, -1.4)
			AnimeFx.flash(front.Position, GREEN, 3, 0.18)
			AnimeFx.slash(
				front * CFrame.Angles(0, 0, math.rad(45)),
				1.6,
				{ color = GREEN, duration = 0.2, width = 0.15 }
			)
		end
	end)
	task.delay(windup, function()
		if not rootPart.Parent then
			return
		end
		local from = rootPart.Position
		AnimeFx.shockwave(CFrame.new(feet(rootPart)), GREEN, 12, 0.35)
		for i = 0, 3 do
			task.delay(i * dashTime / 4, function()
				if character.Parent then
					AnimeFx.afterimage(character, GREEN, 0.3, 0.55)
				end
			end)
		end
		task.delay(dashTime, function()
			if rootPart.Parent then
				AnimeFx.streak(from, rootPart.Position, GREEN, 1.4, 0.45)
			end
		end)
		if isLocal(character) then
			AnimeFx.speedLines(dashTime + 0.25)
		end
	end)
	return nil
end

-- The delayed cut: three blades crossing on everyone he passed through.
function Zoro.OnigiriCut(payload: VfxUtil.Payload): (() -> ())?
	local caster = casterOf(payload)
	local positions = payload.positions :: { Vector3 }
	local direction = payload.direction :: Vector3
	for _, position in positions do
		local face = CFrame.lookAt(position, position + direction)
		for _, angle in { -0.65, 0, 0.65 } do
			AnimeFx.slash(face * CFrame.Angles(0, 0, angle) * CFrame.new(0, -2.5, 0), 4.5, {
				color = GREEN,
				duration = 0.4,
				width = 0.6,
			})
		end
		AnimeFx.flash(position, GREEN, 7, 0.3)
		AnimeFx.shockwave(across(position, direction), MINT, 14, 0.35)
	end
	local first = positions[1]
	if first and (isLocal(caster) or nearCamera(first, 40)) then
		AnimeFx.impactFrame(0.8)
		VfxUtil.shake(0.6, 0.3)
	end
	return nil
end

-- 2: Bird Dance --------------------------------------------------------------------------------------

function Zoro.BirdDance(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local windup = payload.windup :: number
	animate(character, 2, Clips.BirdDance)

	-- Conqueror's Haki crackling along Enma while he winds up.
	for i = 1, 5 do
		task.delay(i * windup / 6, function()
			local grip = Swords.gripCFrame(character, "Enma")
			if grip then
				local tip = (grip * CFrame.new(0, 0, -3.8)).Position
				AnimeFx.lightning(grip.Position, tip + VfxUtil.randomDirection() * 2, CRIMSON, 0.25, 0.12)
			end
		end)
	end
	task.delay(windup, function()
		if rootPart.Parent then
			local front = rootPart.CFrame * CFrame.new(0, 0.5, -2.5)
			AnimeFx.slash(
				CFrame.fromMatrix(front.Position, front.RightVector, front.LookVector),
				6,
				{ color = CRIMSON, duration = 0.3, width = 0.8 }
			)
			AnimeFx.flash(front.Position, CRIMSON, 5, 0.2)
		end
	end)
	return nil
end

-- The flying slash itself. The server stops it (by id) when it's done.
function Zoro.BirdDanceSlash(payload: VfxUtil.Payload): (() -> ())?
	local origin = payload.origin :: Vector3
	local direction = payload.direction :: Vector3
	local speed = payload.speed :: number
	local maxTime = payload.maxTime :: number
	local stopSlash = AnimeFx.flyingSlash(origin, direction, speed, maxTime, 7, { color = CRIMSON, width = 1.3 })
	local stopCrackle = VfxUtil.everyFrame(maxTime, function(t)
		if math.random() < 0.5 then
			local center = origin + direction * speed * t
			AnimeFx.lightning(
				center + VfxUtil.randomDirection() * 4,
				center + VfxUtil.randomDirection() * 5,
				CRIMSON,
				0.25,
				0.1
			)
		end
		return true
	end)
	return function()
		stopSlash()
		stopCrackle()
	end
end

-- 3: Black Rope Dragon Twister -----------------------------------------------------------------------

function Zoro.DragonTwister(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local windup = payload.windup :: number
	local duration = payload.duration :: number
	local radius = payload.radius :: number
	animate(character, 3, Clips.DragonTwister)

	task.delay(windup, function()
		if not rootPart.Parent then
			return
		end
		AnimeFx.aura(rootPart, BLACK, GREEN, duration, 3)
		-- Haki-black and green slashes whipping around him in a spiral.
		VfxUtil.everyFrame(duration, function()
			local center = rootPart.Position
			for _ = 1, 2 do
				local angle = math.random() * math.pi * 2
				local distance = 3 + math.random() * (radius - 4)
				local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
				local spot = center + outward * distance + Vector3.new(0, math.random() * 9 - 2, 0)
				local tangent = Vector3.new(-outward.Z, 0.25, outward.X).Unit
				local tilt = math.random() * math.pi
				local normal = (outward * math.cos(tilt) + Vector3.yAxis * math.sin(tilt))
				normal = (normal - tangent * normal:Dot(tangent)).Unit
				AnimeFx.slash(CFrame.fromMatrix(spot, tangent, normal), 2.5 + math.random() * 2, {
					color = GREEN,
					dark = math.random() < 0.6,
					duration = 0.25,
					width = 0.5,
				})
			end
			return true
		end)
		-- Wind rings climbing the twister.
		for i = 0, 5 do
			task.delay(i * duration / 6, function()
				if rootPart.Parent then
					AnimeFx.shockwave(CFrame.new(feet(rootPart) + Vector3.new(0, i * 1.7, 0)), GREEN, radius * 1.6, 0.4)
				end
			end)
		end
	end)

	-- Everyone gets thrown up out of the top.
	task.delay(windup + duration, function()
		if not rootPart.Parent then
			return
		end
		local center = rootPart.Position
		AnimeFx.flash(center + Vector3.new(0, 3, 0), GREEN, 14, 0.35)
		AnimeFx.shockwave(CFrame.new(feet(rootPart)), MINT, radius * 2.5, 0.5)
		for _ = 1, 6 do
			local offset = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * radius
			local from = feet(rootPart) + offset
			AnimeFx.streak(from, from + Vector3.new(0, 25 + math.random() * 10, 0), GREEN, 0.8, 0.4)
		end
		if nearCamera(center, 50) then
			VfxUtil.shake(0.6, 0.35)
		end
	end)
	return nil
end

-- 4: King of Hell Three Sword Style: 103 Mercies Dragon Damnation ------------------------------------

-- A serpent dragon of Conqueror's flames: a chain of glossy crimson orbs with purple cores, horns and
-- glowing eyes. It spirals up with Zoro, coils around him in the sky, then dives ahead of him.
local function spawnDragon(root: BasePart): Dragon
	local SEGMENTS = 26
	local SPACING = 1.6
	local segments: { { outer: BasePart, inner: BasePart } } = {}
	for i = 1, SEGMENTS do
		local size = 4.4 * (1 - (i - 1) / SEGMENTS * 0.8)
		local outer = VfxUtil.part({
			size = Vector3.one * size,
			color = CRIMSON,
			shape = Enum.PartType.Ball,
			material = Enum.Material.ForceField,
		})
		local inner = VfxUtil.part({
			size = Vector3.one * size * 0.6,
			color = PURPLE,
			shape = Enum.PartType.Ball,
			transparency = 0.15,
		})
		segments[i] = { outer = outer, inner = inner }
		if i % 5 == 1 then
			AnimeFx.aura(outer, CRIMSON, PURPLE, 12, size * 0.6)
		end
	end
	local horns = {
		VfxUtil.part({ size = Vector3.new(0.45, 0.45, 3.2), color = BLACK, material = Enum.Material.Glass }),
		VfxUtil.part({ size = Vector3.new(0.45, 0.45, 3.2), color = BLACK, material = Enum.Material.Glass }),
	}
	local eyes = {
		VfxUtil.part({ size = Vector3.one * 0.75, color = Color3.fromRGB(255, 235, 140), shape = Enum.PartType.Ball }),
		VfxUtil.part({ size = Vector3.one * 0.75, color = Color3.fromRGB(255, 235, 140), shape = Enum.PartType.Ball }),
	}

	local history: { Vector3 } = {}
	local dragon: Dragon = { mode = "Rise", diveDirection = Vector3.new(0, -1, 0), destroy = function() end }
	dragon.destroy = VfxUtil.everyFrame(12, function(t)
		if not root.Parent then
			return false
		end
		local center = root.Position
		local head: Vector3
		if dragon.mode == "Dive" then
			head = center + dragon.diveDirection * 6
		else
			local theta = t * 5.5
			local orbit = if dragon.mode == "Rise" then 4 + t * 6 else 10
			head = center + Vector3.new(math.cos(theta) * orbit, math.sin(theta * 1.3) * 3 + 2, math.sin(theta) * orbit)
		end
		table.insert(history, 1, head)
		if #history > 400 then
			table.remove(history)
		end

		-- Lay the body along the path the head has taken, one segment every SPACING studs.
		local index, travelled = 1, 0
		for i, segment in segments do
			local needed = (i - 1) * SPACING
			while index < #history do
				local step = (history[index] - history[index + 1]).Magnitude
				if travelled + step >= needed then
					break
				end
				travelled += step
				index += 1
			end
			local point = history[index]
			segment.outer.CFrame = CFrame.new(point)
			segment.inner.CFrame = CFrame.new(point)
		end

		local behind = history[math.min(4, #history)]
		local heading = history[1] - behind
		local look = if heading.Magnitude > 0.05 then heading.Unit else Vector3.new(0, 0, -1)
		local headFrame = CFrame.lookAt(history[1], history[1] + look)
		for side = 1, 2 do
			local x = if side == 1 then -1.1 else 1.1
			horns[side].CFrame = headFrame * CFrame.new(x, 1.3, 1.3) * CFrame.Angles(math.rad(35), 0, 0)
			eyes[side].CFrame = headFrame * CFrame.new(x * 0.8, 0.6, -1.5)
		end
		return true
	end, function()
		local parts: { BasePart } = {}
		for _, segment in segments do
			table.insert(parts, segment.outer)
			table.insert(parts, segment.inner)
		end
		for _, part in horns do
			table.insert(parts, part)
		end
		for _, part in eyes do
			table.insert(parts, part)
		end
		VfxUtil.fadeOut(parts, 0.25, 1.4)
	end)
	return dragon
end

local function playDamnationCutscene(root: BasePart, charge: number, rise: number, hover: number)
	local groundSpot = root.CFrame:PointToWorldSpace(Vector3.new(7, -2, -11))
	local lookUp = function()
		return CFrame.lookAt(groundSpot, root.Position)
	end
	Cutscene.play({
		-- Close on his face as Enma drains his haki.
		{
			duration = charge * 0.45,
			from = shot(root, Vector3.new(0, 1.2, -4.2), Vector3.new(0, 1.6, 0)),
			to = shot(root, Vector3.new(0, 1.1, -3.1), Vector3.new(0, 1.6, 0)),
			fov = 45,
		},
		-- Low orbit as the red lightning starts falling.
		{
			duration = charge * 0.55,
			from = shot(root, Vector3.new(-9, -1.5, -7), Vector3.new(0, 2, 0)),
			to = shot(root, Vector3.new(9, -1.5, -7), Vector3.new(0, 2, 0)),
			fov = 65,
		},
		-- From the ground, watching him leap into the black sky.
		{ duration = rise, from = lookUp, to = lookUp, fov = 70 },
		-- Above and behind him while the dragon coils, looking down at the target.
		{
			duration = hover,
			from = shot(root, Vector3.new(0, 8, 16), Vector3.new(0, -6, -20)),
			to = shot(root, Vector3.new(0, 10, 12), Vector3.new(0, -10, -20)),
			fov = 75,
		},
	}, "KING OF HELL: 103 MERCIES DRAGON DAMNATION")
end

function Zoro.DragonDamnation(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local charge = payload.charge :: number
	local rise = payload.rise :: number
	local hover = payload.hover :: number
	local skyTime = payload.skyTime :: number
	local total = charge + rise + hover + 1.2
	local torso = Rig.part(character, { "UpperTorso", "Torso" }) or rootPart
	animate(character, 4, Clips.DragonDamnation)

	-- King of Hell: Enma draws out all of his haki. Black glossy blades, purple flames, red outline.
	Swords.setHaki(character, true)
	task.delay(total + 0.8, function()
		Swords.setHaki(character, false)
	end)
	AnimeFx.aura(torso, PURPLE, CRIMSON, total, 3)
	AnimeFx.outline(character, CRIMSON, total)

	-- The sky goes black and red lightning comes down everywhere.
	if nearCamera(rootPart.Position, SKY_RANGE) then
		AnimeFx.darkSky(skyTime, Color3.fromRGB(255, 150, 150))
		AnimeFx.screenFlash(Color3.new(0, 0, 0), 0.4)
	end
	VfxUtil.everyFrame(skyTime - 0.5, function()
		if not rootPart.Parent then
			return false
		end
		if math.random() < 0.35 then
			local angle = math.random() * math.pi * 2
			local distance = 15 + math.random() * 80
			local ground = feet(rootPart) + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
			local sky = ground
				+ Vector3.new((math.random() - 0.5) * 30, 90 + math.random() * 40, (math.random() - 0.5) * 30)
			AnimeFx.lightning(sky, ground, CRIMSON, 0.9, 0.18)
		end
		if math.random() < 0.3 then
			local from = torso.Position
			AnimeFx.lightning(from, from + VfxUtil.randomDirection() * (4 + math.random() * 4), CRIMSON, 0.3, 0.1)
		end
		return true
	end)
	for i = 0, 2 do
		task.delay(i * charge / 3, function()
			if rootPart.Parent then
				AnimeFx.shockwave(CFrame.new(feet(rootPart)), CRIMSON, 18 + i * 6, 0.5)
			end
		end)
	end

	-- He springs into the sky and the dragon is born around him.
	task.delay(charge, function()
		if not rootPart.Parent then
			return
		end
		AnimeFx.flash(feet(rootPart), CRIMSON, 12, 0.3)
		AnimeFx.shockwave(CFrame.new(feet(rootPart)), WHITE, 30, 0.5)
		AnimeFx.debris(feet(rootPart), 10, STONE, 40)
		dragons[character] = spawnDragon(rootPart)
	end)
	task.delay(charge + rise, function()
		local dragon = dragons[character]
		if dragon then
			dragon.mode = "Coil"
		end
	end)
	-- Safety net: never leave a dragon behind if the dive never comes.
	task.delay(total + 2, function()
		local dragon = dragons[character]
		if dragon then
			dragons[character] = nil
			dragon.destroy()
		end
	end)

	if isLocal(character) then
		playDamnationCutscene(rootPart, charge, rise, hover)
	end
	return nil
end

function Zoro.DragonDamnationDive(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local to = payload.to :: Vector3
	local time = payload.time :: number
	local offset = to - rootPart.Position
	local dragon = dragons[character]
	if dragon and offset.Magnitude > 0.1 then
		dragon.mode = "Dive"
		dragon.diveDirection = offset.Unit
	end
	for i = 0, 4 do
		task.delay(i * time / 5, function()
			if character.Parent then
				AnimeFx.afterimage(character, CRIMSON, 0.3, 0.5)
			end
		end)
	end
	AnimeFx.streak(rootPart.Position, to, CRIMSON, 2.5, time + 0.3)
	if isLocal(character) then
		AnimeFx.speedLines(time + 0.2, Color3.fromRGB(255, 200, 200))
	end
	return nil
end

-- The landing: three giant blades crossing, a blinding flash, a crater and lightning bursting out.
function Zoro.DragonDamnationImpact(payload: VfxUtil.Payload): (() -> ())?
	local caster = casterOf(payload)
	local position = payload.position :: Vector3
	local direction = payload.direction :: Vector3
	if caster then
		local dragon = dragons[caster]
		if dragon then
			dragons[caster] = nil
			dragon.destroy()
		end
		MoveAnimator.play(caster, Clips.DragonDamnationLand)
	end

	local ground = position - Vector3.new(0, 2.7, 0)
	local face = CFrame.lookAt(position, position + direction)
	AnimeFx.flash(position, CRIMSON, 34, 0.5)
	AnimeFx.flash(position, WHITE, 18, 0.25)
	for _, angle in { -0.8, 0, 0.8 } do
		AnimeFx.slash(face * CFrame.Angles(0, 0, angle) * CFrame.new(0, -9, 0), 16, {
			color = CRIMSON,
			duration = 0.7,
			width = 2.4,
			grow = 1.25,
		})
	end
	AnimeFx.slash(CFrame.fromMatrix(position, face.RightVector, face.LookVector), 18, {
		color = PURPLE,
		duration = 0.6,
		width = 2,
		grow = 1.3,
	})
	AnimeFx.shockwave(CFrame.new(ground), CRIMSON, 70, 0.7)
	AnimeFx.shockwave(CFrame.new(ground + Vector3.new(0, 0.3, 0)), WHITE, 45, 0.5)
	AnimeFx.shockwave(across(position, direction), PURPLE, 40, 0.5)
	AnimeFx.debris(ground, 26, STONE, 60)
	for i = 1, 10 do
		local angle = i / 10 * math.pi * 2
		local outward = Vector3.new(math.cos(angle) * 25, math.random() * 18, math.sin(angle) * 25)
		AnimeFx.lightning(position, position + outward, CRIMSON, 0.7, 0.3)
	end

	local crater = VfxUtil.part({
		size = Vector3.new(0.3, 22, 22),
		color = Color3.fromRGB(38, 34, 34),
		shape = Enum.PartType.Cylinder,
		material = Enum.Material.Slate,
		cframe = CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
	})
	task.delay(4, function()
		VfxUtil.fadeOut({ crater }, 1)
	end)

	if nearCamera(position, NEAR) then
		AnimeFx.impactFrame(1.4)
		VfxUtil.shake(1.2, 0.7)
	end
	return nil
end

-- 5: Nine Sword Style Asura: Blades Drawn, Dance of the Dead -----------------------------------------

-- Asura form on Zoro himself: two ghost heads and four ghost arms, each extra hand holding another
-- sword. Nine swords in total. The ghost limbs follow his real limbs, fanned out around the joints.
local function asuraForm(character: Model, duration: number)
	local joints = Rig.findJoints(character)
	type Ghost = { part: BasePart, source: BasePart, joint: string, rotation: CFrame }
	type GhostSword = { model: Model, hand: BasePart, isArm: boolean, joint: string, rotation: CFrame }
	local ghosts: { Ghost } = {}
	local swords: { GhostSword } = {}

	local function ghostOf(source: BasePart): BasePart?
		local ok, copy = pcall(source.Clone, source)
		if not ok or not copy or not copy:IsA("BasePart") then
			return nil
		end
		copy:ClearAllChildren()
		copy.Anchored = true
		copy.CanCollide = false
		copy.CanQuery = false
		copy.CanTouch = false
		copy.CastShadow = false
		copy.Material = Enum.Material.ForceField
		copy.Color = GREEN
		copy.Parent = VfxUtil.folder()
		return copy
	end

	local head = Rig.part(character, { "Head" })
	if head and joints.Neck then
		for _, sign in { 1, -1 } do
			local ghost = ghostOf(head)
			if ghost then
				table.insert(ghosts, {
					part = ghost,
					source = head,
					joint = "Neck",
					rotation = CFrame.Angles(0, sign * 0.5, sign * 0.85),
				})
			end
		end
	end

	local kinds: { Swords.SwordKind } = { "Enma", "Kitetsu", "Wado" }
	for _, side in { "Right", "Left" } do
		local jointName = side .. "Shoulder"
		local sign = if side == "Right" then 1 else -1
		local hand = Rig.part(character, { side .. "Hand" })
		local isArm = false
		if not hand then
			hand = Rig.part(character, { side .. " Arm" })
			isArm = true
		end
		for n, spread in { 0.55, 1.1 } do
			local rotation = CFrame.Angles(spread * 0.4, 0, sign * spread)
			for _, source in Rig.armParts(character, side :: any) do
				local ghost = ghostOf(source)
				if ghost then
					table.insert(ghosts, { part = ghost, source = source, joint = jointName, rotation = rotation })
				end
			end
			if hand then
				local model, blade, edge = Swords.build(kinds[(n + (if side == "Right" then 0 else 1)) % 3 + 1])
				Swords.coat(blade, edge, true)
				model.Parent = VfxUtil.folder()
				table.insert(
					swords,
					{ model = model, hand = hand, isArm = isArm, joint = jointName, rotation = rotation }
				)
			end
		end
	end

	VfxUtil.everyFrame(duration, function()
		for _, ghost in ghosts do
			local joint = joints[ghost.joint]
			local pivot = if joint then Rig.pivot(joint) else nil
			if pivot then
				ghost.part.CFrame = pivot * ghost.rotation * pivot:Inverse() * ghost.source.CFrame
			end
		end
		for _, sword in swords do
			local joint = joints[sword.joint]
			local pivot = if joint then Rig.pivot(joint) else nil
			if pivot then
				local handFrame = if sword.isArm
					then sword.hand.CFrame * CFrame.new(0, -sword.hand.Size.Y / 2, 0)
					else sword.hand.CFrame
				sword.model:PivotTo(pivot * sword.rotation * pivot:Inverse() * handFrame * Swords.GRIP)
			end
		end
		return true
	end, function()
		local parts: { BasePart } = {}
		for _, ghost in ghosts do
			table.insert(parts, ghost.part)
		end
		VfxUtil.fadeOut(parts, 0.3)
		for _, sword in swords do
			sword.model:Destroy()
		end
	end)
end

-- The demon behind him: a giant shadow with three heads and six arms holding glowing blades,
-- rising out of the ground.
local function asuraDemon(root: BasePart, duration: number)
	type Piece = { part: BasePart, offset: CFrame, transparency: number }
	local pieces: { Piece } = {}
	local function add(
		size: Vector3,
		offset: CFrame,
		color: Color3,
		material: Enum.Material,
		shape: Enum.PartType?,
		transparency: number?
	)
		local part = VfxUtil.part({
			size = size,
			color = color,
			material = material,
			shape = shape,
			transparency = transparency,
		})
		table.insert(pieces, { part = part, offset = offset, transparency = transparency or 0 })
	end

	local force = Enum.Material.ForceField
	add(Vector3.new(7, 8, 3.5), CFrame.identity, SHADOW, force)
	add(Vector3.new(5, 4, 2.8), CFrame.new(0, -5.5, 0), SHADOW, force)
	for _, yaw in { -0.7, 0, 0.7 } do
		local headFrame = CFrame.new(math.sin(yaw) * 3.2, 6, 0) * CFrame.Angles(0, -yaw, 0)
		add(Vector3.one * 3.4, headFrame, SHADOW, force, Enum.PartType.Ball)
		for _, x in { -0.7, 0.7 } do
			add(
				Vector3.one * 0.6,
				headFrame * CFrame.new(x, 0.3, -1.5),
				Color3.fromRGB(255, 240, 200),
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
		end
		add(Vector3.new(0.5, 2.2, 0.5), headFrame * CFrame.new(0, 2, 0.3), BLACK, Enum.Material.Glass)
	end
	for _, arm in
		{
			{ x = 3.2, angle = -0.5 },
			{ x = 3.2, angle = -1.2 },
			{ x = 3.2, angle = -1.9 },
			{ x = -3.2, angle = 0.5 },
			{ x = -3.2, angle = 1.2 },
			{ x = -3.2, angle = 1.9 },
		}
	do
		local shoulder = CFrame.new(arm.x, 2.5, 0) * CFrame.Angles(0, 0, arm.angle)
		add(Vector3.new(1.4, 8, 1.4), shoulder * CFrame.new(0, 4, 0), SHADOW, force)
		local hand = shoulder * CFrame.new(0, 8, 0)
		add(Vector3.new(0.35, 1.2, 12), hand * CFrame.new(0, 0, -6), MINT, Enum.Material.Neon, nil, 0.1)
		add(Vector3.new(0.6, 1.8, 12.5), hand * CFrame.new(0, 0, -6), GREEN, force)
	end

	VfxUtil.everyFrame(duration, function(t)
		local rise = math.min(t / 0.5, 1)
		local fade = math.clamp((t - (duration - 0.3)) / 0.3, 0, 1)
		local base = root.CFrame * CFrame.new(0, 4 - (1 - rise) * 10, 6) * CFrame.Angles(0, math.sin(t * 3) * 0.05, 0)
		for _, piece in pieces do
			piece.part.CFrame = base * piece.offset
			piece.part.Transparency = math.max(piece.transparency, fade)
		end
		return true
	end, function()
		for _, piece in pieces do
			piece.part:Destroy()
		end
	end)
end

local function playAsuraCutscene(root: BasePart, charge: number)
	Cutscene.play({
		-- Behind him as the demon rises.
		{
			duration = charge * 0.35,
			from = shot(root, Vector3.new(3, 0, 9), Vector3.new(0, 5, -2)),
			to = shot(root, Vector3.new(2, -1, 7), Vector3.new(0, 7, 0)),
			fov = 70,
		},
		-- His face, with the two ghost heads beside it.
		{
			duration = charge * 0.3,
			from = shot(root, Vector3.new(0, 1.5, -5), Vector3.new(0, 1.6, 0)),
			to = shot(root, Vector3.new(0, 1.6, -3.6), Vector3.new(0, 1.6, 0)),
			fov = 50,
		},
		-- Wide: Zoro, six arms, nine swords, the demon over him.
		{
			duration = charge * 0.35,
			from = shot(root, Vector3.new(-12, 2, -4), Vector3.new(0, 3, 0)),
			to = shot(root, Vector3.new(-10, 1, -10), Vector3.new(0, 3, 0)),
			fov = 65,
		},
	}, "NINE SWORD STYLE ASURA: DANCE OF THE DEAD")
end

function Zoro.Asura(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local charge = payload.charge :: number
	local dashTime = payload.dashTime :: number
	local cutDelay = payload.cutDelay :: number
	local total = charge + dashTime + cutDelay + 0.6
	local torso = Rig.part(character, { "UpperTorso", "Torso" }) or rootPart
	animate(character, 5, Clips.Asura)

	Swords.setHaki(character, true)
	task.delay(total + 0.5, function()
		Swords.setHaki(character, false)
	end)
	asuraForm(character, total)
	asuraDemon(rootPart, charge + 0.3)
	AnimeFx.aura(torso, BLACK, GREEN, total, 3.2)
	AnimeFx.outline(character, GREEN, total)
	if nearCamera(rootPart.Position, SKY_RANGE) then
		AnimeFx.darkSky(charge + 1.6, Color3.fromRGB(180, 255, 210), Color3.fromRGB(16, 70, 40))
	end
	for i = 0, 3 do
		task.delay(i * charge / 4, function()
			if rootPart.Parent then
				AnimeFx.shockwave(CFrame.new(feet(rootPart)), GREEN, 16 + i * 4, 0.6)
			end
		end)
	end

	if isLocal(character) then
		playAsuraCutscene(rootPart, charge)
	end
	return nil
end

function Zoro.AsuraDash(payload: VfxUtil.Payload): (() -> ())?
	local caster, root = casterOf(payload)
	if not caster or not root then
		return nil
	end
	local character: Model, rootPart: BasePart = caster, root
	local time = payload.time :: number
	local from = rootPart.Position
	for i = 0, 4 do
		task.delay(i * time / 5, function()
			if character.Parent then
				AnimeFx.afterimage(character, GREEN, 0.35, 0.45)
			end
		end)
	end
	task.delay(time, function()
		if rootPart.Parent then
			AnimeFx.streak(from, rootPart.Position, GREEN, 3, 0.7)
		end
	end)
	if isLocal(character) then
		AnimeFx.speedLines(time + 0.3)
	end
	return nil
end

-- Nine cuts appear on the target one after another in a wheel, then everything bursts.
function Zoro.AsuraCut(payload: VfxUtil.Payload): (() -> ())?
	local caster = casterOf(payload)
	local positions = payload.positions :: { Vector3 }
	local direction = payload.direction :: Vector3
	local slashes = payload.slashes :: number
	local delay = payload.delay :: number
	local interval = delay / slashes

	for _, position in positions do
		local face = CFrame.lookAt(position, position + direction)
		for i = 1, slashes do
			task.delay((i - 1) * interval, function()
				local angle = (i / slashes) * math.pi * 2
				AnimeFx.slash(face * CFrame.Angles(0, 0, angle) * CFrame.new(0, -3.5, 0), 6, {
					color = GREEN,
					duration = 0.45,
					width = 0.9,
				})
				AnimeFx.flash(position + VfxUtil.randomDirection() * 1.5, MINT, 4, 0.15)
			end)
		end
		task.delay(delay, function()
			AnimeFx.flash(position, GREEN, 30, 0.5)
			AnimeFx.flash(position, WHITE, 14, 0.25)
			AnimeFx.shockwave(across(position, direction), GREEN, 45, 0.6)
			AnimeFx.shockwave(CFrame.new(position - Vector3.new(0, 2.7, 0)), MINT, 50, 0.6)
			for _, angle in { -0.78, 0.78 } do
				AnimeFx.slash(face * CFrame.Angles(0, 0, angle) * CFrame.new(0, -8, 0), 13, {
					color = GREEN,
					duration = 0.6,
					width = 2,
					grow = 1.3,
				})
			end
			AnimeFx.debris(position - Vector3.new(0, 2.7, 0), 14, STONE, 45)
		end)
	end

	local first = positions[1]
	if first and (isLocal(caster) or nearCamera(first, NEAR)) then
		task.delay(delay, function()
			AnimeFx.impactFrame(1.3)
			VfxUtil.shake(1, 0.6)
		end)
	end
	return nil
end

return Zoro
