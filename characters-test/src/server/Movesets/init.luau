--!strict
-- Server movesets by character id. The id must match the one in ReplicatedStorage.Shared.Characters.
local CombatTypes = require(script.Parent.Combat.CombatTypes)

local Movesets: { [string]: CombatTypes.Moveset } = {
	Zoro = require(script.Zoro),
}

return Movesets
