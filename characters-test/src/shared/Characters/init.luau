--!strict
-- The character roster, in the order the select screen shows it.
-- To add a character: copy Zoro.luau or Sasuke.luau, add it to LIST, and add a server moveset in
-- ServerScriptService > Server > Movesets.
local Types = require(script.Parent.Types)

local function comingSoon(id: string, displayName: string, series: string, color: Color3): Types.CharacterInfo
	return {
		Id = id,
		DisplayName = displayName,
		Subtitle = series,
		Series = series,
		Description = "Coming soon.",
		Available = false,
		AccentColor = color,
		Moves = {},
	}
end

local LIST: { Types.CharacterInfo } = {
	require(script.Zoro).Info,
	require(script.Sasuke).Info,
	comingSoon("Luffy", "Luffy", "One Piece", Color3.fromRGB(220, 45, 45)),
	comingSoon("Sanji", "Sanji", "One Piece", Color3.fromRGB(240, 200, 70)),
	comingSoon("Kaido", "Kaido", "One Piece", Color3.fromRGB(150, 110, 220)),
}

local byId: { [string]: Types.CharacterInfo } = {}
for _, info in LIST do
	byId[info.Id] = info
end

return {
	List = LIST,
	ById = byId,
}
