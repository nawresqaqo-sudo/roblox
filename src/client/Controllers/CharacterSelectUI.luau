--!strict
-- The character select screen. Opens on join and from the CHARACTERS button. Picking a card asks the
-- server to switch; the server sets the player's "Character" attribute when it goes through.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Characters = require(Shared:WaitForChild("Characters"))
local Net = require(Shared:WaitForChild("Net"))
local Types = require(Shared:WaitForChild("Types"))
local Ui = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("Ui"))

local LOCKED_COLOR = Color3.fromRGB(90, 90, 100)
local CARD_COLOR = Color3.fromRGB(24, 24, 30)

type Card = {
	info: Types.CharacterInfo,
	action: TextLabel,
}

local CharacterSelectUI = {}

local player = Players.LocalPlayer
local screen: Frame
local closeButton: TextButton
local cards: { [string]: Card } = {}

local function setOpen(open: boolean)
	screen.Visible = open
end

local function refresh()
	local current = player:GetAttribute("Character")
	closeButton.Visible = current ~= nil
	for id, card in cards do
		local action = card.action
		if not card.info.Available then
			action.Text = "COMING SOON"
			action.BackgroundColor3 = LOCKED_COLOR
		elseif id == current then
			action.Text = "SELECTED"
			action.BackgroundColor3 = card.info.AccentColor
		else
			action.Text = "SELECT"
			action.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		end
	end
end

local function buildCard(info: Types.CharacterInfo, order: number, parent: Instance)
	local available = info.Available
	local accent = if available then info.AccentColor else LOCKED_COLOR
	local stroke = Ui.stroke(accent, 2)
	local action = Ui.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -20, 0, 30),
		BackgroundTransparency = 0,
		Font = Enum.Font.GothamBlack,
		TextSize = 14,
	})
	Ui.corner(8).Parent = action

	local card: TextButton = Ui.new("TextButton", {
		Name = info.Id,
		LayoutOrder = order,
		Size = UDim2.fromOffset(190, 280),
		BackgroundColor3 = CARD_COLOR,
		AutoButtonColor = false,
		Text = "",
		Parent = parent,
	}, {
		Ui.corner(12),
		stroke,
		action,
		-- Portrait placeholder: swap for an ImageLabel with real art later.
		Ui.new("Frame", {
			Position = UDim2.fromOffset(8, 8),
			Size = UDim2.new(1, -16, 0, 120),
			BackgroundColor3 = accent,
			BackgroundTransparency = if available then 0 else 0.5,
		}, {
			Ui.corner(10),
			Ui.new("UIGradient", {
				Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(110, 110, 110)),
				Rotation = 90,
			}),
			Ui.label({
				Size = UDim2.fromScale(1, 1),
				Font = Enum.Font.GothamBlack,
				Text = string.sub(info.DisplayName, 1, 1),
				TextScaled = true,
				TextTransparency = 0.1,
			}, { Ui.new("UITextSizeConstraint", { MaxTextSize = 80 }) }),
		}),
		Ui.label({
			Position = UDim2.fromOffset(12, 136),
			Size = UDim2.new(1, -24, 0, 24),
			Font = Enum.Font.GothamBlack,
			TextSize = 20,
			Text = info.DisplayName,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Ui.label({
			Position = UDim2.fromOffset(12, 160),
			Size = UDim2.new(1, -24, 0, 16),
			TextSize = 12,
			Text = info.Subtitle,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Ui.label({
			Position = UDim2.fromOffset(12, 180),
			Size = UDim2.new(1, -24, 0, 50),
			Font = Enum.Font.Gotham,
			TextSize = 12,
			Text = info.Description,
			TextColor3 = Color3.fromRGB(200, 200, 210),
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}),
	})

	if available then
		card.Activated:Connect(function()
			Net.remote("SelectCharacter"):FireServer(info.Id)
		end)
		card.MouseEnter:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.15), { Thickness = 4 }):Play()
		end)
		card.MouseLeave:Connect(function()
			TweenService:Create(stroke, TweenInfo.new(0.15), { Thickness = 2 }):Play()
		end)
	end
	cards[info.Id] = { info = info, action = action }
end

function CharacterSelectUI.init()
	local gui: ScreenGui = Ui.new("ScreenGui", {
		Name = "CharacterSelect",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 10,
	})

	screen = Ui.new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 8, 12),
		BackgroundTransparency = 0.25,
		Parent = gui,
	})
	Ui.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.12),
		Size = UDim2.new(1, -32, 0, 44),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		Text = "CHOOSE YOUR FIGHTER",
		Parent = screen,
	}, { Ui.new("UITextSizeConstraint", { MaxTextSize = 40 }) })

	local list: ScrollingFrame = Ui.new("ScrollingFrame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(1, -32, 0, 300),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 4,
		ScrollingDirection = Enum.ScrollingDirection.X,
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		CanvasSize = UDim2.new(),
		Parent = screen,
	}, {
		Ui.new("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 14),
		}),
	})
	for order, info in Characters.List do
		buildCard(info, order, list)
	end

	closeButton = Ui.new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 70),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = CARD_COLOR,
		Font = Enum.Font.GothamBlack,
		Text = "X",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 18,
		Parent = screen,
	}, { Ui.corner(8) })
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)

	local openButton: TextButton = Ui.new("TextButton", {
		Position = UDim2.fromOffset(16, 70),
		Size = UDim2.fromOffset(130, 36),
		BackgroundColor3 = CARD_COLOR,
		BackgroundTransparency = 0.1,
		Font = Enum.Font.GothamBlack,
		Text = "CHARACTERS",
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
		Parent = gui,
	}, { Ui.corner(8), Ui.stroke(Color3.fromRGB(255, 140, 30), 2) })
	openButton.Activated:Connect(function()
		setOpen(not screen.Visible)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
end

function CharacterSelectUI.start()
	player:GetAttributeChangedSignal("Character"):Connect(function()
		refresh()
		setOpen(false)
	end)
	refresh()
	setOpen(player:GetAttribute("Character") == nil)
end

return CharacterSelectUI
