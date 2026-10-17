# Huddle · a home for small things

**Role:** mobile off-tank. **Health:** 600 HP, with no personal shield HP. **Motto:** “Relocate, don't exterminate!”

Huddle is a displaced garden colony. Individually, its bugs are tiny, fluffy, earnest creatures with glossy eyes, pom-pom antennae and bright wings. Together they make a single protective body: a lookout on top, neighbors stacked below, and a chorus of little voices speaking as “we.” They fight for safe homes and humane relocation. The colony visibly scatters and reforms, but always has one ordinary body collider and shared health pool. Its top lookout cluster marks the ordinary headshot region.

The original procedural model draws inspiration from the supplied yellow bug reference. The reference's pet instructions are not gameplay requirements. Team-colored leaf bands distinguish friendly and hostile colonies. No external image-generation or character assets are required.

## Play

Run `Launch.ps1 -Huddle` for Meridian Gardens or add `-Training` for the arena. Both pause menus offer Huddle. Training offers **Huddle rescue**, with an injured colony, a friendly garden neighbor, three attackers and the existing raised traversal decks. A **Huddle** bot profile is also available.

Huddle can dive alongside teammates, screen someone under fire, shove away pursuers, then spend a flight charge to escape and regroup. Focused fire, ranged pressure, roots/slows and depleted movement charges remain meaningful counters. Values below are editable prototype defaults in `resources/huddle.tres` and `HuddleTuning`.

| Input | Action | Default |
| --- | --- | --- |
| LMB hold | Seed Spitter | Six physical seeds per volley, 8 damage each, 55 m/s, 24 m maximum travel, 2° spread. 0.45 s cadence, 10 volleys, 1.6 s reload. No outgoing headshot bonus. |
| RMB hold | Regroup | 0.3 s preparation, then 80 HP/s for up to 3 s. Move at 60% speed. 10 s cooldown begins with the first healing tick. Release to rearm. |
| Q | Scatterbound | Two charges; committed three-dimensional travel at 22 m/s for up to 10 m. Five seconds sequential recharge per charge. |
| E | We've Got You! | Aimed visible ally within 18 m, otherwise self. A 2.8 × 2.4 m, 250-durability screen faces the recipient's aim, follows them for 2.5 s, and has a 10 s cooldown. |
| 1 | Personal Space! | 0.2 s windup, 35 damage within 4 m, radial 10 m/s push. Requires clear sight, adds no stun or slow. Nine-second cooldown. |
| 2 | Nobody Gets Squished! | 0.45 s warning, then a 5 m wide × 2 m high bug wave advancing at 12 m/s for 2 s. Steer at up to 60°/s. Sixty damage once per enemy, continued 12 m/s forward displacement during contact. |

Shared dash, slides, wall kicks, mantles, melee, guard and throws retain their usual bindings. RMB replaces aerial braking; Huddle falls normally outside burst flight. The HUD shows flight charges/recharge, healing cooldown, screen durability/remaining lifetime and wave duration. The wave smoothly pulls the shoulder camera back to 4.5 m without changing its normal field of view or collision checks.

## Authority and lifecycle

