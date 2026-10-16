# Nimbus · Field Training

A playable offline third-person hero shooter prototype built from `docs/DESIGN.md`, using original geometry and synth sound cues. **Godot 4.7.2 stable** is the verified engine (`4.7.2.stable.official.ed1daf0bf`).

## Play

Import **project.godot** in Godot 4.7.2 and press **F6** to run the training scene, or **F5** to run the project. On Windows, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\Launch.ps1
```

`Launch.ps1 -Editor` opens the editor. The launcher finds the installed 4.7.2 console executable in Downloads or `GODOT_BIN`. It does not download an engine. Click the game to capture the mouse; **Tab** opens the paused training console, **Esc** also toggles it. An ordinary-rule live-fire scenario launches immediately.

## Controls

| Input | Action |
| --- | --- |
| WASD / mouse | Move / look |
| Left click / right hold | Semi-auto umbrella rifle / shoulder aim |
| R / Space | Reload / jump |
| Shift | Crosshair-directed 3D dash, after a short buildup |
| Ctrl hold | Momentum slide; downhill entry works from low speed |
| E | Hover: upward burst, then glide; press again to end |
| Q / G | Frontal Deflect / bouncing Pocket Bomb |
| X, then left click | Final Notice stance, then one shot after preparation; X cancels |
| V / C hold / F | Committed umbrella strike / melee guard / throw or timed counterthrow |
| Tab or Esc | Paused training console / return to play |
| F3 / F5 / F6 | State and hitbox telemetry / scenario reset / training refill |

Bindings use named InputMap actions in `scripts/training/input_bindings.gd`. Existing editor-configured bindings take precedence. A downward dash automatically enters a momentum slide. Jump ends a slide; holding and then releasing Ctrl can also end an automatic dash slide. Guard limits movement and does **not** reduce bullets at the default setting.

## Included

- Nimbus's complete prototype kit: 45/90 body/head rifle, upward Hover, timed projectile reflection and hitscan blocking, 80-peak bomb with falloff and cover checks, and 150-damage Final Notice with a pre-hit 20% execution check.
- Shared acceleration, braking, air steering, jump buffering/coyote time, fixed-direction dash, both slide entries, and collision-aware shoulder camera.
- Committed melee, finite frontal guard with attacker stagger, interruptible throws, counterthrows, paired animation/90% outside-damage reduction, and safe release.
- Five bot profiles; six exercises; spawn/despawn; 250/500 HP experiments; 19/20/21% target presets; shield/invulnerability controls; AI settings; resource refills; movement presets; live combat tuning; route timer; event export.
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
godot --headless --path . --script res://tests/integration_test.gd
```

Results are written to `artifacts/`. See `docs/PLAYTESTS.md` for performed checks and the remaining human playtest. These automated checks do not establish game feel or final balance. Tune the Resource in `resources/nimbus.tres` through the Inspector; the training console edits isolated runtime copies.

## Layout

`scenes/actors` composes the common actor. `scripts/actors` owns intent, actor state, movement and camera. `scripts/abilities` owns Nimbus and close-combat lifecycles. `scripts/combat` is the offline authority boundary for damage, cover and projectiles. `scripts/presentation` owns geometry, animation and sound. `scripts/training` owns exercises, bots/debug control and HUD. All dimensions are meters, times seconds, health/damage HP.

The prototype uses deliberately simple geometry, local obstacle avoidance and procedural animation. It requires human keyboard/mouse playtesting for responsiveness, camera comfort, route difficulty and combat readability. See `docs/DECISIONS.md` and `docs/TASKS.md` before extending it.
