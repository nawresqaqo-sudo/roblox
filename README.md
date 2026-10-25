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

**Animations** (made in code, so there's nothing to upload and everyone sees them on everyone;
full body on R15, arms/legs/body on R6):
- **Sprint:** forward lean, big arm pumps, high knees, bounce, leaning into turns.
- **Slide:** feet-first, low to the ground, one hand trailing, leaning as you steer.
- **Flail:** arms windmilling and legs kicking while you fly after getting hit (or fall).

**Feel:**
- Dust, a speed streak and wind sound behind every slider; anime speed lines on your screen.
- Lower camera and wider view while sliding.
- Hits: shockwave, sparks, a comic word (POW! BAM! YEET!...), a thud, screen shake and an FOV kick.

**Gameplay:**
- **Clashes:** two players sliding head-on. Clearly faster wins and launches the other; otherwise
  both bounce off.
- **KOs and streaks** on the leaderboard. Falling into the void counts as a KO for the last person
  who hit you (within 8 seconds). Your streak resets when you go down.
- **KO feed** (top right) and big popups: "KNOCKED OFF SAM!", "DOUBLE KO!", "RAMPAGE!"...
- "Hold to slide" hint for new players, gone after 3 slides.
- **Safe zone:** slide hits don't count on the spawn rooftop.
- **Test dummies** on the main rooftop that come back after being knocked off.

## Getting it into Roblox Studio

**Quick test:** open `build/RooftopChaos.rbxl` in Studio (File > Open from File) and press Play.
It has a spawn rooftop, a bridge, a main rooftop with cover to slide around (stairwell, AC units,
crates, water tank), glowing edges so you can see the drop, a sunset city skyline far below, and
three dummies.

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
knockback strength and lift; how long you tumble; clash rules; KO credit time; animation speed,
size and turn lean; and the sound ids (built-in Roblox sounds by default; add a KO "ding" there).

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
  Controllers/CharacterAnimator  sprint, slide and flail animations, trails, wind sound
  Controllers/CameraFx           camera drop, FOV and shake (one place so they don't fight)
  Controllers/HitEffects         what a hit looks and sounds like
  Controllers/Hud                hint, speed lines, KO feed and popups
  Util/Sfx                       sound helper
```

Your own game client spots slide hits for a snappy feel. The server double-checks each one (were
you actually sliding, are you close enough, is the target in a safe zone) before anyone gets launched.

## Not in yet

Rounds or a timer, a way to block or dodge a slide, and saving stats between sessions. If you'd
rather use animations made in Eclipse or Moon Animator than the coded ones, that's an easy swap.
