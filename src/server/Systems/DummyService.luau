--!strict
-- Test dummies to slide into. Put parts in a Workspace folder named "DummySpawns" and a dummy stands on
-- each one; knocked-off dummies come back after a moment. No folder = no dummies.
local Players = game:GetService("Players")

local KnockoutService = require(script.Parent.KnockoutService)

local RESPAWN_TIME = 2
local BODY_COLOR = Color3.fromRGB(240, 200, 60)
local LIMB_COLOR = Color3.fromRGB(70, 70, 80)

local DummyService = {}

local folder: Folder

local function spawnDummy(spawnPart: BasePart)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = BODY_COLOR
	description.TorsoColor = BODY_COLOR
	description.LeftArmColor = LIMB_COLOR
	description.RightArmColor = LIMB_COLOR
	description.LeftLegColor = LIMB_COLOR
	description.RightLegColor = LIMB_COLOR
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok then
		warn(`[DummyService] couldn't build a dummy: {model}`)
		return
	end

	model.Name = "Dummy"
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BaseScript") then
			descendant:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		model:Destroy()
		return
	end
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	humanoid.BreakJointsOnDeath = false

	local standHeight = spawnPart.Size.Y / 2 + humanoid.HipHeight + root.Size.Y / 2
	model:PivotTo(spawnPart.CFrame + Vector3.new(0, standHeight, 0))
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	task.spawn(KnockoutService.watch, model)
	humanoid.Died:Connect(function()
		task.wait(RESPAWN_TIME)
		model:Destroy()
		spawnDummy(spawnPart)
	end)
end

function DummyService.init()
	folder = Instance.new("Folder")
	folder.Name = "Dummies"
	folder.Parent = workspace
end

function DummyService.start()
	local spawns = workspace:FindFirstChild("DummySpawns")
	if not spawns then
		return
	end
	for _, spawnPart in spawns:GetChildren() do
		if spawnPart:IsA("BasePart") then
			task.spawn(spawnDummy, spawnPart)
		end
	end
end

return DummyService
