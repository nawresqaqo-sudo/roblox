--!strict
-- Finds characters (players, dummies, NPCs) inside an area. Shadow clones never count as targets.
local Hitbox = {}

local function targetFromPart(part: BasePart): Model?
	local model = part:FindFirstAncestorWhichIsA("Model")
	-- Workspace is itself a Model, so stop there or the whole map would count as a target.
	while model and model ~= workspace do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.Health <= 0 or model:GetAttribute("IsClone") then
				return nil
			end
			return model
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

local function collect(parts: { BasePart }): { Model }
	local seen: { [Model]: boolean } = {}
	local result: { Model } = {}
	for _, part in parts do
		local model = targetFromPart(part)
		if model and not seen[model] then
			seen[model] = true
			table.insert(result, model)
		end
	end
	return result
end

local function overlapParams(ignore: { Instance }): OverlapParams
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	return params
end

function Hitbox.box(cframe: CFrame, size: Vector3, ignore: { Instance }): { Model }
	return collect(workspace:GetPartBoundsInBox(cframe, size, overlapParams(ignore)))
end

function Hitbox.sphere(position: Vector3, radius: number, ignore: { Instance }): { Model }
	return collect(workspace:GetPartBoundsInRadius(position, radius, overlapParams(ignore)))
end

-- Box sitting directly in front of a part (used while dashing).
function Hitbox.inFront(part: BasePart, size: Vector3, ignore: { Instance }): { Model }
	return Hitbox.box(part.CFrame * CFrame.new(0, 0, -size.Z / 2), size, ignore)
end

function Hitbox.nearest(position: Vector3, range: number, ignore: { Instance }): Model?
	local best: Model? = nil
	local bestDistance = math.huge
	for _, model in Hitbox.sphere(position, range, ignore) do
		local distance = (model:GetPivot().Position - position).Magnitude
		if distance < bestDistance then
			best = model
			bestDistance = distance
		end
	end
	return best
end

function Hitbox.rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

return Hitbox
