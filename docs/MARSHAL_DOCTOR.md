# Marshal and Doctor

October 17, 2026. Two new playable heroes, separate from the reserved Annex and Ahab concepts. The kits implement the requested roles; all numerical balance remains provisional.

## Play

Run `Launch.ps1 -Marshal` or `Launch.ps1 -Doctor`. Add `-Training` for the arena. Both pause menus offer all four heroes. Training offers **Doctor rounds** and **Marshal drill**, also available in the exercise selector. City teams contain one Marshal, one Doctor, two Nimbus and two Slayer; the player replaces a matching slot.

Both retain Space traversal, 3 dash, Shift slide, 5 melee, 4 throw/counter and 6 melee guard. Neither new hero uses RMB shoulder zoom. Held firing is specific to these kits; Nimbus and Slayer retain their existing trigger behavior.

## Marshal Alden Vale

A warm, commanding arcane officer with a curled moustache, navy dress uniform, brass epaulettes, ceremonial mace and heavy cannon. 550 HP; 5.5 m/s movement.

| Input | Ability | Prototype tuning |
| --- | --- | --- |
| LMB hold | Service Cannon | 60 body damage across eight pellets, 0.65 s cadence, eight rounds, 2 s reload, 1.5× heads. Full damage to 8 m, decreasing to 30% at 20 m. |
| RMB hold | Standard of Protection | 8 × 4.5 m directional barrier; 1,200 durability; 65% movement; 1.6 m forward offset; camera pulls back to 4.2 m. Regenerates 180/s after 2 s lowered; breaking imposes 4 s downtime. |
| Q | Forward March | Up to 5 m in 0.45 s; 8 s cooldown. First actor/wall stops it. Enemy contact deals 45 and applies 8 m/s upward plus 2 m/s forward impulse. Frontal shared guard blocks and staggers the marshal. No pin or added stun. |
| E | Iron Resolve | 30% self damage reduction for 3 s; 12 s cooldown. Available while shielding. |
| 1 | Breach Line | Fixed 3D aim; 0.4 s warning, then ten explosions spaced 2 m and 0.08 s apart. 2 m blast radius, 75 damage once per enemy per cast; 10 s cooldown. Stops at world geometry or an enemy barrier. |
| 2 | Marshal�s Verdict | 0.2 s takeoff preparation, physical 10 m/s leap, then a 26 m/s plunge. Landing after at least 0.8 s hits a 16 m / 90-degree forward cone for 100 damage and 0.55 s stagger; 0.65 s recovery. Walls and more than 1.5 m elevation difference protect targets. Airborne targets are excluded. |

The barrier is an analytic attack surface rather than a movement collider. Allied attacks, actors and melee pass through it. Existing rifles, shotguns, knives, axes, generic projectiles, thrown snares and bomb blasts recognize it. Bombs bounce; axes stop rather than pierce. A shield-breaking explosion still protects actors across its surface from that explosion. Shots that originate behind the surface can hit the owner. The barrier is distinct from personal shield HP.

Shooting/reloading cannot occur while shielding. Q, Breach Line, Verdict and shared combat lower it. Dash and traversal require lowering first. Verdict consumes charge on preparation; interruption does not refund it. Breach Line samples direction and damage power at cast, then continues independently of ordinary stagger; death/reset cancels pending blasts.

## Dr. Edith Bellamy

A composed Edwardian physician with pinned hair, ivory tailored coat, high collar, gloves and polished medical instruments. 250 HP; 6 m/s movement.

| Input | Ability | Prototype tuning |
| --- | --- | --- |
| LMB hold | Clinical Sidearm | 24 damage, 0.3 s cadence, 12 rounds, 1.4 s reload, 1.5× heads. |
| RMB hold | Attending Care | 65 HP/s to one ally within 18 m; 12° acquisition / 20° retention cone. Newly aimed patients replace the current patient immediately. |
| Passive aftereffect | Continuing Care | Former patients retain 15 HP/s for 2 s; suspended during that doctor’s active beam. |
| Q | House Call | Swept travel toward an aimed ally within 20 m at 16 m/s, stopping 2 m short; 4 s cooldown. No invulnerability. |
| E | Ward Round | Self and visible allies within 10 m: 50 immediate healing plus 15 HP/s for 3 s; 10 s cooldown. |
| 1 | Clean Prescription | Aimed visible ally within 18 m: remove bleed, wound, root and slow; heal 35; grant 70% damage reduction for 1 s. 12 s cooldown. |
| 2 | Exemplary Condition | 0.4 s preparation, one visible friendly target within 20 m: +40% direct damage, +30% running speed and 40% damage reduction for 8 s. Independent of distance after application. No self targeting. |

Healing wins simultaneous mouse holds. The beam never heals through cover: a 0.15 s grace retains selection only. Patients retain their existing aftercare during a sight break. Other teammates do not occlude care, while world geometry and hostile barriers do.

