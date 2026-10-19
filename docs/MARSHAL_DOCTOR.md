# Marshal and Doctor

October 17, 2026. Two new playable heroes, separate from the reserved Annex and Ahab concepts. The kits implement the requested roles; all numerical balance remains provisional.

## Play

Run `Launch.ps1 -Marshal` or `Launch.ps1 -Doctor`. Add `-Training` for the arena. Both pause menus offer all four heroes. Training offers **Doctor rounds** and **Marshal drill**, also available in the exercise selector. City teams contain one Marshal, one Doctor, two Nimbus and two Slayer; the player replaces a matching slot.

Both retain Space traversal, 3 dash, Shift slide, 5 melee, 4 throw/counter and 6 melee guard. Neither new hero uses RMB shoulder zoom. Held firing is specific to these kits; Nimbus and Slayer retain their existing trigger behavior.

## Marshal Alden Vale

A warm, commanding arcane officer with a curled moustache, navy dress uniform, brass epaulettes, ceremonial mace and heavy cannon. 550 HP; 5.5 m/s movement.

| Input | Ability | Prototype tuning |
| --- | --- | --- |
| LMB hold | Service Cannon | One large cannonball: 150 direct impact damage and 90 splash damage within 3 m (direct victim takes 150 total), 1.1 s cadence, four rounds, 1.8 s reload. 32 m/s speed, 0.24 m radius, 3 m/s² gravity and a 60 m flight budget. No pellet spread, headshot multiplier or damage falloff. Swept sphere collision; world and hostile barriers stop the shot, friendly actors are passed through, and frontal Deflect can return it. |
| RMB hold | Standard of Protection | 8 × 4.5 m directional barrier; 1,200 durability; 65% movement; 1.6 m forward offset; camera pulls back to 4.2 m. Regenerates 180/s after 2 s lowered; breaking imposes 4 s downtime. |
| Q | Forward March | 20 m path budget at 18 m/s, with 0.08 s startup and 90 m/s² acceleration; 8 s cooldown. Movement input spends a cumulative 30-degree steering budget at up to 65 degrees/s. Swept contacts deal 100 once per enemy, with 12 m/s upward and 6 m/s forward knockback plus 0.25 s stagger. Ordinary enemies do not stop travel; world walls, frontal guards and hostile barriers do. Immediate normal movement on completion; 2.5 s safety timeout. |
| E | Rallying Command | Instant defensive shout: 175 temporary overhealth for Marshal, 75 for living visible allies within 12 m at cast time. Lasts 5 s; 12 s cooldown. Usable while ready, guarding or holding the barrier, including while reloading or rooted. No heal, damage, speed or resource bonus. |
| 1 | Orbital Barrage | Aim sets a terrain-following lane: ten sequential ground strikes over 20 m, 2 m spacing, 0.4 s initial warning and 0.08 s intervals. Each has a 2 m blast radius, 75 damage once per enemy per cast, and a 10 s cooldown. Roofs and floors block orbital access; walls and hostile barriers stop the lane. |
| 2 | Marshal�s Verdict | 0.2 s takeoff preparation, physical 19 m/s leap (approximately 8 m apex at 22 m/s² gravity), then a 26 m/s plunge. Landing after at least 0.8 s hits a 16 m / 90-degree forward cone for 100 damage and 0.55 s stagger; 0.65 s recovery. Walls and more than 1.5 m elevation difference protect targets. Airborne targets are excluded. |

The barrier is an analytic attack surface rather than a movement collider. Allied attacks, actors and ordinary melee pass through it; a hostile Forward March instead damages the barrier and ends. Existing rifles, shotguns, knives, axes, generic projectiles, thrown snares and bomb blasts recognize it. Bombs bounce; axes stop rather than pierce. A shield-breaking explosion still protects actors across its surface from that explosion. Shots that originate behind the surface can hit the owner. The barrier is distinct from personal shield HP.

Shooting/reloading cannot occur while shielding. Q, Orbital Barrage, Verdict and shared combat lower it. Dash and traversal require lowering first. Verdict consumes charge on preparation; interruption does not refund it. Orbital Barrage commits its ground lane and damage power at cast, then continues independently of ordinary stagger; death/reset cancels pending blasts.

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

Verdict now reaches 16 m. After a short preparation Marshal physically leaps, raises his mace and plunges down; damage occurs once on supported landing, never at an airborne timer expiry. The ground warning projects the remaining trajectory onto terrain and preserves the committed cone orientation. Ceilings shorten the leap safely; stagger/capture/death/reset cancel it, and a 3 s no-landing timeout aborts without damage or refund. AI checks full charge lanes for walls, missing ground and enemy spawn rooms, and rejects Verdict under insufficient overhead clearance. Damage, cone angle, target elevation/cover checks and recovery remain as before.

Revision validation: 144 headless hero checks, 146 native hero checks, and 28 camera regression checks pass. Rendered city shielding, airborne preparation and landing impact were reviewed.

### Forward leap and heavy landing

