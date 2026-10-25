--!strict
-- The move bar at the bottom of the screen. Keys 1-5 (or tapping a slot) ask the server to use a
-- move; the server answers with MoveAccepted and the slot shows its cooldown.
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
}

local KIND_COLORS: { [Types.MoveKind]: Color3 } = {
	Normal = Color3.fromRGB(90, 90, 105),
	Ult = Color3.fromRGB(80, 160, 255),
	BigUlt = Color3.fromRGB(255, 190, 60),
}

local KIND_TAGS: { [Types.MoveKind]: string } = {
	Normal = "",
	Ult = "ULT",
	BigUlt = "MAX",
}

local SLOT_SIZE = 78

type Slot = {
	button: TextButton,
	overlay: Frame,
	timer: TextLabel,
	stroke: UIStroke,
	color: Color3,
	cooldown: number,
	endsAt: number,
}

local MovesHotbar = {}

local player = Players.LocalPlayer
local bar: Frame
local slots: { [number]: Slot } = {}

local function flash(slot: Slot)
	slot.stroke.Color = Color3.fromRGB(255, 70, 70)
	TweenService:Create(slot.stroke, TweenInfo.new(0.35), { Color = slot.color }):Play()
end

local function useMove(index: number)
	local slot = slots[index]
	if not slot then
		return
	end
	if workspace:GetServerTimeNow() < slot.endsAt then
		flash(slot)
		return
	end
	Net.remote("UseMove"):FireServer(index)
end

local function buildSlot(move: Types.MoveInfo): Slot
	local color = KIND_COLORS[move.Kind]
	local stroke = Ui.stroke(color, 2)
	local overlay: Frame = Ui.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = 3,
	}, { Ui.corner(10) })
	local timer = Ui.label({
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextSize = 22,
		Text = "",
		ZIndex = 4,
	})

	local children: { Instance } = {
		Ui.corner(10),
		stroke,
		overlay,
		timer,
		Ui.label({
			Position = UDim2.fromOffset(6, 4),
			Size = UDim2.fromOffset(16, 16),
			Font = Enum.Font.GothamBlack,
			Text = tostring(move.Slot),
			TextColor3 = color:Lerp(Color3.new(1, 1, 1), 0.5),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 2,
		}),
		Ui.label({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.55),
			Size = UDim2.new(1, -8, 0.6, 0),
			Text = move.Name,
			TextWrapped = true,
			TextScaled = true,
			ZIndex = 2,
		}, { Ui.new("UITextSizeConstraint", { MaxTextSize = 14 }) }),
	}
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
				TextColor3 = color,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 2,
			})
		)
	end

	local button: TextButton = Ui.new("TextButton", {
		Name = `Slot{move.Slot}`,
		LayoutOrder = move.Slot,
		Size = UDim2.fromOffset(SLOT_SIZE, SLOT_SIZE),
		AutoButtonColor = false,
		Text = "",
		BackgroundColor3 = Color3.fromRGB(22, 22, 28),
		BackgroundTransparency = 0.1,
		Parent = bar,
	}, children)
	button.Activated:Connect(function()
		useMove(move.Slot)
	end)

	return {
		button = button,
		overlay = overlay,
		timer = timer,
		stroke = stroke,
		color = color,
		cooldown = move.Cooldown,
		endsAt = 0,
	}
end

local function rebuild()
	for _, slot in slots do
		slot.button:Destroy()
	end
	table.clear(slots)

	local id = player:GetAttribute("Character")
	local info = if typeof(id) == "string" then Characters.ById[id] else nil
	bar.Visible = info ~= nil
	if not info then
		return
	end
	for _, move in info.Moves do
		slots[move.Slot] = buildSlot(move)
	end
end

local function onMoveAccepted(data: unknown)
	if typeof(data) ~= "table" then
		return
	end
	local accepted = data :: Types.MoveAccepted
	local slot = slots[accepted.Slot]
	if slot and typeof(accepted.EndsAt) == "number" then
		slot.endsAt = accepted.EndsAt
	end
end

local function updateCooldowns()
	local now = workspace:GetServerTimeNow()
	for _, slot in slots do
		local remaining = slot.endsAt - now
		if remaining > 0 then
			slot.overlay.Size = UDim2.fromScale(1, math.clamp(remaining / slot.cooldown, 0, 1))
			slot.timer.Text = string.format("%.1f", remaining)
		elseif slot.timer.Text ~= "" then
			slot.overlay.Size = UDim2.fromScale(1, 0)
			slot.timer.Text = ""
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
		Size = UDim2.fromOffset(SLOT_SIZE * 5 + 8 * 4, SLOT_SIZE),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 8),
		}),
	})
	gui.Parent = player:WaitForChild("PlayerGui")
end

function MovesHotbar.start()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
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
