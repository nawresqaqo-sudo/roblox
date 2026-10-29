--!strict
-- Runs moves: checks the request, starts the cooldown, then hands off to the character's moveset.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Characters)
local Net = require(ReplicatedStorage.Shared.Net)
local Types = require(ReplicatedStorage.Shared.Types)
local CharacterService = require(script.Parent.CharacterService)
local CombatTypes = require(script.Parent.Parent.Combat.CombatTypes)
local Movesets = require(script.Parent.Parent.Movesets)

local MAX_REQUESTS_PER_SECOND = 8

type PlayerState = {
	-- character id -> slot -> os.clock() when it's ready again. Per character, so switching characters
	-- can't be used to skip a cooldown and the hotbar always matches.
	cooldowns: { [string]: { [number]: number } },
	busy: boolean,
	windowStart: number,
	requestCount: number,
}

local CombatService = {}

local states: { [Player]: PlayerState } = {}

local function getState(player: Player): PlayerState
	local state = states[player]
	if not state then
		state = { cooldowns = {}, busy = false, windowStart = 0, requestCount = 0 }
		states[player] = state
	end
	return state
end

local function rateLimited(state: PlayerState): boolean
	local now = os.clock()
	if now - state.windowStart >= 1 then
		state.windowStart = now
		state.requestCount = 0
	end
	state.requestCount += 1
	return state.requestCount > MAX_REQUESTS_PER_SECOND
end

local function findMove(info: Types.CharacterInfo, slot: number): Types.MoveInfo?
	for _, move in info.Moves do
		if move.Slot == slot then
			return move
		end
	end
	return nil
end

local function onUseMove(player: Player, slot: unknown)
	local state = getState(player)
	if rateLimited(state) then
		return
	end
	if typeof(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > 5 then
		return
	end

	local characterId = CharacterService.getSelected(player)
	if not characterId then
		return
	end
	local info = Characters.ById[characterId]
	local moveset = Movesets[characterId]
	if not info or not moveset then
		return
	end
	local moveInfo = findMove(info, slot)
	local move = moveset.moves[slot]
	if not moveInfo or not move then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return
	end

	local now = os.clock()
	local stunnedUntil = character:GetAttribute("StunnedUntil")
	local cooldowns = state.cooldowns[characterId]
	if not cooldowns then
		cooldowns = {}
		state.cooldowns[characterId] = cooldowns
	end
	if state.busy or (cooldowns[slot] or 0) > now then
		return
	end
	if typeof(stunnedUntil) == "number" and stunnedUntil > now then
		return
	end

	cooldowns[slot] = now + moveInfo.Cooldown
	state.busy = true
	local accepted: Types.MoveAccepted = {
		Character = characterId,
		Slot = slot,
		EndsAt = workspace:GetServerTimeNow() + moveInfo.Cooldown,
	}
	Net.remote("MoveAccepted"):FireClient(player, accepted)

	local ctx: CombatTypes.MoveContext = {
		player = player,
		character = character,
		humanoid = humanoid,
		root = root,
		isActive = function()
			return humanoid.Health > 0 and player.Character == character and character.Parent ~= nil
		end,
	}
	local ok, err = pcall(move :: any, ctx)
	state.busy = false
	if not ok then
		warn(`[CombatService] {characterId} move {slot} errored: {err}`)
	end
end

function CombatService.init()
	Net.remote("UseMove").OnServerEvent:Connect(onUseMove)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return CombatService
