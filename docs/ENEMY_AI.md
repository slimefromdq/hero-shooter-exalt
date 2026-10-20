# Tactical enemy AI

City and Museum match bots now share a perception, utility, positioning and combat pipeline. The existing offline actor, movement, kit and combat components still resolve every action. Seeded 2 tank / 2 support / 2 DPS roster selection is unchanged; the director itself accepts arbitrary compositions.

## Play and inspect

- **Settings & Controls → Bot difficulty:** Beginner, Normal (default), Hard, Expert. Saved in the existing game settings; active tactical bots adopt changes at their next decision and discard pending reactions.
- **Training console → Advanced Training Tools → Tactical Sparring:** an additional exercise and spawn profile. Its opponent uses the selected hero with ordinary hero health and finite resources. Existing stationary, tracking, ranged, close, sparring, guard, and hero exercise bots retain their original controlled behavior.
- **F3:** enable existing telemetry plus tactical bot diagnostics. **[ / ]** selects a tactical bot. The panel includes class/hero/difficulty, state, target visibility, utility and ability scores, position/range, intentions, observations, team assignment, recent decisions, navigation and effectiveness metrics. A line marks the selected engagement position. The extra overlay hides while a menu is open.
- **Settings & Controls → Export Bot Diagnostics:** writes `user://bot_metrics.json`, containing active tactical bots, per-ability cast/hit metrics, damage/deaths/idle/objective time, bomb combo metrics, query counters, recovery counts and recent decisions. Simulation reports also contain bot metrics.

## Components and tuning

`BotBrain` owns high-level state and target utility. `BotPerception` is the only tactical component that samples live enemies. `BotMovement` chooses reachable positions and requests existing traversal inputs. `BotCombat` scores abilities separately from aim and action execution. `TeamDirector` exchanges observed reports, assigns temporary soft responsibilities and leases positions. `BotDebug` observes combat events independently of tactical knowledge; global diagnostics never become perception inputs.

Profiles live in `resources/bots/classes`, `resources/bots/heroes`, and `resources/bots/skills`. Class resources modify priorities instead of locking actions. Hero resources define range bands, aggression, mobility, vulnerable-target preference and escape reserve. Kit-specific scorers use current gameplay tuning for actual ability ranges, charges and costs. Unknown hero IDs receive conservative generic spacing, weapon, objective and survival behavior.

| Hero | Preferred enemy range | Specialization |
|---|---|---|
| Nimbus | 12–24 m | Rifle angles, clear overhead Hover, reactive Deflect, ballistic bomb throws and airborne bomb shooting, three-shot Final Notice |
| Slayer | 4–10 m | Knife approach, supported Boot Rush and bounded steering, close follow-up, route snares, piercing axe value |
| Marshal | 5–12 m | Anchoring, threat-facing barrier, cannon pressure, March engagement/peel, Rallying Command for threatened allies, validated Orbital Barrage and Verdict |
| Stitch | 2–16 m | Sampled isolation/marks, pursuit thread, tethered hook, bounded ambush/escape concealment, marked-target Curtain Call |
| Doctor | 14–22 m | Recoverable-patient triage, beam positioning, self-defense, Ward, cleanse/reduction, safe House Call and ally ultimate |
| Huddle | 6–14 m | Mobile pressure, ally interception, escape-charge reserve, safe Regroup and directed Wave |
| Relay | 12–24 m | Drone triage, battery recall, drone-centered Shock, escape Kickstart and team Full Circuit |
| Dynamo | 12–25 m | Prespin and sustained pressure, lightning, Lodestone, Storm and checked wall placement |
| Wisp | 5–14 m | Mark-to-shell follow-up, safe steps with escape reserve, Phase, overhead lift/glide and Ballet |

### Nimbus bomb sequence

Nimbus throws using the current throw speed and gravity, then tracks its own bomb with life and cast identity. It temporarily aims at that moving object and fires a normal rifle shot when the visible blast opportunity is useful and ordinary ammo, reload, shot cooldown and permissions allow it. The existing weapon ray must actually strike the bomb. The AI never calls explosion directly and never uses an ultimate shot for the combo.

First collision permanently removes shoot eligibility, including a later airborne bounce. Foreign bombs, occlusion, expired/deleted bombs, life changes, protected rooms, survival decisions and ultimate commitments invalidate the sequence. Normal aiming remains bounded and misses are possible. Shot-triggered explosions retain the existing damage, falloff, cover, ownership and exactly-once rules. The bomb's event now records `trigger=shot` or `trigger=fuse` so metrics distinguish an actual early shot from a subsequent fuse explosion.

