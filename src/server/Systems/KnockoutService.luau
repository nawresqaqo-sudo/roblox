--!strict
-- KOs and streaks. Anyone who falls into the void dies, and whoever slid into them last gets the KO.
-- The void is just above Workspace.FallenPartsDestroyHeight, so set that below your islands.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

-- Kill this far above FallenPartsDestroyHeight, before Roblox deletes the character, so the KO counts.
local VOID_MARGIN = 25

local KnockoutService = {}

local function stat(player: Player, name: string): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	if value and value:IsA("IntValue") then
		return value
	end
	return nil
end

local function lastHitter(victim: Model, victimPlayer: Player?): Player?
	local attackerId = victim:GetAttribute("LastHitBy")
	local hitTime = victim:GetAttribute("LastHitTime")
	if typeof(attackerId) ~= "number" or typeof(hitTime) ~= "number" then
		return nil
	end
	if os.clock() - hitTime > Config.KnockoutCreditTime then
		return nil
	end
	local attacker = Players:GetPlayerByUserId(attackerId)
	if attacker == victimPlayer then
		return nil
	end
	return attacker
end

local function onDied(victim: Model)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local victimName = if victimPlayer then victimPlayer.DisplayName else victim.Name
	if victimPlayer then
		local victimStreak = stat(victimPlayer, "Streak")
		if victimStreak then
			victimStreak.Value = 0
		end
	end

	local attacker = lastHitter(victim, victimPlayer)
	local streak = 0
	if attacker then
		local kos = stat(attacker, "KOs")
		local attackerStreak = stat(attacker, "Streak")
		if kos then
			kos.Value += 1
		end
		if attackerStreak then
			attackerStreak.Value += 1
			streak = attackerStreak.Value
		end
	end
	-- Clients use this for the KO feed and popups. attacker is nil when someone just fell.
	Net.remote("Knockout"):FireAllClients(attacker, victimName, victimPlayer, streak)
end

-- Starts tracking a character (player or NPC) for KOs.
function KnockoutService.watch(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.Died:Connect(function()
			onDied(character)
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
	for _, name in { "KOs", "Streak" } do
		local value = Instance.new("IntValue")
		value.Name = name
		value.Parent = stats
	end
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
