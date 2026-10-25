--!strict
-- Onigashima Zoro: dark green kimono, light green haramaki, dark trousers, short green hair, the scar
-- over his closed left eye, three gold earrings and the black bandana on his left arm.
-- The three swords are drawn by each client (Controllers/Swords), not here.
-- Found real Zoro clothes or hair in the Marketplace? Put their catalog ids in CATALOG and they
-- replace the built-in look (0 / "" = keep the built-in look).
local CATALOG = {
	Shirt = 0, -- classic shirt id
	Pants = 0, -- classic pants id
	HairAccessory = "", -- hair accessory id(s), comma separated, e.g. "1234567"
}

local COLORS = {
	Skin = Color3.fromRGB(198, 142, 102),
	Kimono = Color3.fromRGB(38, 82, 54),
	Haramaki = Color3.fromRGB(104, 172, 92),
	Trousers = Color3.fromRGB(38, 42, 40),
	Boots = Color3.fromRGB(52, 38, 30),
	Hair = Color3.fromRGB(70, 168, 82),
	Bandana = Color3.fromRGB(20, 20, 24),
	Scar = Color3.fromRGB(120, 40, 40),
	Gold = Color3.fromRGB(235, 190, 70),
}

local PART_COLORS: { [string]: Color3 } = {
	Head = COLORS.Skin,
	UpperTorso = COLORS.Kimono,
	LowerTorso = COLORS.Haramaki,
	LeftUpperArm = COLORS.Kimono,
	RightUpperArm = COLORS.Kimono,
	LeftLowerArm = COLORS.Skin,
	RightLowerArm = COLORS.Skin,
	LeftHand = COLORS.Skin,
	RightHand = COLORS.Skin,
	LeftUpperLeg = COLORS.Trousers,
	RightUpperLeg = COLORS.Trousers,
	LeftLowerLeg = COLORS.Trousers,
	RightLowerLeg = COLORS.Trousers,
	LeftFoot = COLORS.Boots,
	RightFoot = COLORS.Boots,
	-- R6 rigs
	Torso = COLORS.Kimono,
	["Left Arm"] = COLORS.Skin,
	["Right Arm"] = COLORS.Skin,
	["Left Leg"] = COLORS.Trousers,
	["Right Leg"] = COLORS.Trousers,
}

local OUTFIT_NAME = "ZoroOutfit"
local HAIR_SPIKES = 12

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
)
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
end

local function shaped(shape: Enum.PartType): Part
	local part = Instance.new("Part")
	part.Shape = shape
	return part
end

-- Short, slightly spiky green hair.
local function buildHair(outfit: Model, head: BasePart)
	local s = head.Size
	addPiece(
		outfit,
		head,
		shaped(Enum.PartType.Cylinder),
		Vector3.new(s.Y * 0.32, s.X * 1.06, s.Z * 1.06),
		CFrame.new(0, s.Y * 0.36, 0.02) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Hair,
		Enum.Material.SmoothPlastic
	)
	for i = 1, HAIR_SPIKES do
		local angle = (i / HAIR_SPIKES) * math.pi * 2
		addPiece(
			outfit,
			head,
			Instance.new("WedgePart"),
			Vector3.new(s.X * 0.1, s.Y * 0.28, s.Z * 0.3),
			CFrame.new(0, s.Y * 0.5, 0)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, s.Z * 0.3)
				* CFrame.Angles(math.rad(25), 0, 0),
			COLORS.Hair,
			Enum.Material.SmoothPlastic
		)
	end
end

-- The scar down his left eye and the three gold earrings on his left ear.
local function buildFaceDetails(outfit: Model, head: BasePart)
	local s = head.Size
	addPiece(
		outfit,
		head,
		Instance.new("Part"),
		Vector3.new(0.05, s.Y * 0.42, 0.03),
		CFrame.new(-s.X * 0.17, s.Y * 0.06, -s.Z * 0.5) * CFrame.Angles(0, 0, math.rad(4)),
		COLORS.Scar,
		Enum.Material.SmoothPlastic
	)
	for i = 0, 2 do
		addPiece(
			outfit,
			head,
			shaped(Enum.PartType.Ball),
			Vector3.one * 0.1,
			CFrame.new(-s.X * 0.52, -s.Y * 0.08 - i * 0.11, 0.02),
			COLORS.Gold,
			Enum.Material.Metal
		)
	end
end

local function buildBandana(outfit: Model, character: Model)
	local arm = character:FindFirstChild("LeftUpperArm") or character:FindFirstChild("Left Arm")
	if not arm or not arm:IsA("BasePart") then
		return
	end
	local s = arm.Size
	addPiece(
		outfit,
		arm,
		shaped(Enum.PartType.Cylinder),
		Vector3.new(s.Y * 0.28, s.X * 1.15, s.Z * 1.15),
		CFrame.new(0, s.Y * 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Bandana,
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
	buildFaceDetails(outfit, head)
	buildBandana(outfit, character)
	outfit.Parent = character
end

return Outfit
