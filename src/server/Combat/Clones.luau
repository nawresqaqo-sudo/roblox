--!strict
-- Shadow clones: copies of a player's character that the server controls.
local Vfx = require(script.Parent.Vfx)

local FALLBACK_RUN_ANIMATION = "rbxassetid://913376220"

-- Things a copied character must not keep: its scripts, spawn shield, and any move forces.
local REMOVE_CLASSES = {
	"BaseScript",
	"ForceField",
	"LinearVelocity",
	"AngularVelocity",
	"AlignPosition",
	"AlignOrientation",
	"VectorForce",
	"BodyMover",
}

local CLEARED_ATTRIBUTES = { "BaseWalkSpeed", "BaseJumpPower", "BaseJumpHeight", "FrozenUntil" }

local Clones = {}

local folder: Folder? = nil

function Clones.folder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = "ShadowClones"
	created.Parent = workspace
	folder = created
	return created
end

local function shouldRemove(instance: Instance): boolean
	for _, className in REMOVE_CLASSES do
		if instance:IsA(className) then
			return true
		end
	end
	return false
end

local function runAnimationId(clone: Model): string
	local animate = clone:FindFirstChild("Animate")
	local run = animate and animate:FindFirstChild("run")
	local animation = run and run:FindFirstChildOfClass("Animation")
	if animation and animation.AnimationId ~= "" then
		return animation.AnimationId
	end
	return FALLBACK_RUN_ANIMATION
end

local function playRunWhenMoving(humanoid: Humanoid, animationId: string)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = animationId
	local ok, track = pcall(animator.LoadAnimation, animator, animation)
	if not ok then
		return
	end
	track.Looped = true
	humanoid.Running:Connect(function(speed: number)
		if speed > 1 then
			if not track.IsPlaying then
				track:Play(0.1)
			end
		elseif track.IsPlaying then
			track:Stop(0.15)
		end
	end)
end

function Clones.spawn(owner: Player, source: Model, cframe: CFrame): (Model?, Humanoid?)
	local wasArchivable = source.Archivable
	source.Archivable = true
	local clone = source:Clone()
	source.Archivable = wasArchivable
	if not clone then
		return nil, nil
	end

	local runId = runAnimationId(clone)
	for _, descendant in clone:GetDescendants() do
		if shouldRemove(descendant) then
			descendant:Destroy()
		end
	end

	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	local root = clone:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		clone:Destroy()
		return nil, nil
	end

	clone.Name = owner.Name .. "'s Clone"
	clone:SetAttribute("IsClone", true)
	clone:SetAttribute("CloneOwner", owner.UserId)
	clone:SetAttribute("StunnedUntil", nil)
	for _, attribute in CLEARED_ATTRIBUTES do
		humanoid:SetAttribute(attribute, nil)
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.BreakJointsOnDeath = false
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50
	humanoid.JumpHeight = 7.2
	root.Anchored = false

	clone:PivotTo(cframe)
	clone.Parent = Clones.folder()
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	playRunWhenMoving(humanoid, runId)
	return clone, humanoid
end

function Clones.poof(clone: Model)
	if not clone.Parent then
		return
	end
	Vfx.play("Common.Smoke", { position = clone:GetPivot().Position, scale = 1 })
	clone:Destroy()
end

return Clones
