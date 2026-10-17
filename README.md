# EXALT · Meridian Gardens

A playable offline **6v6 King of the Hill** hero shooter in a modern fantasy city, with a separate Nimbus training arena. Built with original modular geometry and synthesized sound. **Godot 4.7.2 stable** is the verified engine (`4.7.2.stable.official.ed1daf0bf`).

The city includes a celestial conservatory, garden and market flanks, an underground shopping arcade with six through-shops and cover, accessible balconies and wizard's study, elevated promenades, monumental railway arches and moving scenic trains. Six small packs heal **75 HP**; two large packs heal **400 HP**, capped at maximum health. See [Meridian Gardens field guide and validation](docs/MERIDIAN_GARDENS.md) and the [geometry revision](docs/GEOMETRY_AUDIT.md).

## Play

Import **project.godot** in Godot 4.7.2 and press **F5** to enter Meridian Gardens. On Windows, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Launch.ps1
```

`Launch.ps1 -Editor` opens the editor; `Launch.ps1 -Training` starts the original arena directly. The launcher finds the installed 4.7.2 console executable in Downloads or `GODOT_BIN`. Click the game to capture the mouse. **Tab / Esc** opens the pause menu, including exploration, match restart and return to training. **M** opens the tactical atlas; **F3** adds route/resource debugging.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Left click / right hold | Semi-auto umbrella rifle / shoulder aim |
| R | Reload |
| Space | Press to jump / wall kick; hold while moving into a ledge to mantle automatically |
| 3 | Crosshair-directed 3D dash, after a short buildup |
| Shift hold | Momentum slide; downhill entry works from low speed |
| Q | Ability 1 — Hover: higher umbrella vault, then glide; press again to end |
| E | Ability 2 — frontal Deflect |
| 1 | Ability 3 — bouncing Pocket Bomb |
| 2, then left click | Final Notice stance, then one shot after preparation; 2 cancels |
| 5 | Forward lunging umbrella strike |
| 4 | 2.8 m throw or timed counterthrow |
| 6 hold | Shield / frontal melee guard |
| Tab or Esc | Pause menu / training console / return to play |
| M | City district atlas with routes, levels and shared health locations |
| B | Switch the open city atlas between surface and underground plans |
| F3 / F5 / F6 | Telemetry / match or exercise restart / training-only refill |

Bindings use named InputMap actions in `scripts/training/input_bindings.gd`; the saved project map contains the user's requested controls. Existing editor-configured bindings take precedence, and HUD prompts read the actual map. A downward dash automatically enters a momentum slide. Jump ends a slide; holding and then releasing Shift can also end an automatic dash slide. Guard limits movement and does **not** reduce bullets at the default setting.

## Guard practice

Press **Tab → Start guard drill**, walk inside the coral ring, face the stationary bot and hold **6**. The bot starts strikes within **2.4 m**, repeating at a **1.6 s** interval after its normal reaction/startup. A successful block produces a metallic clang, shield flash, expanding rings and sparks. The attacker snaps backward, spreads its arms, buckles its knees and shows rotating daze markers during the existing 0.55 s stagger. It uses the shared melee and stagger rules but stays planted. Change **Strike trigger range** and **Strike interval** under **Stationary guard drill** in the training console. The same bot is available as the **Guard trainer** spawn profile. Starting the dedicated drill clears AI freeze.

## Climbing and wall jumps

**Hold Space and move into a wall or tower** to mantle automatically when a ledge comes within about **0.95 m** and **2.2 m above your feet**, provided the top has room to stand. Keep holding through a jump, umbrella ascent or successive ledges; you do not need another press at each lip. The climb takes about **0.32 s**, with continuous collision checks and a two-arm pull-up pose. Your incoming horizontal momentum carries through the finish straight into running. **Press Space during the last 0.12 s** to jump immediately off the top with that momentum. Holding Space while standing still or moving away does not start an automatic climb; holding alone does not jump on completion.

While airborne within **0.72 m** of a wall, press **Space** to kick upward and away while keeping your momentum along the wall. Moving forward beside a left wall carries you forward and right; a right wall carries you forward and left. Camera direction does not replace your existing velocity. Wall kicks still need a new press, and landing or reaching a differently facing wall enables another kick. Try the marked ledge and kick wall beside the east-side traversal route. Q launches at **12 m/s for 0.4 s** and reaches roughly **8 m** above its starting point in open space before descending into the glide; ceilings stop the ascent safely.

## Included

- Meridian Gardens: one player and eleven Nimbus bots, navigation across five elevations, fixed-hill capture/contest/scoring, team-only safe rooms, eight-second respawns, ultimate retention, shared health pickups, match HUD, exploration mode and tactical atlas. First to 100% wins after the 20-second unlock and five-second uncontested capture.
- Nimbus's complete prototype kit: 45/90 body/head rifle, upward Hover, timed projectile reflection and hitscan blocking, 80-peak bomb with falloff and cover checks, and 150-damage Final Notice with a pre-hit 20% execution check.
- Shared acceleration, braking, air steering, jump buffering/coyote time, collision-checked mantling, wall jumps, fixed-direction dash, both slide entries, and collision-aware shoulder camera.
- A 4.8 m committed melee lunge for engages/finishers, finite frontal guard with attacker stagger, interruptible 2.8 m throws, counterthrows, and an articulated pull/hip-lift/turn/slam/get-up animation. Slam damage occurs at impact; both participants retain 90% outside-damage reduction during the pair.
- Reload movement retains 85% of normal speed (5.1 m/s); shoulder aiming retains its usual 60% cap. Reload still takes 1.6 s and prevents firing until complete.
- Six bot profiles; seven exercises including the stationary guard drill; spawn/despawn; 250/500 HP experiments; 19/20/21% target presets; shield/invulnerability controls; AI settings; resource refills; movement presets; live combat tuning; route timer; event export.
- Cover, firing lane, slope, elevated traversal platforms, and a ranged projectile-emitter opponent. The crossfire exercise uses a third-faction probe to test damage on **both** throw participants while preserving friendly-fire rules.
- All gameplay components and per-actor resources are shared by player and bots. Multiplayer and the remaining roster are deferred.

## Verify

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify.ps1
# Add -Capture to render arena and console PNGs.
```