- Regroup restores only missing effective health, respects max-health wounds and spawn-room restrictions, and never earns healing ultimate charge. Existing passive/damage charge rules remain. Damage continues normally; release, reload, attacking, another ability, stagger or capture ends healing. Holding RMB cannot restart a completed or interrupted channel until released.
- Scatterbound sweeps the unchanged body against world and actors. It cannot fire, shrink its collider, bypass walls, cleanse or become invulnerable. Ending velocity carries into ordinary movement. Root, slow and stagger interrupt it; cooldown is not refunded.
- Screens use the same `CombatBarrier` intersection and nearest-surface contract as Marshal. Friendly attacks and physical actors pass through. Hostile ranged attacks and blasts damage the screen, with per-cast deduplication and cover sampled before destruction. Melee bypasses it. The screen is an external temporary defense, not personal shield HP. Source/recipient death, reset or hero change, expiry, destruction or scene exit ends it.
- The ultimate consumes charge on transformation, retaining charge when preparation is interrupted. It requires ground support, follows walkable slopes and ramps/stairs, and ends at a solid wall or unsupported edge. It cannot reverse or stop through backward input. Root, slow, stagger, capture and death end it. The wave offers no damage reduction, invulnerability, healing or flight refill.
- Swept wave contact damages each enemy once. Barriers intercept initial damage; solid cover blocks both damage and contact. Repeated contact maintains a bounded push instead of accumulating impulses. Enemies retain their controls and can leave the wave. Displacement obeys physical collision; there is no pin, capture, stun or wall-crush damage. Other abilities and shared close combat are unavailable during transformation. Existing screens finish their ordinary lifetime.
- The broad wave is an attack volume; the unchanged center remains Huddle's only damage collider, marked by the larger lookout bug. Visual bugs do not become independent targets or actors.

## Roster and bots

Each team uses Marshal, Huddle, Doctor, Nimbus and two Slayers. Huddle takes a flank route; Marshal and Doctor retain the main approach. A Nimbus bot retains the dedicated subway route whenever present; when the player is the sole Nimbus, a Slayer bot covers that route instead. Hero selection refreshes the assignments.

Huddle bots screen threatened visible allies, keep the final flight charge for escape, check flight paths and landing support before diving, regroup when clear of close pressure and sweep visible groups with their ultimate. Their ordinary controller retains navigation ownership.

## Verify

`tools/verify.ps1` includes `tests/huddle_test.gd`; `-Capture` adds native input/camera checks and `tests/capture_huddle.gd`. The capture script generates actual gameplay PNGs under `artifacts/huddle-*.png` and the original portrait under `assets/portraits/huddle.png`. Import afterward to refresh the portrait in Godot.

Focused coverage includes healing, max-health wounds, interruption, two-charge recovery, vertical and obstructed travel, every hero's weapon against the screen, thrown weapons, explosions, wave steering and displacement, barriers, walls, edges, lifecycle, training and pause. The city simulation exercises the five-hero composition. Human keyboard/mouse playtesting is still needed for balance, comfort and competitive feel.

### Recorded validation · October 17, 2026

- Final focused suite: 101 headless checks and 105 native checks, all passing. Native coverage includes held RMB, Q and the wave camera transition. Actual healing movement is checked at 3.6 m/s, including the shared motor's state scaling.
- Full verification completed successfully: 1,266 checks across 23 suites, plus 2,516 structural surface probes and 4,420 winding checks. The final expanded Huddle suite above supersedes its earlier 95-check run. Existing camera framing adds 28 passing regression checks.
- Navigation regression: nine checks pass, covering repeated short casts and the exact underground stair pocket found during stress testing. Recovery validates a local capsule path and, when needed, a normal jump with checked upward/landing clearance. It does not teleport or exceed the shared jump height or existing path-update budget.
- Rendered review covers the portrait, Regroup, screen, Scatterbound, wingbeat, warning, wave/displacement, both menus and the city shoulder camera. The training HP editor now supports Huddle's full health instead of clamping its display to 500.
- In a 1440 × 900 city comparison on Intel Arc, the same camera averaged 1,470 draw calls with two colonies versus 1,446 after replacing them with Nimbuses (about +1.6%). Shared sphere meshes/materials allow the renderer to batch bug geometry. CPU timings were collected alongside other verification processes and are not an isolated frame-rate benchmark. Raw data is in `artifacts/huddle-performance.json`.

- Final 600-second five-hero simulation, seed 76: all 17 checks pass; 4/3 captures, 97 deaths, 44 shared health collections and one completed/restarted match. Both teams use subway, arcade and elevated routes. No falls, persistent stalls or recovery teleports; worst temporary stall is 3 s. Report: `artifacts/city-simulation-76-600s.json`.
