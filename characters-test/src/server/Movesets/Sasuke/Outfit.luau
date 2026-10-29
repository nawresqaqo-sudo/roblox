--!strict
-- Taka-era Sasuke: a white high-collared shirt open at the chest with the Uchiha crest on the back, the
-- purple rope belt tied in a bow at the back, dark navy trousers, black spiky hair with long bangs, and
-- the Kusanagi sword pushed through the rope behind him.
-- Found real Sasuke clothes or hair in the Marketplace? Put their catalog ids in CATALOG and they
-- replace the built-in look (0 / "" = keep the built-in look).
local CATALOG = {
	Shirt = 0, -- classic shirt id
	Pants = 0, -- classic pants id
	HairAccessory = "", -- hair accessory id(s), comma separated, e.g. "1234567"
}

local COLORS = {
	Skin = Color3.fromRGB(236, 206, 180),
	Shirt = Color3.fromRGB(226, 226, 234),
	Trousers = Color3.fromRGB(30, 34, 62),
	Sandals = Color3.fromRGB(36, 36, 44),
	Hair = Color3.fromRGB(20, 20, 32),
	Rope = Color3.fromRGB(112, 62, 176),
	RopeDark = Color3.fromRGB(76, 38, 128),
	Sheath = Color3.fromRGB(24, 22, 30),
	Hilt = Color3.fromRGB(46, 42, 56),
	CrestRed = Color3.fromRGB(205, 32, 42),
	CrestWhite = Color3.fromRGB(245, 245, 245),
}

local PART_COLORS: { [string]: Color3 } = {
	Head = COLORS.Skin,
	UpperTorso = COLORS.Shirt,
	LowerTorso = COLORS.Trousers,
	LeftUpperArm = COLORS.Shirt,
	RightUpperArm = COLORS.Shirt,
	LeftLowerArm = COLORS.Shirt,
	RightLowerArm = COLORS.Shirt,
	LeftHand = COLORS.Skin,
	RightHand = COLORS.Skin,
	LeftUpperLeg = COLORS.Trousers,
	RightUpperLeg = COLORS.Trousers,
	LeftLowerLeg = COLORS.Trousers,
	RightLowerLeg = COLORS.Trousers,
	LeftFoot = COLORS.Sandals,
	RightFoot = COLORS.Sandals,
	-- R6 rigs
	Torso = COLORS.Shirt,
	["Left Arm"] = COLORS.Shirt,
	["Right Arm"] = COLORS.Shirt,
	["Left Leg"] = COLORS.Trousers,
	["Right Leg"] = COLORS.Trousers,
}

local OUTFIT_NAME = "SasukeOutfit"

local Outfit = {}

local function usesCatalog(): boolean
	return CATALOG.Shirt ~= 0 or CATALOG.Pants ~= 0 or CATALOG.HairAccessory ~= ""
end

local function applyCatalog(humanoid: Humanoid)
	local description = humanoid:GetAppliedDescription()
	description:SetAccessories({}, true)
	description.Shirt = CATALOG.Shirt
	description.Pants = CATALOG.Pants
	description.GraphicTShirt = 0
	description.HairAccessory = CATALOG.HairAccessory
	local ok, err = pcall(humanoid.ApplyDescriptionAsync, humanoid, description)
	if not ok then
		warn(`[Outfit] couldn't apply catalog items: {err}`)
	end
end

local function stripAvatar(character: Model)
	for _, child in character:GetChildren() do
		if child:IsA("Accessory") or child:IsA("Clothing") or child:IsA("ShirtGraphic") or child:IsA("BodyColors") then
			child:Destroy()
		end
	end
end

local function paintBody(character: Model)
	for _, part in character:GetChildren() do
		if not part:IsA("BasePart") then
			continue
		end
		local color = PART_COLORS[part.Name]
		if not color then
			continue
		end
		part.Color = color
		-- Body textures would hide the colors. Heads keep theirs because some faces live in the texture.
		if part.Name ~= "Head" then
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
			local surface = part:FindFirstChildOfClass("SurfaceAppearance")
			if surface then
				surface:Destroy()
			end
		end
	end
end

-- Welds a decoration part onto `anchor` at `offset` (relative to the anchor part).
local function addPiece(
	parent: Instance,
	anchor: BasePart,
	part: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
): BasePart
	part.Size = size
	part.CFrame = anchor.CFrame * offset
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
	return part
end

