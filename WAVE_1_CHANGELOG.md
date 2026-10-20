# EXALT Wave 1: THE UNQUIET

Final integration pass, 2026-10-19. Godot 4.7.2. Samson and Stitch are integrated alongside the Seeker and phantom-thief reworks. Rogue remains the display name; `wisp` and `relay` remain compatible internal IDs.

## Gameplay and integration

- **Samson:** successful Q arrival/completed E grants Evidence, capped at two. Successful 1 spends all Evidence for footprints of 11 x 7.5, 16.5 x 11.25 or 22 x 15 m; failed placement preserves it. Bounds, floor checks, visuals and HUD share cast-time sizing. Death, switch, reset and round end clear Evidence.
- **Seeker:** RMB arrows deal 28 damage each at full charge, up from 22; both arrow modes travel at 115 m/s, up from 90. Healing and cooldowns remain unchanged. Healing beams carry team colors.
- **Rogue:** Q travels 4 m, up from 2.5. E lasts 1.6 seconds with collision-safe free flight: W/S follow pitch, A/D strafe, Space rises, Shift descends; normalized movement retains 3 m/s. Immunity, cooldown and return recovery remain.
- **Stitch:** concealed speed is 110% of walking speed. Needles fire every 0.30 seconds; scissors deal 60 every 0.42. Enemy thread acquires at 22 m, pulls beyond 10 m slack at min(12, excess x 4) m/s, and breaks beyond 28 m. Cover blocks pulling.
- **Stitch mobility/ambush:** 45 m terrain hook supports walls, floors, ceilings and slopes, rejects actors/temporary structures, and hangs indefinitely. Hook/hang preserves concealment, whose normal timer still expires. Q releases during cooldown; Space wall-jumps. Concealed primary becomes one 10 m lunge at 35 m/s, dealing 45 plus 60 bleed over three seconds; no extra scissors/mark damage. Misses consume it. Curtain Call pierces actors over 26 m, 2 m wide, at 65 m/s, retaining damage/execute rules and cover stops.
- **Marshal:** Verdict applies its own 1.5-second stun without changing ordinary melee stagger duration.
- **Shared control:** hostile stun/root/forced stagger diminishes to 100%, 50%, then 25%, resetting after four seconds without an accepted hard disable. Same-category reapplication cannot extend an active disable. Scripted capture/throw choreography is excluded; silence/slow conventions remain.
- **Bots:** sampled threat data includes channels, protection, healing, pursuit and tethers. Bots suppress offensive casts into sampled immunity, exploit interrupt opportunities, seek cover from incoming thread, avoid blocked leash mobility, use surface approaches/ambushes, and steer flight safely. Existing sensing budgets remain.
- **Presentation/cleanup:** reusable thread/hook meshes, cached doll/ghost meshes, bounded dodge trails, snappy scissors, team-colored legal boundaries and healing, animated court procession, updated descriptions and controls. Rogue effects now validate owner life/kit. Round victory cancels abilities, companions, buffs and owned attacks and blocks further damage/healing; restart restores a clean round.

## Tests actually performed

| Validation | Result |
| --- | --- |
| Full `tools/verify.ps1` checkpoint | 59 scripts; 4,517 PASS lines; zero failure/script-error/engine-error lines |
| Final Wave 1 focused suite | 124 checks passed, including Evidence, flight, real movement speed, ambush from a wall hang, bleed elimination credit, piercing, disable chains and repeated cleanup |
| Final City/Museum end-of-round suite | 52 checks passed; active states/companions cancelled, delayed combat blocked, restart restored |
| Final affected regressions | City/Museum rules and integration, menus, attribution, bot integration/tactics, Seeker and Stitch passed again after relevant fixes |
| Rendered controller/input smoke | 85 checks passed: Wave 1 12, Stitch 15, Seeker/Rogue 40, Samson 18 |
| Seed 76 City and Museum mixed matches | 180 simulated seconds per map; 13 checks each; no terrain falls; all four heroes dealt real damage and both supports healed allies |
| Cleanup stress | Five death/switch cycles per hero; no retained owned effects or node growth in equivalent cleanup states |
| Whitespace | `git diff --check` passed |

