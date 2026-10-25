--!strict
-- Dashes, knockback and movement locks. Constraints made on the server replicate, so these work
-- on player characters too (the player's own client simulates them).
local Movement = {}

local function attachVelocity(root: BasePart, velocity: LinearVelocity, duration: number): () -> ()
	local attachment = Instance.new("Attachment")
	attachment.Name = velocity.Name
	velocity.Attachment0 = attachment
	velocity.RelativeTo = Enum.ActuatorRelativeTo.World
	velocity.MaxForce = math.huge
	velocity.Parent = attachment
	attachment.Parent = root

	local function stop()
		attachment:Destroy()
	end
	task.delay(duration, stop)
	return stop
end

-- Slides the part horizontally (gravity still applies). Returns a function that stops it early.
function Movement.dash(root: BasePart, velocity: Vector3, duration: number): () -> ()
	local constraint = Instance.new("LinearVelocity")
	constraint.Name = "DashVelocity"
	constraint.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	constraint.PrimaryTangentAxis = Vector3.xAxis
	constraint.SecondaryTangentAxis = Vector3.zAxis
	constraint.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	return attachVelocity(root, constraint, duration)
end

-- Forces the part to move at `velocity` for a moment (knockback, pulls).
function Movement.push(root: BasePart, velocity: Vector3, duration: number): () -> ()
	local constraint = Instance.new("LinearVelocity")
	constraint.Name = "Knockback"
	constraint.VectorVelocity = velocity
	return attachVelocity(root, constraint, duration)
end

-- Stops walking and jumping for `duration` seconds. Overlapping freezes extend each other.
function Movement.freeze(humanoid: Humanoid, duration: number)
	if humanoid:GetAttribute("BaseWalkSpeed") == nil then
		humanoid:SetAttribute("BaseWalkSpeed", humanoid.WalkSpeed)
		humanoid:SetAttribute("BaseJumpPower", humanoid.JumpPower)
		humanoid:SetAttribute("BaseJumpHeight", humanoid.JumpHeight)
	end
	local current = humanoid:GetAttribute("FrozenUntil")
	local untilTime = math.max(if typeof(current) == "number" then current else 0, os.clock() + duration)
	humanoid:SetAttribute("FrozenUntil", untilTime)
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0

	task.delay(duration, function()
		local latest = humanoid:GetAttribute("FrozenUntil")
		if not humanoid.Parent or (typeof(latest) == "number" and os.clock() < latest - 0.01) then
			return
		end
		humanoid.WalkSpeed = humanoid:GetAttribute("BaseWalkSpeed") :: number
		humanoid.JumpPower = humanoid:GetAttribute("BaseJumpPower") :: number
		humanoid.JumpHeight = humanoid:GetAttribute("BaseJumpHeight") :: number
	end)
end

-- Holds the part completely still. Releases on its own after `maxDuration` as a safety net.
function Movement.anchor(root: BasePart, maxDuration: number): () -> ()
	root.Anchored = true
	local released = false
	local function release()
		if released then
			return
		end
		released = true
		root.Anchored = false
	end
	task.delay(maxDuration, release)
	return release
end

return Movement
