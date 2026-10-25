--!strict
-- Every RemoteEvent in the game. The server creates them at startup (see Net.luau).

export type RemoteName = "SelectCharacter" | "UseMove" | "MoveAccepted" | "PlayVfx"

local NAMES: { RemoteName } = { "SelectCharacter", "UseMove", "MoveAccepted", "PlayVfx" }

return NAMES