Verdict now advances along a 9 m horizontal path budget at 11 m/s during its airborne phase, with a separate 3 m steering budget at up to 4 m/s, accelerated at 20 m/s². Steering remains available after committed forward travel ends. The cone direction stays committed at activation. Solid walls and actors stop the advance; landing stops travel for recovery. It retains its 16 m cone, damage and cover rules. The landing produces three expanding ground rings reaching 8 m, scattered debris and a dedicated 0.9 s bass/crunch/rumble cue that can finish independently of weapon sounds. The circular shockwave is visual feedback; damage still follows the forward cone.

Forward-leap validation: 155 headless and 157 native checks passed, including travel bounds, wall stops, landing timing, shockwave cleanup and unclipped cached audio. Rendered training/city capture completed; the forward landing, layered rings and debris were visually reviewed.

### Marshal movement rework verification

`tests/marshal_rework_test.gd` checks 20/30/60/120 Hz charge integration, multiple targets without duplicate damage, cumulative steering, glancing elevated contacts, root interruption, slopes, thin walls, guard/barrier interactions, movement handoff, safe AI lanes, low-ceiling rejection, eight-metre Verdict apex, horizontal steering with committed cone orientation, and no-ground timeout. `tests/care_heroes_test.gd` retains landed-impact, cover, ceiling, interruption, lifecycle and shared combat regressions. These run through `tools/verify.ps1`.

Charge feedback uses a shoulder-forward startup/lean animation, speed-driven camera FOV and recoil, sparse dust and streaks, and the existing heavy impact audio. The warning predicts the current trajectory; subsequent player steering or moving geometry can change the eventual landing. Human keyboard/mouse playtesting remains necessary to judge comfort and balance.

Validation: the full headless verification script completed successfully. Final affected runs passed 42 Marshal rework checks, 163 headless / 165 rendered care-hero checks, 79 bot tactics checks, 19 bot integration checks and 148 camera checks. Charge, apex and impact captures were visually inspected; logs and captures are under artifacts/marshal-*. No human game-feel or balance playtest was performed.

Marshal cannon rework: the shared Doctor sidearm remains unchanged. Cannon firing uses MarshalKit and MarshalCannonball, existing ammo/reload rules, CombatResolver damage/deflect rules and cast-time damage snapshots. The model has a broad single muzzle with recoil and a dark metal/brass cannonball. Tactical bots lead moving targets and compensate for the slight gravity arc. tests/marshal_cannon_test.gd covers flight, damage, cadence, ammo/reload, glancing sphere hits, low-frame-rate walls, close muzzle cover, range expiry, guard/barrier/deflect, friends, cast-time buffs and reset cleanup.

Cannon validation: 36 focused checks, 255 roster checks, 163 care-hero checks, 42 movement checks, 105 QoL checks, 79 bot tactics checks and 19 bot integration checks pass. The roster wall fixture now keeps the firing position clear instead of overlapping another hero with the shooter. Cannon flight was rendered and inspected. Damage tuning and game feel still need human playtesting.

### Rallying Command and universal overhealth

Every HeroActor owns ActorOverhealth, independent of hero kit, base HP, personal shields, and healing benefits. Existing guard/deflect and mitigation resolve first; damage then consumes **temporary overhealth, personal shield HP, ordinary health**, in that order. Damage to temporary health participates in confirmed hits, damage events, contribution/assist credit, elimination attribution, and ordinary damage-based ultimate charge. It never generates healing credit. Execution eligibility retains the existing ordinary-health percentage and requires both temporary overhealth and personal shields to be absent. Wounds and health thresholds continue to use ordinary effective health.

Rally selects recipients once, using three-dimensional 12 m distance and chest-height line of sight. World cover, hostile barriers and closed spawn doors block eligibility. Dead, hostile or protected recipients are excluded. Leaving range, losing sight, or being crowd controlled afterward does not revoke the grant. E preserves an existing guard/barrier stance and does not cancel a committed charge, leap, melee, capture or stagger. Iron Resolve and its damage reduction are removed; there is no Command Momentum or alternate resource.

Overlapping grants are **non-additive**. Each source has one grant slot with an independent expiry. The strongest remaining amount is the effective overhealth pool. All absorbed damage is subtracted from every grant, so weaker grants cannot become an undamaged refill. For example, 100 for 2 s plus 75 for 5 s gives 100, not 175; after absorbing 40, the grants contain 60 and 35. When the first expires, only 35 remains. A fresh different source can raise the pool if its grant is stronger. Each source is locked out until its original grant expires, even if depleted; repeated casts neither restore it nor extend its deadline. Expiry does not play a break cue. Recipient death/reset/hero switching clears its grants and locks; source death/reset/hero switching/removal also removes its owned grants from allies. Match resets clear every pool.

Cyan/teal armor bands and separate numerical HUD/overhead/roster strips use the same shared overhealth color. Existing blue personal shields retain a distinct display. Exhausting the entire pool produces a brief armor fracture and sound. The command adds a voiced, synthesized two-syllable shout and a thin expanding 12 m pulse; these are presentation only. No opaque bubble obscures silhouettes.