The full verifier checkpoint precedes the final round-end fix; the affected suites and new lifecycle tests were rerun afterward. Old assertions changed only for approved tuning, new timing, terrain-only hooks and the new Verdict stun. Natural-match events record casts separately from completions, attachments, hangs and damage. Coverage is backed by tests or recorded events, not inferred from a cast attempt. Full machine-readable evidence: [validation results](docs/validation/wave-1-results.json); full checkpoint log: `artifacts/wave-1-verifier.log`.

Headless seed-76 runtime comparison against `c68e6052`: **37.67 s baseline / 37.94 s current (+0.70%)** for 180 simulated seconds. Peak transient counts were 65 / 70; repeated cleanup had no node growth. This single run includes different combat outcomes and timing noise; it is not a GPU/FPS benchmark.

Reproduce focused checks with the engine from `tools/find_godot.ps1`, project-local `APPDATA=.tools/runtime`, and `--headless --path . --fixed-fps 60 --script res://tests/wave_1_test.gd` or `wave_1_round_test.gd`. Run `wave_1_match_test.gd` similarly, adding `-- --museum` for Museum. Render `wave_1_input_test.gd` without `--headless`, adding `--windowed --resolution 1440x900 --audio-driver Dummy`. Both focused suites are registered in the default verifier; Wave 1 input smoke is in its `-Capture` branch.

## Known bugs and remaining polish

No reproducible failing check or new gameplay bug remains in the exercised scenarios. Art/audio remain procedural placeholders. Moving/removed hook surfaces release Stitch. Native combat smoke uses controlled bot targets; mixed-match runs use ordinary AI for every actor. Automated results do not establish human control feel or competitive balance.

Next: human mixed-composition playtests for thread resistance, ambush readability and disable-chain recovery; improve wall-hang pose/camera framing near cover; replace synthesized audio and procedural ability visuals; broaden seed/map/performance sampling and high-concurrency ultimate tests.

## Files modified or added

- `README.md`
- `WAVE_1_CHANGELOG.md`
- `docs/ROGUE_REWORK.md`
- `docs/SAMSON.md`
- `docs/SEEKER_REWORK.md`
- `docs/STITCH.md`
- `docs/validation/wave-1-results.json`
- `resources/stitch.tres`
- `scripts/abilities/close_combat.gd`
- `scripts/abilities/marshal_kit.gd`
- `scripts/abilities/relay_kit.gd`
- `scripts/abilities/samson_kit.gd`
- `scripts/abilities/stitch_kit.gd`
- `scripts/abilities/wisp_kit.gd`
- `scripts/actors/combat_intent.gd`
- `scripts/actors/hero_actor.gd`
- `scripts/actors/marshal_tuning.gd`
- `scripts/actors/player_controller.gd`
- `scripts/actors/relay_tuning.gd`
- `scripts/actors/stitch_tuning.gd`
- `scripts/actors/wisp_tuning.gd`
- `scripts/bots/bot_brain.gd`
- `scripts/bots/bot_combat.gd`
- `scripts/bots/bot_movement.gd`
- `scripts/bots/bot_perception.gd`
- `scripts/bots/roster_tactics.gd`
- `scripts/city/city_match.gd`
- `scripts/combat/combat_resolver.gd`
- `scripts/combat/combat_statuses.gd`
- `scripts/combat/red_thread.gd`
- `scripts/combat/samson_court.gd`
- `scripts/combat/samson_notice.gd`
- `scripts/presentation/care_hud.gd`
- `scripts/presentation/control_feedback.gd`
- `scripts/presentation/game_menu.gd`
- `scripts/presentation/hero_presentation.gd`
- `scripts/presentation/seeker_presentation.gd`
- `scripts/presentation/stitch_presentation.gd`
- `scripts/presentation/wisp_effects.gd`
- `scripts/training/training_manager.gd`
- `tests/care_heroes_test.gd`
- `tests/roster_expansion_test.gd`
- `tests/seeker_test.gd`
- `tests/stitch_input_test.gd`
- `tests/stitch_test.gd`
- `tests/wave_1_input_test.gd`
- `tests/wave_1_input_test.gd.uid`
- `tests/wave_1_match_test.gd`
- `tests/wave_1_match_test.gd.uid`
- `tests/wave_1_round_test.gd`
- `tests/wave_1_round_test.gd.uid`
- `tests/wave_1_test.gd`
- `tests/wave_1_test.gd.uid`
- `tests/wisp_rework_test.gd`
- `tools/verify.ps1`
