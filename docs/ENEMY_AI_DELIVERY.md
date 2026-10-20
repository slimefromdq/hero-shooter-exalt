# Enemy AI delivery

Implemented shared tactical AI for all eight heroes in City and Museum, plus opt-in Tactical Sparring. Normal is the saved default difficulty. Existing drills, hero gameplay values, player controls, seeded roster composition and offline combat authority are preserved.

## Systems and hero coverage

- Added modular brain, perception, positioning/movement, combat scoring/execution, team director, diagnostics, and editable class/hero/skill resources.
- City and Museum retain authored routes, phase-specific objectives, reset hooks, path budgets and checked recovery. Training gains a static navigation bake and a shared tactical controller.
- Every current hero is specialized: **Nimbus, Slayer, Marshal, Doctor, Huddle, Seeker, Dynamo and Wisp**. Actual kits enforce all mechanics.
- Nimbus performs throw, bounded tracking, ordinary rifle shot and owner-only airborne explosion. It compares current and near-future blast value, respects first-collision eligibility and can miss. Its three-shot ultimate keeps execution priority over Hover.
- Other specializations include bounded Slayer boot steering, Marshal shield pressure, Doctor triage/self-defense, Huddle escape reserves/Regroup, Seeker bird assignment, charged volleys, Omen and Wing, Dynamo fields/walls and Wisp mark/shell follow-ups.
- Added four saved difficulty levels, selectable F3 diagnostics with bracket cycling, and JSON metric export. Added cast provenance and shot/fuse detonation diagnostics without bypassing damage resolution.

Shared generic behavior remains in utility selection, cover sampling, path following, aiming, reservations and recovery. Unknown heroes use conservative fallback tactics. Existing controlled training profiles retain their earlier scripted behavior. Matchups use observed range/health/defense and local numbers; movement uses authored navigation plus checked local traversal opportunities. A full matchup matrix and general parkour route planner are not part of this implementation.

## Tests actually run

| Run | Result |
|---|---|
| Full `tools/verify.ps1` | 3,168 checks across 42 suites; zero failures |
| Latest `bot_tactics_test.gd` | 79 checks; zero failures |
| Latest `bot_integration_test.gd` | 19 checks; zero failures |
| Forward+ `capture_bot_ai.gd` at 1440x900 | 8 checks; zero failures, including F3 and bracket input dispatch |

Counts overlap and should not be added together. Focused suites were rerun after the final tactical fixes. They cover all eight real kit effects, actual role-state selection, shield visibility/pressure, hidden information and expiring memory, reaction delays and finite turn rates, unsupported dives, retreat, cooldowns, unique-cast metrics, real Nimbus bomb shots and three-shot ultimates, difficulty persistence, navigation, reset, selection and drill preservation.

The rendered review produced and visually inspected `artifacts/ai-bomb-track.png`, `ai-bomb-explosion.png`, `ai-training-debug.png`, `ai-difficulty-settings.png`, and `ai-city-debug.png`. These are engine captures and input-dispatch checks; human gameplay-feel testing remains separate.

### Final 600-second simulations

| Map / fixture | Checks | Outcome | Longest temporary stall |
|---|---:|---|---:|
| City / seed 76, nimbus, both | 17 / 0 failures | Captures 3 / 3; 133 deaths | 7 s |
| City / seed 971, wisp, both | 17 / 0 failures | Captures 2 / 2; 129 deaths | 3 s |
| Museum / seed 76, nimbus, attack | 16 / 0 failures | Natural capture defense win; separate full route drill 166 s | 3 s |
| Museum / seed 971, wisp, defend | 16 / 0 failures | Natural capture defense win; separate full route drill 166 s | 4 s |

Across the final fixtures: all eight heroes are represented, no out-of-bounds falls, no recovery teleports, and no persistent eight-second route stalls. City decision and navigation budgets passed. The temporary seven-second City stall is below the regression threshold but remains relevant to human navigation review.

Both natural Museum matches ended during capture with defenders winning. Later checkpoint combat and complete payload-route traversal were exercised in separate staged fights and an unopposed bot-driven drill; natural full-route victory is not claimed. Museum attack/defense balance needs human playtesting.

### Performance

Fresh before/after runs used the same existing 12-actor conservatory fixture, Forward+, RTX 3080, 1920x1080, five seconds warmup and twenty seconds sampling. Benchmark-only enlarged health pools are confined to the existing test.

| Metric | Baseline | New AI |
|---|---:|---:|
| Average FPS | 86.5 | 79.7 |
| p95 frame time | 15.070 ms | 15.817 ms |
| p99 frame time | 16.551 ms | 17.765 ms |
| Average draw calls | 2803 | 3209 |

