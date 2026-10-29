# Characters Test

A JJS-style test arena for anime characters: **Roronoa Zoro, as he fought in the Raid on Onigashima**,
and **Sasuke Uchiha in his Taka days**.

## Zoro's moves

| Key | Move | What it does |
| --- | --- | --- |
| 1 | **Three Sword Style: Onigiri** | Crouch with all three blades crossed, dash straight through. Everyone he passes freezes, then the three-blade cut lands a beat later. |
| 2 | **One Sword Style: Bird Dance** | Winds Enma back (Conqueror's Haki crackling on the blade) and sends a huge crimson flying slash that cuts through everyone in a line. |
| 3 | **Three Sword Style: Black Rope Dragon Twister** | Spins into a tornado of haki-black and green slashes, drags everyone in, then throws them into the air. |
| 4 | **Ult: King of Hell Three Sword Style: 103 Mercies Dragon Damnation** | The move that beat King. Locks the nearest enemy, the sky goes black, red lightning everywhere, cutscene. Zoro leaps into the sky, a crimson-and-purple dragon coils around him, he dives down and three giant blades cross on impact (crater, debris, impact frames). |
| 5 | **Ult: Nine Sword Style Asura: Blades Drawn, Dance of the Dead** | The cut that scarred Kaido. Two ghost heads and four ghost arms appear (nine swords), a three-headed six-armed demon rises behind him, cutscene, then he dashes through and nine cuts appear on the target in a wheel before it all bursts. |

## Sasuke's moves

| Key | Move | What it does |
| --- | --- | --- |
| 1 / Z | **Chidori: Lightning Assault** | Crouches with lightning gathering in his hand, then dashes in a blur and thrusts it into the first enemy on his path. Fast startup, medium dash, short stun and knockback. If nobody is there, the Chidori fizzles out. |
| 2 / X | **Fire Style: Phoenix Flower** | Two hand signs, then five fireballs (each with a shuriken inside) in a staggered fan. Each one burns the first enemy it reaches or bursts on a wall. He can walk while he breathes them out. |
| 3 / C | **Amaterasu: Black Flame Curse** | His Mangekyo opens and whoever he's looking at (in front, in range, no wall in between) is marked; a moment later black flames erupt on them. They burn for a few seconds (refreshing, never stacking, capped), and the ground keeps burning. Breaking line of sight during the mark dodges it. |
| 4 / V | **Ult: Kirin: Heavenly Lightning Devastation** | He raises his arm to the sky, the sky turns stormy and a warning circle appears where it will land (the white ring closing in counts down to the strike). Then a giant bolt falls with a huge impact. The spot is fixed when he casts, so you can run out of it; hitting Sasuke before it lands calls it off. |

Character select opens when you join (Zoro and Sasuke are playable; Luffy, Sanji and Kaido are
placeholders). Use keys 1-5 or Z X C V B, or tap the hotbar on mobile. Cooldowns are kept per
character, so switching characters doesn't reset them.

## The look

- **Zoro:** dark green kimono, light green haramaki, short green hair, the scar over his left eye,
  three gold earrings and the black bandana on his arm.
- **Swords:** Wado Ichimonji (white), Sandai Kitetsu (red) and Enma (purple). They hang at his hip
  and come out into his hands and mouth for each move. Drawn blades leave glossy swing trails, and
  turn haki-black for the ultimates.
- **Anime-style VFX:** bright and glossy, not chunky. Crescent slashes with a white core and a
  colored glow, speed streaks, glossy flashes and rings, afterimages, character outlines, haki
  flames, impact frames, a blacked-out sky and anime speed lines.
- **Animations:** every move has its own keyframed animation, made in code. Clips blend out of each
  other instead of snapping, hits freeze for a split second (hit-stop) and whoever gets hit flinches.
- **Sasuke:** white high-collared shirt open at the chest with the Uchiha crest on the back, the purple
  rope belt with its bow, navy trousers, black spiky hair with long bangs, and the Kusanagi through the
  rope. His effects are obsidian black, violet and electric purple with blue-white lightning, and crimson
  for the Mangekyo.
- **Hotbar:** dark slots in the character's accent color with each move's kanji (or your own icon), the
  keys, a cooldown fill and timer, a pop when a move goes through, a pulse when it's ready, a shake if
  pressed too early, and a brighter frame with a moving shine for ultimates.

## Getting it into Roblox Studio

**Quick test:** open `build/CharactersTest.rbxl` in Studio (File > Open from File) and press Play.
It's the Characters Test arena: a stone arena at dusk with pillars, two torii gates and three
training dummies.

**Into a place you already have open:** install the Rojo plugin and Rojo 7.4, then in a terminal
in this folder run `rojo serve` and click **Connect** in the plugin.

## Upgrading with Eclipse Animator and Sine VFX

Those plugins run inside Studio on your computer, so the game is set up to take their work directly.

### Animations (Eclipse Animator, Moon Animator or Roblox's Animation Editor)

Every coded animation can be turned into a real, editable Roblox animation:

1. Open the place in Studio (don't press Play). In the command bar (View > Command Bar), run:
   `require(game.ServerStorage.Dev.ExportAnimations)()`
2. A rig called **AnimRig** appears with every coded animation in its **AnimSaves**, named
   `<Character>_<Clip>`: `Zoro_Onigiri`, `Zoro_BirdDance`, `Zoro_DragonTwister`, `Zoro_DragonDamnation`,
   `Zoro_DragonDamnationLand`, `Zoro_Asura`, `Sasuke_ChidoriCharge`, `Sasuke_ChidoriDash`,
   `Sasuke_ChidoriThrust`, `Sasuke_ChidoriFizzle`, `Sasuke_PhoenixFlower`, `Sasuke_Amaterasu`,
   `Sasuke_Kirin`, plus the hit flinches `Common_Flinch` and `Common_FlinchHeavy`. To use your own R15 rig
   instead, run `require(game.ServerStorage.Dev.ExportAnimations)(workspace.YourRig)`.
3. Select the rig in Eclipse Animator, load an animation, polish it, and publish it to Roblox.
4. Paste the id into that move's `AnimationId` in `src/shared/Characters/Zoro.luau` or `Sasuke.luau`
   (Zoro's move 4 landing goes in `Tuning.DragonDamnation.LandAnimationId`). The game then plays your
   animation and skips the coded ones for that move. Chidori is one move made of four clips, so a
   published Chidori animation should cover the whole thing.

Animations only play in games owned by the account or group that published them.

### Effects (Sine VFX or any VFX plugin)

Build an effect, name it after one of these slots, and put it in **ReplicatedStorage > Assets > VFX**.
It plays at that moment of the move automatically:

| Slot name | When / where |
| --- | --- |
| `Zoro_OnigiriCharge` | follows Zoro during the Onigiri crouch |
| `Zoro_OnigiriCut` | on each target when the Onigiri cut lands |
| `Zoro_BirdDanceRelease` | in front of Zoro as he swings |
| `Zoro_BirdDanceSlash` | flies along with the slash |
| `Zoro_DragonTwister` | follows Zoro while he spins |
| `Zoro_DamnationCharge` | follows Zoro from the charge up into the sky |
| `Zoro_DamnationImpact` | at the Dragon Damnation landing |
| `Zoro_AsuraCharge` | follows Zoro while Asura forms |
| `Zoro_AsuraCut` | on each target when the nine cuts burst |
| `Impact` | every normal hit |

Sasuke's slots work the same way:

| Slot name | When / where |
| --- | --- |
| `Sasuke_ChidoriHand` | follows his hand while the Chidori is lit |
| `Sasuke_ChidoriImpact` | where the thrust connects |
| `Sasuke_Fireball` | follows each Phoenix Flower fireball |
| `Sasuke_FireballImpact` | where a fireball bursts |
| `Sasuke_AmaterasuMark` | the spot marked before the flames erupt |
| `Sasuke_AmaterasuFlames` | follows a burning target |
| `Sasuke_AmaterasuPatch` | the burning ground |
| `Sasuke_KirinStorm` | the storm cloud above the strike point |
| `Sasuke_KirinImpact` | where Kirin lands |

Burst emitters (Rate 0) are emitted once; set an `EmitCount` attribute on an emitter to change the
amount. Your effects play next to the built-in ones; set `REPLACE_BUILT_IN = true` at the top of
`src/client/Vfx/Zoro.luau` (or `src/client/Vfx/Sasuke/Kit.luau`) to hide the built-in effect wherever
you've added your own.

## Sounds

Every moment of Sasuke's moves has its own sound cue (charge, crackle, dash, impact, residual sparks,
hand signs, ignition, each fireball, flames, the Mangekyo, the storm's rumble, the thunder, the shockwave
and more). Out of the box they're **stand-ins**: Roblox's own wind and landing sounds (they ship with
every Roblox client) reshaped with sound effects, so nothing is silent and no asset ids are made up. For
the real thing, paste sounds you're allowed to use from the Creator Store into `Sounds` in
`src/shared/Characters/Sasuke.luau`, e.g. `ChidoriImpact = "rbxassetid://1234567890"`. Volumes and how
far each one carries are in `STAND_INS` in `src/client/Vfx/Sasuke/Kit.luau`. Sounds come from where
things happen in the world, so other players hear them from the right direction.

## Tuning

- Damage, cooldowns, timings, ranges: `src/shared/Characters/Zoro.luau` and `Sasuke.luau`
- Poses and timing of each animation: `src/client/Animations/Zoro.luau` and `Sasuke.luau`
- Colors and effects of each move: `src/client/Vfx/Zoro.luau`; Sasuke's are in `src/client/Vfx/Sasuke/`
  (one file per move, palette and sounds in `Kit.luau`)
- Zoro's look: `src/server/Movesets/Zoro/Outfit.luau`; swords: `src/client/Controllers/Swords.luau`
- Sasuke's look: `src/server/Movesets/Sasuke/Outfit.luau`
- The arena: `tools/build_map.py` (then rebuild the place file)

## How it fits together

```text
src/shared/    Characters (roster + each character's info, tuning and sounds), remotes
src/server/
  Systems/     CharacterService (select + outfit), CombatService (runs moves), DummyService
  Combat/      hitboxes (incl. line of sight), damage/stun, dashes/knockback/anchoring, animation ids,
               VFX broadcast
  Movesets/    Zoro: five moves and his outfit; Sasuke: four moves and his outfit
src/client/
  Controllers/ character select, hotbar, VFX player, MoveAnimator (coded clips), Swords
  Animations/  keyframed clips for Zoro and Sasuke, plus Common (hit flinches)
  Vfx/         Zoro's effects and cutscenes, Sasuke/ (a module per move), Common (shared hit effects)
  Util/        AnimeFx (anime effect pieces), Rig (joints/poses), Cutscene, Sfx (sounds), UI and VFX
               helpers
tools/         build_map.py (the arena), check_effects.py (effect names, payloads and sound cues)
```

The server owns cooldowns, targets, hitboxes and damage; clients only ask to use a move. Clients draw
the animations and effects when the server says a move started, so everyone sees the same thing.
Sasuke's moves never take the client's word for anything: Chidori's dash path, Amaterasu's target (in
range, in a cone, line of sight) and Kirin's strike point are all picked on the server, Phoenix Flower's
fireballs fly on the server, and the Amaterasu burn is a single capped timer per target.

**Adding a character:** add `src/shared/Characters/<Name>.luau` and list it in `Characters/init.luau`,
add `src/server/Movesets/<Name>/` (its outfit Model must be named `<Name>Outfit`), register it in
`Movesets/init.luau`, then add `src/client/Vfx/<Name>.luau` (or a `<Name>/` folder with an
`init.luau`, like Sasuke) and `src/client/Animations/<Name>.luau`.

## Checks

From this folder: `stylua src`, `rojo sourcemap default.project.json -o sourcemap.json`, then
`luau-lsp analyze --platform=roblox --definitions=@roblox=globalTypes.d.luau --sourcemap=sourcemap.json src`
and `python3 tools/check_effects.py`.

## Not in yet

- Controller (gamepad) buttons for moves. Keyboard and touch work.
- Real sound effects: the stand-ins are there until you add Creator Store sounds (see Sounds).
- Real animation assets: the coded clips play until you publish your own (see above).

## Before you publish

Using official names like Zoro or Onigiri in a public game can get it taken down. Most big
battlegrounds games rename their characters for this reason.
