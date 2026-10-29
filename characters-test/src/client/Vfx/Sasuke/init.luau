--!strict
-- Sasuke's moves on screen. Each move lives in its own module next to this one (Kit holds what they
-- share); this gathers their effect functions, so the effect "Sasuke.Chidori" runs Chidori(payload)
-- from Chidori.luau, "Sasuke.KirinStrike" runs KirinStrike(payload) from Kirin.luau, and so on.
local VfxUtil = require(script.Parent.Parent:WaitForChild("Util"):WaitForChild("VfxUtil"))

local Sasuke: { [string]: VfxUtil.Handler } = {}

for _, effects in
	{
		require(script.Chidori),
		require(script.PhoenixFlower),
		require(script.Amaterasu),
		require(script.Kirin),
	}
do
	for name, handler in effects do
		Sasuke[name] = handler
	end
end

return Sasuke
