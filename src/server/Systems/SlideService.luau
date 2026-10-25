--!strict
-- Server side of sliding: tracks who is sliding, checks the slide hits clients report, and launches
-- whoever got hit. Players are launched by their own client (it owns their physics); NPCs here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local SafeZones = require(script.Parent.Parent.Util.SafeZones)

local MAX_REQUESTS_PER_SECOND = 20
local HIT_GRACE = 0.3 -- a hit may arrive this long after the slide ended (network delay)
local MAX_HIT_DISTANCE = 14 -- the server sees positions slightly late, so be generous

type State = {
	sliding: boolean,
	slideId: number,
	slideEnded: number,
	lastHits: { [Model]: number },
	windowStart: number,
	requests: number,
}

local SlideService = {}

local states: { [Player]: State } = {}

local function getState(player: Player): State
	local state = states[player]
	if not state then
		state = {
			sliding = false,
			slideId = 0,
			slideEnded = -math.huge,
			lastHits = setmetatable({}, { __mode = "k" }) :: any,
			windowStart = 0,
			requests = 0,
		}
		states[player] = state
	end
	return state
end

local function rateLimited(state: State): boolean
	local now = os.clock()
	if now - state.windowStart >= 1 then
		state.windowStart = now
		state.requests = 0
	end
	state.requests += 1
	return state.requests > MAX_REQUESTS_PER_SECOND
end

local function rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function aliveHumanoid(model: Model): Humanoid?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function flatten(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function setSliding(player: Player, state: State, sliding: boolean)
	state.sliding = sliding
	if not sliding then
		state.slideEnded = os.clock()
	end
	local character = player.Character
	if character then
		character:SetAttribute("Sliding", sliding)
	end
end

local function onSlideState(player: Player, sliding: unknown)
	local state = getState(player)
	if rateLimited(state) or typeof(sliding) ~= "boolean" or sliding == state.sliding then
		return
	end
	if not sliding then
		setSliding(player, state, false)
		return
	end

	local character = player.Character
	if not character or not aliveHumanoid(character) or character:GetAttribute("Down") then
		return
	end
	setSliding(player, state, true)
	state.slideId += 1
	local slideId = state.slideId
	-- Safety net in case the "stopped sliding" message never arrives.
	task.delay(Config.Slide.MaxTime + 0.5, function()
		if state.sliding and state.slideId == slideId then
			setSliding(player, state, false)
		end
	end)
end

-- Knocks a character over and sends it flying. `attacker` gets the KO if it falls off.
function SlideService.launch(target: Model, velocity: Vector3, attacker: Player?)
	local humanoid = aliveHumanoid(target)
	local root = rootOf(target)
	if not humanoid or not root then
		return
	end

	local downTime = Config.Knockback.DownTime
	local previous = target:GetAttribute("DownId")
	local downId = (if typeof(previous) == "number" then previous else 0) + 1
	target:SetAttribute("DownId", downId)
	target:SetAttribute("Down", true)
	if attacker then
		target:SetAttribute("LastHitBy", attacker.UserId)
		target:SetAttribute("LastHitTime", os.clock())
	end

	local victim = Players:GetPlayerFromCharacter(target)
	if victim then
		local victimState = states[victim]
		if victimState and victimState.sliding then
			setSliding(victim, victimState, false)
		end
		Net.remote("Knockback"):FireClient(victim, velocity, downTime)
	else
		humanoid.PlatformStand = true
		root.AssemblyLinearVelocity = velocity
		root.AssemblyAngularVelocity = Vector3.new(math.random() * 6 - 3, 0, math.random() * 6 - 3)
	end

	task.delay(downTime, function()
		if target:GetAttribute("DownId") ~= downId then
			return -- hit again since; that hit's timer gets them up
		end
		target:SetAttribute("Down", false)
		if not victim and humanoid.Parent then
			humanoid.PlatformStand = false
		end
	end)
end

local function onSlideHit(player: Player, target: unknown)
	local state = getState(player)
	if rateLimited(state) then
		return
	end
	if typeof(target) ~= "Instance" or not target:IsA("Model") then
		return
	end
	local character = player.Character
	if not character or target == character then
		return
	end

	local now = os.clock()
	if not state.sliding and now - state.slideEnded > HIT_GRACE then
		return
	end
	if now - (state.lastHits[target] or -math.huge) < Config.Knockback.SameTargetCooldown then
		return
	end

	local root = rootOf(character)
	local targetRoot = rootOf(target)
	if not root or not targetRoot or not aliveHumanoid(character) or not aliveHumanoid(target) then
		return
	end
	local offset = targetRoot.Position - root.Position
	if offset.Magnitude > MAX_HIT_DISTANCE or SafeZones.contains(targetRoot.Position) then
		return
	end
	state.lastHits[target] = now

	-- Launch along the slide, or straight away from the slider if they were barely moving.
	local slideVelocity = flatten(root.AssemblyLinearVelocity)
	local away = flatten(offset)
	local direction = if slideVelocity.Magnitude > 5
		then slideVelocity.Unit
		elseif away.Magnitude > 0.1 then away.Unit
		else flatten(root.CFrame.LookVector).Unit
	local knockback = Config.Knockback
	local power = math.min(knockback.Base + slideVelocity.Magnitude * knockback.PerSlideSpeed, knockback.Max)

	SlideService.launch(target, direction * power + Vector3.new(0, knockback.Lift, 0), player)
	Net.remote("SlideImpact"):FireAllClients(targetRoot.Position, direction)
end

function SlideService.init()
	Net.remote("SlideState").OnServerEvent:Connect(onSlideState)
	Net.remote("SlideHit").OnServerEvent:Connect(onSlideHit)

	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			getState(player).sliding = false
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return SlideService
