--!strict
-- The one client entry point. Every ModuleScript in Controllers gets init() (all of them), then start().
local Controllers = script:WaitForChild("Controllers")

type Controller = {
	init: (() -> ())?,
	start: (() -> ())?,
}

local loaded: { [string]: Controller } = {}
for _, child in Controllers:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = (require :: any)(child)
	end
end

for _, controller in loaded do
	if controller.init then
		controller.init()
	end
end

for _, controller in loaded do
	if controller.start then
		task.spawn(controller.start)
	end
end
