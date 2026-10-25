--!strict
-- Short camera sequences for ultimates. Only this player's camera moves.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Ui = require(script.Parent.Ui)

-- One camera move: glides from `from` to `to` over `duration`. Both are functions so shots can
-- follow a moving character.
export type Shot = {
	duration: number,
	from: () -> CFrame,
	to: () -> CFrame,
	fov: number?,
}

local BIND_NAME = "UltimateCutscene"
local BAR_HEIGHT = 0.12

local Cutscene = {}

local playing = false

local function showBars(title: string?, titleAt: number): () -> ()
	local player = Players.LocalPlayer
	local gui: ScreenGui = Ui.new("ScreenGui", {
		Name = "CutsceneBars",
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 50,
	})
	local top: Frame = Ui.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 0),
		Parent = gui,
	})
	local bottom: Frame = Ui.new("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		Parent = gui,
	})
	gui.Parent = player:WaitForChild("PlayerGui")

	local barInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(top, barInfo, { Size = UDim2.fromScale(1, BAR_HEIGHT) }):Play()
	TweenService:Create(bottom, barInfo, { Size = UDim2.fromScale(1, BAR_HEIGHT) }):Play()

	if title then
		task.delay(titleAt, function()
			if not gui.Parent then
				return
			end
			local label = Ui.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.82),
				Size = UDim2.fromScale(0.8, 0.12),
				Font = Enum.Font.GothamBlack,
				Text = title,
				TextScaled = true,
				TextColor3 = Color3.fromRGB(200, 235, 255),
				Parent = gui,
			})
			Ui.stroke(Color3.fromRGB(20, 60, 140), 3).Parent = label
			local scale = Instance.new("UIScale")
			scale.Scale = 1.6
			scale.Parent = label
			TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		end)
	end

	return function()
		TweenService:Create(top, barInfo, { Size = UDim2.fromScale(1, 0) }):Play()
		TweenService:Create(bottom, barInfo, { Size = UDim2.fromScale(1, 0) }):Play()
		task.delay(0.25, function()
			gui:Destroy()
		end)
	end
end

function Cutscene.isPlaying(): boolean
	return playing
end

-- Plays the shots back to back, then hands the camera back to the player.
function Cutscene.play(shots: { Shot }, title: string?)
	if playing or #shots == 0 then
		return
	end
	playing = true

	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local oldFov = camera.FieldOfView
	local total = 0
	for _, shot in shots do
		total += shot.duration
	end

	camera.CameraType = Enum.CameraType.Scriptable
	local hideBars = showBars(title, math.max(total - 0.7, 0))
	local start = os.clock()
	local finished = false

	local function finish()
		if finished then
			return
		end
		finished = true
		RunService:UnbindFromRenderStep(BIND_NAME)
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = oldFov
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
		hideBars()
		playing = false
	end

	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local elapsed = os.clock() - start
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if elapsed >= total or not humanoid or humanoid.Health <= 0 then
			finish()
			return
		end
		local shotStart = 0
		for _, shot in shots do
			if elapsed < shotStart + shot.duration then
				local alpha = (elapsed - shotStart) / shot.duration
				local eased = TweenService:GetValue(alpha, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
				camera.CFrame = shot.from():Lerp(shot.to(), eased)
				if shot.fov then
					camera.FieldOfView = shot.fov
				end
				break
			end
			shotStart += shot.duration
		end
	end)
end

return Cutscene
