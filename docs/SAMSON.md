# Samson — The Unquiet

Playable Support in Godot 4.7.2. Samson is a cockroach lawyer who rescues allies, cross-examines divers, denies new movement casts and establishes Witness Protection. Art and audio are original procedural placeholders; balance and human feel acceptance remain open.

## Play

Use `Launch.ps1 -Samson`, add `-Training` or `-Museum`, or select Samson through the startup and pause menus. Advanced training includes **Samson intervention**, with an injured witness, approaching diver and ranged attacker. Tactical Sparring also supports Samson. Existing movement, melee, guard and throw bindings remain unchanged.

| Input | Ability | Initial tuning |
| --- | --- | --- |
| LMB hold | Deposition | Accurate ink projectiles; 12 damage, 1.5× headshots, 0.15 s interval, 70 m/s, 35 m range; 24 rounds and 1 s reload. |
| Q | Motion to Intervene | Two charges, sequential 8 s recharge; aimed ally within 22 m, 26 m/s swept travel stopping 1.5 m away. Arrival: 65 healing and 60 overhealth for that ally, 30 overhealth for Samson, 3 s shield duration; nearby enemies within 4 m receive a 9 m/s horizontal outward impulse. |
| E | Cross-Examination | Aimed enemy within 20 m; 1.5 s LOS channel at unchanged movement speed. Success: 0.6 s stun, then 2.5 more seconds of silence. 10 s cooldown. Second E cancels. |
| 1 | Cease and Desist | Shootable 120-HP notice and traversable 11 × 7.5 m jurisdiction; 15 m placement range, 0.2 s warning, 6 s active lifetime, 12 s cooldown. Enemies inside suffer 30% ordinary-movement slow and cannot start movement abilities or shared dashes. |
| 2 | Roach Court: Witness Protection | Ground placement within 18 m; 0.6 s summon warning. Open 4 × 2 × 1 m physical court with 750 HP, 8 s lifetime and 11 m protection radius. Qualifying allies gain 25% damage reduction and 75 overhealth once per cast, lasting 4 s. No healing, enemy disable or movement-speed buff. |

Samson has 250 HP, ordinary traversal, no separate RMB ability and no additional passive. His rescue charges are independent of shared dash charges. The HUD shows rescue charge pips/count, the next recharge timer, selected channel target/progress, field durability/lifetime and ordinary overhealth bars.

The jurisdiction footprint is now 82.5 m², approximately 53% larger than its original 54 m². Witness Protection's radius increased from 10 to 11 m; its physical bench and 750 HP are unchanged.

All current hero abilities that select another actor show an overhead key marker when their aimed target can be used: Samson Q/E, Doctor Q/RMB/1/2, Relay RMB and Huddle E. Friendly prompts are mint; enemy prompts are orange. Multiple usable abilities share one target marker. Markers respect targeting cones, range, cover, resources, cooldowns, immunity, movement restrictions and collision sweeps as applicable. They disappear during unavailable states, menus, pause, death and target loss. This is local-player feedback and does not change aim, acquisition or bot behavior.

## Authority and cancellation rules

- Intervene validates team, life serial, range, cover, protection and a capsule sweep before spending a charge. A valid launch spends the charge; collision, lost LOS/range, target invalidation, disabling effects or timeout after launch abort without refund or arrival effects. Already-close allies can receive an immediate rescue. It never teleports or grants invulnerability.
- Cross requires continuing LOS/range and the same target life. Broken channels never apply a partial disable. Other action inputs cancel before normal handling, including shared melee/throw/guard. Stun/capture/stagger interrupt; ordinary damage, roots and slows alone do not. Cleanse removes the stun and silence together; no delayed callback reapplies silence.
- Silence blocks new hero casts and shared dash, including starts of Doctor beam, Marshal shield, Huddle self-heal and Relay assignment. Ordinary weapons, weapon secondaries, reload, movement/jump and shared melee/throw/guard remain available. Silence alone does not cancel effects already started.
- Notice occupancy is queried at action admission, including enemies already inside on arming. Exit, destruction or expiry removes restrictions immediately; overlapping notices use the strongest slow. Cleanse cannot bypass spatial jurisdiction. Already committed movement abilities retain their travel; ordinary jumping, sliding, mantling and wall kicks remain available. Its vertical tolerance is 1.8 m and solid cover/spawn doors prevent effects through walls.
- Court placement checks support, physical clearance, protected spawn footprints and Museum track exclusion. Preparation locks position/orientation; charge is spent only on a successful summon. Its collider provides normal physical cover for both teams. Bots use existing local structure avoidance with a court-specific checked detour.
- Court eligibility uses horizontal distance, 2 m vertical tolerance and LOS excluding the court's own collider. Reduction is queried live and ends immediately on exit or destruction. The strongest reduction wins; Doctor reduction does not add to it. Re-entry cannot refresh the once-per-cast shield. Existing shield duration survives court destruction, while source death/reset clears owned grants normally.
- Intervene and court use separate optional overhealth slots. Shields never add; strongest remaining grant wins and damage drains every grant. Legacy overhealth calls preserve their original source lockout.
- Owner death/reset/swap or scene exit removes owned fields and projectiles. Stun and silence after summoning do not remove the autonomous court. Active court suppresses Samson's ultimate-charge gain.

