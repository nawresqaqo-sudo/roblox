--!strict
-- Small helpers for building UI in code: Ui.new("Frame", { Size = ..., Parent = ... }, { children })
local Ui = {}

function Ui.new(className: string, props: { [string]: any }?, children: { any }?): any
	local instance: any = Instance.new(className :: any)
	local parent: Instance? = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function Ui.corner(radius: number): Instance
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	return corner
end

function Ui.stroke(color: Color3, thickness: number): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	return stroke
end

-- A transparent white text label; `props` override the defaults.
function Ui.label(props: { [string]: any }, children: { any }?): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextSize = 14,
	}
	for key, value in props do
		merged[key] = value
	end
	return Ui.new("TextLabel", merged, children)
end

return Ui
