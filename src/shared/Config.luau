--!strict
-- General tunables. Character balance numbers live in Characters/<Name>.luau instead.

return {
	Dummy = {
		MaxHealth = 500,
		-- Seconds without taking damage before a dummy heals back to full.
		RegenDelay = 4,
		RespawnTime = 3,
		-- A dummy knocked further than this from its spot gets put back.
		MaxDrift = 60,
		-- Where dummies stand, relative to the first SpawnLocation (studs, -Z is in front of it).
		Offsets = {
			Vector3.new(-8, 0, -22),
			Vector3.new(8, 0, -22),
		},
	},
}
