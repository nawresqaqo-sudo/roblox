--!strict
-- On-screen stuff: a "hold to slide" hint for new players, anime speed lines while sliding,
-- the KO feed (top right), and the big KO / streak popups.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Sfx = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Sfx"))
local CameraFx = require(script.Parent.CameraFx)
local SlideController = require(script.Parent.SlideController)

local TAU = math.pi * 2
local HINT_SLIDES = 3 -- the hint disappears after this many slides
local LINE_COUNT = 18
local FEED_SIZE = 5
local FEED_TIME = 5
local FONT = Enum.Font.LuckiestGuy

local STREAK_CALLOUTS: { [number]: string } = {
	[2] = "DOUBLE KO!",
	[3] = "TRIPLE KO!",
	[4] = "QUAD KO!",
	[5] = "RAMPAGE!",
	[7] = "UNSTOPPABLE!",
	[10] = "GODLIKE!",
}

type SpeedLine = {
	frame: Frame,
	age: number,
	life: number,
	angle: number,
	from: number,
	to: number,
}

local Hud = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local hint: TextLabel
local hintGone = false
local linesFrame: Frame
local feed: Frame
local popupSlot: Frame
local speedLines: { SpeedLine } = {}
local lineStrength = 0
local feedOrder = 0

local function label(props: { [string]: any }): TextLabel
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = FONT
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextScaled = true
	for key, value in props do
		(text :: any)[key] = value
	end
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 20, 28)
	stroke.Parent = text
	return text
end

local function fadeOut(text: TextLabel, time: number)
	TweenService:Create(text, TweenInfo.new(time), { TextTransparency = 1 }):Play()
	local stroke = text:FindFirstChildOfClass("UIStroke")
	if stroke then
		TweenService:Create(stroke, TweenInfo.new(time), { Transparency = 1 }):Play()
	end
end

-- Speed lines ------------------------------------------------------------------------------------

local function resetLine(line: SpeedLine)
	line.age = 0
	line.life = 0.18 + math.random() * 0.15
	line.angle = math.random() * TAU
	line.from = 0.75 + math.random() * 0.35
	line.to = line.from - (0.2 + math.random() * 0.15)
end

local function updateSpeedLines(dt: number)
	local goal = SlideController.intensity()
	lineStrength += (goal - lineStrength) * math.min(1, dt * 8)
	local visible = lineStrength > 0.02
	linesFrame.Visible = visible
	if not visible then
		return
	end

	local size = linesFrame.AbsoluteSize
	local center = size / 2
	local radius = math.max(size.X, size.Y) / 2
	for _, line in speedLines do
		line.age += dt
		if line.age >= line.life then
			resetLine(line)
		end
		local t = line.age / line.life
		local distance = (line.from + (line.to - line.from) * t) * radius
		local direction = Vector2.new(math.cos(line.angle), math.sin(line.angle))
		local spot = center + direction * distance
		line.frame.Position = UDim2.fromOffset(spot.X, spot.Y)
		line.frame.Size = UDim2.fromOffset(radius * 0.25, 2)
		line.frame.Rotation = math.deg(line.angle)
		line.frame.BackgroundTransparency = 1 - math.sin(t * math.pi) * 0.75 * lineStrength
	end
end

-- KO feed and popups -----------------------------------------------------------------------------

local function addFeedEntry(text: string, color: Color3)
	feedOrder += 1
	local entry = label({
		LayoutOrder = -feedOrder, -- newest on top
		Size = UDim2.new(1, 0, 0, 24),
		Text = text,
		TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = feed,
	})
	local entries = {}
	for _, child in feed:GetChildren() do
		if child:IsA("TextLabel") then
			table.insert(entries, child)
		end
	end
	if #entries > FEED_SIZE then
		table.sort(entries, function(a, b)
			return a.LayoutOrder > b.LayoutOrder
		end)
		entries[#entries]:Destroy()
	end
	task.delay(FEED_TIME, function()
		if entry.Parent then
			fadeOut(entry, 0.4)
			task.delay(0.45, function()
				entry:Destroy()
			end)
		end
	end)
end

local function popup(title: string, subtitle: string?, color: Color3)
	popupSlot:ClearAllChildren()
	local main = label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromScale(1, 0.6),
		Text = title,
		TextColor3 = color,
		Parent = popupSlot,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 1.8
	scale.Parent = main
	TweenService:Create(scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()

	local labels = { main }
	if subtitle then
		local sub = label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.fromScale(0.5, 0.62),
			Size = UDim2.fromScale(0.8, 0.38),
			Text = subtitle,
			TextColor3 = Color3.fromRGB(255, 225, 70),
			Parent = popupSlot,
		})
		table.insert(labels, sub)
	end
	task.delay(1.6, function()
		for _, text in labels do
			if text.Parent then
				fadeOut(text, 0.4)
			end
		end
	end)
