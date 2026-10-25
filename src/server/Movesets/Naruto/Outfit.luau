--!strict
-- Teen Naruto look: orange and black outfit, Leaf headband, spiky blonde hair.
-- Found real Naruto clothes or hair in the Marketplace? Put their catalog ids in CATALOG and they
-- replace the built-in look (0 / "" = keep the built-in look).
local CATALOG = {
	Shirt = 0, -- classic shirt id
	Pants = 0, -- classic pants id
	HairAccessory = "", -- hair accessory id(s), comma separated, e.g. "1234567"
}

local COLORS = {
	Skin = Color3.fromRGB(240, 196, 150),
	Orange = Color3.fromRGB(255, 130, 20),
	Black = Color3.fromRGB(30, 30, 35),
	Hair = Color3.fromRGB(255, 214, 60),
	Metal = Color3.fromRGB(180, 186, 196),
}

local PART_COLORS: { [string]: Color3 } = {
	Head = COLORS.Skin,
	UpperTorso = COLORS.Orange,
	LowerTorso = COLORS.Orange,
	LeftUpperArm = COLORS.Black,
	RightUpperArm = COLORS.Black,
	LeftLowerArm = COLORS.Orange,
	RightLowerArm = COLORS.Orange,
	LeftHand = COLORS.Skin,
	RightHand = COLORS.Skin,
	LeftUpperLeg = COLORS.Orange,
	RightUpperLeg = COLORS.Orange,
	LeftLowerLeg = COLORS.Orange,
	RightLowerLeg = COLORS.Orange,
	LeftFoot = COLORS.Black,
	RightFoot = COLORS.Black,
	-- R6 rigs
	Torso = COLORS.Orange,
	["Left Arm"] = COLORS.Orange,
	["Right Arm"] = COLORS.Orange,
	["Left Leg"] = COLORS.Orange,
	["Right Leg"] = COLORS.Orange,
}

local OUTFIT_NAME = "NarutoOutfit"
local HAIR_SPIKES = 10

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

local function addPiece(
	parent: Instance,
	head: BasePart,
	part: BasePart,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	material: Enum.Material
)
	part.Size = size
	part.CFrame = head.CFrame * offset
	part.Color = color
	part.Material = material
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = head
	weld.Part1 = part
	weld.Parent = part
	part.Parent = parent
end

local function cylinder(): Part
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function buildHeadband(outfit: Model, head: BasePart)
	local s = head.Size
	local upright = CFrame.Angles(0, 0, math.rad(90)) -- cylinders point along X; stand them up
	local bandY = s.Y * 0.18
	addPiece(
		outfit,
		head,
		cylinder(),
		Vector3.new(s.Y * 0.2, s.X * 1.06, s.Z * 1.06),
		CFrame.new(0, bandY, 0) * upright,
		COLORS.Black,
		Enum.Material.Fabric
	)
	addPiece(
		outfit,
		head,
		Instance.new("Part"),
		Vector3.new(s.X * 0.5, s.Y * 0.17, 0.08),
		CFrame.new(0, bandY, -s.Z * 0.53),
		COLORS.Metal,
		Enum.Material.Metal
	)
	for _, side in { -1, 1 } do
		addPiece(
			outfit,
			head,
			Instance.new("Part"),
			Vector3.new(s.X * 0.12, s.Y * 0.5, 0.04),
			CFrame.new(side * s.X * 0.1, bandY - s.Y * 0.25, s.Z * 0.55)
				* CFrame.Angles(math.rad(15), 0, math.rad(side * 10)),
			COLORS.Black,
			Enum.Material.Fabric
		)
	end
end

local function buildHair(outfit: Model, head: BasePart)
	local s = head.Size
	addPiece(
		outfit,
		head,
		cylinder(),
		Vector3.new(s.Y * 0.3, s.X * 1.08, s.Z * 1.08),
		CFrame.new(0, s.Y * 0.38, 0) * CFrame.Angles(0, 0, math.rad(90)),
		COLORS.Hair,
		Enum.Material.SmoothPlastic
	)
	-- A ring of wedge "fins" whose tips lean outward = spiky anime hair.
	for i = 1, HAIR_SPIKES do
		local angle = (i / HAIR_SPIKES) * math.pi * 2
		addPiece(
			outfit,
			head,
			Instance.new("WedgePart"),
			Vector3.new(s.X * 0.12, s.Y * 0.6, s.Z * 0.42),
			CFrame.new(0, s.Y * 0.55, 0)
				* CFrame.Angles(0, angle, 0)
				* CFrame.new(0, 0, s.Z * 0.28)
				* CFrame.Angles(math.rad(35), 0, 0),
			COLORS.Hair,
			Enum.Material.SmoothPlastic
		)
	end
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
	buildHeadband(outfit, head)
	if CATALOG.HairAccessory == "" then
		buildHair(outfit, head)
	end
	outfit.Parent = character
end

return Outfit
