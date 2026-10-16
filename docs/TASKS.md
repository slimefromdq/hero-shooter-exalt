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
| NIM-02 | Implemented / automated ability checks | Upward Hover then glide, timed Deflect, physical reflection and excluded attacks |
| NIM-03 | Implemented / automated rule checks | 80 peak bomb, falloff/cover, 150 Final Notice, threshold/shield/invulnerability and charge consumption |
| TRAIN-01 | Implemented / integration verification | Five profiles, six exercises, paused controls, refills, presets, debug and logs |
| NIM-ACCEPT | Automated checks and rendered review; human playtest pending | See PLAYTESTS.md; no claim of completed feel evaluation |
| Later roster/networking | Deferred by design | Preserve the established roster references in DESIGN.md |

Next work should follow observations from a keyboard/mouse acceptance session, especially camera clearance, downhill route control, bot counter timing and whether Hover overpowers ground angles. Do not infer accepted balance from passing correctness tests.