House Call checks the destination and full capsule path before spending cooldown. Collision, root, slow, stagger or capture interrupts active travel without refund. An invalid target spends nothing. The ultimate validates its target both before and after preparation; charge is consumed only on valid application. Interruption retains its unspent charge. No resurrection, invulnerability, tether upkeep or beam-based extension.

## Shared authority and lifecycle

- `HeroTuning` subclasses contain editable numbers; kits own finite ammunition, cooldowns, target selection and casts. Controllers request ordinary combat intents.
- `CombatResolver.heal` restores only missing effective health and emits confirmed healing. Actual restored HP earns 0.06% ultimate per HP; full-health attempts earn nothing. Healing cannot originate in or reach protected spawn rooms.
- `ActorBenefits` owns source-bound timed effects. Identical ongoing treatments use the strongest rate, distinct treatments combine, and damage reductions use the strongest percentage. Exemplary Condition cannot stack or refresh while active.
- Damage power is captured when an attack is emitted. Existing projectiles and bombs cannot acquire a later damage buff; bleed and execution thresholds are unchanged. Bonus damage earns no additional ultimate charge. Resistance also reduces would-be execution damage; surviving hits are not reported as executions.
- Speed bonuses retain existing global speed limits. House Call uses its specified travel speed.
- Source/recipient death, reset, hero changes and scene exit retire life-bound benefits. Pause freezes timers. Personal shield HP follows existing actor behavior; these heroes do not add temporary personal shield grants.
- City doctors prioritize injured allies, pulse for group injuries, cleanse threats, escape and empower allies engaging enemies. Marshals shield under ranged pressure and use their cannon, launch, barrage and slam when enemies approach. One Nimbus bot per team retains the authored subway/arcade route while the marshal uses the main approach; changing heroes updates these assignments.

## Verification

Run `tools/verify.ps1`; it includes `tests/care_heroes_test.gd`. `-Capture` additionally runs `tests/capture_care_heroes.gd`, which writes gameplay frames under `artifacts/care-*.png` and regenerates the two original procedural-model portraits. Import afterward to refresh those textures in Godot.

The focused suite covers treatments, damage modifiers, historical projectile power, shield edges and break behavior, every existing ranged attack, launches and guard, three-dimensional barrage, ten-metre Verdict, movement, reset and training integration. The existing city simulation exercises the expanded mixed roster. Balance, comfort and the emotional feel of protecting teammates still require keyboard/mouse playtesting.


### Recorded validation - October 17

- Full verification run: 1,112 checks across 21 suites, plus 2,516 structural surface and 4,420 winding probes, all passing. Later changes were checked with the expanded focused suite and affected city/Slayer regressions.
- Final focused suite: 126 headless checks; 128 native checks including held mouse input, all passing.
- Final mixed-roster simulation: 600 seconds, seed 76, 17 checks, zero failures. Both teams use the subway and shopping arcade, doctors heal, marshals intercept attacks, the match completes and restarts, and no participant falls through the map or requires recovery teleportation.
- Rendered review: procedural portraits, shield, enemy launch, barrage, Verdict warning, healing, ultimate, training menu, and both city HUDs. Captures are under `artifacts/care-*.png`.

The simulation caught a missing dedicated underground route after moving Marshal onto the main approach. Role assignment now preserves that route on a Nimbus bot for every selectable player hero; source and destination assignments refresh on hero changes. The initial full-roster assertion in Slayer's integration test now counts the player toward the two Slayers per team.


### Marshal feel revision

The barrier now sits 1.6 m ahead of Marshal (previously 0.9 m). Holding it smoothly increases the ordinary 1.85 m camera distance to 4.2 m, retaining the normal field of view and spring-arm collision. Release, death or a hero change returns the ordinary camera target distance.

Verdict now reaches 16 m. After a short preparation Marshal physically leaps, raises his mace and plunges down; damage occurs once on supported landing, never at an airborne timer expiry. The ground warning follows the terrain beneath him. Ceilings shorten the leap safely; stagger/capture/death/reset cancel it, and a 2.5 s no-landing timeout aborts without damage or refund. The AI uses the expanded range. Damage, cone angle, target elevation/cover checks and recovery remain as before.

Revision validation: 144 headless hero checks, 146 native hero checks, and 28 camera regression checks pass. Rendered city shielding, airborne preparation and landing impact were reviewed.

### Forward leap and heavy landing

Verdict now advances up to 6 m at 11 m/s during its airborne phase, in the direction committed at activation. Solid walls and actors stop the advance; landing stops travel for recovery. It retains its 16 m cone, damage and cover rules. The landing produces three expanding ground rings reaching 8 m, scattered debris and a dedicated 0.9 s bass/crunch/rumble cue that can finish independently of weapon sounds. The circular shockwave is visual feedback; damage still follows the forward cone.

Forward-leap validation: 155 headless and 157 native checks passed, including travel bounds, wall stops, landing timing, shockwave cleanup and unclipped cached audio. Rendered training/city capture completed; the forward landing, layered rings and debris were visually reviewed.
