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
| Melee | 75 HP; 2.6 m hit reach plus up to 3.6 m collision-limited travel; 0.24 s startup / 0.2 s active / 0.4 s recovery; no action cancels. Lunge starts at 0.06 s and lasts 0.34 s. Direction is fixed on input. |
| Guard | 100 meter; 24/s drain; 35/s immediate regen after release; 28 per blocked strike; 2 s re-block cooldown; 15% movement; 0 bullet reduction |
| Throw | 2.8 m; 0.3 s startup; 0.65 s whiff; 0.24 s counter window; 1.1 s pair; 1.05 m lift; impact at 72% of the pair; 95 HP scripted damage; outside damage ×0.1 on both; 0.8 s re-grab grace |
| Ultimate economy | Starts ready for training; +0.8%/s and +0.09% per HP damage. Consumed on stance entry, no cancellation refund. This economy is a sandbox assumption. |
| Rifle head region | One capsule ray hit; upper 1.5–1.9 m is head, lower section body. A single hit record prevents overlapping head/body duplicate damage. |
| Bot response | 0.22 s default, adjustable 0.05–1.5 s; 15% configured counter error; local ray avoidance and stuck recovery. No full navigation mesh or parkour planner. |

## Action permissions

The actor state table is authoritative; procedural animation never applies damage. State and motion mode are shown by F3.

| State | Permitted actions |
| --- | --- |
| Ready, ground/air/slide/Hover | Rifle, aim, reload, kit, jump, shared combat; dash additionally requires cooldown |
| Dash buildup / dash | Steering intent is suppressed during the burst; no other combat casts |
| Melee startup / active / recovery | Swept, committed forward lunge during startup/active; limited normal translation in recovery; no rifle, guard, throw, dash or ability cancels |
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
- Throws require facing, range, clear line, a validated full capsule trajectory and a supported landing. A mutual startup is a single counter break. Capture starts at the victim's real position, draws them to the hip, lifts and carries their capsule, then lands them to the attacker's forward right. Only the paired capsules ignore one another during the sequence; environment and other actors still collide. New obstacles abort at the last swept position. An interrupted lift retraces safe travel to separate the pair before restoring normal capsule collision.
- The actual AnimationPlayer library has separate reach, thrower, victim and melee clips with keyed torso, shoulder, elbow, hip, knee and weapon tracks. Physics supplies normalized progress, positioning and the single slam damage event. Keyframes cannot grant damage, mitigation or control. Impact timing stays aligned with the configurable slam point. The victim's keyed get-up completes inside the paired sequence, with no additional release stun.
- Stagger/capture cancels a live stance but does not delete already thrown bombs. Death, despawn and scenario reset remove owned bombs/projectiles. Reset releases both ends of any pair, clears effects and AI state, and restores selected scenario health/resources.
- Crossfire laboratory deliberately adds a **third team** probe that alternates aim between the two participants; ordinary enemy friendly-fire rejection remains intact.
- Bot corpses remain as non-colliding meshes, then respawn after 3.5 s. Player death waits for F5 or F6. AI freeze stops intent; opening the console pauses the simulation.
- Event records include physics tick, actor, ability, cast, hit type and applied damage. Recent 200 events can be exported to `user://combat_events.json`. Runtime state is never stored in shared tuning resources.

## Remaining design choices

All numerical balance, bullet guard reduction, future cancel windows, camera feel, team sizes, long-term ultimate economy, full bot navigation and multiplayer prediction remain open. A human playtest is required before accepting the movement presets or combat timings.

## CQ-FEEL-02 · User-directed revision

The user reported that melee and throws felt bad and requested forward-traveling melee, increased throw range and an actual throw animation. This establishes the new interaction direction, replacing the original in-place strike and simple paired tilts. The numbers above are the first proposed defaults for another feel pass. Melee damage, throw damage, guard rules and counterthrow are preserved.

## CQ-FEEL-03 · Longer engagement and guarding practice

The user requested more melee travel, a stationary bot that strikes at a specific range, and personal key bindings. Lunge travel increases from 2.2 to 3.6 m, with its duration extended from 0.28 to 0.34 s. A normal strike can finish an injured target initially 5.75 m away in the focused check; obstacles and frontal guard still stop travel.

The Guard trainer profile issues zero movement intent and requests a stationary version of the shared melee action. This suppresses that cast's lunge without modifying shared tuning resources. It strikes inside the smaller of its configured trigger range and actual melee hit reach. Default range is 2.4 m; interval 1.6 s; both are editable. Normal windup, hit deduplication, facing, line of sight, damage, guard and stagger all apply. The range ring and bot/HUD prompts expose the exercise rules. The dedicated start button resets the exercise and enables AI.

Saved bindings are now 3 dash; Q Hover; E Deflect; 1 bomb; 2 ultimate; Shift slide; 5 melee; 4 throw/counter; 6 guard. The old V/C/F/G/X/Ctrl combat bindings are removed. Runtime defaults and the persisted project map agree; ability cards, guard/counter prompts and preview labels derive their keys from the actual InputMap.
