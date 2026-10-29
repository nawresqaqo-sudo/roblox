--!strict
-- Sasuke Uchiha in his Taka days (the fight with Itachi): what the UI shows (Info), every balance number
-- and timing for his moves (Tuning) and the sound for each moment of them (Sounds). The client reads
-- all of it too, so visuals and sounds line up with what the server does.
local Types = require(script.Parent.Parent.Types)

local Info: Types.CharacterInfo = {
	Id = "Sasuke",
	DisplayName = "Sasuke",
	Subtitle = "Taka | Mangekyo Sharingan",
	Series = "Naruto Shippuden",
	Description = "Chidori, Uchiha fire and the Mangekyo. Calm, precise and terrifyingly fast.",
	Available = true,
	AccentColor = Color3.fromRGB(140, 80, 255),
	Moves = {
		{
			Slot = 1,
			Name = "Chidori",
			Description = "Lightning Assault: lightning gathers in his hand, then a blinding dash and a thrust into whoever stands in the way.",
			Kind = "Normal",
			Cooldown = 8,
			AnimationId = "",
			Glyph = "千鳥",
		},
		{
			Slot = 2,
			Name = "Phoenix Flower",
			Description = "Fire Style: Phoenix Flower Jutsu. A fan of fireballs, each hiding a shuriken.",
			Kind = "Normal",
			Cooldown = 10,
			AnimationId = "",
			Glyph = "鳳仙花",
		},
		{
			Slot = 3,
			Name = "Amaterasu",
			Description = "Black Flame Curse: whoever he looks at bursts into black flames that won't go out, and the ground keeps burning.",
			Kind = "Normal",
			Cooldown = 14,
			AnimationId = "",
			Glyph = "天照",
		},
		{
			Slot = 4,
			Name = "Kirin",
			Description = "Heavenly Lightning Devastation: he raises his arm, a storm gathers, and a dragon of lightning falls on the marked ground.",
			Kind = "Ult",
			Cooldown = 45,
			AnimationId = "",
			Glyph = "麒麟",
		},
	},
}

local Tuning = {
	Chidori = {
		Charge = 0.34, -- lightning forms in his hand
		DashSpeed = 105,
		MaxDashTime = 0.3, -- so the dash covers at most ~31 studs
		StopShort = 3, -- the dash ends this far in front of the enemy it was aimed at
		HitWidth = 6, -- how wide the path is when looking for someone in the way
		HitRadius = 4.5, -- the thrust lands if the enemy is still this close to where he stops
		Damage = 15,
		Knockback = 55,
		Lift = 0.3,
		Stun = 0.7,
		Recovery = 0.35,
	},
	PhoenixFlower = {
		Signs = 0.3, -- hand signs before the first fireball (the only time he can't walk)
		Count = 5,
		Interval = 0.075,
		Speed = 95,
		MaxFlightTime = 0.85,
		HitRadius = 2.6,
		Damage = 4, -- per fireball
		Knockback = 14,
		Stun = 0.35,
		-- Per fireball: angle off his aim (degrees), sideways curve and lift (studs).
		Spread = { -9, 6, -3, 10, 0 },
		Bend = { 1.6, -1.3, 0.9, -1.8, 0.4 },
		Rise = { 0.5, 1.1, 0.2, 0.8, 0.3 },
	},
	Amaterasu = {
		Cast = 0.42, -- the Mangekyo opens
		Mark = 0.32, -- a black-purple distortion on the target before the flames erupt
		Range = 55,
		ConeAngle = 40, -- degrees either side of where he faces; walls block his sight
		BurstRadius = 6,
		BurstDamage = 8,
		Stun = 0.45,
		BurnTime = 3, -- a target keeps burning this long after it last caught fire
		TickInterval = 0.5,
		TickDamage = 2.5,
		MaxBurnTime = 6.5, -- however often it's refreshed, one burn never lasts longer than this
		PatchTime = 3.5, -- the ground keeps burning this long; walking through it sets you on fire
		PatchRadius = 7,
		AheadDistance = 24, -- where the flames go when nobody is in sight
	},
	Kirin = {
		LockRange = 75, -- the nearest enemy in front this close is where Kirin falls
		AheadDistance = 38, -- otherwise it falls this far ahead
		Buildup = 0.9, -- arm raised to the sky while the storm gathers
		TelegraphAt = 0.25, -- the warning circle appears this far into the buildup...
		Anticipation = 0.75, -- ...and the strike lands this long after the buildup
		Radius = 18,
		Height = 14, -- how far above and below the ground the strike reaches
		Damage = 40,
		Knockback = 85,
		Lift = 0.6,
		Stun = 1.4,
		Recovery = 0.45,
		SkyTime = 3.4, -- how long the sky stays stormy
	},
}

-- Sound for each moment of the moves. "" plays a built-in stand-in (Roblox's own wind and landing
-- sounds reshaped with sound effects, see Client > Vfx > Sasuke > Kit). For the real thing, paste a
-- sound you're allowed to use from the Creator Store, e.g. "rbxassetid://1234567890".
local Sounds = {
	ChidoriCharge = "", -- rising crackle as lightning gathers in his hand
	ChidoriCrackle = "", -- the chirping crackle while Chidori is lit (loops)
	ChidoriDash = "",
	ChidoriImpact = "",
	ChidoriResidual = "", -- leftover electricity on whoever got hit
	PhoenixSigns = "", -- hand signs
	PhoenixIgnite = "",
	PhoenixLaunch = "", -- each fireball leaving
	PhoenixFlight = "", -- air rushing past each fireball (loops)
	PhoenixImpact = "",
	AmaterasuActivate = "", -- the Mangekyo opening
	AmaterasuTone = "", -- low, unnatural hum
	AmaterasuIgnite = "",
	AmaterasuBurn = "", -- lingering black flames (loops)
	AmaterasuEnd = "", -- the flames collapsing
	KirinRumble = "", -- the storm gathering (loops)
	KirinTension = "", -- electricity building up
	KirinCue = "", -- the beat right before it lands
	KirinThunder = "",
	KirinShockwave = "",
	KirinResidual = "", -- crackling after the strike
}

-- Where a Phoenix Flower fireball is `t` seconds after leaving his mouth. `bend` curves it sideways and
-- `rise` lifts it, both easing back to its straight line by the end. The server and every client use
-- this, so the flames are drawn exactly where the hits are checked.
local function fireballPosition(origin: Vector3, direction: Vector3, bend: number, rise: number, t: number): Vector3
	local f = Tuning.PhoenixFlower
	local right = direction:Cross(Vector3.yAxis)
	right = if right.Magnitude > 1e-3 then right.Unit else Vector3.xAxis
	local sway = math.sin(math.clamp(t / f.MaxFlightTime, 0, 1) * math.pi)
	return origin + direction * f.Speed * t + right * bend * sway + Vector3.yAxis * rise * sway
end

return {
	Info = Info,
	Tuning = Tuning,
	Sounds = Sounds,
	fireballPosition = fireballPosition,
}