Both bot paths reserve Rally for a visible close engagement or credible incoming fire with an eligible nearby ally, or recent damage plus low-health emergency self-defense. They skip locked/sufficient grants and cooldowns. Tactical bots retain or raise a warranted barrier in the same tick as the shout. Perception includes temporary overhealth when judging effective target durability.

`tests/overhealth_test.gd` covers values, radius and sight, state legality, absorption/overflow, mitigation, independent expiry and source locks, overlap rules, healing isolation, execution gating, damage/ultimate credit, lifecycle cleanup, all eight heroes, visual synchronization and bot decisions. `tools/verify.ps1` runs it with existing regressions.

Rally/overhealth validation: the full tools/verify.ps1 run completed with exit 0. Final focused runs passed 118 checks in both headless and rendered Godot, plus the existing care-hero, health-bar, tactical-bot and bot-integration suites. Training and city captures, including simultaneous personal shields and overhealth, were visually inspected; activation, depletion and expiration captures are under artifacts/overhealth-*. One initial run failed an unchanged angled-wall traversal assertion; the isolated and full reruns passed without changing that test. Human gameplay/audio comfort and balance remain untested.

### Orbital Barrage and Marshal combat presentation

The ability keeps slot 1 and the existing aim/cast controls. Aim defines the horizontal lane; projection follows the actual terrain instead of spawning explosions at airborne points. Each sample searches up to 3 m above / 12 m below the preceding surface. Walkable slopes and upper platforms retain their real heights and normals. Walls clip the lane. Marked ground is checked again immediately before damage; removed/moved floors and newly added cover can cancel a strike. The orbital shaft checks 80 m upward with both a ray and a 0.30 m sphere sweep, including roof edges. No beam or damage is allowed through solid overhead geometry. An upward-facing hostile barrier can intercept the incoming shaft; ordinary lane barriers and splash cover retain their existing resolver rules, including protection when a barrier breaks. As before, ordinary stagger does not cancel the committed barrage; death/reset/hero changes retire pending markers and audio.

Gold ground reticles and descending cyan targeting needles precede narrow white-blue impact columns. Actual damage triggers the brilliant phase; markers cannot apply damage. Expanding energy rings and six small dust puffs give grounded impact feedback. Each caster has four reusable orbital audio channels; effects use no dynamic lights or particle systems and have a hard 40-effect world cap. Damage continues authoritatively even if the optional presentation budget is full. Impact audio combines a sharp discharge and a slightly delayed bass strike.

The confirmed cannonball weapon remains 150 direct damage, four rounds, 1.1 s cadence, 1.8 s reload and 32 m/s flight. This pass adds an immediate short arcane muzzle flash, heavier cached report/impact sounds, visible recoil and a supported reload pose. Existing hit-confirmation signals still report authoritative hits. Barrier mechanics remain the same 8 x 4.5 m analytic surface, 1,200 HP, regeneration and 4 s break downtime. Raising/lowering is visually responsive without delaying blocking; ten readable durability segments, progressive cracks, damage flashes, break fragments and a ready chime expose its state. Marshal's camera pullback uses frame-rate-independent exponential smoothing. No new resource is added and other hero kits are unchanged.

`tests/marshal_orbital_test.gd` verifies projected and revalidated targets, warning/impact phases, sequential damage/deduplication, roofs and roof edges, upper floors, slopes, dynamic walls, ordinary/overhead barriers, interruption/reset, weapon invariants, durability glow/cracks, audio caching and effect/voice budgets. `tests/capture_marshal_polish.gd` captures actual rendered telegraphs, orbital impacts, barrier full/low/break states, cannon firing and reload.

Validation: `tools/verify.ps1` completed with exit 0 and no failure/error lines. Final focused runs passed Orbital Barrage (73 checks), cannon mechanics (36), and care-hero integration (163 headless / 165 rendered). The affected tactical bot, bot integration and camera framing suites passed (79 / 19 / 148). Final polish captures completed with exit 0; orbital impacts, barrier cracks/durability and the cannon muzzle flash were visually inspected. Automated and rendered checks do not establish human game feel, audio comfort or competitive balance.

Cannonball impact follow-up: every hostile player, world surface, structure or barrier impact detonates a 90-damage, 3 m radius blast without falloff. Direct player hits remain 150 total; the same cast ID prevents double damage/credit. Friendly actors still let the ball pass, frontal Deflect reflects without premature detonation, and range expiry/reset silently retires the projectile. Splash uses CombatResolver, preserving cover, team immunity, overhealth, damage attribution and fire-time buffs. Blast origins stay outside the collided surface. Cover eligibility is snapshotted before barriers/structures take damage, so breaking cover still protects against that blast; directly hit cover receives 150 while other exposed cover receives 90. MarshalTuning exposes both blast parameters. A short brass-energy expansion and heavier explosive report accompany detonation.

Blast validation: full `tools/verify.ps1` passed with exit 0. Final focused suites passed cannon (55 checks), orbital/presentation (74), care heroes (163), and overhealth (118). Rendered polish capture passed and the explosion was visually inspected. Coverage includes low-frame-rate surface blasts, ground/player impacts, radius, friendly-fire immunity, direct-hit deduplication, ultimate credit, fire-time buffs, and breaking barriers/structures protecting nearby targets.
