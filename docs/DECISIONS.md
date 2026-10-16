# Implementation decisions · Nimbus training slice

2026-10-16. The attached design remains the source of established creative decisions. This record distinguishes implementation assumptions from accepted balance. No proposed tuning is promoted to an accepted design decision by this build.

## Foundation

- Fresh project in this workspace; no earlier hero projects imported.
- Requested engine family: Godot 4.7. Installed and verified exact engine: **4.7.2.stable.official.ed1daf0bf**. `.godot-version` pins 4.7.2 stable.
- Offline third-person Nimbus versus bots is the implementation scope. Slayer, Ahab, Annex, the reserve heroine, networking and objectives remain deferred.
- Compatibility renderer with 4× MSAA, GodotPhysics3D, 60 Hz physics. Keyboard/mouse, original procedural meshes and short original synth cues. No downloaded art or dependencies.
- Lightweight SceneTree test scripts provide actual Godot physics/ray/actor tests without a third-party runner.

## Proposed defaults selected for unresolved details

All fields live in `HeroTuning`. Values can be changed through the Resource Inspector; important close-combat and movement fields also appear in the training console.

| Experiment | Initial implementation |
| --- | --- |
| Dash | 0.16 s buildup; direction sampled at end; 22 m/s; 26 m/s² decay; 0.38 s burst; 4.5 s cooldown; one charge; air use allowed; no invulnerability |
| Slide | 5 m/s ordinary entry; slope entry at 8°; 3.6 m/s² friction; gravity acts on floor tangent; 26 m/s global speed cap; automatic continuation after ground dash |
| Movement | 6 m/s ground; 30 m/s² acceleration; 24 braking; 7.5 air steering; 8 m/s jump; 22 m/s² gravity; 0.1 s edge forgiveness, 0.12 s jump buffer |
| Hover | 8.5 m/s ascent for 0.3 s, then up to 2.5 s glide approaching 1.6 m/s descent; cooldown after end |
| Melee | 75 HP; 2.6 m; 0.32 s startup / 0.13 s active / 0.5 s recovery; no action cancels |
| Guard | 100 meter; 24/s drain; 35/s immediate regen after release; 28 per blocked strike; 2 s re-block cooldown; 15% movement; 0 bullet reduction |
| Throw | 1.8 m; 0.3 s startup; 0.65 s whiff; 0.24 s counter window; 0.85 s pair; 95 HP scripted damage; outside damage ×0.1 on both; 0.8 s re-grab grace |
| Ultimate economy | Starts ready for training; +0.8%/s and +0.09% per HP damage. Consumed on stance entry, no cancellation refund. This economy is a sandbox assumption. |
| Rifle head region | One capsule ray hit; upper 1.5–1.9 m is head, lower section body. A single hit record prevents overlapping head/body duplicate damage. |
| Bot response | 0.22 s default, adjustable 0.05–1.5 s; 15% configured counter error; local ray avoidance and stuck recovery. No full navigation mesh or parkour planner. |

## Action permissions

The actor state table is authoritative; procedural animation never applies damage. State and motion mode are shown by F3.

| State | Permitted actions |
| --- | --- |
| Ready, ground/air/slide/Hover | Rifle, aim, reload, kit, jump, shared combat; dash additionally requires cooldown |
| Dash buildup / dash | Steering intent is suppressed during the burst; no other combat casts |
| Melee startup / active / recovery | Limited translation; no rifle, guard, throw, dash or abilities |
| Guard | Slow translation, release; responding counterthrow input; no gun/kit casts |
| Throw startup / whiff | Limited translation, no new casts; damage interrupts startup |
| Captured / throw pair | No translation or unrelated actions; outside damage ×0.1; scripted throw damage bypasses only pair mitigation |
| Deflect / reload | Limited translation; no competing casts |
| Final Notice | Aim and prepared primary shot; X cancels; slow movement |
| Stagger / counter break | Brief explicit control restriction; no casts |
| Release | Clears at next physics update with no added timed stun |
| Dead | No gameplay intents until training reset/refill |

## Collision and combat assumptions

- All actor movement uses CharacterBody3D sweeps. Dash floor contact projects the existing velocity once into slide. Wall and ceiling hits cannot create a floor slide. Slide owns its tangent momentum so the floor solver's normal correction cannot create or destroy downhill momentum each tick.
- Third-person shots first resolve camera aim, then muzzle-to-target obstruction, including a shoulder-to-muzzle check for a barrel already inside cover.
- Friendly fire is off. Explosions do not damage their owner in this prototype. Bombs bounce only on environment geometry; detonation does radial falloff and line-of-sight checks.
- Executions inspect pre-shot HP and require shields already at zero. A shot that depletes shields is ordinary damage. Invulnerability rejects the hit. Pair damage mitigation also applies to Final Notice; it cannot bypass the protected sequence.
- Reflections transfer source/team and aim along the defender's aim; one reflection per Deflect cast per projectile, with two total reflections maximum to bound loops. Hitscan blocks without reflection. Melee and explosions bypass Deflect.
- Throws require facing, range, clear line, non-overlapping swept capsule placement, and valid actor state. A mutual startup is a single counter break. During the paired presentation, authoritative capsule positions remain separated at validated locations; animation supplies lift and rotation. Release never teleports into new geometry.
- Stagger/capture cancels a live stance but does not delete already thrown bombs. Death, despawn and scenario reset remove owned bombs/projectiles. Reset releases both ends of any pair, clears effects and AI state, and restores selected scenario health/resources.
- Crossfire laboratory deliberately adds a **third team** probe that alternates aim between the two participants; ordinary enemy friendly-fire rejection remains intact.
- Bot corpses remain as non-colliding meshes, then respawn after 3.5 s. Player death waits for F5 or F6. AI freeze stops intent; opening the console pauses the simulation.
- Event records include physics tick, actor, ability, cast, hit type and applied damage. Recent 200 events can be exported to `user://combat_events.json`. Runtime state is never stored in shared tuning resources.

## Remaining design choices

All numerical balance, bullet guard reduction, future cancel windows, camera feel, team sizes, long-term ultimate economy, full bot navigation and multiplayer prediction remain open. A human playtest is required before accepting the movement presets or combat timings.
