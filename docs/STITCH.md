# Stitch

Stitch is a playable 225-HP DPS porcelain/rag-doll assassin. Select her in the hero menu or run `Launch.ps1 -Stitch`; add `-Training` or `-Museum`. The training console includes **Stitch hunt** and a tactical Stitch bot profile. Standard movement remains unchanged outside her explicit ability states, including wheel-up dash and Shift slide/crouch.

## Controls and tuning

| Input | Ability | Starting values |
| --- | --- | --- |
| Hold LMB | Needlepoint / Shears | Needles: 18 damage, 0.30 s interval, 65 m/s, 45 m range, 24 rounds, 1.2 s reload. Shears: 60 damage every 0.42 s, 2.6 m reach, no ammo cost. |
| Passive | Loose Ends | Each needle hit adds a source-owned stack; cap 3, refresh 4 s expiry. Shears consume stacks for +12 damage each. |
| Q | Spoolstep | 45 m terrain hook at 40 m/s, 28 m/s reel, 2 s reel timeout. Hang indefinitely; Q releases, Space wall-jumps. **13 s cooldown committed on launch, including misses.** |
| E | Play Dead | 0.25 s collapse then up to **20 s** concealment at 110% walking speed. **12 s cooldown begins on exit**, including timeout, manual E, damage and action reveal. |
| 1 | Red Thread | Aimed enemy within 22 m; 5 s tether, 10 m spring leash, 12 s cooldown on attachment. +20% speed while pursuing. |
| 2 | Curtain Call | 0.65 s warning, 26 m fixed horizontal seam, 2 m width, 65 m/s swept travel. 140 damage +12 per mark; marked targets at or below 25% pre-hit HP qualify for execution. |

Stitch shares the current movement overhaul and Wave 1 status authority, including Samson's silence, stun and movement-cast denial. Samson Intervene also respects Red Thread without awarding arrival benefits when truncated.

All values are exposed in `StitchTuning` and the existing training tuning UI. The primary has no headshot bonus. RMB has no Stitch-specific action.

## Combat rules

Shears engage against a visible frontal enemy within 2.6 m, 40 degrees to either side and 1.5 m vertical separation. Mode retention extends to 3.1 m / 50 degrees, with a 0.15 s loss grace. Damage still requires the actual 2.6 m / 40 degree volume. Cover and hostile barriers prevent acquisition and hits. Both modes share their cooldown; shears can interrupt reload without granting ammunition. Guard blocks shears under the existing melee rules.

Marks are tracked separately from Slayer information marks and Wisp soul marks. Each Stitch owns her stacks independently; misses and changing targets preserve them. Only accepted damaging shears consume stacks. Expiry, cleanse, source/target death, reset, hero swap and removal clear their corresponding ownership. The shooter sees stack count and remaining time above a target; victims also see incoming stacks in status feedback.

Red Thread limits outward ability movement and pulls enemies toward Stitch beyond 10 m slack at min(12, excess distance x 4) m/s. Collision, cover, barriers, immunity and paired actions gate displacement; gravity remains available. It breaks after 0.3 s sustained obstruction, beyond 28 m separation, on expiry, cleanse, death/reset/removal, phase immunity or spawn protection. The victim sees a thick red connection and explicit warning. Walking and external knockback still use their existing movement rules.

Play Dead uses the existing crouch capsule and safe-standing checks. Jump, dash, slide and mantle are disabled while concealed. Distant enemies lose the complete presentation, including labels and shadows; enemies within 5 m with line of sight see a translucent doll. Quiet positional joint clicks have a 5 m maximum audio range. Allies and the owner retain readable presentation. Concealment provides no invulnerability, healing or cleanse, and contributes nothing to City capture or Museum capture/escort/contest/overtime.

Damage reveals immediately. Primary, shared melee, guard, throw, enemy thread and ultimate reveal before resolving. Hook and hanging preserve concealment, which still expires normally. Primary initiated after collapse while concealed becomes one 10 m horizontal slicing lunge at 35 m/s: 45 direct damage plus 20 bleed damage per second for three seconds to the first valid enemy. Swept motion respects cover, barriers and body collision. This attack neither consumes marks nor adds ordinary needle/scissors damage. A miss consumes the opening; manual exit, damage reveal and timeout bank no attack.

The hook visibly flies up to 45 m and accepts capsule-safe terrain walls, ceilings, slopes and floors. Actors and temporary combat structures are rejected. Reel sweeps stop at obstructions or the safe anchor position, then hang indefinitely without gravity. Q toggles release even during cooldown; Space releases with the existing wall-jump push. Invalid anchors, control interruption, death, switch and reset release the hang. Invisibility expires on its normal timer. No enemy receives hook damage or displacement.