p95 increased **5.0%**, below the planned 15% investigation threshold. Average FPS decreased 7.9%. This is one fixed scenario, not a guarantee for every map or device.

Machine-readable results: `docs/validation/enemy-ai-results.json`. Full logs, per-bot metrics, screenshots and raw simulation/performance reports are under `artifacts/`; reproduction commands and architecture notes are in `docs/ENEMY_AI.md`.

## Human acceptance still needed

- Play Normal ranged duels and all eight matchups for aim fairness, readable reactions, pacing and enjoyment.
- Review tank initiation/peel and support decisions under dives, especially choosing recoverable patients and preserving escapes.
- Test Hard/Expert jumping, sliding, mantle and wall-kick opportunities on both maps, including crowded routes and dynamic walls.
- Judge Nimbus bomb timing, Slayer boot follow-up, Wisp marks/shells, and ultimate value in real engagements.
- Play Museum attack and defense through overtime and later payload checkpoints; both natural final soak fixtures favored defenders at capture.
- Inspect the occasional temporary navigation delay and tune preferred positions/route choices where needed.

## Exact changed files

The inventory includes generated Godot `.uid` companions. Test-generated Slayer asset validation output was restored and is not part of the change.

64 files:

- `README.md`
- `docs/ENEMY_AI.md`
- `docs/ENEMY_AI_DELIVERY.md`
- `docs/validation/enemy-ai-results.json`
- `resources/bots/classes/dps.tres`
- `resources/bots/classes/support.tres`
- `resources/bots/classes/tank.tres`
- `resources/bots/heroes/doctor.tres`
- `resources/bots/heroes/dynamo.tres`
- `resources/bots/heroes/huddle.tres`
- `resources/bots/heroes/marshal.tres`
- `resources/bots/heroes/nimbus.tres`
- `resources/bots/heroes/relay.tres`
- `resources/bots/heroes/slayer.tres`
- `resources/bots/heroes/wisp.tres`
- `resources/bots/skills/beginner.tres`
- `resources/bots/skills/expert.tres`
- `resources/bots/skills/hard.tres`
- `resources/bots/skills/normal.tres`
- `scripts/abilities/dynamo_kit.gd`
- `scripts/abilities/relay_kit.gd`
- `scripts/abilities/wisp_kit.gd`
- `scripts/bots/bot_brain.gd`
- `scripts/bots/bot_brain.gd.uid`
- `scripts/bots/bot_class_profile.gd`
- `scripts/bots/bot_class_profile.gd.uid`
- `scripts/bots/bot_combat.gd`
- `scripts/bots/bot_combat.gd.uid`
- `scripts/bots/bot_debug.gd`
- `scripts/bots/bot_debug.gd.uid`
- `scripts/bots/bot_debug_overlay.gd`
- `scripts/bots/bot_debug_overlay.gd.uid`
- `scripts/bots/bot_hero_profile.gd`
- `scripts/bots/bot_hero_profile.gd.uid`
- `scripts/bots/bot_movement.gd`
- `scripts/bots/bot_movement.gd.uid`
- `scripts/bots/bot_perception.gd`
- `scripts/bots/bot_perception.gd.uid`
- `scripts/bots/bot_skill_profile.gd`
- `scripts/bots/bot_skill_profile.gd.uid`
- `scripts/bots/team_director.gd`
- `scripts/bots/team_director.gd.uid`
- `scripts/bots/training_tactical_controller.gd`
- `scripts/bots/training_tactical_controller.gd.uid`
- `scripts/city/city_bot_controller.gd`
- `scripts/city/city_match.gd`
- `scripts/combat/combat_resolver.gd`
- `scripts/combat/pocket_bomb.gd`
- `scripts/museum/museum_bot_controller.gd`
- `scripts/museum/museum_match.gd`
- `scripts/presentation/game_menu.gd`
- `scripts/presentation/game_settings.gd`
- `scripts/training/arena.gd`
- `scripts/training/training_hud.gd`
- `scripts/training/training_manager.gd`
- `tests/bot_integration_test.gd`
- `tests/bot_integration_test.gd.uid`
- `tests/bot_tactics_test.gd`
- `tests/bot_tactics_test.gd.uid`
- `tests/capture_bot_ai.gd`
- `tests/capture_bot_ai.gd.uid`
- `tests/city_simulation_test.gd`
- `tests/museum_simulation.gd`
- `tools/verify.ps1`