## Implementation map

- Kit and balance: `scripts/abilities/samson_kit.gd`, `scripts/actors/samson_tuning.gd`, `resources/samson.tres`.
- Fields: `scripts/combat/samson_notice.gd` and `samson_court.gd`, extending the existing damageable structure contract and deployable collision conventions.
- Shared additions: `CombatStatuses` stun/silence, action and spatial movement restrictions; `ActorOverhealth` optional slots; live court reduction through `ActorBenefits`; actor/motor admission and channel handoff. Existing status and damage rules retain their original behavior when these effects are absent.
- Integration: roster, launcher, hero menus, City/Museum portraits, shared care HUD, training drill, `SamsonVisuals`, and an SVG placeholder portrait.
- Select feedback: `HeroKit.selection_previews()` defaults to empty; selecting kits supply read-only candidates through their existing acquisition checks. `scripts/presentation/ability_selection_markers.gd` renders pooled world markers through the common `HeroPresentation`, so training, City and Museum use the same feedback.
- Bots: `SamsonTactics` supplies intent choices to tactical and legacy controllers, with thresholds in the Samson bot profile. Bots prioritize endangered allies, reserve the last rescue charge for emergencies, avoid already-disabled Cross targets, and require threatened allies before spending court.

## Validation

Sizing and universal selection follow-up: `tests/ability_selection_test.gd` passed 39 headless checks and 48 native checks, including all selecting heroes, blocked rescue sweeps, cooldown/resource gates, immunity, LOS, freed targets, combined input labels, pause/cursor handling and hero-switch cleanup. Updated Samson boundary tests passed all 116 checks; native Samson integration passed all 18. Review captures: `artifacts/ability-selection-ally.png`, `ability-selection-enemy.png`, and `samson-enemy-selection.png`. The shared selection test is registered in the default verifier and its native `-Capture` branch.

The follow-up complete verifier passed all 55 headless test scripts (exit 0; no failure or engine-error lines): `artifacts/selection-verifier.log`. Restored the asset-test-generated Slayer validation report from its pre-run copy; existing Slayer gameplay and its configured knife-capacity assertion remain intact.

Validation completed on October 19, 2026 using Godot 4.7.2:

| Validation | Result | Evidence |
| --- | --- | --- |
| Complete default verifier | All 54 headless test scripts passed; exit 0; no failure or engine-error lines | `artifacts/samson-verify-complete.log` |
| Final focused Samson mechanics | 116 checks, zero failures, including freed-target cancellation and court detours | `artifacts/samson-test-final.log`, `artifacts/samson-results.json` |
| Final scene integration | 18 checks, zero failures, including manual Samson bot spawning and City/Museum selection | `artifacts/samson-integration-final.log` |
| Native physical input and rendering | 18 checks, zero failures; Forward+ / Vulkan | `artifacts/samson-native-final.log`, `artifacts/samson-integration-results.json` |
| City mixed-roster match | Seed 76, 120 seconds; seven checks, zero failures or terrain falls | `artifacts/samson-match-city.json` |
| Museum mixed-roster match | Seed 76, 120 seconds; seven checks, zero failures or terrain falls | `artifacts/samson-match-museum.json` |
| Patch whitespace and launcher syntax | Passed | `git diff --check`; PowerShell parser |

Both live match runs recorded Deposition, Intervene, Cross-Examination, Cease and Desist, Roach Court and witness shield grants through the real bot/actor/combat pipeline. City Samson bots applied about 1,391 damage and restored 591.5 HP; Museum Samson bots applied 348 damage and restored 541 HP. These are seeded functional observations, not balance benchmarks.

Rendered review captures include `artifacts/samson-hud.png`, `samson-intervene.png`, `samson-channel.png`, `samson-silence.png`, `samson-notice.png`, `samson-court-hud.png` and `samson-court.png`.

The roster regression now checks the full registered roster instead of a hardcoded eight heroes. An existing throw test had one frame-scheduling failure, then passed unchanged in both ordinary and fixed-60-FPS reruns; its verifier command now pins 60 FPS like other movement checks. No throw behavior or assertion was changed. The subsequent complete verifier passed. Restored the tracked Slayer validation JSON rewritten by asset tests; pre-existing Slayer gameplay changes remain intact.

Reproduction:

```powershell
./tools/verify.ps1
$taskEngine = & ./tools/find_godot.ps1
& $taskEngine --path . --windowed --resolution 1440x900 --fixed-fps 60 --audio-driver Dummy --script res://tests/samson_integration_test.gd -- --capture
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/samson_match_test.gd
& $taskEngine --headless --path . --fixed-fps 60 --script res://tests/samson_match_test.gd -- --museum
```

## Known limits

The court and notice require mostly level supported ground; difficult terrain can reject placement without spending resources. Models, poses, portrait and synthesized cues are placeholders. The new states use the existing offline authority; this adds no networking. Correctness tests and seeded matches establish functionality, not competitive balance, human aiming comfort or final animation readability.
