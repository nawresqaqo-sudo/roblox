--!strict
-- Types that cross the client/server boundary.

export type MoveKind = "Normal" | "Ult" | "BigUlt"

export type MoveInfo = {
	Slot: number,
	Name: string,
	Description: string,
	Kind: MoveKind,
	Cooldown: number,
	-- Animation made in Eclipse/Moon Animator, e.g. "rbxassetid://1234567890". Empty = no animation.
	AnimationId: string,
	-- Hotbar art: an image ("rbxassetid://...") or, until there is one, a short glyph drawn big (e.g. kanji).
	Icon: string?,
	Glyph: string?,
}

export type CharacterInfo = {
	Id: string,
	DisplayName: string,
	Subtitle: string,
	Series: string,
	Description: string,
	Available: boolean,
	AccentColor: Color3,
	Moves: { MoveInfo },
}

-- Server -> client when a move goes through, so the hotbar can show its cooldown.
-- EndsAt is in workspace:GetServerTimeNow() time so both sides agree on the clock. Cooldowns belong to
-- a character, so switching characters and back keeps them.
export type MoveAccepted = {
	Character: string,
	Slot: number,
	EndsAt: number,
}

return {}