Curtain Call locks its direction and consumes charge immediately, without interruption refunds. Its visible seam is truncated by cover/barriers. Windup holds horizontal movement, allows camera rotation, and is interrupted by stagger, capture, root/slow or death. Travel pierces actors and stops at geometry or hostile barriers. Damage follows only the actual traveled segment and includes ordinary target body overlap at the seam edge. A cast-local set and the resolver prevent duplicate damage. Each target's marks are read before damage; survivors retain them. A marked kill caused by the cast refreshes Red Thread even when ordinary burst damage, rather than execution, kills the victim. Shields, temporary overhealth, immunity and mitigation retain the existing resolver's execute rules.

## Bots and presentation

Stitch uses the shared tactical brain in City, Museum and her training drill. Tactics favor isolated sampled opponents, marks, spring-thread pursuit, surface-hook approaches, concealed lunges and piercing ultimate opportunities. Bots release hangs to resume objective play. Concealment filters tactical and legacy perception without hidden position updates.

The procedural model, portrait, synthesized effects and named animation hooks are placeholders: porcelain joints, unnatural head turn, needle trails, red thread, shears confirmation, collapse/crawl and enlarged spectral shears snap. There is no blindness mechanic in this version.

## Verification

Run `powershell -ExecutionPolicy Bypass -File .\tools\verify.ps1`. Stitch's focused suite is included. `-Capture` additionally runs her native input and rendered-feedback checks alongside existing native checks.

Focused commands:

```powershell
$taskEngine = & .\tools\find_godot.ps1
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/stitch_test.gd
& $taskEngine --path . --fixed-fps 60 --windowed --resolution 1280x800 --script res://tests/stitch_input_test.gd
& $taskEngine --path . --windowed --resolution 800x600 --script res://tests/capture_stitch.gd
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/city_simulation_test.gd -- --hero=stitch --seconds=180 --seed=971
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/museum_simulation.gd -- --hero=stitch --seconds=120 --seed=971 --defend
```

Results and the changed-file manifest are recorded in [validation/stitch-results.json](validation/stitch-results.json). Automated checks and simulations establish functional coverage, not competitive balance or game feel. Human playtesting is still needed, particularly for 20-second concealment. This is offline combat; networking and final authored art/audio remain outside this delivery.

### Recorded outcome (October 19, 2026)

- Full repository verifier: passed, 3,706 PASS lines and no FAIL/error entries.
- Final focused and movement regression run: 873 checks passed across Stitch, roster expansion, crouch, QoL, combat rules, traversal, mantle exit and Slayer abilities. Stitch-specific coverage comprises 162 checks.
- Native Stitch input: 15/15 passed. Eight rendered frames cover the portrait, enemy near/far concealment, revealed model, thread, local Play Dead and Curtain Call windup/finish.
- City seed 971, 180 seconds: 15/15 passed. Museum seed 76 attacking (180 natural seconds) and seed 971 defending (120 natural seconds): 16/16 each, plus 180 seconds of staged combat and a 166-second full escort drill per run.
- City seed 76, 600 seconds: 16/17 passed. The strict eight-second stall check flagged Huddle (`crown_02`) and Dynamo (`crown_06`) at second 84. Both resumed; the worst stall was nine seconds. Neither Stitch participant was flagged. This mixed-roster navigation limitation remains unresolved; the soak must not be described as fully passing. Both teams captured five times, with no falls or recovery teleports.

### Push integration validation

Rebased Stitch onto `17aaa33`, preserving Samson, shared Wave 1 status/selection behavior, the newer shared movement overhaul and movement feedback. Samson Intervene respects the leash and does not grant arrival benefits after truncation; enemy selection cannot expose distant concealed Stitch. The combined default verifier exited 0 with 4147 PASS lines and no failure/engine-error entries. Additional compatibility validation passed 345 checks (168 Stitch, 120 Samson, 18 Samson integration, 39 selection), and native Stitch input passed 15 checks. Evidence: `artifacts/stitch-push-verification.log`, `artifacts/stitch-push-compatibility.log`, `artifacts/stitch-push-input.log`. The previously reported City-soak limitation remains recorded above.

## Wave 1 validation

Current changed-behavior tests, rendered input checks, mixed-match evidence and limitations are recorded in [WAVE_1_CHANGELOG.md](../WAVE_1_CHANGELOG.md). Older validation below/above describes the original kit pass.
