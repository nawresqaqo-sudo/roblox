# Project notes

- Roblox game: JJS-style anime battlegrounds (Naruto / One Piece / JJK). Luau, `--!strict` everywhere.
- Rojo 7.4 project: `default.project.json` (code only, for `rojo serve`), `testplace.project.json`
  (code + baseplate, builds `build/AnimeBattlegrounds.rbxl`). Rebuild the .rbxl after code changes.
- One Script (`src/server/init.server.luau`) and one LocalScript (`src/client/init.client.luau`);
  both load modules with two-phase init()/start().
- Server-authoritative combat: `Systems/CombatService` validates and runs `Movesets/<Char>` move
  functions; VFX are client-side via the `PlayVfx` remote (`Vfx.play("<Module>.<Effect>", payload)`).
- Character data and balance numbers live in `src/shared/Characters/<Char>.luau`.
- User authors animations in Eclipse Animator (ids go in AnimationId) and VFX with a Studio plugin
  (assets go in ReplicatedStorage.Assets.VFX by effect name).
- Checks: `stylua src`, `rojo sourcemap default.project.json -o sourcemap.json`, then
  `luau-lsp analyze --platform=roblox --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src`.
