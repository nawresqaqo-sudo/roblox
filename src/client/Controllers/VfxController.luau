--!strict
-- Plays the effects the server asks for. Each module in Client/Vfx is a table of effect functions:
-- the effect "Naruto.Rasengan" runs Vfx/Naruto.luau -> Rasengan(payload).
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Net"))
local VfxUtil = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("VfxUtil"))

-- How long an effect's stop function is kept around for a late Stop message.
local STOP_WINDOW = 30

local VfxController = {}

local handlers: { [string]: VfxUtil.Handler } = {}
local stoppers: { [string]: () -> () } = {}

local function onPlay(effect: unknown, payload: unknown)
	if typeof(effect) ~= "string" or typeof(payload) ~= "table" then
		return
	end
	local data = payload :: VfxUtil.Payload
	local id = data.id

	if effect == "Stop" then
		local stop = if typeof(id) == "string" then stoppers[id] else nil
		if stop and typeof(id) == "string" then
			stoppers[id] = nil
			stop()
		end
		return
	end

	local handler = handlers[effect]
	if not handler then
		warn(`[Vfx] no effect named "{effect}"`)
		return
	end
	local ok, result = pcall(handler, data)
	if not ok then
		warn(`[Vfx] "{effect}" errored: {result}`)
		return
	end
	if result and typeof(id) == "string" then
		stoppers[id] = result
		task.delay(STOP_WINDOW, function()
			if stoppers[id] == result then
				stoppers[id] = nil
			end
		end)
	end
end

function VfxController.init()
	local folder = script.Parent.Parent:WaitForChild("Vfx")
	for _, module in folder:GetChildren() do
		if module:IsA("ModuleScript") then
			local effects: { [string]: VfxUtil.Handler } = (require :: any)(module)
			for name, handler in effects do
				handlers[`{module.Name}.{name}`] = handler
			end
		end
	end
end

function VfxController.start()
	Net.remote("PlayVfx").OnClientEvent:Connect(onPlay)
end

return VfxController