### Knowledge, scheduling and navigation

Enemy observations store their original sighting time, sampled position/velocity, visible health/status and observed defense use. Lost targets retain snapshots for at most four seconds. Team reports preserve original timestamps and do not provide live enemy references for aiming. Target selection has no player preference. Local visibility and acquisition time are required before attacking.

Transparent Marshal/Huddle shields preserve visual observation while still blocking weapon rays. Bots can pressure a visible shield with normal attacks; they avoid spending Nimbus bombs or Slayer projectiles on a clearly blocked firing lane. Opaque structures and terrain still remove visual contact.

Beginner / Normal / Hard / Expert acquisition delays are **0.60 / 0.38 / 0.26 / 0.18 seconds**. Turn speed, tracking acceleration, prediction, aim error, consistency and coordination are configurable; health, damage, cooldowns and movement rules are shared with the player.

Tactical decisions remain at most **5 Hz** and navigation retargeting at most **2 Hz**, staggered by slot. Position selection is cached for 0.4 seconds, and the team director refreshes assignments at 0.4 seconds. Perception has a six-opponent ray budget per evaluation, with round-robin sampling if there are more opponents. Position scoring uses five bounded candidates and one endpoint reachability path query. Bomb visibility/value checks are capped at 20 Hz only during an active sequence. Aim and path following update each physics tick.

States have a 0.6-second commitment and require a 0.15 normalized score improvement to switch, except danger, invalid targets or objective phase changes. Existing City approach/subway/high-ground routes, Museum sector routes, local structure avoidance and checked recovery are retained. Position candidates consider cover, range, height, sightlines, escape direction and reservations. Mobility uses capsule/landing checks and the shared motor; no AI teleport recovery is added. Tactical Sparring bakes navigation once from the existing static training geometry.

Reaching or securing the objective lowers contest utility, allowing actual hold, pressure, flank, support and commit decisions. Marshal/Dynamo receive the first anchor preference; Huddle keeps a mobile pressure preference. These are scoring bonuses, so survival, ally danger or a vulnerable enemy can override them. Nimbus's active ultimate owns its shot sequence; Hover cannot replace those shots. Doctor prioritizes self-protecting Ward over an unsafe beam or ally-only cast when a close attacker threatens a critically injured Doctor.

## Verification

Focused suites are `tests/bot_tactics_test.gd` and `tests/bot_integration_test.gd`; both are included in `tools/verify.ps1`. The tactics suite exercises perception fairness, memory, utility commitments, low-health retreat, unsupported diving, finite aim rotation, every hero's actual kit effects, unique-cast metrics, and real moving-bomb shooting plus failure cases. Integration covers training navigation, difficulty changes/persistence/export, freeze, selection, respawn and preserved guard drills.

`tests/capture_bot_ai.gd` runs rendered Nimbus bomb shooting, captures training/match diagnostics and difficulty settings, and verifies real splash damage. Existing City and Museum simulation scripts export tactical metrics and retain their independent route-stall sampling. Museum additionally exercises later checkpoint fights and an unopposed bot-driven route drill; these are reported separately from the natural match.

Automated tests and captures establish connected behavior and regression coverage. Human playtesting is still required for combat readability, enjoyable difficulty, credible team behavior, competitive balance and traversal feel. Wall-jump/mantle opportunities rely on the existing probes and local movement opportunities; this is not a general parkour route planner. Matchups use observed range, health, defenses and local risk rather than a hand-authored complete hero-versus-hero matchup matrix.

Offensive hit metrics group pellets, damage ticks and delayed releases under their originating attack or activation. A successful hit means damage to an opposing actor; shield pressure and bomb-shooting success have separate events/metrics. Per-ability rates retain a bounded recent cast window; damage, deaths, idle and objective counters accumulate for the controller's lifetime.

### Reproduction

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\verify.ps1
$taskEngine = & .\tools\find_godot.ps1
$env:APPDATA = Join-Path (Get-Location) '.tools/runtime'
& $taskEngine --path . --script res://tests/capture_bot_ai.gd --windowed --resolution 1440x900 --audio-driver Dummy --fixed-fps 60
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/city_simulation_test.gd -- --seconds=600 --seed=76
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/city_simulation_test.gd -- --seconds=600 --seed=971 --hero=wisp
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/museum_simulation.gd -- --seconds=600 --seed=76
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/museum_simulation.gd -- --seconds=600 --seed=971 --hero=wisp --defend
```

The rendered bot review is also included in `tools/verify.ps1 -Capture`. Full verification includes the existing combat, movement, roster, menu, scene, map and navigation checks; the long soaks are separate explicit commands.
