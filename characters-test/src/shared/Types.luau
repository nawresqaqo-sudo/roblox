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
-- EndsAt is in workspace:GetServerTimeNow() time so both sides agree on the clock.
export type MoveAccepted = {
	Slot: number,
	EndsAt: number,
}

return {}