local function shaped(shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Shape = shape
	return part
end

-- Black hair with a blue sheen: a cap over the top, spikes sweeping up and back, and two long bangs
-- framing the face.
local function buildHair(outfit: Model, head: BasePart)
	local s = head.Size
	local glossy = Enum.Material.SmoothPlastic
	addPiece(
		outfit,
		head,
		shaped(Enum.PartType.Ball),
		Vector3.new(s.X * 1.1, s.Y * 0.78, s.Z * 1.12),
		CFrame.new(0, s.Y * 0.24, s.Z * 0.06),
		COLORS.Hair,
		glossy
	)
	-- The spikes at the back, fanned out and pointing up and back.
	local spikes = {
		{ x = 0, y = 0.42, tilt = 35, length = 0.55 },
		{ x = -0.24, y = 0.36, tilt = 28, length = 0.5 },
		{ x = 0.24, y = 0.36, tilt = 28, length = 0.5 },
		{ x = -0.4, y = 0.18, tilt = 18, length = 0.42 },
		{ x = 0.4, y = 0.18, tilt = 18, length = 0.42 },
		{ x = -0.12, y = 0.12, tilt = 10, length = 0.48 },
		{ x = 0.12, y = 0.12, tilt = 10, length = 0.48 },
	}
	for _, spike in spikes do
		addPiece(
			outfit,
			head,
			Instance.new("WedgePart"),
			Vector3.new(s.X * 0.2, s.Y * 0.16, s.Z * spike.length),
			CFrame.new(s.X * spike.x, s.Y * spike.y, s.Z * 0.55)
				* CFrame.Angles(math.rad(spike.tilt), math.rad(spike.x * -40), 0),
			COLORS.Hair,
			glossy
		)
	end
	-- Long bangs on either side of the face, down to the jaw.
	for _, side in { -1, 1 } do
		addPiece(
			outfit,
			head,
			Instance.new("Part"),
			Vector3.new(s.X * 0.16, s.Y * 0.78, s.Z * 0.14),
			CFrame.new(side * s.X * 0.43, -s.Y * 0.04, -s.Z * 0.44) * CFrame.Angles(0, 0, math.rad(side * 6)),
			COLORS.Hair,
			glossy
		)
	end
	-- A short fringe over the forehead that stays above the eyes.
	for i = -1, 1 do
		addPiece(
			outfit,
			head,
			Instance.new("WedgePart"),
			Vector3.new(s.X * 0.2, s.Y * 0.22, s.Z * 0.12),
			CFrame.new(i * s.X * 0.2, s.Y * 0.3, -s.Z * 0.52) * CFrame.Angles(0, math.rad(180), math.rad(i * 8)),
			COLORS.Hair,
			glossy
		)
	end
end

-- The open chest, the high collar and the Uchiha crest on the back of the shirt.
local function buildShirt(outfit: Model, torso: BasePart)
	local s = torso.Size
	addPiece(
		outfit,
		torso,
		Instance.new("Part"),
		Vector3.new(s.X * 0.2, s.Y * 0.5, 0.04),
		CFrame.new(0, s.Y * 0.24, -s.Z * 0.5 - 0.015),
		COLORS.Skin,
		Enum.Material.SmoothPlastic
	)
	addPiece(
		outfit,
		torso,
		Instance.new("Part"),
		Vector3.new(s.X * 0.62, s.Y * 0.2, 0.14),
		CFrame.new(0, s.Y * 0.56, s.Z * 0.28) * CFrame.Angles(math.rad(-12), 0, 0),
		COLORS.Shirt,
		Enum.Material.Fabric
	)

	-- The crest is drawn on a see-through plate: a fan, red on top and white below, with a handle.
	local plate = addPiece(
		outfit,
		torso,
		Instance.new("Part"),
		Vector3.new(s.X * 0.36, s.X * 0.5, 0.02),
		CFrame.new(0, s.Y * 0.1, s.Z * 0.5 + 0.02),
		COLORS.Shirt,
		Enum.Material.SmoothPlastic
	)
	plate.Transparency = 1
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.LightInfluence = 1
	gui.CanvasSize = Vector2.new(100, 140)
	gui.Parent = plate
	local fan = Instance.new("Frame")
	fan.Size = UDim2.fromScale(1, 100 / 140)
	fan.BorderSizePixel = 0
	fan.BackgroundColor3 = Color3.new(1, 1, 1)
	fan.Parent = gui
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = fan
	local halves = Instance.new("UIGradient")
	halves.Rotation = 90
	halves.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COLORS.CrestRed),
		ColorSequenceKeypoint.new(0.5, COLORS.CrestRed),
		ColorSequenceKeypoint.new(0.52, COLORS.CrestWhite),
		ColorSequenceKeypoint.new(1, COLORS.CrestWhite),
	})
	halves.Parent = fan
	local handle = Instance.new("Frame")
	handle.AnchorPoint = Vector2.new(0.5, 0)
	handle.Position = UDim2.fromScale(0.5, 96 / 140)
	handle.Size = UDim2.fromScale(0.18, 44 / 140)
	handle.BorderSizePixel = 0
	handle.BackgroundColor3 = COLORS.CrestWhite
	handle.Parent = gui
