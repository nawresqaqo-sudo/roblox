--!strict
-- Slide hits don't count inside safe zones: any part inside a Workspace folder named "SafeZones"
-- (for example a big invisible, non-collidable box covering the spawn island). No folder = no safe zones.
local SafeZones = {}

function SafeZones.contains(position: Vector3): boolean
	local folder = workspace:FindFirstChild("SafeZones")
	if not folder then
		return false
	end
	for _, zone in folder:GetDescendants() do
		if zone:IsA("BasePart") then
			local offset = zone.CFrame:PointToObjectSpace(position)
			local half = zone.Size / 2
			if math.abs(offset.X) <= half.X and math.abs(offset.Y) <= half.Y and math.abs(offset.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

return SafeZones
