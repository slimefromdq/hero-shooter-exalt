# Relay, Dynamo and Wisp

Three complete offline heroes extend EXALT's roster to eight. All use the shared actor, collision, combat authority, traversal, close combat and shoulder camera. The original procedural models and portraits match the existing prototype's geometric art. Every gameplay value is editable in the respective tuning class or `resources/relay.tres`, `resources/dynamo.tres` and `resources/wisp.tres`.

Run `Launch.ps1 -Relay`, `-Dynamo` or `-Wisp`; add `-Training` to enter the arena. Startup, city and training menus include all eight heroes. Advanced training provides **Relay circuit**, **Dynamo siege** and **Wisp ballet**, plus individual bot profiles. Input labels follow the existing named bindings.

## Relay · drone support

An androgynous field engineer in amber workwear with an indestructible two-rotor healing drone. 250 HP, 6 m/s movement.

| Input | Ability | Prototype behavior |
| --- | --- | --- |
| LMB hold | Carbine | 14-damage projectiles at 70 m/s; 10 shots/s, 30 rounds, 1.2 s reload, 1.5× headshots. |
| RMB press | Assign drone | Aim at a visible ally within 35 m. 0.25 s transfer gap and 1 s reassignment cooldown. Invalid targets preserve the previous recipient. |
| Q | Kickstart | Physical directional jump: 11 m/s upward and 8 m/s horizontal; 8 s cooldown. |
| E | Shock Delivery | 60 damage within **6 m** of the drone, or Relay while docked. 20 energy and 8 s cooldown. Cover and barriers block it. |
| 1 | Return to Sender | Recall an attached drone; while docked, attach to self. Self assignment observes the ordinary energy and reassignment gates. |
| 2 | Full Circuit | 0.35 s preparation, then an 8 s / 12 m aura: **80 HP/s** and +25% ordinary primary fire rate. Move the drone to move the aura. |

Normal attachment heals 55 HP/s without sightline or continued-distance checks. The 100-energy battery drains 10/s even on a healthy recipient. Transfers pause healing and battery drain. Docking recharges 20/s; depletion recalls automatically, and deployment requires 20 energy. Ally and self-healing use the same supply. Drone relocation is magical rather than a physical navigation problem.

Full Circuit can begin with an empty battery. It freezes battery drain/recharge and replaces single-target healing. Its healing and haste pass through cover; overlapping circuits use the strongest healing and haste, not their sum. It provides no resistance or invulnerability. Haste changes primary shot intervals for every hero, preserving reloads, secondary recovery and ultimate shot cadence.

The HUD reports battery, recipient/charging state and ultimate duration. The drone follows the recipient and visibly disappears on its owner's death. Recipient death, respawn, hero change or team change detaches it. Owner death/hero change/reset retires its aura and benefits.

## Dynamo · storm tank

A heavyset woman and storm-mason with brass-and-slate armor, pale hair and a six-barrel rune-powered minigun. 650 HP, 5 m/s movement.

| Input | Ability | Prototype behavior |
| --- | --- | --- |
| LMB hold | Minigun | 9 damage per bullet; 6→18 shots/s over 1.8 s. 180 rounds, 2.4 s reload, 1.5× headshots. |
| RMB hold | Prespin | Spin without spending ammunition. Spinning limits movement to 60%; release decays spin over 1 s. Reload resets spin. |
| Q | Stormcharge | 6 s enchantment, 12 s cooldown. A hit can chain to two additional enemies within 6 m per jump for 18 then 12 damage. Shared 0.2 s chain cooldown. |
| E | Raise the Line | Preview a wall; LMB places, RMB rotates 90°, E cancels. E dismisses an active wall. |
| 1 | Lodestone | **28 m** cast range, 0.4 s warning, 5 m radius, 35 damage. Pull up to **4 m over 0.3 s**, stopping at terrain or before the center; 11 s cooldown. |
| 2 | Storm Dominion | **35 m** cast range, 0.8 s warning, then 6 s / 8 m-radius storm. **40 damage every 0.5 s** with a refreshing 25% slow. Dynamo may fight during the storm. |

Walls are 10×4×0.5 m, split into five 250-HP sections; 8 s duration and 14 s placement cooldown. Both teams and their shots collide. Friendly fire cannot damage the wall; enemy hitscan, projectiles, knives, axes, melee and explosions damage sections. The cast that destroys a section still respects its cover. Breaking a section opens a climbable physical gap. Unsupported/obstructed placement, overlapping actors or protected rooms spends no cooldown. Cancelling or dismissing does not refund a previously spent cooldown. Idle previews expire after 3 s.

Lightning cannot revisit a victim or recurse. Terrain and hostile barriers block each jump, the pull and storm damage. Pulling grants no stun, capture or wall-crush damage. Physical local bot waypoints route around intact ends or through destroyed gaps while retaining the baked city mesh.