Or use Godot directly:

```text
godot --headless --path . --editor --import --quit
godot --headless --path . --script res://tests/rules_test.gd
godot --headless --path . --script res://tests/close_combat_test.gd
godot --headless --path . --script res://tests/guard_drill_test.gd
godot --headless --path . --script res://tests/block_feedback_test.gd
godot --headless --path . --script res://tests/traversal_test.gd
godot --headless --path . --script res://tests/traversal_flow_test.gd
godot --headless --path . --script res://tests/mantle_exit_test.gd
godot --headless --path . --script res://tests/integration_test.gd
```

Results are written to `artifacts/`. The current suite passes **530 checks**, plus **1,358 structural collision probes**. City checks cover healing, objective heights, spawn protection, respawns, complete resets, route timings, physical stairs/shop/subway traversal, roof landings, navigation recovery and camera clearance. Two ten-minute simulations pass without persistent stuck bots. The field guide includes reproduction commands and surface/underground 1080p benchmarks. See `docs/PLAYTESTS.md` for performed checks; competitive balance and game feel still need human playtesting. Tune `resources/nimbus.tres` or the map definition through the Inspector.

## Layout

`scenes/actors` composes the common actor. `scripts/actors` owns intent, actor state, movement and camera. `scripts/abilities` owns Nimbus and close-combat lifecycles. `scripts/combat` is the offline authority boundary for damage, cover and projectiles. `scripts/presentation` owns geometry, animation and sound. `scripts/training` owns exercises, bots/debug control and HUD. All dimensions are meters, times seconds, health/damage HP.

The city uses a reusable batched architecture kit, a baked pedestrian navigation mesh, original material shaders and static indirect lamp illumination. Nimbus retains the existing prototype character art and procedural animation. Human keyboard/mouse playtesting remains useful for responsiveness, route difficulty and combat balance. See `docs/DECISIONS.md` and `docs/TASKS.md` before extending it.

To render the revised combat choreography for review, run `godot --path . --script res://tests/capture_close_combat.gd --fixed-fps 60 --resolution 1100x720`. It writes actual engine frames under `artifacts/combat-frames/`.
