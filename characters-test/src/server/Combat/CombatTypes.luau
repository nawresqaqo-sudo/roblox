--!strict
-- Server-only types shared by the combat helpers and every moveset.

export type MoveContext = {
	player: Player,
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	-- False once the character dies or respawns. Long moves should stop when this flips.
	isActive: () -> boolean,
}

export type MoveFn = (ctx: MoveContext) -> ()

export type Moveset = {
	applyOutfit: (character: Model) -> (),
	moves: { [number]: MoveFn },
}

return {}
