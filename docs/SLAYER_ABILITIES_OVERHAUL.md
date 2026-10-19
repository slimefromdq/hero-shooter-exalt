# Slayer ability, projectile and VFX overhaul

Implemented from the Task 2 brief, building on the Phase 1 shotgun presentation. The two intentional gameplay changes are limited Boot Rush steering and physical knife gravity. All damage, shield/guard/deflect rules, ammo/charges, cooldowns, attachment/CC/knockback/recovery timings, projectile radii, piercing, debuffs and ranges retain their established values. Other hero kits and the character model are unchanged.

## Boot Rush

`SlayerTuning.boot_turn_rate` defaults to **40 degrees/second** and `boot_max_steer_angle` to **15 degrees**. The launch direction is captured once. Active steering reads live world-space `CombatIntent.move` (WASD in PlayerController), not HeroActor's deliberately locked aim direction. Input requests a heading clamped relative to launch; `move_toward` advances heading by turn rate times delta. No input holds the current heading. Pure backward input cannot reverse the attack or choose an arbitrary turning side. Forward input can bring the heading back toward launch. There is no target tracking.

Steering rotates about world UP, preserving the launch vector's vertical component and the existing airborne vertical/gravity rules. Body yaw and aim used by Boot Rush contact tests follow the steered direction in the same movement update. Existing capsule sweeps, short movement steps, thin-wall stops, and swept target checks remain authoritative. Speed is still 32 m/s and the travel budget is still 12 m. Steering changes the path, not the budget. The nine-second cooldown, 55 damage, 0.45 s hold, launch impulse, and hit/miss recovery values are unchanged.

Presentation now includes a lowered launch pose and leading-leg surge, two bounded crimson/silver world-space ribbons following actual motion, restrained timed speed/ground sparks, turn lean, rushing wind, a directional contact flash/shockwave, revised attachment and kick poses, contact camera feedback, and a smaller miss effect with a recovery dip. Control returns through the existing rules; the pose eases out as the existing slow expires. Wind stops on contact, recovery, interruption, or cleanup; its distance gain follows the moving owner.

## Heads Will Roll

The shared axe mesh has its shaft along local Y and blades in **local XY**, with thickness in Z. The old arbitrary local-X rotation did not preserve that cutting plane. The projectile now has three separate transforms:

1. The physics/travel root points local -Z along travel (including elevated shots).
2. A fixed mesh frame rotates Y by +90 degrees, placing mesh X along travel, Y upward, and Z across travel.
3. The mesh tumbles around its own **local Z blade normal**, starting at -45 degrees so the head initially leads. `axe_spin_rate` defaults to **20 radians/second** and is editable. This is clockwise in the mesh cutting plane, with no mirrored world-direction branch.

Projectile visual scale is **1.215**, exactly 1.35 times the former 0.9. The broader faceted head has separate polished cutting edges, dark metal body, heavier shaft, wrapped crimson grip, silver collars and a decorative metal hub. Held and thrown weapons share the same cached mesh; the held variant uses 0.82 scale rather than the former 0.7.

**Visual/collision mismatch is deliberate:** the physical sphere remains radius **0.55 m**. The largest visible head corner reaches approximately **1.81 m** from the mesh pivot at projectile scale. Blade silhouette/trails therefore extend beyond the damaging sphere, especially near the head and handle. This pass does not enlarge damage reach to match the art. Future alignment is a separate balance decision.

Windup energy and upward fragments accompany the revised anticipation pose and charge sound. Release gets follow-through and an air-displacement burst. A central path ribbon and a second ribbon sampling the actual spinning blade edge show flight and tumble. Impact layers a large directional burst, fragments, expanding ring, heavy sound, and a small violet wound pulse. Confirmed maximum-health wounds get a restrained once-per-second marker while the actual status remains active. Piercing, 110 direct damage, shield restrictions, 50% maximum-health wound, eight-second duration, speed 20 m/s, 30 m range, and radius are unchanged.

## Silver knives

Held, belt and thrown knives share a cached three-surface ArrayMesh with one draw node per weapon: tapered point, raised central ridge, bright blade highlight, silver guard/fittings, and dark wrapped grip. No external model or sound assets are required.

Each knife initializes `velocity = initial_direction * 110 m/s`. Editable `knife_gravity` starts at **12 m/s�**. Physics integrates `motion = velocity * dt + 0.5 * acceleration * dt�`, then updates velocity. Each real displacement is swept by the 0.17 m sphere. Short chords of at most 1/240 s keep curvature/collision consistent at 30, 60 and 144 Hz. Range is accumulated from actual swept movement and expires at 50 m. Visual forward follows instantaneous velocity; no fake visual drop is applied over a straight collision path.

