--!strict
-- Finds characters (players, dummies, NPCs) inside an area. Shadow clones never count as targets.
local Hitbox = {}

-- The character (alive or not) a part belongs to, if any.
local function characterOf(part: BasePart): Model?
	local model = part:FindFirstAncestorWhichIsA("Model")
	-- Workspace is itself a Model, so stop there or the whole map would count as a character.
	while model and model ~= workspace do
		if model:FindFirstChildOfClass("Humanoid") then
			return model
		end
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	return nil
end

local function targetFromPart(part: BasePart): Model?
	local model = characterOf(part)
	local humanoid = if model then model:FindFirstChildOfClass("Humanoid") else nil
	if not model or not humanoid or humanoid.Health <= 0 or model:GetAttribute("IsClone") then
		return nil
	end
	return model
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

-- Everyone within `radius` of a point on the ground (measured flat), up to `height` above or below it.
function Hitbox.cylinder(base: Vector3, radius: number, height: number, ignore: { Instance }): { Model }
	local result: { Model } = {}
	for _, model in Hitbox.box(CFrame.new(base), Vector3.new(radius * 2, height * 2, radius * 2), ignore) do
		local root = Hitbox.rootOf(model)
		local position = if root then root.Position else model:GetPivot().Position
		-- A little slack so someone whose body is in the circle counts even if their middle isn't.
		if Vector3.new(position.X - base.X, 0, position.Z - base.Z).Magnitude <= radius + 1.5 then
			table.insert(result, model)
		end
	end
	return result
end

-- The first character on a straight path `width` studs wide, and how far along the path it stands.
function Hitbox.firstAlong(
	from: Vector3,
	direction: Vector3,
	length: number,
	width: number,
	ignore: { Instance }
): (Model?, number)
	local center = from + direction * (length / 2)
	local best: Model? = nil
	local bestDistance = math.huge
	for _, model in Hitbox.box(CFrame.lookAt(center, center + direction), Vector3.new(width, 7, length), ignore) do
		local distance = (model:GetPivot().Position - from):Dot(direction)
		if distance < bestDistance then
			best, bestDistance = model, distance
		end
	end
	return best, bestDistance
end

-- The first piece of the map a ray hits. Characters don't block it, and neither do parts you can walk
-- through (decorations, effects).
function Hitbox.raycastMap(origin: Vector3, direction: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.RespectCanCollide = true
	for _ = 1, 8 do
		local hit = workspace:Raycast(origin, direction, params)
		if not hit then
			return nil
		end
		local character = characterOf(hit.Instance)
		if not character then
			return hit
		end
		params:AddToFilter(character)
	end
	return nil
end

-- True if no wall stands between `from` and the middle of `target`.
function Hitbox.canSee(from: Vector3, target: Model, ignore: { Instance }): boolean
	local root = Hitbox.rootOf(target)
	local to = if root then root.Position else target:GetPivot().Position
	return Hitbox.raycastMap(from, to - from, ignore) == nil
end

function Hitbox.rootOf(model: Model): BasePart?
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return model.PrimaryPart
end

return Hitbox
