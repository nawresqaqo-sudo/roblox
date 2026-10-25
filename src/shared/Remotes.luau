--!strict
-- Every RemoteEvent in the game. The server creates them at startup (see Net.luau).

export type RemoteName = "SlideState" | "SlideHit" | "Knockback" | "SlideImpact"

local NAMES: { RemoteName } = { "SlideState", "SlideHit", "Knockback", "SlideImpact" }

return NAMES