For a level unobstructed throw, analytical drop is about 5 cm at 10 m and 20 cm at 20 m. The initial aim direction and launch speed are preserved; aim compensation is left to the player. Thirty damage and the existing four-second/eight-DPS bleed remain unchanged. Existing Nimbus deflect **consumes** these projectiles; it did not reflect them previously, and this behavior is retained. Team collisions and barrier handling remain unchanged.

Release uses a silver glint, flight a narrow silver-blue ribbon, and impact a short contact flash and metal/piercing cue. Flesh is crimson, remaining shields cyan, barriers violet, deflect mint, and world contacts tan. Bleed application adds a separate small crimson burst under the existing application rules.

## Reuse, budgets and cleanup

- `SlayerWeaponMeshes`: cached original geometry, three shared materials/surfaces per weapon; no per-projectile material/geometry rebuild.
- `SlayerRibbon`: persistent ImmediateMesh with at most 32 world-space samples, finite sample lifetime, and no per-frame scene spawning. It visualizes actual path/spin samples only.
- `slayer_ability_energy.tscn`: reusable finite 0.5 s burst with ten one-shot GPU sparks/fragments, shrinking contact flash, expanding translucent shockwave, and shadows disabled. Tint, placement and scale distinguish ability phases.
- The Phase 1 pool prewarms another 32 ability bursts. The reserved pools are now 16 shotgun muzzles, 48 shotgun impacts and 32 ability bursts (96 reserved nodes; 992 total particle slots). The shared **64 active burst** world limit is preserved, with at most 12 active ability bursts per Slayer; saturation drops presentation only. Startup prewarming avoids Godot's GPU particle constructor consuming gameplay RNG on casts or switches.
- Phase 1 shotgun code, burst scenes, fallback and exact gameplay recoil are preserved. Ability camera feedback reuses the same projection-offset/local-roll mechanism without changing the aim ray.
- Presentation observes ability state/results; it never drives damage, physics or cooldowns. Owner death, reset, switching and scene exit recycle bursts and clear ribbons/audio. Windup interruption clears local effects and charge/wind cues. Existing already-launched attacks retain their normal interrupt behavior; a stun does not silently erase valid in-flight damage. Life-serial checks additionally reject stale projectiles after respawn.

## Audio replacement slots

Original finite cached procedural sounds supply launch transients, rush wind, low impact bodies, inharmonic metal, charge sweeps and knife glints/piercing feedback. They use private seeded noise. The Phase 1 bounded eight-voice overlap mechanism is retained, including separate shotgun blast/pump layers.

`resources/slayer_audio.tres` now has an `ability_cues` dictionary mapping cue names to optional original/licensed finite AudioStreams. Useful keys are `boot_start`, `boot_wind`, `boot_hit`, `boot_kick`, `boot_recover`, `axe_draw`, `axe_release`, `axe_hit`, `knife`, `knife_hit`, plus `knife_shield`, `knife_barrier`, `knife_deflect`, `knife_world` and the corresponding `axe_*` surface keys. Empty entries use synthesis. Use non-looping streams shorter than three seconds; `boot_wind` is also explicitly stopped when active travel ends. These replace their synthesized cue; they do not layer duplicate external and procedural copies.

## Reproduction and review

`tools/verify.ps1` includes `tests/slayer_abilities_overhaul_test.gd`, which has 71 focused checks. Supplemental rendered execution uses Vulkan and the same assertions. Existing Slayer and Phase 1 tests remain in the suite.

Run the capture script through Godot with `--path . --script res://tests/capture_slayer_abilities.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60`, or use `tools/verify.ps1 -Capture`. Fifteen PNGs under `artifacts/slayer-task2-*` cover Boot startup/curve/contact/kick, axe windup/impact, four actual side-view spin positions at 0/0.05/0.10/0.15 s, frontal/trailing axe views, and knife detail/arc/hit. Nine isolated original cue WAVs are also exported. These are real engine-rendered actors/projectiles; the side-view inspection pauses between sampled physics updates to make the cutting plane reviewable.

Manual follow-up: assess steering comfort and commitment against moving players; inspect launch/attachment/recovery transitions during real play; listen on headphones/speakers for wind, charge and impact mix/overlap; assess axe silhouette versus its intentionally smaller hitbox and check trail readability from moving third-person cameras; judge knife glint/bleed distinction at medium range; benchmark pooled GPU particles on lower-end hardware. Dummy-audio captures and automated parity checks cannot establish listening quality or game feel. See `docs/validation/slayer-task2-results.json` for the recorded checks and capture inventory.
