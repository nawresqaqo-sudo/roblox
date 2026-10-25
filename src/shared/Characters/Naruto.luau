--!strict
-- Teen Naruto: what the UI shows (Info) and every balance number for his moves (Tuning).
-- The server reads Tuning for damage and timing; the client reads it so visuals line up.
local Types = require(script.Parent.Parent.Types)

local Info: Types.CharacterInfo = {
	Id = "Naruto",
	DisplayName = "Naruto",
	Subtitle = "Teen | Hidden Leaf",
	Series = "Naruto",
	Description = "Knucklehead ninja. Floods the field with clones and Rasengans.",
	Available = true,
	AccentColor = Color3.fromRGB(255, 140, 30),
	Moves = {
		{
			Slot = 1,
			Name = "Rasengan",
			Description = "Dash forward with a spinning chakra sphere and blast the target away.",
			Kind = "Normal",
			Cooldown = 6,
			AnimationId = "",
		},
		{
			Slot = 2,
			Name = "Shadow Clone Jutsu",
			Description = "Clones rush the nearest enemy and beat them up.",
			Kind = "Normal",
			Cooldown = 12,
			AnimationId = "",
		},
		{
			Slot = 3,
			Name = "Double Rasengan",
			Description = "A clone joins in and you hit back to back.",
			Kind = "Normal",
			Cooldown = 10,
			AnimationId = "",
		},
		{
			Slot = 4,
			Name = "Giant Rasengan",
			Description = "Form a huge Rasengan with a clone, then ram it into everything ahead.",
			Kind = "Ult",
			Cooldown = 25,
			AnimationId = "",
		},
		{
			Slot = 5,
			Name = "Rasenshuriken",
			Description = "Quick cutscene, then throw a Rasenshuriken that bursts into a shredding dome.",
			Kind = "BigUlt",
			Cooldown = 45,
			AnimationId = "",
		},
	},
}

local Tuning = {
	Rasengan = {
		Windup = 0.3, -- seconds holding the sphere before the dash
		DashSpeed = 75,
		DashTime = 0.35,
		Damage = 15,
		Knockback = 60,
		Stun = 0.8,
		Scale = 1.3, -- sphere size
	},
	ShadowClone = {
		Count = 3,
		SummonTime = 0.4,
		Lifetime = 6,
		SearchRange = 80, -- how far clones look for someone to attack
		RunSpeed = 30,
		PunchRange = 4.5,
		PunchDamage = 2,
		PunchInterval = 0.45,
		PunchesEach = 4,
		PunchAnimationId = "", -- optional punch animation for the clones
	},
	DoubleRasengan = {
		Windup = 0.5,
		DashSpeed = 80,
		DashTime = 0.4,
		HitDamage = 10,
		Hits = 2,
		Knockback = 85,
		Stun = 1,
		Scale = 1.3,
	},
	GiantRasengan = {
		Charge = 1,
		DashSpeed = 65,
		DashTime = 0.5,
		Damage = 28,
		Knockback = 110,
		Stun = 1.2,
		Scale = 6,
		HitboxSize = 10,
	},
	Rasenshuriken = {
		Charge = 1.8, -- also the cutscene length
		Speed = 110,
		MaxFlightTime = 1.2,
		HitRadius = 4,
		BlastRadius = 14,
		BlastTicks = 6,
		TickInterval = 0.2,
		TickDamage = 4,
		FinalDamage = 12,
		Knockback = 100,
	},
}

return {
	Info = Info,
	Tuning = Tuning,
}
