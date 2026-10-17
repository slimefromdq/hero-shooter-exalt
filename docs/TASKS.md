# Nimbus milestone status

Implementation date: 2026-10-16. The project is playable; completion of human acceptance is tracked separately from implementation.

| Ticket | Status | Evidence |
| --- | --- | --- |
| BOOT-01 | Implemented / engine launch checked | Fresh scene, pinned Godot 4.7.2, README and launcher |
| MOVE-01 | Implemented / automated physics checks | Acceleration, jump, air control, shoulder camera, route geometry |
| MOVE-02 | Implemented / automated collision checks | 3D sampled dash, floor transition, ordinary and slope sliding, friction, cooldown isolation |
| MOVE-03 | Implemented / 34 focused traversal checks and rendered review | Ground/air mantle, safe lift-over path, wall jump and alternating-wall rearm, higher Nimbus umbrella launch, authored poses and marked practice geometry |
| MOVE-04 | Implemented / 25 focused flow checks and rendered controller verification | Held Space catches ledges through jumps and successive climbs; wall kicks preserve tangential momentum with outward push, independent of facing |
| MOVE-05 | Implemented / 21 focused handoff checks and rendered review | 0.32 s mantle, preserved horizontal exit speed, same-tick running / buffered jump, cap and collision checks, interruption cleanup |
| NIM-01 | Implemented / actual ray checks | 45/90 once per shot, ammunition/reload, cover and muzzle obstruction |
| CQ-01 | Implemented / automated interaction checks | Windup/active/recovery, frontal guard, meter, rear bypass, bullet baseline, stagger |
| CQ-02 | Implemented / automated pair checks | Startup interrupt, whiff, counter, simultaneous grabs, mitigation, scripted damage and release |
| CQ-FEEL-02 | Implemented / 30 focused physics and animation checks, rendered review | Forward melee lunge, expanded throw reach, keyed reach/lift/turn/slam/get-up, impact synchronization, obstacle aborts and capsule separation |
| CQ-FEEL-03 / TRAIN-GUARD | Implemented / dedicated input and guard-drill checks | 3.6 m melee travel; stationary range-triggered melee bot; range ring, cadence controls, one-click guard exercise and requested personal bindings |
| CQ-FEEL-04 | Implemented / focused feedback and movement checks, rendered review | Block clang/flash/rings/sparks, keyed recoil and daze marks; 4.8 m lunge; 85% reload movement |
| NIM-02 | Implemented / automated ability checks | Upward Hover then glide, timed Deflect, physical reflection and excluded attacks |
| NIM-03 | Implemented / automated rule checks | 80 peak bomb, falloff/cover, 150 Final Notice, threshold/shield/invulnerability and charge consumption |
| TRAIN-01 | Implemented / integration verification | Five profiles, six exercises, paused controls, refills, presets, debug and logs |
| NIM-ACCEPT | Automated checks and rendered review; human playtest pending | See PLAYTESTS.md; no claim of completed feel evaluation |
| MAP-01 | Implemented / integration, traversal, simulations and rendered benchmarks | Offline 6v6 Meridian Gardens, fixed-hill rules, protected spawns, health, respawns, nav roles, atlas, scenic railway and retained training |
| MAP-02 | Implemented / structural audit, physical traversal and rendered review | Supported roof/arch/stair geometry, matching structural collision, six through-shops and cover beneath the hill, underground atlas and progress recovery; see GEOMETRY_AUDIT.md |
| DISPLAY-01 | Implemented / 20 native display checks and rendered review | F11 / Alt+Enter, both pause menus, saved fullscreen preference, restored window geometry, proportional HUD and expanded widescreen/ultrawide viewport |
| Later roster/networking | Deferred by design | Preserve the established roster references in DESIGN.md |

Next work should evaluate the 4.8 m melee engage/finisher and use Tab → Start guard drill to practice holding 6 inside the range ring. Check the block clang/impact, attacker recoil, reload strafing, commitment, whiff punishment and throw readability under fire. Do not infer accepted balance from passing correctness tests.

Traversal follow-up: hold Space and move into the marked ledge, keep holding through jumps toward higher lips, and press Space beside a wall while airborne. Run forward beside the left/right walls and judge whether the kick carries your approach momentum smoothly. Combine Q's higher launch with the towers. Evaluate grab reach, climb duration, wall-kick push and camera comfort before accepting these tuning values.

Mantle exit follow-up: approach at running or faster traversal speed, climb and continue forward; press Space near the end to launch straight into a jump. Check that the quicker climb still reads clearly and preserves the expected travel direction without a stop at the top.

City follow-up: play the revised main approaches, inner stairs and underground shops using the shoulder camera. Evaluate hill pressure, flank commitment, health-pack contention and cover readability with human input. M opens the atlas; B switches its surface/underground layer. Automated simulations and rendered FPS samples establish functionality and a performance baseline; competitive balance remains a playtest decision.
