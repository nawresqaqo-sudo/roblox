--!strict
-- Training dummies in front of the spawn so every move can be tested. They heal back to full a few
-- seconds after the last hit and respawn when killed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

type Dummy = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	home: CFrame,
	lastHit: number,
}

local WOOD = Color3.fromRGB(176, 132, 88)
local WOOD_DARK = Color3.fromRGB(140, 100, 62)

local DummyService = {}

local dummies: { Dummy } = {}
local folder: Folder

local function buildBlockDummy(): Model
	local model = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.Transparency = 1
	root.Parent = model

	local function block(name: string, size: Vector3, offset: Vector3)
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.CFrame = CFrame.new(offset)
		part.Color = WOOD
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	block("UpperTorso", Vector3.new(2, 2, 1), Vector3.zero)
	block("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 1.6, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.HipHeight = 2
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

local function buildModel(): Model
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = WOOD
	description.TorsoColor = WOOD_DARK
	description.LeftArmColor = WOOD
	description.RightArmColor = WOOD
	description.LeftLegColor = WOOD_DARK
	description.RightLegColor = WOOD_DARK
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if ok then
		return result
	end
	warn(`[DummyService] couldn't build an R15 dummy, using a block one: {result}`)
	return buildBlockDummy()
end

local function attachHealthBar(model: Model, humanoid: Humanoid)
	local head = model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "DummyHealth"
	gui.Size = UDim2.fromOffset(150, 38)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 150
	gui.Adornee = head

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 16)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 14
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = "Training Dummy"
	title.Parent = gui

	local back = Instance.new("Frame")
	back.Position = UDim2.fromOffset(0, 18)
	back.Size = UDim2.new(1, 0, 0, 16)
	back.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	back.BorderSizePixel = 0
	back.Parent = gui
	Instance.new("UICorner").Parent = back

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = back
	Instance.new("UICorner").Parent = fill

	local amount = Instance.new("TextLabel")
	amount.BackgroundTransparency = 1
	amount.Size = UDim2.fromScale(1, 1)
	amount.Font = Enum.Font.GothamBold
	amount.TextSize = 12
	amount.TextColor3 = Color3.new(1, 1, 1)
	amount.TextStrokeTransparency = 0.5
	amount.ZIndex = 2
	amount.Parent = back

	local function refresh()
		local ratio = math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1)
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = Color3.fromRGB(230, 70, 60):Lerp(Color3.fromRGB(90, 220, 110), ratio)
		amount.Text = `{math.ceil(humanoid.Health)} / {humanoid.MaxHealth}`
	end
	humanoid.HealthChanged:Connect(refresh)
	refresh()
	gui.Parent = model
end

local function spawnDummy(ground: CFrame)
	local model = buildModel()
	model.Name = "Training Dummy"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			descendant.Material = Enum.Material.Wood
		end
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		warn("[DummyService] dummy model is missing a Humanoid or HumanoidRootPart")
		model:Destroy()
		return
	end
	humanoid.MaxHealth = Config.Dummy.MaxHealth
	humanoid.Health = Config.Dummy.MaxHealth
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	model:SetAttribute("IsDummy", true)

	local home = ground + Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2, 0)
	model:PivotTo(home)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	attachHealthBar(model, humanoid)

	local dummy: Dummy = { model = model, humanoid = humanoid, root = root, home = home, lastHit = 0 }
	table.insert(dummies, dummy)

	local lastHealth = humanoid.Health
	humanoid.HealthChanged:Connect(function(health: number)
		if health < lastHealth then
			dummy.lastHit = os.clock()
		end
		lastHealth = health
	end)
	humanoid.Died:Connect(function()
		local index = table.find(dummies, dummy)
		if index then
			table.remove(dummies, index)
		end
		task.wait(Config.Dummy.RespawnTime)
		model:Destroy()
		spawnDummy(ground)
	end)
end

local function groundBelow(position: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(position + Vector3.new(0, 50, 0), Vector3.new(0, -200, 0), params)
	return if hit then hit.Position else position
end

function DummyService.init()
	folder = Instance.new("Folder")
	folder.Name = "Dummies"
	folder.Parent = workspace
end

function DummyService.start()
	local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	local origin = if spawnLocation and spawnLocation:IsA("BasePart") then spawnLocation.CFrame else CFrame.new()

	for _, offset in Config.Dummy.Offsets do
		local ground = groundBelow((origin * CFrame.new(offset)).Position)
		local facing = Vector3.new(origin.X, ground.Y, origin.Z)
		local placement = if (facing - ground).Magnitude > 0.1
			then CFrame.lookAt(ground, facing)
			else CFrame.new(ground)
		task.spawn(spawnDummy, placement)
	end

	while true do
		task.wait(0.5)
		local now = os.clock()
		for _, dummy in dummies do
			local humanoid = dummy.humanoid
			if humanoid.Health <= 0 then
				continue
			end
			if now - dummy.lastHit > Config.Dummy.RegenDelay and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
			if (dummy.root.Position - dummy.home.Position).Magnitude > Config.Dummy.MaxDrift then
				dummy.root.AssemblyLinearVelocity = Vector3.zero
				dummy.model:PivotTo(dummy.home)
			end
		end
	end
end

return DummyService
