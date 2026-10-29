--!strict
-- The move bar at the bottom of the screen. Keys 1-5 or Z X C V B (or tapping a slot) ask the server to
-- use a move; the server answers with MoveAccepted and the slot shows its cooldown. Slots take the
-- character's accent color and show the move's icon (or a big glyph until it has one); ultimates get a
-- thicker frame with a shine running around it. Slots pop when a move goes through, pulse when they're
-- ready again, shake if pressed too early, and dim while you're dead. Cooldowns are remembered per
-- character, the same way the server keeps them.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared:WaitForChild("Characters"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Ui = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Ui"))

local KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5,
	[Enum.KeyCode.Z] = 1,
	[Enum.KeyCode.X] = 2,
	[Enum.KeyCode.C] = 3,
	[Enum.KeyCode.V] = 4,
	[Enum.KeyCode.B] = 5,
}
local LETTERS = { "Z", "X", "C", "V", "B" }

local KIND_TAGS: { [Types.MoveKind]: string } = {
	Normal = "",
	Ult = "ULT",
	BigUlt = "MAX",
}

local SLOT_SIZE = 78
local STEEL = Color3.fromRGB(90, 90, 105)
local GOLD = Color3.fromRGB(255, 190, 60)
local SHINE = Color3.fromRGB(205, 232, 255)
local DENIED = Color3.fromRGB(255, 70, 70)
local WHITE = Color3.new(1, 1, 1)

type Slot = {
	button: TextButton,
	scale: UIScale,
	overlay: Frame,
	progress: Frame,
	timer: TextLabel,
	stroke: UIStroke,
	shine: UIGradient?,
	color: Color3,
	cooldown: number,
	endsAt: number,
	ready: boolean,
}

local MovesHotbar = {}

local player = Players.LocalPlayer
local bar: Frame
local slots: { [number]: Slot } = {}
local currentId: string? = nil
-- Character id -> slot -> server time its cooldown ends.
local readyAt: { [string]: { [number]: number } } = {}

local function tween(instance: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?)
	TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goals)
		:Play()
end

local function kindColor(kind: Types.MoveKind, accent: Color3): Color3
	if kind == "BigUlt" then
		return GOLD
	elseif kind == "Ult" then
		return accent
	end
	return STEEL:Lerp(accent, 0.25)
end

-- Pressed too early: the frame flashes red and the slot shakes.
local function deny(slot: Slot)
	slot.stroke.Color = DENIED
	tween(slot.stroke, 0.35, { Color = slot.color })
	slot.button.Rotation = 6
	tween(slot.button, 0.3, { Rotation = 0 }, Enum.EasingStyle.Elastic)
end

-- The move went through: the slot pops.
local function pop(slot: Slot)
	slot.scale.Scale = 0.88
	tween(slot.scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	slot.stroke.Color = WHITE
	tween(slot.stroke, 0.3, { Color = slot.color })
end

-- Ready again: a bright pulse.
local function pulse(slot: Slot)
	slot.scale.Scale = 1.1
	tween(slot.scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	slot.stroke.Color = WHITE
	tween(slot.stroke, 0.5, { Color = slot.color })
end

local function useMove(index: number)
	local slot = slots[index]
	if not slot then
		return
	end
	if workspace:GetServerTimeNow() < slot.endsAt then
		deny(slot)
		return
	end
	Net.remote("UseMove"):FireServer(index)
end

local function buildSlot(move: Types.MoveInfo, accent: Color3): Slot
	local color = kindColor(move.Kind, accent)
	local isUlt = move.Kind ~= "Normal"
	local stroke = Ui.stroke(color, if isUlt then 3 else 2)
	local shine: UIGradient? = nil
	if isUlt then
		shine = Ui.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, color),
				ColorSequenceKeypoint.new(0.42, color),
				ColorSequenceKeypoint.new(0.5, SHINE),
				ColorSequenceKeypoint.new(0.58, color),
				ColorSequenceKeypoint.new(1, color),
			}),
			Parent = stroke,
		})
	end
	local scale: UIScale = Ui.new("UIScale")
	local overlay: Frame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, { Ui.corner(10) })
	local progress: Frame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 8, 1, -5),
		Size = UDim2.new(0, 0, 0, 3),
		BackgroundColor3 = accent:Lerp(WHITE, 0.35),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 5,
	}, { Ui.corner(2) })
	local timer = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		Text = "",
		ZIndex = 4,
	})
	local letter = LETTERS[move.Slot]
	local children: { Instance } = {
		Ui.corner(10),
		stroke,
		scale,
		overlay,
		progress,
		timer,
		Ui.new("UIGradient", {
			Color = ColorSequence.new(Color3.fromRGB(36, 32, 48), Color3.fromRGB(10, 9, 14)),
			Rotation = 90,
		}),
		Ui.label({
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(40, 14),
			Font = Enum.Font.GothamBlack,
			TextSize = 12,
			Text = if letter then `{move.Slot}·{letter}` else tostring(move.Slot),
			TextColor3 = color:Lerp(WHITE, 0.55),
			TextXAlignment = Enum.TextXAlignment.Left,
			Visible = UserInputService.KeyboardEnabled,
			ZIndex = 2,
		}),
	}

	-- The art: an image if the move has one, otherwise its glyph drawn big, otherwise just the name.
	local art: Instance? = nil
	if move.Icon and move.Icon ~= "" then
		art = Ui.new("ImageLabel", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.44),
			Size = UDim2.fromScale(0.52, 0.52),
			BackgroundTransparency = 1,
			Image = move.Icon,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 2,
		})
	elseif move.Glyph and move.Glyph ~= "" then
		art = Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.45),
			Size = UDim2.new(1, -10, 0.44, 0),
			Font = Enum.Font.GothamBlack,
			Text = move.Glyph,
			TextScaled = true,
			TextColor3 = color:Lerp(WHITE, 0.75),
			ZIndex = 2,
		}, { Ui.new("UITextSizeConstraint", { MaxTextSize = 30 }) })
	end
	if art then
		table.insert(children, art)
		table.insert(
			children,
			Ui.label({
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -9),
				Size = UDim2.new(1, -8, 0, 13),
				Text = move.Name,
				TextScaled = true,
				ZIndex = 2,
			}, { Ui.new("UITextSizeConstraint", { MaxTextSize = 11 }) })
		)
	else
		table.insert(
			children,
			Ui.label({
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.55),
				Size = UDim2.new(1, -8, 0.6, 0),
				Text = move.Name,
				TextWrapped = true,
				TextScaled = true,
				ZIndex = 2,
			}, { Ui.new("UITextSizeConstraint", { MaxTextSize = 14 }) })
		)
	end
	local tag = KIND_TAGS[move.Kind]
	if tag ~= "" then
		table.insert(
			children,
			Ui.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -6, 0, 4),
				Size = UDim2.fromOffset(36, 14),
				Font = Enum.Font.GothamBlack,
				TextSize = 11,
				Text = tag,
				TextColor3 = color:Lerp(WHITE, 0.2),
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 2,
			})
		)
	end

	local width = if isUlt then SLOT_SIZE + 10 else SLOT_SIZE
	local button: TextButton = Ui.new("TextButton", {
		Name = `Slot{move.Slot}`,
		LayoutOrder = move.Slot,
		Size = UDim2.fromOffset(width, SLOT_SIZE),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.05,
		Parent = bar,
	}, children)
	button.Activated:Connect(function()
		useMove(move.Slot)
	end)

	return {
		button = button,
		scale = scale,
		overlay = overlay,
		progress = progress,
		timer = timer,
		stroke = stroke,
		shine = shine,
		color = color,
		cooldown = move.Cooldown,
		endsAt = 0,
		ready = true,
	}
