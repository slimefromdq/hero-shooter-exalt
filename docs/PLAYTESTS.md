# Verification and playtest record

## Engine and build

2026-10-16 · Godot **4.7.2.stable.official.ed1daf0bf** · Windows · GodotPhysics3D at 60 Hz. Rendered review used the Compatibility OpenGL renderer on an NVIDIA RTX 3080 at 1440 × 900. No human keyboard/mouse game-feel acceptance has been performed.

## Performed verification

- Editor import and class registration completed. The final project parses and launches in the actual pinned engine.
- **79 focused checks, zero failures** in `tests/rules_test.gd`. These use real actors, capsule sweeps, ray queries and simulation time. Coverage includes 45 body / 90 head single-hit rifle damage; muzzle obstruction; ammo/cadence/reload; actor independence; Final Notice just below/at/above 20%, shields and invulnerability; frontal/rear guard; committed melee; throw interruption, whiff, counter and simultaneous requests; both participants' 90% mitigation; full scripted throw damage; release and death cleanup; Hover ascent/glide/ceiling; physical projectile reflection; 80-peak bomb and cover; ultimate charge consumption; ordinary slide, ground dash slide, vertical fixed dash, wall/ceiling collision, downhill acceleration, uphill slowdown and cooldown continuity; reset of persistent combat/motion states.
- **35 integration checks, zero failures** in `tests/integration_test.gd`. Coverage includes ordinary-rule scene launch, all core named actions, physical keyboard/mouse event bindings, actual camera pull-in/restoration around collision, six-shot target elimination and respawn, strafing, freeze, ranged projectile damage and sightline blocking, close bot melee, sparring guard and delayed counterthrow, pair/scenario reset, crossfire probe setup, paused console/resume, route timer and repeated reset cleanup.
- **30 additional close-combat checks, zero failures** in `tests/close_combat_test.gd`. Actual 3.6 m swept lunge travel, a finisher from 5.75 m, fixed direction, wall/guard stops, reset during travel, capture at 2.6 m, no initial pull teleport, locked pair facing, physical lift with keyed body flip, damage exactly once at slam, supported landing, standing recovery, capsule exception cleanup, low-ceiling rejection, new-obstacle interruption, and reset/separation at three throw phases.
- **38 guard-drill and binding checks** in `tests/guard_drill_test.gd`: all nine requested physical keys, no cross-triggered actions, removal of old bindings, live key captions, no attacks beyond range, guard/stagger, planted bot across repeated damaging attacks, adjustable range/ring, cover, reset, ordinary spawning and one-click recovery from AI freeze. Total suite: **182 checks**.
- GPU-rendered arena and training-console images were captured and visually inspected. HUD text, ability rail, enemy labels, resource state and menu layout were reviewed. Lighting and anti-aliasing were adjusted after the first rendered review.
- Initial failures found and corrected: mutual grabs resolving as capture; low-speed slope slide ending before gravity could accelerate it; floor-normal bias opposing downhill motion; persistent audio generator references on shutdown. The final finite synth cues and test shutdowns produce no ObjectDB leak warnings.
- Verification runs keep generated user/editor data under `.tools/runtime`. A task-local editor save setting avoids this sandbox's Windows backup/rename error. The user's normal Godot editor settings are unchanged.

Machine-readable results and rendered PNGs are written to the ignored `artifacts/` directory. Event export through the console writes the latest 200 events to `user://combat_events.json`.

## Human acceptance still required

1. Play the east-side route through the gap, narrow platforms and finish deck; use ordinary slide, the west ramp downhill slide, dash-to-ground slide and Hover. Compare the responsive and weighty presets. Record time, falls, overshoots and landing accuracy.
2. Repeat while aiming at a moving target. Judge mouse sensitivity, shoulder placement, camera comfort near cover, landing readability and perceived weight independently of response time.
3. Fight ranged and sparring bots with debug overrides off. Demonstrate rifle, bomb, Hover, Deflect, melee, guard, throw and counter separately, then test the suggested combinations.
4. Use the console's 19/20/21% HP, shield and invulnerability controls to inspect Final Notice tells and outcomes. In the crossfire exercise, observe damage during both ends of the paired throw.
5. Die/reset interactively during reload, guard, capture, dash, slide, Hover, Deflect, bomb fuse and ultimate stance. Automated cleanup is covered; this pass checks presentation and input restoration.
6. Assess sound, startup/recovery tells, bot fairness and whether aerial firing dominates. Record concrete observations before changing balance.

## Known prototype limits

Original geometric characters and procedural poses stand in for authored animation and art. The slide keeps the standing collision capsule; low-clearance crouch traversal is not implemented. Bot navigation uses local obstacle rays, simple routes and stuck recovery; complex navigation and parkour remain deferred. Route overshoots are a rough floor-return metric, not an automatic judgment of player error. The stage has a safe continuous foundation beneath the route, so platform misses usually cost route time rather than lives. No networking, objective play, other heroes or final balance is claimed.

## Next experiment

**MOVE-FEEL-01** — Compare the two movement presets with the same route and ranged opponent. Record completion/landing metrics and player explanations. Hold kit values constant. Choose the next single adjustment from observed loss of control, missed readability or dominant aerial angles.

## CQ-FEEL-02 · Revision after user feedback

**Observed feedback supplied by the user:** throws and melee feel very bad. Requested forward melee travel to reward engages/finishers, greater throw reach and a real throw animation.

**Implemented:** 2.2 m committed lunge; startup/active/recovery 0.24/0.2/0.4 s; grab reach 1.8 → 2.8 m; paired duration 0.85 → 1.1 s. Articulated AnimationPlayer clips now pose both characters through reach, draw-in, hip lift, turn, slam and get-up. A shared physics path moves the victim and checks landing/clearance; damage triggers at 72% impact. Holding a camera direction cannot redirect either committed motion.

**Rendered verification:** inspected the actual engine's reach, draw-in, inverted lift, slam, get-up and release frames, plus the moving melee finisher. The rendered throw ended at 155 HP and returned both actors to ready; the melee preview finished a 50 HP target after 2.2 m of travel. Preview capture uses frozen AI and scripted input; it is a visual check, not a claim of human gameplay feel testing. A preview setup issue (detaching the bot controller while the training manager still expected it) was corrected by disabling the manager during capture.

**Next feel pass (updated controls):** use 5 from around 5 m against an injured moving target, then try a miss and a frontal guard. Use 4 from 2–2.8 m against a guarding bot, then test a counterthrow and nearby cover. Judge whether the commitment and slam read clearly in the normal shoulder camera before changing damage.

## CQ-FEEL-03 / TRAIN-GUARD · Further user request

Melee travel is now 3.6 m over 0.34 s, with damage and the startup/active/recovery commitment unchanged. Added Guard drill with a stationary bot that attacks only inside a 2.4 m visible ring at a default 1.6 s interval. It uses the shared melee resolver with travel disabled for that training cast. Input mappings and all live prompts follow the user's requested number/ability layout.

The rendered drill showed the new range ring, key labels and a blocked strike leaving Nimbus at 250 HP and the bot staggered. Keyboard events verified 3/Q/E/1/2/Shift/5/4/6 independently. These checks establish behavior and presentation; evaluation of the longer melee's feel remains a human playtest.
