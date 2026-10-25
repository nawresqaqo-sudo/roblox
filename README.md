# Anime Battlegrounds (prototype)

A JJS-style battlegrounds game with characters from Naruto, One Piece and Jujutsu Kaisen.
Right now it has **Teen Naruto** (5 moves), a character select screen, a move hotbar and
training dummies.

## Controls

| Key | Move | Type |
| --- | --- | --- |
| 1 | Rasengan: dash with a chakra sphere, knocks the target away | Normal |
| 2 | Shadow Clone Jutsu: 3 clones run at the nearest enemy and punch | Normal |
| 3 | Double Rasengan: a clone joins in, two hits back to back | Normal |
| 4 | Giant Rasengan: charge a huge sphere with a clone, then ram it | Secondary ult |
| 5 | Rasenshuriken: quick cutscene, throw, shredding dome | Big ult |

Tap the hotbar slots on mobile. The **CHARACTERS** button (top left) reopens the select screen.

## Getting it into Roblox Studio

**Quick test:** open `build/AnimeBattlegrounds.rbxl` in Studio (File > Open from File) and press
Play. It's a baseplate with everything already in it.

**Sync into your own place (recommended for ongoing work):**

1. Install the Rojo plugin in Studio (Creator Store: "Rojo") and the Rojo 7.4 command line tool
   from https://github.com/rojo-rbx/rojo/releases.
2. Clone this repo, open a terminal in it, and run `rojo serve`.
3. In Studio, open the Rojo plugin and click **Connect**. The code shows up in
   `ServerScriptService > Server`, `ReplicatedStorage > Shared` and
   `StarterPlayerScripts > Client`.

Edit the code in the repo, not in Studio, because Rojo overwrites synced scripts. Use a fresh
Baseplate place rather than the old Steal an Egg place so the two games' scripts don't clash.

## Adding your animations (Eclipse / Moon Animator)

1. Animate on an R15 rig and publish the animation to Roblox.
2. Copy the animation id into `AnimationId` for that move in
   `src/shared/Characters/Naruto.luau` (a bare number like `1234567890` works too).
   The clones' punch animation goes in `Tuning.ShadowClone.PunchAnimationId`.

Animations only play in games owned by the same account or group that published them.

## Adding your VFX (Sine VFX or any plugin)

Every effect has a built-in look made of parts. To replace one, build your effect in Studio and
put it in **ReplicatedStorage > Assets > VFX** with one of these exact names:

| Name | Kind | Used by |
| --- | --- | --- |
| `Rasengan` | held, follows the hand | moves 1 and 3 |
| `GiantRasengan` | held, in front of the player | move 4 |
| `Rasenshuriken` | held over the shoulder, then flies | move 5 |
| `RasenshurikenExplosion` | burst | move 5 |
| `Impact` | burst | every hit |
| `Smoke` | burst | clones appearing and vanishing |

Held effects are moved every frame. For burst effects, every ParticleEmitter inside gets
`:Emit(20)`; set an `EmitCount` attribute on an emitter to change that number. The `Assets`
folder lives outside the Rojo-synced folders, so Rojo leaves it alone.

## Tuning

- Damage, cooldown and timing for every move: `src/shared/Characters/Naruto.luau`
- Dummy health, regen and positions: `src/shared/Config.luau`
- Naruto's look (colors, or real Marketplace clothes and hair ids): `src/server/Movesets/Naruto/Outfit.luau`
- Where held effects sit and the cutscene camera shots: top of `src/client/Vfx/Naruto.luau`

## How it fits together

```text
src/shared/   -> ReplicatedStorage.Shared   roster, move data, remotes
src/server/   -> ServerScriptService.Server
  Systems/      CharacterService (select + outfit), CombatService (runs moves), DummyService
  Combat/       hitboxes, damage, knockback, clones, animation and VFX helpers
  Movesets/     one folder per character: its moves and outfit
src/client/   -> StarterPlayerScripts.Client
  Controllers/  character select screen, move hotbar, VFX player
  Vfx/          effects per character (Common = shared ones)
  Util/         UI builder, VFX helpers, cutscene camera
```

The server owns everything that matters (cooldowns, hitboxes, damage). The client only sends
"use move N" and draws effects when the server says so.

**Adding a character:** copy `src/shared/Characters/Naruto.luau` (info and tuning), add it to the
list in `Characters/init.luau`, add `src/server/Movesets/<Name>/` with its moves and outfit,
register it in `Movesets/init.luau`, and add `src/client/Vfx/<Name>.luau` for its effects.

## Before you publish

Using official names like Naruto or Rasengan in a public game can get it taken down. Most big
battlegrounds games rename their characters for this reason.

## Not in yet

M1 combos, blocking, an ult meter (ults use plain cooldowns for now), being hit interrupting your
move, sounds, and character portraits.
