--!strict
-- The one server entry point. Every ModuleScript in Systems gets init() (all of them), then start().
local Systems = script:WaitForChild("Systems")

type System = {
	init: (() -> ())?,
	start: (() -> ())?,
}

local loaded: { [string]: System } = {}
for _, child in Systems:GetChildren() do
	if child:IsA("ModuleScript") then
		loaded[child.Name] = (require :: any)(child)
	end
end

for _, system in loaded do
	if system.init then
		system.init()
	end
end

for _, system in loaded do
	if system.start then
		task.spawn(system.start)
	end
end
