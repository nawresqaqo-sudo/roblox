--!strict
-- The KO scoreboard. Anyone who falls into the void dies, and whoever slid into them last gets the KO.
-- The void is just above Workspace.FallenPartsDestroyHeight, so set that below your islands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

-- Kill this far above FallenPartsDestroyHeight, before Roblox deletes the character, so the KO counts.
local VOID_MARGIN = 25

local KnockoutService = {}

local function creditKnockout(victim: Model)
	local attackerId = victim:GetAttribute("LastHitBy")
	local hitTime = victim:GetAttribute("LastHitTime")
	if typeof(attackerId) ~= "number" or typeof(hitTime) ~= "number" then
		return
	end
	if os.clock() - hitTime > Config.KnockoutCreditTime then
		return
	end
	local attacker = Players:GetPlayerByUserId(attackerId)
	if not attacker or attacker == Players:GetPlayerFromCharacter(victim) then
		return
	end
	local stats = attacker:FindFirstChild("leaderstats")
	local kos = stats and stats:FindFirstChild("KOs")
	if kos and kos:IsA("IntValue") then
		kos.Value += 1
	end
end

-- Starts tracking a character (player or NPC) for KO credit.
function KnockoutService.watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			creditKnockout(character)
		end)
	end
end

local function killIfFallen(character: Model?, voidY: number)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") and root.Position.Y < voidY then
		humanoid.Health = 0
	end
end

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local kos = Instance.new("IntValue")
	kos.Name = "KOs"
	kos.Parent = stats
	stats.Parent = player

	player.CharacterAdded:Connect(KnockoutService.watch)
	if player.Character then
		task.spawn(KnockoutService.watch, player.Character)
	end
end

function KnockoutService.init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

function KnockoutService.start()
	while true do
		task.wait(0.2)
		local voidY = workspace.FallenPartsDestroyHeight + VOID_MARGIN
		for _, player in Players:GetPlayers() do
			killIfFallen(player.Character, voidY)
		end
		local dummies = workspace:FindFirstChild("Dummies")
		if dummies then
			for _, dummy in dummies:GetChildren() do
				if dummy:IsA("Model") then
					killIfFallen(dummy, voidY)
				end
			end
		end
	end
end

return KnockoutService
