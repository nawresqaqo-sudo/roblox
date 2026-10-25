--!strict
-- Every tunable number in one place. The client uses them for feel; the server re-checks what matters.

return {
	Slide = {
		StartSpeed = 55, -- studs per second when a slide starts
		MinSpeed = 26, -- it slows down to this while you keep holding
		Deceleration = 20, -- speed lost per second
		TurnRate = 2.5, -- how fast you can steer mid-slide (radians per second)
		MinTime = 0.3, -- a quick tap still gives a short slide
		MaxTime = 2.5, -- longest slide while holding
		Cooldown = 0.5, -- wait between slides
		Hitbox = Vector3.new(5, 5, 4), -- area in front of you that counts as a hit
	},
	Knockback = {
		Base = 45, -- launch speed from the slowest slide
		PerSlideSpeed = 1.1, -- extra launch per stud/s of the slider's speed
		Max = 110,
		Lift = 45, -- upward launch
		DownTime = 1.2, -- seconds the victim tumbles before getting up
		SameTargetCooldown = 0.6,
	},
	-- Seconds after a hit that falling off still counts as the hitter's KO.
	KnockoutCreditTime = 8,
	Animation = {
		RunStrideRate = 0.55, -- run cycle speed per stud/s of movement
		RunAmount = 1, -- size of the arm and leg swings (0.5 = subtle, 1.3 = wild)
	},
}
