# Rooftop Chaos

Spawn on a safe rooftop, cross to the main rooftop, and **slide into people to knock them off**.
Whoever slid into someone last gets the KO when they fall.

## Controls

| Platform | Slide |
| --- | --- |
| Mobile | Hold anywhere on the screen (not the joystick or jump button) |
| PC | Hold left mouse button, or hold C |
| Controller | Hold R2 |

- Hold to keep sliding (up to 2.5 s). It slows down over time; let go to get up.
- Steer a little while sliding with the joystick or WASD.
- Jump out of a slide to keep your speed.
- Sliding into someone launches them. Faster slide = bigger launch.

## What's in it

- **Custom run animation:** a forward-leaning sprint with big arm pumps and high knees.
- **Slide animation:** a feet-first baseball slide, low to the ground, with a dust trail.
- Both animations are made in code, so there's nothing to upload and everyone sees them on
  everyone. Works on R15 (full body) and R6 (arms, legs and body only).
- Lower camera and a wider field of view while you slide.
- **KOs on the leaderboard:** falling into the void counts as a KO for the last person who hit you
  (within 8 seconds).
- **Safe zone:** slide hits don't count on the spawn rooftop.
- **Test dummies** on the main rooftop that come back after being knocked off.

## Getting it into Roblox Studio

**Quick test:** open `build/RooftopChaos.rbxl` in Studio (File > Open from File) and press Play.
It has a spawn rooftop, a bridge, the main rooftop and three dummies.

**Into your own Rooftop Chaos place:**

1. Install the Rojo plugin in Studio (Creator Store: "Rojo") and Rojo 7.4 from
   https://github.com/rojo-rbx/rojo/releases.
2. Clone this repo, open a terminal in it, run `rojo serve`, then click **Connect** in the Rojo
   plugin. The code goes into `ServerScriptService > Server`, `ReplicatedStorage > Shared` and
   `StarterPlayerScripts > Client`. Your map and other scripts are left alone.
3. Set up your map:
   - **Void:** set `Workspace > FallenPartsDestroyHeight` somewhere below your islands. Anyone who
     falls 25 studs above that height is knocked out.
   - **Safe zone (optional):** make a Folder in Workspace named `SafeZones`. Put a big part inside it
     covering the spawn island, with Transparency 1, CanCollide off and Anchored on.
   - **Test dummies (optional):** make a Folder in Workspace named `DummySpawns` and put small
     invisible parts in it where dummies should stand.

## Tuning

Everything is in `src/shared/Config.luau`: slide speed, length, steering, cooldown and hitbox;
knockback strength and lift; how long you tumble; KO credit time; run animation speed and size.

The poses themselves (how far the arms swing, how low the slide goes) are at the top of
`src/client/Controllers/CharacterAnimator.luau`.

## How it fits together

```text
src/shared/   -> ReplicatedStorage.Shared       Config (all numbers), remotes
src/server/   -> ServerScriptService.Server
  Systems/SlideService     who's sliding, checks slide hits, launches the victim
  Systems/KnockoutService  leaderboard, void, KO credit
  Systems/DummyService     test dummies
  Util/SafeZones           "is this spot in a safe zone?"
src/client/   -> StarterPlayerScripts.Client
  Controllers/SlideController    hold-to-slide input, slide movement, hit detection, getting launched
  Controllers/CharacterAnimator  the run and slide animations for every character
  Controllers/HitEffects         the burst where a slide connects
```

Your own game client spots slide hits for a snappy feel. The server double-checks each one (were
you actually sliding, are you close enough, is the target in a safe zone) before anyone gets launched.

## Not in yet

Sounds, a KO message on screen, and a way to block or dodge a slide. If you'd rather use animations
made in Eclipse or Moon Animator than the coded ones, that's an easy swap.
