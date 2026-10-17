# QoL and balance pass · October 17, 2026

## Play and controls

`Launch.ps1` now opens Main Menu → Match/Training → Hero Select. All five existing heroes have portraits, roles and kit descriptions. Pause offers hero selection, settings, restart, mode switching, main menu and quit. Advanced training exercises and tuning remain under Advanced Training Tools. Explicit `-Training` and hero launcher switches retain direct entry.

Dash is **scroll wheel up**, with no default `3` binding. Slide remains **hold Shift**. A ground-start dash is horizontal. An air-start dash follows full 3D aim and converts to slide only with a fresh Shift press no more than **0.12 s** before downward floor impact, with enough projected speed. Holding Shift before dashing fails. Failed conversions require releasing Shift before ordinary slide entry; walls and ceilings never qualify. No extra momentum or cooldown reset is awarded.

Loaded normal-weapon shots during a physically grounded, held slide cost no ammunition. Empty magazines still need reload; rate limits and ability resources are unchanged. Melee lunges travel **6 m over 0.40 s**, with the final movement resolved safely at the start of recovery and no residual velocity bonus.

Holding Shift below slide-entry speed crouches, with **50% walking speed** and a **1.2 m capsule**. Momentum/downhill slides take priority, and a slowing slide returns to crouch while Shift stays held. Release stands when there is enough headroom; under low cover the hero remains crouched and can crouch-walk out. Camera, muzzle and headshot height follow the lower stance. Crouching allows ordinary firing and concurrent reloads, and never grants slide ammunition. Air-dash timing and failed-conversion rearming remain unchanged. Both crouch values are editable in `HeroTuning`.

## Reload, camera and feedback

Reload is a per-kit timer, independent of the actor action state. Movement, jumps, mantles, slides, dashes, guard, melee and abilities can coexist with it. Reload contributes no movement slowdown; aim and ability restrictions still apply. CC does not pause reload. Death, hero changes and resets cancel it. Weapons cannot fire until reload completes, including Slayer's full shell-loading sequence.

| Hero | Reload |
|---|---|
| Nimbus | 0.8 s |
| Marshal | 1.0 s |
| Doctor | 0.7 s |
| Huddle | 0.8 s |
| Slayer | 0.15 s startup + 0.22 s per missing shell |

Default shoulder framing is **3 m / 82°**, or **60°** when aiming. Nimbus keeps 34° ultimate zoom; larger barrier/wave cameras remain. Settings persist across scenes and launches in a versioned local config. The settings menu also controls mouse sensitivity, display mode and master/combat/feedback audio buses.

Nimbus's canopy moves higher and left/back from the aim line. Only the locally controlled Nimbus fades an obstructing canopy to **20%** opacity; other actors retain opaque umbrellas. HUDs expose independent reload progress, free slide ammunition and Nimbus's remaining ultimate shots.

`ControlFeedback` provides read-only snapshots of root, slow, stagger, counter break, throw capture, boot hold and forced displacement. Distinct symbols, names, timers, sounds and world markers supplement color. Bleed, wounds and buffs remain separate. Existing root/slow restrictions are preserved. CC cues use a separate audio channel, and synthesized tones use local noise so audio cannot alter gameplay random state.

## Health visibility follow-up

All allies and enemies have camera-facing overhead health bars with current/effective-maximum HP and a shield strip when applicable. Bars use green for allies and red for enemies, respect cover depth, hide on death and beyond 65 m, and return on respawn. The local hero retains the existing player HUD. City enemy roster cards now include live health bars and numeric HP; only allied cards show ultimate charge. Training ally meshes are initialized on the correct team, matching their bars and nameplates.

`tests/health_bars_test.gd` covers damage, healing, wounds, shields, death/respawn, visibility and both roster sides. `tests/capture_health_bars.gd` captures city bars at three aspect ratios and training ally bars.

## Hero balance

Slayer knives travel **110 m/s** with a **0.14 m** swept collision radius; traps launch at **18 m/s**. Boot Rush starts in **0.06 s**, with **1.65 m** forward reach and **0.55 m** sweep radius against enemy capsules. Collision-limited substeps retain cover, slopes and low-rate safety.

