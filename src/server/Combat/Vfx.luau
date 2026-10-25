--!strict
-- Tells every client to play an effect. The visuals live in StarterPlayerScripts > Client > Vfx:
-- Vfx.play("Naruto.Rasengan", ...) runs the Rasengan function in Client/Vfx/Naruto.luau.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local Vfx = {}

local counter = 0

-- Give an effect an id when the server may need to end it early with Vfx.stop.
function Vfx.newId(): string
	counter += 1
	return tostring(counter)
end

function Vfx.play(effect: string, payload: { [string]: any })
	Net.remote("PlayVfx"):FireAllClients(effect, payload)
end

function Vfx.stop(id: string)
	Net.remote("PlayVfx"):FireAllClients("Stop", { id = id })
end

return Vfx