The HUD reports spin, enchantment and wall duration. Wall previews show valid/invalid placement; minigun barrels rotate with spin. Visible zone boundaries and warnings precede both area attacks. Owner life cleanup retires walls, storms, warnings and pulls.

## Rogue · phantom thief DPS (existing Wisp ID)

Rogue preserves the Wisp registration, resources, inputs, marks and burst ammunition. Her current rework makes Majestic Leap more than twice as high, replaces the long Q dash with a short dodge, converts right-click to an aimed explosion and adds powerful pre-blast suction to Grand Heist.

| Input | Ability | Current behavior |
| --- | --- | --- |
| LMB hold | Dual pistols | Unchanged 13-damage alternating hitscan shots and source-specific marks. |
| RMB press | Explosive burst | 32 m impact/airburst, 3 m radius, 80 base damage plus owned marks. Full within 1 m; 60% at the edge. One burst charge and 0.65 s recovery; no pellets/headshots. |
| Q | Phantom Dodge | 2.5 m at 12.5 m/s; exit velocity capped at 2 m/s. Retains three charges, 4 s recharge, shell loading, 0.15 s damage immunity and cosmetic afterimage. |
| E | Vanishing Act | Retained 1 s defensive horizontal hover, second-press cancellation and 0.20 s vulnerable recovery. |
| 1 | Majestic Leap | 18 m/s up, 10 m/s forward; hold-Jump float and second-press 24 m/s dive. Firing remains available throughout. Measured apex at 60 Hz: 3.17 -> 7.21 m. |
| 2 | Grand Heist | Retained calling-card throw and 0.80 s impact warning. Final 0.25 s pulls enemies inward at 20 m/s, then a 6 m blast deals 220 base plus marks with radial falloff. Cover and immunity block pull/damage. |

Full behavior, before/after tuning and verification are in [Rogue rework](ROGUE_REWORK.md). The [initial Wisp revision](WISP_REWORK.md) remains a historical record.

## Shared roster and authority

Seeded compositions select two tanks from Marshal/Huddle/Dynamo, both supports Doctor/Relay, and two DPS from Nimbus/Slayer/Wisp, always including the selected player in slot zero. Both teams use the composition. A DPS bot retains the subway route. New rounds refresh bot kits/routes to preserve the role balance and stable six-slot layout. Mid-match hero selection preserves existing bots and match progress.

Bots manage drone charge, self-preservation and assignments; prespin, chain, build, pull and storm; and combine pistol marks, safe dash paths, shells, phase and aerial attacks. Physical walls do not rebake or replace city navigation.

New ultimates consume charge after preparation; interrupted preparation retains it. Active ultimates cannot earn their owner's passive/damage/healing charge. Cast snapshots also prevent delayed ultimate projectiles from charging the next ultimate. Source-bound effects and physical sections retire on restart, scene exit and hero/life cleanup.

## Verification

`tools/verify.ps1` includes `tests/roster_expansion_test.gd`. `-Capture` adds native `tests/roster_input_test.gd` and `tests/capture_roster.gd`. The latter creates portraits from the actual character models and gameplay frames under `artifacts/roster-*.png`. Reimport after regenerating portraits.

Run seeded full-combat simulations with `tests/city_simulation_test.gd -- --seconds=600 --seed=76` and another seed. Automated checks establish behavior and stability; human playtesting remains necessary for balance and feel.

### Recorded validation · October 17, 2026

- Full headless verification: **1,938 passing checks**, plus **2,516 structural surface probes** and **4,420 winding checks**. Final focused suite: **255 passing checks**, including firing cadence at 30/60/144 FPS, cover, resource accounting, source-specific marks, life cleanup, seeded role balance and retained high-ground assignments.
- Native engine input: **27 passing checks**, covering drone assignment/recall/self-heal, carbine fire, jump/shock, minigun prespin, wall preview/rotation/placement/dismissal, pull/storm preparation, dash-loaded shells, phase restrictions, lift, pause and full ballet completion.
- Rendered review: **16 actual engine frames**; clean portraits, all eight selection cards, active healing/circuit/shock, minigun/wall/pull/storm, dash/phase/ballet and training/city views. Large ammunition counts and ultimate descriptions fit the HUD. Final logs contain no script errors or warnings.
- Seed 76 / Nimbus player, 600 seconds: all **17 checks pass**, 6/6 captures, 134 deaths, 11 health collections, no falls or persistent stalls; maximum temporary stall 4 s.
- Seed 971 / Wisp player, 600 seconds, including Relay and Dynamo: all **17 checks pass**, 5/6 captures, 161 deaths, 24 health collections, no falls or persistent stalls; maximum temporary stall 2 s. Both simulations exercise high-ground, subway and shopping-arcade routes without recovery teleports.
- Persistent summary: `docs/validation/roster-results.json`. Detailed logs, JSON reports and rendered frames are generated under `artifacts/`. Balance and manual play feel remain for human playtesting.