end

local function onKnockout(attacker: unknown, victimName: unknown, victim: unknown, streak: unknown)
	if typeof(victimName) ~= "string" then
		return
	end
	local attackerPlayer = if typeof(attacker) == "Instance" and attacker:IsA("Player") then attacker else nil
	local streakCount = if typeof(streak) == "number" then streak else 0

	if attackerPlayer then
		addFeedEntry(`{attackerPlayer.DisplayName} knocked off {victimName}`, Color3.new(1, 1, 1))
	else
		addFeedEntry(`{victimName} fell off`, Color3.fromRGB(190, 190, 200))
	end

	if attackerPlayer == player then
		local callout = STREAK_CALLOUTS[streakCount]
		if not callout and streakCount > 10 then
			callout = `GODLIKE x{streakCount}!`
		end
		popup(`KNOCKED OFF {string.upper(victimName)}!`, callout, Color3.new(1, 1, 1))
		Sfx.play(Config.Sounds.Knockout, 0.8)
		CameraFx.punch(4)
	elseif victim == player and attackerPlayer then
		popup(`KNOCKED OFF BY {string.upper(attackerPlayer.DisplayName)}`, nil, Color3.fromRGB(255, 110, 100))
	end
end

-- Setup ------------------------------------------------------------------------------------------

function Hud.init()
	gui = Instance.new("ScreenGui")
	gui.Name = "RooftopHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5

	linesFrame = Instance.new("Frame")
	linesFrame.Name = "SpeedLines"
	linesFrame.BackgroundTransparency = 1
	linesFrame.Size = UDim2.fromScale(1, 1)
	linesFrame.Visible = false
	linesFrame.Parent = gui
	for _ = 1, LINE_COUNT do
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundColor3 = Color3.new(1, 1, 1)
		frame.BorderSizePixel = 0
		frame.Parent = linesFrame
		local line: SpeedLine = { frame = frame, age = 0, life = 1, angle = 0, from = 1, to = 1 }
		resetLine(line)
		line.age = math.random() * line.life -- start them at different points
		table.insert(speedLines, line)
	end

	local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	hint = label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -40),
		Size = UDim2.new(0.8, 0, 0, 34),
		Text = if mobile then "HOLD THE SCREEN TO SLIDE" else "HOLD CLICK OR C TO SLIDE",
		Parent = gui,
	})

	feed = Instance.new("Frame")
	feed.Name = "KnockoutFeed"
	feed.AnchorPoint = Vector2.new(1, 0)
	feed.Position = UDim2.new(1, -16, 0, 70)
	feed.Size = UDim2.fromOffset(340, 160)
	feed.BackgroundTransparency = 1
	feed.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 4)
	layout.Parent = feed

	popupSlot = Instance.new("Frame")
	popupSlot.Name = "Popup"
	popupSlot.AnchorPoint = Vector2.new(0.5, 0)
	popupSlot.Position = UDim2.fromScale(0.5, 0.2)
	popupSlot.Size = UDim2.new(0.9, 0, 0, 90)
	popupSlot.BackgroundTransparency = 1
	popupSlot.Parent = gui

	gui.Parent = player:WaitForChild("PlayerGui")
end

function Hud.start()
	Net.remote("Knockout").OnClientEvent:Connect(onKnockout)
	RunService.RenderStepped:Connect(function(dt: number)
		updateSpeedLines(dt)
		if not hintGone and SlideController.slideCount() >= HINT_SLIDES then
			hintGone = true
			fadeOut(hint, 0.5)
			task.delay(0.6, function()
				hint:Destroy()
			end)
		end
	end)
end

return Hud
