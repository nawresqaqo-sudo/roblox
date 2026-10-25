--!strict
-- Lets players pick a character and dresses their avatar as that character on every spawn.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Characters = require(ReplicatedStorage.Shared.Characters)
local Net = require(ReplicatedStorage.Shared.Net)
local Movesets = require(script.Parent.Parent.Movesets)

local SELECT_COOLDOWN = 1

local CharacterService = {}

local selected: { [Player]: string } = {}
local lastRequest: { [Player]: number } = {}

local function dress(player: Player)
	local id = selected[player]
	local character = player.Character
	local moveset = id and Movesets[id]
	if not moveset or not character then
		return
	end
	local ok, err = pcall(moveset.applyOutfit :: any, character)
	if not ok then
		warn(`[CharacterService] outfit for {id} failed: {err}`)
	end
end

local function onSelect(player: Player, id: unknown)
	local now = os.clock()
	if now - (lastRequest[player] or 0) < SELECT_COOLDOWN then
		return
	end
	lastRequest[player] = now

	if typeof(id) ~= "string" then
		return
	end
	local info = Characters.ById[id]
	if not info or not info.Available or not Movesets[id] then
		return
	end

	selected[player] = id
	player:SetAttribute("Character", id)
	if player:HasAppearanceLoaded() then
		dress(player)
	end
end

function CharacterService.getSelected(player: Player): string?
	return selected[player]
end

function CharacterService.init()
	Net.remote("SelectCharacter").OnServerEvent:Connect(onSelect)

	local function onPlayerAdded(player: Player)
		-- Wait for the avatar to finish loading, otherwise its clothes would land on top of the outfit.
		player.CharacterAppearanceLoaded:Connect(function()
			dress(player)
		end)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		selected[player] = nil
		lastRequest[player] = nil
	end)
end

return CharacterService