end

local function rebuild()
	for _, slot in slots do
		slot.button:Destroy()
	end
	table.clear(slots)

	local id = player:GetAttribute("Character")
	local info = if typeof(id) == "string" then Characters.ById[id] else nil
	currentId = if info then info.Id else nil
	bar.Visible = info ~= nil
	if not info then
		return
	end
	local remembered = readyAt[info.Id] or {}
	local now = workspace:GetServerTimeNow()
	for _, move in info.Moves do
		local slot = buildSlot(move, info.AccentColor)
		slot.endsAt = remembered[move.Slot] or 0
		slot.ready = slot.endsAt <= now
		slots[move.Slot] = slot
	end
end

local function onMoveAccepted(data: unknown)
	if typeof(data) ~= "table" then
		return
	end
	local accepted = data :: Types.MoveAccepted
	if typeof(accepted.Slot) ~= "number" or typeof(accepted.EndsAt) ~= "number" then
		return
	end
	local id = if typeof(accepted.Character) == "string" then accepted.Character else currentId
	if not id then
		return
	end
	local remembered = readyAt[id] or {}
	readyAt[id] = remembered
	remembered[accepted.Slot] = accepted.EndsAt
	local slot = slots[accepted.Slot]
	if slot and id == currentId then
		slot.endsAt = accepted.EndsAt
		slot.ready = false
		pop(slot)
	end
end

local function updateCooldowns()
	local now = workspace:GetServerTimeNow()
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local alive = humanoid ~= nil and humanoid.Health > 0
	local spin = (os.clock() * 140) % 360
	for _, slot in slots do
		if slot.shine then
			slot.shine.Rotation = spin
		end
		local remaining = slot.endsAt - now
		if not alive then
			slot.overlay.Size = UDim2.fromScale(1, 1)
			slot.progress.Visible = false
			slot.timer.Text = ""
		elseif remaining > 0 then
			local left = math.clamp(remaining / slot.cooldown, 0, 1)
			slot.overlay.Size = UDim2.fromScale(1, left)
			slot.progress.Visible = true
			slot.progress.Size = UDim2.new((1 - left), -16 * (1 - left), 0, 3)
			slot.timer.Text = string.format("%.1f", remaining)
		else
			if not slot.ready then
				slot.ready = true
				pulse(slot)
			end
			if slot.timer.Text ~= "" or slot.progress.Visible or slot.overlay.Size.Y.Scale > 0 then
				slot.overlay.Size = UDim2.fromScale(1, 0)
				slot.progress.Visible = false
				slot.timer.Text = ""
			end
		end
	end
end

function MovesHotbar.init()
	-- Number keys would otherwise equip Backpack tools.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)

	local gui: ScreenGui = Ui.new("ScreenGui", {
		Name = "MovesHotbar",
		ResetOnSpawn = false,
		DisplayOrder = 5,
	})
	bar = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(0, SLOT_SIZE),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	gui.Parent = player:WaitForChild("PlayerGui")
end

function MovesHotbar.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		-- `processed` covers typing in chat or any text box; checked twice to be safe.
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local slot = KEYS[input.KeyCode]
		if slot then
			useMove(slot)
		end
	end)
	Net.remote("MoveAccepted").OnClientEvent:Connect(onMoveAccepted)
	player:GetAttributeChangedSignal("Character"):Connect(rebuild)
	RunService.RenderStepped:Connect(updateCooldowns)
	rebuild()
end

return MovesHotbar
