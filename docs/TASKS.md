# Nimbus milestone status

Implementation date: 2026-10-16. The project is playable; completion of human acceptance is tracked separately from implementation.

| Ticket | Status | Evidence |
| --- | --- | --- |
| BOOT-01 | Implemented / engine launch checked | Fresh scene, pinned Godot 4.7.2, README and launcher |
| MOVE-01 | Implemented / automated physics checks | Acceleration, jump, air control, shoulder camera, route geometry |
| MOVE-02 | Implemented / automated collision checks | 3D sampled dash, floor transition, ordinary and slope sliding, friction, cooldown isolation |
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
| Later roster/networking | Deferred by design | Preserve the established roster references in DESIGN.md |

Next work should evaluate the 4.8 m melee engage/finisher and use Tab → Start guard drill to practice holding 6 inside the range ring. Check the block clang/impact, attacker recoil, reload strafing, commitment, whiff punishment and throw readability under fire. Do not infer accepted balance from passing correctness tests.