end

-- The purple rope belt, a big bow at the back, and the Kusanagi pushed through the rope.
local function buildBelt(outfit: Model, waist: BasePart)
	local s = waist.Size
	addPiece(
		outfit,
		waist,
		Instance.new("Part"),
		Vector3.new(s.X * 1.08, 0.32, s.Z * 1.16),
		CFrame.new(0, s.Y * 0.35, 0),
		COLORS.Rope,
		Enum.Material.Fabric
	)
	addPiece(
		outfit,
		waist,
		Instance.new("Part"),
		Vector3.new(s.X * 1.1, 0.14, s.Z * 1.2),
		CFrame.new(0, s.Y * 0.35 + 0.14, 0) * CFrame.Angles(0, 0, math.rad(2)),
		COLORS.RopeDark,
		Enum.Material.Fabric
	)
	for _, side in { -1, 1 } do
		addPiece(
			outfit,
			waist,
			shaped(Enum.PartType.Ball),
			Vector3.new(0.62, 0.4, 0.34),
			CFrame.new(side * 0.34, s.Y * 0.4, s.Z * 0.62),
			COLORS.Rope,
			Enum.Material.Fabric
		)
		addPiece(
			outfit,
			waist,
			shaped(Enum.PartType.Cylinder),
			Vector3.new(1.1, 0.16, 0.16),
			CFrame.new(side * 0.16, -s.Y * 0.6, s.Z * 0.6) * CFrame.Angles(0, 0, math.rad(90 + side * 12)),
			COLORS.RopeDark,
			Enum.Material.Fabric
		)
	end
	addPiece(
		outfit,
		waist,
		shaped(Enum.PartType.Ball),
		Vector3.one * 0.3,
		CFrame.new(0, s.Y * 0.4, s.Z * 0.66),
		COLORS.RopeDark,
		Enum.Material.Fabric
	)

	-- Kusanagi: across the small of his back, hilt up and to the right.
	local sword = CFrame.new(0, s.Y * 0.2, s.Z * 0.75) * CFrame.Angles(0, 0, math.rad(22))
	addPiece(
		outfit,
		waist,
		Instance.new("Part"),
		Vector3.new(2.9, 0.2, 0.2),
		sword * CFrame.new(-0.35, 0, 0),
		COLORS.Sheath,
		Enum.Material.Glass
	)
	addPiece(
		outfit,
		waist,
		Instance.new("Part"),
		Vector3.new(0.06, 0.34, 0.34),
		sword * CFrame.new(1.13, 0, 0),
		COLORS.Hilt,
		Enum.Material.Metal
	)
	addPiece(
		outfit,
		waist,
		Instance.new("Part"),
		Vector3.new(0.85, 0.17, 0.17),
		sword * CFrame.new(1.58, 0, 0),
		COLORS.Hilt,
		Enum.Material.Fabric
	)
end

function Outfit.apply(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local head = character:FindFirstChild("Head")
	if not humanoid or not head or not head:IsA("BasePart") then
		return
	end

	local old = character:FindFirstChild(OUTFIT_NAME)
	if old then
		old:Destroy()
	end

	if usesCatalog() then
		applyCatalog(humanoid)
	else
		stripAvatar(character)
	end
	paintBody(character)

	local outfit = Instance.new("Model")
	outfit.Name = OUTFIT_NAME
	if CATALOG.HairAccessory == "" then
		buildHair(outfit, head)
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if CATALOG.Shirt == 0 and torso and torso:IsA("BasePart") then
		buildShirt(outfit, torso)
	end
	local waist = character:FindFirstChild("LowerTorso") or character:FindFirstChild("Torso")
	if waist and waist:IsA("BasePart") then
		buildBelt(outfit, waist)
	end
	outfit.Parent = character
end

return Outfit