An unblocked boot deals **55 damage once**, then holds both participants at safe contact positions for **0.45 s**. Slayer can turn freely; the victim cannot act. The automatic release launches along Slayer's final horizontal facing at **18 m/s + 3 m/s upward** (increased from 11 m/s horizontally), without another damage packet. Guard rejects the hold and staggers Slayer. The pair receives ordinary outside damage, without throw mitigation. Death, removal, reset, cleanse, new movement control or external displacement breaks the attachment without a delayed kick.

Nimbus bombs use **140 peak damage, 5 m radius, 2 s fuse and 22 m/s throw speed**. Existing gravity, lift, bounce, falloff and cover rules remain. Only the owner's weapon traces can hit the bomb, and only before its first environment/barrier impact. Detonation is idempotent and credited to Nimbus. Other weapon traces ignore bombs.

Final Notice grants **three individually aimed shots in an eight-second stance**, after one 0.6 s preparation, at the existing 0.6 s cadence. Damage and execution rules remain. Third shot, timeout, cancellation or interruption ends the stance, with no charge refund.

## Practice range and hero switching

The training arena has an accessible northern wing, preserving the original traversal route. Its default exercise contains **six stationary enemies** in a compact 2×3 formation, **three patrolling enemies**, **three stationary shooters**, and **three allies at half health**. Up to eight manual targets can be added independently. Existing focused exercises remain separate selections.

Look at a physical panel within 2.5 m and press **F**. Prompts require line of sight. Panels reset each station, set enemy groups to 250 or 25 HP, toggle shooters, injure allies, apply bleed/slow/root test effects, and reset kill feedback. Firing starts disabled and station reset disables it. Dummies respawn after 3.5 s using normal actor rules. Training shares the city's real elimination, multikill and killstreak sounds/banners.

City hero selection applies immediately in the player's safe room; elsewhere it queues for the next respawn. Switching resets the player's ultimate, preserving the match, hill progress and existing bots. Training selection resets the player and exercise. Queues clear when applied.

## Verification

- `tests/crouch_test.gd`: crouch/walk for every hero, collision and weapon height, low headroom, slide priority, ammo, reloads, jump/dash transitions and stronger boot distance/wall collision.
- `tests/capture_crouch.gd`: all five crouched heroes at three aspect ratios, plus side views of crouch, slide and standing; PNGs in `artifacts/crouch/`.
- `tests/qol_test.gd`: shared movement, reload concurrency, ammo, boot lifecycle, bomb ownership, ultimate, training and menu construction.
- `tests/menu_flow_test.gd`: real scene transitions, settings control callbacks, hero-selection queue and match preservation.
- `tests/qol_input_test.gd`: native wheel pulses at 30/60/144 FPS, pause isolation, F interactions/occlusion and local-only canopy transparency.
- `tests/capture_qol.gd`: menus, all five hero cameras, umbrella and CC at 1440×900, 1600×900 and 2160×900; PNGs in `artifacts/qol/`.
- `tools/verify.ps1` runs focused checks and the existing regression suite. `-Capture` adds native input and rendering checks.

The seeded ten-minute city simulation also exposed a low-parapet navigation stall. Recovery now retains validated detour steering over optional support movement and permits checked jumps to level/lower landing surfaces. The recorded Huddle position is covered by `city_navigation_regression.gd`; no teleport recovery was introduced.

The crouch follow-up passed **64 focused checks**, **94 standing/crouched camera checks** and the full verification suite, including combat, hero, training, menu, traversal and city navigation regressions. Native wheel/interaction checks passed **14 checks**. Render review covered **18 crouch/slide captures** across 16:10, 16:9 and ultrawide. With ordinary stationary targets and default braking, the stronger boot travels about **6.90 m**, compared with **2.61 m** at the former release speed; thin-wall collision remains intact.

The final seeded ten-minute run passed all 17 stability checks, recorded 1 natural completed round(s), 110 eliminations, and no persistent stalls or navigation falls. The stress test also explicitly exercises ordinary score completion and restart after its soak instead of requiring every balance configuration to naturally finish within ten minutes. Scoring rules are unchanged.

Validation: the full verification script passed 1,460 checks across 26 groups; expanded menu-flow coverage passed 17 checks, native input/interaction/audio passed 14, native Slayer passed 47, and fullscreen passed 20. Render review covered 42 captures at three aspect ratios. The compact evidence record is [validation/qol-results.json](validation/qol-results.json).

All numerical buffs remain editable playtest defaults. Human playtesting is still needed to judge balance and feel.
