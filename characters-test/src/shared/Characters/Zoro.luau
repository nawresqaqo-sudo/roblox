--!strict
-- Roronoa Zoro as he fought in the Raid on Onigashima: what the UI shows (Info) and every balance
-- number and timing for his moves (Tuning). The client reads Tuning too, so visuals line up.
local Types = require(script.Parent.Parent.Types)

local Info: Types.CharacterInfo = {
	Id = "Zoro",
	DisplayName = "Zoro",
	Subtitle = "Onigashima | King of Hell",
	Series = "One Piece",
	Description = "Three Sword Style. Cuts down calamities, scars Emperors.",
	Available = true,
	AccentColor = Color3.fromRGB(70, 200, 110),
	Moves = {
		{
			Slot = 1,
			Name = "Onigiri",
			Description = "Three Sword Style: dash straight through with all three blades. The cut lands a beat later.",
			Kind = "Normal",
			Cooldown = 7,
			AnimationId = "",
		},
		{
			Slot = 2,
			Name = "Bird Dance",
			Description = "One Sword Style: a Conqueror's-coated flying slash that cuts through everything in a line.",
			Kind = "Normal",
			Cooldown = 9,
			AnimationId = "",
		},
		{
			Slot = 3,
			Name = "Black Rope Dragon Twister",
			Description = "Three Sword Style: spin into a tornado of haki-black slashes that throws everyone up.",
			Kind = "Normal",
			Cooldown = 12,
			AnimationId = "",
		},
		{
			Slot = 4,
			Name = "Dragon Damnation",
			Description = "King of Hell Three Sword Style: 103 Mercies Dragon Damnation. The sky goes black, Zoro leaps into the sky and dives down with a flying dragon. How he beat King.",
			Kind = "Ult",
			Cooldown = 40,
			AnimationId = "",
		},
		{
			Slot = 5,
			Name = "Asura",
			Description = "Nine Sword Style Asura: Blades Drawn, Dance of the Dead. Three heads, six arms, nine swords. The cut that scarred Kaido.",
			Kind = "BigUlt",
			Cooldown = 55,
			AnimationId = "",
		},
	},
}

local Tuning = {
	StanceLinger = 2.5, -- seconds the swords stay drawn after a move
	Onigiri = {
		Windup = 0.3,
		DashTime = 0.16,
		DashSpeed = 150,
		CutDelay = 0.25, -- the cut lands this long after Zoro has passed through
		Damage = 12,
		Knockback = 60,
		Stun = 1,
		HitWidth = 8,
	},
	BirdDance = {
		Windup = 0.35,
		Speed = 120,
		MaxFlightTime = 0.75,
		HitRadius = 5,
		Damage = 14,
		Knockback = 65,
		Stun = 0.8,
	},
	DragonTwister = {
		Windup = 0.15,
		Duration = 1.1,
		Radius = 14,
		Ticks = 5,
		TickDamage = 3,
		FinalDamage = 8,
		Launch = 85,
		Stun = 1.3,
	},
	DragonDamnation = {
		LockRange = 40, -- the nearest enemy this close gets locked in place for the whole ult
		Charge = 1.3, -- aura, black sky, red lightning
		RiseTime = 0.5,
		RiseSpeed = 95,
		Hover = 0.7, -- the dragon forms around Zoro in the sky
		DiveSpeed = 220,
		MaxDiveTime = 0.7,
		Radius = 18,
		Damage = 38,
		Knockback = 120,
		Stun = 1.5,
		SkyTime = 4.2, -- how long the sky stays black
		LandAnimationId = "", -- optional published animation for the landing (move 4's main one is in Info)
	},
	Asura = {
		LockRange = 35,
		Charge = 1.5, -- three heads, six arms, the demon rises behind him
		DashTime = 0.2,
		DashSpeed = 170,
		CutDelay = 0.7, -- nine slashes appear on the target one after another
		HitWidth = 10,
		Slashes = 9,
		SlashDamage = 3,
		FinalDamage = 20,
		Knockback = 115,
		Stun = 1.5,
	},
}

return {
	Info = Info,
	Tuning = Tuning,
}
