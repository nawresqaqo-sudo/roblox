# Characters Test

A JJS-style test arena for anime characters. First up: **Roronoa Zoro, as he fought in the Raid on
Onigashima**.

## Zoro's moves

| Key | Move | What it does |
| --- | --- | --- |
| 1 | **Three Sword Style: Onigiri** | Crouch with all three blades crossed, dash straight through. Everyone he passes freezes, then the three-blade cut lands a beat later. |
| 2 | **One Sword Style: Bird Dance** | Winds Enma back (Conqueror's Haki crackling on the blade) and sends a huge crimson flying slash that cuts through everyone in a line. |
| 3 | **Three Sword Style: Black Rope Dragon Twister** | Spins into a tornado of haki-black and green slashes, drags everyone in, then throws them into the air. |
| 4 | **Ult: King of Hell Three Sword Style: 103 Mercies Dragon Damnation** | The move that beat King. Locks the nearest enemy, the sky goes black, red lightning everywhere, cutscene. Zoro leaps into the sky, a crimson-and-purple dragon coils around him, he dives down and three giant blades cross on impact (crater, debris, impact frames). |
| 5 | **Ult: Nine Sword Style Asura: Blades Drawn, Dance of the Dead** | The cut that scarred Kaido. Two ghost heads and four ghost arms appear (nine swords), a three-headed six-armed demon rises behind him, cutscene, then he dashes through and nine cuts appear on the target in a wheel before it all bursts. |

Character select opens when you join (Zoro is playable; Luffy, Sanji and Kaido are placeholders).
Tap the hotbar on mobile.

## The look

- **Zoro:** dark green kimono, light green haramaki, short green hair, the scar over his left eye,
  three gold earrings and the black bandana on his arm.
- **Swords:** Wado Ichimonji (white), Sandai Kitetsu (red) and Enma (purple). They hang at his hip
  and come out into his hands and mouth for each move. Drawn blades leave glossy swing trails, and
  turn haki-black for the ultimates.
- **Anime-style VFX:** bright and glossy, not chunky. Crescent slashes with a white core and a
  colored glow, speed streaks, glossy flashes and rings, afterimages, character outlines, haki
  flames, impact frames, a blacked-out sky and anime speed lines.
- **Animations:** every move has its own keyframed animation, made in code.

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
2. A rig called **ZoroAnimRig** appears with all six animations in its **AnimSaves**:
   `Zoro_Onigiri`, `Zoro_BirdDance`, `Zoro_DragonTwister`, `Zoro_DragonDamnation`,
   `Zoro_DragonDamnationLand`, `Zoro_Asura`. To use your own R15 rig instead, run
   `require(game.ServerStorage.Dev.ExportAnimations)(workspace.YourRig)`.
3. Select the rig in Eclipse Animator, load an animation, polish it, and publish it to Roblox.
4. Paste the id into that move's `AnimationId` in `src/shared/Characters/Zoro.luau` (the landing of
   move 4 goes in `Tuning.DragonDamnation.LandAnimationId`). The game then plays your animation and
   skips the coded one for that move.

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

Burst emitters (Rate 0) are emitted once; set an `EmitCount` attribute on an emitter to change the
amount. Your effects play next to the built-in ones; set `REPLACE_BUILT_IN = true` at the top of
`src/client/Vfx/Zoro.luau` to hide the built-in effect wherever you've added your own.

## Tuning

- Damage, cooldowns, timings, ranges: `src/shared/Characters/Zoro.luau`
- Poses and timing of each animation: `src/client/Animations/Zoro.luau`
- Colors and effects of each move: `src/client/Vfx/Zoro.luau`
- Zoro's look: `src/server/Movesets/Zoro/Outfit.luau`; swords: `src/client/Controllers/Swords.luau`
- The arena: `tools/build_map.py` (then rebuild the place file)

## How it fits together

```text
src/shared/    Characters (roster + Zoro's info and tuning), remotes
src/server/
  Systems/     CharacterService (select + outfit), CombatService (runs moves), DummyService
  Combat/      hitboxes, damage/stun, dashes/knockback/anchoring, animation ids, VFX broadcast
  Movesets/    Zoro: the five moves (timing, movement, hits) and his outfit
src/client/
  Controllers/ character select, hotbar, VFX player, MoveAnimator (coded clips), Swords
  Animations/  Zoro's keyframed clips
  Vfx/         Zoro's effects and cutscenes (Common = shared hit effects)
  Util/        AnimeFx (anime effect pieces), Rig (joints/poses), Cutscene, UI and VFX helpers
```

The server owns cooldowns, hitboxes and damage. Clients draw the animations and effects when the
server says a move started, so everyone sees the same thing.

**Adding a character:** add `src/shared/Characters/<Name>.luau` and list it in `Characters/init.luau`,
add `src/server/Movesets/<Name>/`, register it in `Movesets/init.luau`, then add
`src/client/Vfx/<Name>.luau` and `src/client/Animations/<Name>.luau`.

## Before you publish

Using official names like Zoro or Onigiri in a public game can get it taken down. Most big
battlegrounds games rename their characters for this reason.
