# Hero milestone status

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
| MAP-03 | Implemented / 230 city checks, 1,364 collision probes and rendered review | Open conservatory roof, low promenade firing rails, two direct hill-approach stairs, retained station underpasses, subway bot rotation and atlas updates |
| MAP-04 | Implemented / 110 traversal checks, 2,440 surface probes, 4,348 winding checks and close rendered review | Correct custom mesh culling, closed stair treads/risers, supported outer flights, finished trench cheeks/rims and guardrails; see GEOMETRY_AUDIT.md |
| MAP-05 | Implemented / 360 city/route checks, 2,480 surface probes, 4,348 winding checks and rendered review | All 18 flights in both directions; rail collision and tread support; complete promenade corners; clear study/outer stair widths; terrace guards and closed architectural seams |
| MAP-06 | Implemented / 455 city/route checks, 2,516 surface probes, 4,420 winding checks and rendered review | Courtyard-facing switchbacks on all four outer approaches, clear entrance supports, clipped spawn paving and ground inlays, updated bot/atlas routes |
| DISPLAY-01 | Implemented / 20 native display checks and rendered review | F11 / Alt+Enter, both pause menus, saved fullscreen preference, restored window geometry, proportional HUD and expanded widescreen/ultrawide viewport |
| SLAYER-01 | Implemented / 108 focused checks, 28 scene checks and rendered review | Complete kit, statuses, selection, AI and training; see SLAYER.md |
| SLAYER-FEEL-02 | Implemented / 32 focused + native input checks and rendered review | 12 m kick with fading recovery slow, E buffering/feedback, single downward snare toss, tighter 100-damage shotgun, knife trails, readable numbers, horizontal health strip and keyed throws |
| SLAYER-FEEL-03 | Implemented / 47 focused + native input checks and rendered review | Reliable enemy knockback across movement states, faster knives/kick, 90-damage shotgun, shorter axe windup, timed aimed snare toss, 275 HP, crosshair ammo, closer shared camera and 3.2 m shared throws; 715 headless checks and a ten-minute simulation pass |
| SLAYER-STABILITY | Verified / mixed roster and native display | 15 simulation checks, 20 display checks, original 530 checks and 1,358 collision probes pass |
| Later roster/networking | Deferred by design | Nimbus and Slayer are playable; preserve remaining references in DESIGN.md |

Next work should evaluate the 4.8 m melee engage/finisher and use Tab → Start guard drill to practice holding 6 inside the range ring. Check the block clang/impact, attacker recoil, reload strafing, commitment, whiff punishment and throw readability under fire. Do not infer accepted balance from passing correctness tests.

Traversal follow-up: hold Space and move into the marked ledge, keep holding through jumps toward higher lips, and press Space beside a wall while airborne. Run forward beside the left/right walls and judge whether the kick carries your approach momentum smoothly. Combine Q's higher launch with the towers. Evaluate grab reach, climb duration, wall-kick push and camera comfort before accepting these tuning values.

Mantle exit follow-up: approach at running or faster traversal speed, climb and continue forward; press Space near the end to launch straight into a jump. Check that the quicker climb still reads clearly and preserves the expected travel direction without a stop at the top.

City follow-up: play the revised main approaches, inner stairs and underground shops using the shoulder camera. Evaluate hill pressure, flank commitment, health-pack contention and cover readability with human input. M opens the atlas; B switches its surface/underground layer. Automated simulations and rendered FPS samples establish functionality and a performance baseline; competitive balance remains a playtest decision.
