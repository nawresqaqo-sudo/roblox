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

## Using Sine VFX and Eclipse Animator

Those plugins run inside Studio on your computer, so they plug in like this:

- **Animations (Eclipse/Moon Animator):** animate on an R15 rig, publish, and paste the id into that
  move's `AnimationId` in `src/shared/Characters/Zoro.luau`. The server plays it and the coded clip
  for that move is skipped.
- **VFX (Sine VFX or any plugin):** effects you make can go in `ReplicatedStorage > Assets > VFX`;
  `Util/VfxUtil.asset(name)` finds them by name. To swap one into a move, call it from that move's
  function in `src/client/Vfx/Zoro.luau`.

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
