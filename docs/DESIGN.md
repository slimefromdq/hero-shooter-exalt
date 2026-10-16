# Hero Shooter Design and Prototype Plan

Version 0.11 · Working draft · October 16, 2026

Build a hero shooter around expressive characters whose weapons, movement, and utility create different ways to enter, shape, and finish a fight. This is a living design contract for Lucy and Codex: preserve the fantasy, prototype the uncertain interaction, and revise from play.

## 1. Decision status

**Established** means Lucy specified the concept. **Proposed** means a starting design to change together. **Open** means deliberately undecided. All numerical values below are proposed test values, not balance commitments. No implementation is implied by this document.

| Topic | Status | Current direction |
| --- | --- | --- |
| Project start | Established | Fresh Godot project; no existing repository assumed |
| First meaningful build | Established | Complete playable Nimbus fighting bots, with test/debug/training mode; shared traversal and close combat included |
| Combat identity | Established | Shooting, movement, melee, and ability combinations all matter |
| Nimbus | Established | British spy; umbrella rifle, hover with an initial upward flight burst, deflect, sniper ultimate executing low-health targets; needs an offensive tool such as a bomb |
| Slayer | Established | Buffy-inspired monster hunter; shotgun, bleeding throwing knives, dash into boot kick, disabling traps usable as thrown combat tools; ultimate throws her carried battle axe for severe max-HP damage |
| Annex | Established | Dr. Lucien Vey; five-star spatial utility support with healing projectiles, linked doors, healing fixture, push/pull and self-displacement, and a climbable furniture-tower ultimate |
| Ahab | Established | Moby-Dick-inspired aquatic tank wielding a harpoon; avoid the design problems associated with Roadhog |
| Kung-fu heroine | Established concept, reserve roster | Palm chi blasts, acrobatic leaps, close-combat stance, Zen Breathing that heals and balances rage, dark side at full rage; ultimate install grants CC immunity |
| Movement feel | Established | Acrobatic but weighty, demanding skill; every hero has limited advanced traversal; specific shared moves and tuning remain proposed |
| Camera | Established | Third-person; tune camera distance, shoulder offset, aiming, and close-range readability in the sandbox |
| Team size and mode | Open | Sandbox first; a small team fight on one capture point is the first multiplayer test. Final team size remains undecided |
| Project name and setting | Open | Working title is simply Hero Shooter; do not merge older game projects automatically |
| Engine | Established | Godot; pin the exact installed version in the repository before implementation |

## 2. Design pillars

1. **Recognizable combat fantasies.** Nimbus manipulates sightlines, Slayer hunts through setups and commitments, Ahab changes the shape of a fight.
2. **Agency on both sides.** Strong abilities have visible preparation, an escape response, a cost, or an exposure window. Opponents should understand why they lost.
3. **Useful between kills.** Every hero contributes through space, pressure, protection, or information when eliminations are unavailable.
4. **Commitment creates payoff.** Mobility, crowd control, and burst damage should not all arrive safely in one button press.
5. **Fast experiments.** Editable data, reusable combat rules, a debug arena, and narrow implementation tasks take priority over content volume.

### Proposed shared baseline

Use 250 HP for the reference target and 500 HP for Ahab. Start with 6 m/s ground movement, jump, and hero-specific movement abilities. Include the established universal dash, both slide entries, and close combat below. Keep sprint, dash invulnerability, armor rules, and passive regeneration open. Provide a debug refill/reset instead of designing a full healing economy now.

Health, damage, distance, seconds, and cooldowns must appear in one consistent set of units. Each kit gets primary fire, secondary fire, three abilities, and an ultimate; unused slots stay empty. Bind by action name, not physical keys, so controls remain rebindable.

## Movement direction

**Established:** Acrobatic but weighty, demanding skill. Every hero has limited advanced traversal. Players should feel capable of impressive movement while sensing the force, trajectory, and commitment of their character. Weight must coexist with responsive input.

### Proposed movement principles

- **Responsive intent, physical consequences.** Inputs register promptly; acceleration, braking, and turning make velocity matter. Avoid input delay as a substitute for weight.
- **Readable trajectories.** Jumps and launches establish a trajectory with useful but limited air steering. Reversing direction midair takes effort; repeated inputs cannot erase momentum for free.
- **Earned acrobatics.** Timing takeoffs, choosing approach angles, steering through openings, and controlling landings create mastery. Every hero receives a restrained shared traversal foundation alongside hero-specific movement. The exact shared moves remain open; test them individually rather than adding a complete parkour suite at once.
- **Committed movement abilities.** Dashes and leaps have explicit steering, momentum-transfer, collision, and recovery rules. Spending an entry tool changes the options available for escape.
- **Expressive landings.** Sound, animation, and brief body compression sell impact without excessive camera shake. Ordinary landings preserve responsiveness; any recovery on an exceptional heavy landing must be visible and proportional. Do not add a stun after every jump.
- **Skill through control and judgment.** Reward route choice, timing, aim during motion, and knowing when to commit. Use small input buffers and edge forgiveness to reduce accidental failures; they must not automate route selection or ability timing.

### Shared traversal foundation

**Established:** Every hero can perform some advanced traversal. Hero abilities extend that baseline and give characters distinctive movement identities.

**Established shared movement:** Universal dash follows the crosshair in 3D, including upward and downward aim, with a short buildup followed by a decaying speed burst on a moderate cooldown. Dash into the ground to transition into a fast slide. Normal sliding is also available with enough speed or down slopes. Both entries belong to the same momentum-based movement system. Exact values remain proposed.

**Established direction:** Dash follows the crosshair rather than movement input; downward aim enables dash-to-ground sliding. **Proposed implementation:** Use the camera aim direction, validate the swept actor path from its actual position, and sample direction at the end of buildup. Keep direction fixed during the burst with limited steering as a tuning experiment; camera movement alone must not continuously redirect the burst. On a valid floor contact, project velocity onto the surface tangent and enter slide without reapplying the dash impulse. Normal crouch/slide input enters slide when speed exceeds a threshold or a sufficient downhill slope provides acceleration. On flat ground friction slows the slide; downhill gravity can sustain or increase speed. Prevent repeated entry from manufacturing speed. Ceiling and wall hits resolve collision without becoming floor slides.

Tune dash buildup, burst speed, decay, steering, cooldown, slide entry speed, friction, slope threshold, and speed limits separately. Use one dash charge initially; air use and exact input scheme are prototype proposals. A low mantle remains proposed, not established. Shared dash, slide, and jump must work for Nimbus before any later hero is added.

**Prototype checks:** Test ordinary slide from running speed, downhill slide, dash-to-ground slide, uphill slowdown, wall/ceiling collision, and repeated transitions. Cooldown is consumed once per dash and slide does not reset it. Every actor uses the same motion resolver; external displacement, death, and reset clean up movement state. Keep firing during slides available for the first combat test; mantle firing remains open.

### Hero expression

| Hero | Proposed movement identity | Skill expression |
| --- | --- | --- |
| Nimbus | Upward flight burst into a controlled aerial glide; existing lateral momentum carries into hover, with limited braking and steering | Choose a takeoff angle and landing before exposing himself; time deflect during vulnerable traversal |
| Slayer | Explosive short bursts with a distinct planted finish to her boot rush | Approach at the right angle, aim the interception, and decide whether the landing is safe |
| Ahab | Heavy forward momentum and forceful advances, with deliberate directional commitment | Use terrain and tether choice to select an advantageous endpoint rather than chase freely |
| Kung-fu heroine | Reserve concept: agile leaps with precise landing placement and rhythmic transitions into close combat | Chain positioning and attack timing while managing rage; exact chaining rules remain open |

### First movement experiment

Before expanding the shared traversal package, build one short route with a gap, a narrow landing platform, a cover turn, and an exposed crossing. Provide editable ground acceleration, braking, air steering, jump impulse, gravity, and ability momentum transfer. Retain the earlier 6 m/s speed only as a provisional baseline.

Compare two tuning presets on the same route. Record completion time, falls, overshoots, landing accuracy, and whether players can explain how to improve their next attempt. Repeat with aiming and a moving enemy: movement should reward mastery while leaving opponents readable opportunities to track and punish a commitment. Evaluate responsiveness separately from perceived weight.

**Acceptance:** A skilled player can take a faster or more advantageous route through deliberate execution; a beginner can still follow a straightforward route. Missed jumps and overcommitted attacks have understandable consequences. Normal movement responds immediately, and greater weight is felt through momentum and impact rather than sluggish controls.

## Shared close combat

**Playtest direction, October 16:** Melee must travel forward so it can serve as an engage or finisher. Increase throw reach and give successful throws an actual paired animation. After a further request for more travel, the current experiment uses a 3.6 m committed lunge and 2.8 m grab, followed by a pull, hip lift, turn, slam, and get-up. These numerical defaults remain tunable; the forward movement and readable throw sequence implement Lucy's requested direction. Guard, counterthrow, startup interruption, paired mitigation and safe release still apply.

**Established for the initial build:** Include the melee, block, and throw concept alongside guns, movement, and hero abilities. Melee is a committed attack with meaningful windup and recovery, dealing substantial damage at close to midrange. Block primarily defends against melee. Holding it slows or immobilizes its user, draws on a regenerating meter, and blocks melee with an attacker-stagger response. Protection against gunfire is a separate tuning question, not the primary purpose of guard. Very-close-range throws threaten block; attacks can interrupt their startup, and a responding throw can counterthrow. Successful throws use a paired animation with heavy incoming damage mitigation for both participants.

**Design intent:** Movement creates approaches and escapes; shooting applies ranged pressure; melee rewards an earned approach; block answers a committed strike; throw punishes passive defense. Do not make any response guaranteed at every distance or timing.

### Proposed first rules to test

- **Melee:** Established direction: a committed attack. Prototype one weighty umbrella strike for Nimbus with readable windup, active hit volume, and punishable recovery, rather than a quick filler hit or automatic combo chain. Proposed first rule: no immediate firing, guarding, throwing, or dashing out of its active/recovery phases; tune any later cancel windows explicitly. Hit each target once per swing, respect walls, and avoid homing through evasive movement. Begin with a close-range hit volume; test extended reach separately before choosing how universal midrange melee works.
- **Block:** Frontal held guard, strongly reduced movement, finite guard meter, and no firing or ability use while held. Melee is stopped and briefly staggers the attacker; ordinary bullets receive no guard reduction in the first experiment and never stagger the shooter. This zero-reduction baseline is proposed; Lucy has established melee-focused defense, not an absolute ban on limited gun protection. Rear attacks bypass guard. Immediate meter regeneration after release and a roughly 2 s re-block cooldown are starting proposals. Exact reduction, regeneration, guard-break outcome, and stagger duration remain tuning questions.
- **Throw:** Short visible startup, very short reach, facing and clearance checks, and punishable whiff recovery. Shooting or melee can interrupt before capture. A defending throw input within a configurable reaction window produces a counterthrow break and separates both actors without damage.
- **Successful capture:** Both actors enter a brief paired sequence with heavy mitigation against outside damage. The throw's own scripted damage bypasses that sequence-specific mitigation, while ordinary defenses still follow explicit rules. No invulnerability, healing, or cooldown reset is implied. Use one flat damage value initially; tank-specific or max-HP scaling remains open.
- **Release:** Release both actors into normal control without an additional post-throw stun in the first experiment. The paired animation itself restricts control; it does not eliminate that cost. Validate landing space and separate capsules safely. Prevent new grabs during an active sequence and for a short configurable grace period afterward.
- **State safety:** Cancel and release safely on death, reset, missing target, invalid geometry, or scene exit. Disable unrelated actions during stagger/capture. Block, Nimbus Deflect, ultimate stance, dash, and melee need an explicit action-permission table; initially treat guard and Deflect as separate, mutually exclusive defenses.

The precise reaction window, mitigation percentage, melee damage/reach, guard behavior, and throw damage are **proposals to tune**, not settled balance. Debug mode must expose them. Represent melee, guard, stagger, throw startup, counterthrow, capture, and release as explicit states; never let an animation alone own authoritative hit or control logic.

**Combat acceptance:** A bot can demonstrate each response with readable delays. Block defeats a committed frontal melee, throw threatens block, attacks punish an unprotected throw startup, and a timed counterthrow prevents capture. Two simultaneous grabs resolve only once. A second bot firing into a throw verifies protection on both participants without reducing the scripted throw payoff. Test whether repeated throws become a defensive exploit before adding damage scaling.

## 3. Nimbus

**First playable hero:** Nimbus is the first complete hero. His shared melee uses an umbrella strike in the prototype; all shared movement and close-combat actions are available alongside his kit. Pocket Bomb and the existing numerical kit values remain starting proposals for the complete slice.

**Fantasy:** An impeccably composed British spy whose umbrella is a rifle, shield, and airborne vantage point. **Fight pattern:** take an angle → force movement → punish exposure → relocate. **Weaknesses to preserve:** close pressure, predictable hovering, and poor positioning after deflect expires.

| Action | Proposed first specification | Enemy response |
| --- | --- | --- |
| Primary — Umbrella Rifle | Accurate semi-auto hitscan; 45 body damage, 2× headshot multiplier (90 head damage), 0.6 s shot interval, 8 rounds, 1.6 s reload. The 2× multiplier is established; the 45 base damage remains a proposed test value | Break sightline between shots; close distance during reload |
| Secondary — Aim | Shoulder aim with reduced movement speed; shared ammo | Force Nimbus to track movement at close range |
| Ability 1 — Hover | Open umbrella with a burst of upward flight, then transition into up to 2.5 s of slow descent and limited lateral steering; 8 s cooldown after ending. Burst height and duration remain open tuning values | Track his exposed aerial path; attack the landing |
| Ability 2 — Deflect | Forward-facing 0.65 s window; 10 s cooldown; weapon disabled during activation. Reflect only explicitly reflectable projectiles; block eligible hitscan damage without reflecting it | Bait it, flank, or use excluded attacks |
| Ability 3 — Pocket Bomb | Proposed offensive tool: bouncing timed bomb, 1.1 s fuse, 3 m radius, up to 80 damage with falloff (80 peak damage established); 9 s cooldown; no stun | Move from the visibly armed bomb; push while his displacement tool is spent |
| Ultimate — Final Notice | Enter a scoped stance for up to 5 s; one shot with a visible 0.6 s preparation cue. Execute a directly hit target at or below 20% max HP; otherwise deal 150 base damage (established) | Break sightline, pressure the stance, or recover above the threshold |

**Headshot scope:** The established 2× multiplier applies to Umbrella Rifle. It does not automatically apply to Pocket Bomb, melee, or Final Notice; test Final Notice at 150 base damage without a headshot bonus unless separately changed. Resolve head and body collision so a single rifle shot deals damage only once.

**Execution rule:** Evaluate the target's HP percentage before this shot's damage. A target above threshold takes normal shot damage and can die normally; it is not retroactively executed. Invulnerability prevents the hit. Temporary shields must be depleted before execution can apply. The ultimate consumes its charge on activation; cancellation gives no refund in the first prototype.

**Deflect scope:** Projectile reflection changes owner/team and travel direction once per deflect event. Beams, melee, ground effects, and area explosions are excluded initially. Reflected damage must not recursively reflect indefinitely. These are proposed interaction rules, not changes to the umbrella fantasy.

**Hover rule:** The upward flight burst on activation is established. Proposed prototype behavior: one burst per cast, usable from the ground or in midair; no repeat ascent while holding Hover. Resolve ceiling collision safely and transition into the controlled glide. Keep ascent strength and duration editable separately from glide duration.

**Prototype question:** Does bomb pressure create rifle opportunities without making hovering the universally best firing position?

**First test:** Repeat ten angle contests against a moving target with cover. Record ascent height, access to elevated angles, hit rate from ground versus hover, bomb displacement, and deaths during/after deflect. If hover dominates every situation, first adjust exposure, steering, or duration.

## 4. Slayer

**Fantasy:** A witty, physical monster hunter who turns preparation into a violent close-range finish. **Fight pattern:** tag with a knife or trap → choose an approach → shotgun and boot → escape or commit. **Weaknesses to preserve:** distance, missed setups, and using her entry movement too early.

| Action | Proposed first specification | Enemy response |
| --- | --- | --- |
| Primary — Shotgun | Fixed pellet pattern; 8 pellets × 10 damage at close range; 0.8 s interval; 6 shells; falloff from 8–18 m; 2 s reload | Maintain distance, use cover, punish reload |
| Secondary — Throwing Knife | Projectile; 25 impact + 20 bleed over 4 s; 2 charges, 6 s recharge per charge. Same-source bleed refreshes duration and does not stack | Dodge the projectile, break pursuit, recover after the bleed |
| Ability 1 — Boot Rush | Dash up to 7 m, stopping at the first enemy or solid obstruction; contact deals 35 damage and a short knockback; 8 s cooldown | Sidestep the approach; punish a miss or the landing |
| Ability 2 — Hunter Trap | Same thrown object supports both uses: direct enemy impact deals 20 damage and 35% slow for 1 s; landing on terrain arms after 0.6 s, then triggers 20 damage and a 0.7 s root. Two charges; 10 s recharge each; max two armed traps | Dodge the throw; spot and destroy the armed trap |
| Ultimate — Headsman | Wind up for 0.6 s and throw a large axe; first enemy hit takes 60 + 20% target max HP; one hit per cast, no return damage or penetration initially | Read the windup, dodge, or put cover between hunter and target |

**Trap rule:** The direct-hit and armed-trigger branches are mutually exclusive. An unarmed trap cannot root. Armed traps last 15 s, have 30 HP, and cannot be stacked at the same location. Root stops voluntary translation but permits aiming and firing. Proposed rule: affected targets ignore another Slayer trap root for 2 s after the first ends; the later trap can still deal damage.

**Axe rule:** Max-HP damage uses base maximum health, excluding temporary shields. It deals ordinary damage after calculation and respects mitigation and invulnerability; it is not an execution. Start uncapped against heroes; define a separate cap before adding bosses or unusually large PvE targets.

**Prototype question:** Can Slayer earn close-range opportunities without needing trap → knife → boot → shotgun to become an unavoidable full-health deletion?

**First test:** Run the full sequence against 250-HP and 500-HP targets, then repeat with an actively evasive player. Capture the time from first tell to final hit and every moment the target can respond. Tune root duration and recovery before adding damage.

## 5. Ahab

**Fantasy:** An obsessive sea captain who holds a battle line and drags an enemy into a dangerous decision. **Fight pattern:** establish a front → threaten a tether → choose to reel or advance → protect the crew through the resulting fight.

The earlier two-stage harpoon and aquatic utility are **proposals**. Prototype the harpoon and one protective ability before committing the full kit.

### What the Roadhog concern means for this design

These are design risks to test, rather than claims about any current game's balance.

| Risk | Proposed response | Evidence needed |
| --- | --- | --- |
| Hook only matters when it guarantees a kill | Tether forces position and attention without guaranteeing a close-range follow-up | Successful tethers sometimes create objective space or a rescued ally rather than a kill |
| Tank contributes little while hook is unavailable | Protection and frontline pressure function independently | Allies can name a useful action Ahab performed between hooks |
| Large health pool becomes a resource battery | No self-heal loop in the initial kit; track damage taken without useful pressure | Ahab can advance or protect without relying on constant allied healing |
| Forced displacement feels arbitrary | Visible projectile, breakable line of sight, short tether lifetime, readable reactivation | Victims can identify the hit, the tether, and their response window |
| Environmental kills overwhelm the kit | Test on a floor-only arena before adding ledges | The kit remains valuable without pits |
| Excessive defenses erase commitment | Harpoon and protection compete for weapon uptime | Ahab becomes punishable when an engagement fails |

| Action | Proposed first specification | Enemy response |
| --- | --- | --- |
| Primary — Harpoon Thrust | Broad short-range thrust; 45 damage, 0.8 s interval, 3.5 m reach. Separate from the tether projectile | Kite outside reach; attack during recovery |
| Secondary — Cast and Command | 15 m projectile, 20 damage; anchors a tether for up to 1.5 s. No silence or initial root. Wait at least 0.35 s, then reactivate to reel target up to 4 m toward Ahab, or use Ability 1 to close in. 10 s cooldown starts on cast | Dodge cast; break line of sight for 0.2 s; exceed 18 m tether range; attack during commitment |
| Ability 1 — Full Sail | Dash 5 m toward the tethered target; consumes tether. Without tether, a 4 m forward advance. No stun; 8 s cooldown | Move behind cover; punish Ahab after the advance |
| Ability 2 — Breakwater | Hold a frontal barrier for up to 2 s with 200 barrier HP; weapon and casting disabled; reduced movement; 12 s cooldown after ending | Flank, wait, or break its finite durability |
| Ability 3 — Undertow | Place a visible 4 m zone within 8 m; after a 0.5 s tell it slows enemies by 25% for 2.5 s; no damage or forced pull; 11 s cooldown | Leave during the tell or move around the zone |
| Ultimate — All Hands | Nearby allies within 8 m gain 100 temporary shield HP for 5 s; Ahab gains 150. One grant per cast, no stacking or refresh from overlapping casts | Wait out the temporary protection, split the team, or focus a vulnerable angle |

**Tether resolution:** Only one tether per Ahab. Reeling and closing consume the same tether, so they cannot both resolve. Reeling moves the victim toward a collision-safe endpoint, never through walls or past Ahab. Active displacement immunity prevents the reel; the initial hit can still deal damage. Do not continuously snap a tethered target into position. Define supported movement and cancellation states explicitly before multiplayer work.

**First test:** Use Ahab, one allied shooter, and two opponents around cover and a capture area. Track hook hit rate, tether breaks, displacement distance, eliminations within 3 s of a reel, protected damage, and objective space gained. A hook should be useful with and without a kill. If protection plus hook makes Ahab compulsory, first test removing Undertow or reducing simultaneous coverage.

## Annex

**Dr. Lucien Vey · Support · ★★★★★ Difficulty**

> “There is no such thing as an empty room. You simply haven't met its occupants.”

**Established archetype:** Spatial Manipulator / Utility Support / Playmaker.

Annex manipulates the battlefield with linked doorways, displacement, and temporary terrain. His accessible weapon healing and automatic healing fixture support a demanding spatial toolkit. Creativity, spatial awareness, momentum, and clever setups enable extraordinary saves and unconventional strategies.

### Established kit

| Action | Behavior | Starting parameters supplied by Lucy |
| --- | --- | --- |
| Primary — Surveyor's Instrument | Accurate semi-automatic projectiles damage enemies and heal allies. Shots pass through allies, permitting healing and damage along the same firing line. Consistent, aim-dependent output | Precise semi-automatic fire; damage, healing, projectile speed, cadence, and ammo remain open |
| Ability 1 — Threshold | Place two linked doorways on suitable surfaces. Players and projectiles from both teams can pass through, preserving momentum. Allies receive a brief heal or overhealth burst on passage, subject to an individual cooldown. Reposition endpoints to create shortcuts, firing angles, and escape routes | Two endpoints; proposed 12 s reposition cooldown. Heal versus overhealth, amount, individual cooldown, placement range, and lifetime remain open |
| Ability 2 — Familiar Light | Deploy a hovering fluorescent fixture that automatically heals nearby allies over time, freeing attention for spatial play | Proposed 6 s duration, 12 s cooldown; healing, radius, placement rules, and durability remain open |
| Ability 3 — SKEW | Fire a spatial distortion that pushes or pulls enemies, including through Thresholds. Peel threats and manipulate positions. Also provides directional self-displacement with momentum preservation, useful without active portals | Proposed 18 m range, 11 s cooldown; targeting, push/pull selection, self-use input, force, and damage remain open |
| Ultimate — LOST & FOUND | Summon an impossible Backrooms furniture tower at a distant location. Creates real climbable cover, high ground, and routes; heals nearby allies; includes a built-in doorway linkable to Threshold; accepts further doors on walls and elevated surfaces. Folds into itself when it expires | Proposed 35–40 m placement range, 10 s duration, 0.8 s deployment; dimensions, healing, ultimate cost, and damageability remain open |

**Ultimate call:** “WE HAVE ROOM FOR EVERYONE!”

Long-range tower placement enables emergency cover and portal routes to isolated allies. Its defining contribution is usable architecture combined with healing and door placement. Preserve that interaction when simplifying the first prototype.

**Strengths:** Exceptional team repositioning, creative rescues, terrain and cover creation, mobility synergy, and coordinated plays.

**Weaknesses:** Fragile when caught out, limited burst healing, setup dependence, doors that also benefit enemies, and demanding spatial awareness. Exact health and healing values must support these intentions.

**Core relationship:** SKEW manipulates positions. Threshold connects positions. LOST & FOUND creates new positions.

**Skill floor:** Place Familiar Light, shoot teammates, and use doors as simple shortcuts. **Skill ceiling:** Displace enemies, engineer firing angles, preserve momentum through doors, and construct rescue routes with temporary architecture. Annex changes the geometry of a fight while keeping allies alive.

### Interaction decisions still open

These are prototype proposals, not additions to Lucy's confirmed kit.

| Question | Proposed first test rule | Why test it |
| --- | --- | --- |
| How does the tower door join two endpoints? | Linking the built-in tower doorway temporarily replaces one chosen active endpoint; never silently create a third simultaneous connection. Additional surface placements still use the same two-endpoint budget | Clarifies what a Threshold network means and avoids accidental multi-exit routing |
| How is momentum preserved? | Rotate velocity relative to the entrance and exit frames, preserving speed; validate exit clearance and place actors beyond the exit plane. Apply a brief re-entry guard | Keeps angled exits useful without teleport loops or wall penetration |
| What can traverse doors? | Prototype actors and physical projectiles first, including Surveyor shots. Hitscan, melee, beams, tethers, held objects, and area effects require explicit later rules | Nimbus and Ahab must not acquire accidental cross-door interactions |
| How does passage healing avoid farming? | One timer per allied actor across all Annex doors, independent of endpoint replacement; no healing while dead. Choose heal or overhealth before tuning | Prevents repeated crossings and door replacements from bypassing limits |
| Can one weapon shot heal many allies? | Initially heal each crossed allied actor once, then stop on the first enemy or solid surface. Keep damage and healing tunable separately | Tests healing lines without duplicate-hit bugs; multi-ally throughput remains a balance question |
| Where can doors and the tower appear? | Require authored-valid surfaces, sufficient clearance, and an unoccupied tower footprint. Reject spawn-room and objective-breaking placements; preview validity before commitment | Makes placement predictable and avoids trapping actors inside new collision |
| What happens on tower expiry? | Telegraph expiry, close attached doors, remove their links, then remove collision. Actors fall normally and regain normal movement; validate that no exit resolves inside disappearing geometry | Defines cleanup and gives players time to leave |
| How does SKEW choose targets and mode? | Test explicit push/pull selection and a separate self-use input. Respect collision and displacement immunity; no ally displacement in the initial experiment | Preserves the specified modes while preventing ambiguous activation |
| How do heal sources stack? | Keep weapon, fixture, tower, and passage healing separately logged; do not settle stacking or cooldown start rules without a sustain test | Reveals whether accessible healing undermines the intended limited burst healing |

### Godot implementation slices

Use the shared actor, combat resolver, status rules, and authority boundary. Annex's stateful geometry needs dedicated systems rather than special cases inside the weapon script.

1. **ANX-01 — Surveyor and Familiar Light.** Prototype allied projectile pass-through, per-shot target deduplication, enemy damage, fixture range and duration, and healing logs. Verify full-health targets, enemy exclusion, death, and reset cleanup. Done when Annex can support a moving ally without doors.
2. **ANX-02 — Threshold traversal.** Use two static validated door frames before endpoint repositioning. Test actor and projectile transforms, preserved speed, rotated exit direction, exit obstruction, re-entry guards, both teams, and actor-specific healing cooldown. Separate the portal camera/rendering experiment from traversal correctness; mark temporary visual limitations clearly.
3. **ANX-03 — SKEW.** Test push, pull, self-use, wall collision, immunity, and one successful door crossing. Record entry/exit velocity and resolve movement through the same displacement pipeline as Ahab. Verify it remains useful when no doors exist.
4. **ANX-04 — LOST & FOUND.** Start with a fixed authored furniture-tower scene using simple collision and climbable platforms. Add valid distant placement, deployment tell, timed healing, built-in doorway linking, extra valid door surfaces, and expiry cleanup. Procedural architecture is unnecessary for this slice.
5. **ANX-05 — Team and authority test.** Verify simultaneous crossings, moving projectiles, door replacement during traversal, owner death, tower expiry, and reset on two peers before relying on a full team fight. The authority validates placement, destinations, healing cooldowns, and SKEW targets. Decide whether doors/light/tower persist through owner death explicitly.

### Annex playtest

Run three scenarios separately: ordinary healing under pressure; rescuing an isolated ally at tower range; and a contested doorway that enemies also use. Record healing by source, successful rescues, traversal failures, enemy door uses, deaths after exits, tower high-ground use, and Annex's attention burden. Ask both teams to explain the route and their available response.

**Acceptance:** A newcomer contributes through weapon and fixture healing; an experienced player wins positional advantages through geometry. The tower is climbed, used as cover, or used for door routing during meaningful fights. If it is only a healing aura, revise the tower's geometry and route utility before increasing its healing. If door management overwhelms basic support play, simplify interaction/input costs while retaining the two-ended spatial concept.

## 6. Reserve character and roster questions

Keep the kung-fu heroine's established concept in reserve. Her central unresolved question is whether full rage triggers the dark side automatically or allows deliberate activation. Her CC-immune ultimate also requires exact exceptions and clear visuals. Do not let reserve work delay the complete Nimbus milestone.

Roster gaps are open. Annex provides an established support and healing concept. Role queue, universal healing rules, progression, and final composition remain open. Test the original trio with controlled pickups/reset rules, then introduce Annex as a separate sustain and geometry experiment; do not assume his addition settles the healing economy.

## 7. Godot implementation contract

This is a proposed project structure, not a claim about an existing repository or an engine API. Start a fresh project. Inspect the installed Godot version, pin it, and establish project conventions before implementation. Do not assume an existing repository. Use typed GDScript, scenes for composition, custom Resources for editable configuration, and named input actions. Consult the pinned version's official documentation when choosing concrete engine APIs.

```text
docs/
  DESIGN.md                 # This document
  DECISIONS.md              # Accepted changes and reasons
  PLAYTESTS.md               # Observations and experiment results
  TASKS.md                   # Ordered, small implementation tickets
scenes/
  actors/hero_actor.tscn
  heroes/{nimbus,slayer,ahab,annex}/
  test/combat_sandbox.tscn
scripts/
  actors/                   # Controller, health, status, team membership
  combat/                   # Damage, hit resolution, projectiles, displacement
  abilities/                # Shared lifecycle and specific behaviors
  bots/                     # Intent generation, perception, and training profiles
  training/                 # Scenario selection, debug controls, and resets
resources/
  heroes/                   # Hero definitions
  abilities/                # Tuning data
tests/                      # Focused rule checks using the repo's test approach
```

### Separation of responsibilities

| Layer | Owns | Must avoid |
| --- | --- | --- |
| Hero definition Resource | Stable hero ID, health, speed, ability references | Mutable per-player health or cooldowns |
| Ability definition Resource | Damage, ranges, timings, effect references | Shared runtime state across actors |
| Ability instance | Per-actor cooldown, charges, cast state, cancellation | Writing runtime changes into a shared definition |
| Hero actor | Controller, aim origin, sockets, ability routing | One large script containing every hero |
| Combat resolver | Team checks, damage, shield interaction, status and displacement validation | Ability-specific copies of death logic |
| Presentation | Animation, sound, telegraphs, HUD | Authoritative damage or cooldown decisions |

**Ability lifecycle:** ready → windup → active → recovery → cooldown. Abilities can explicitly omit phases. Define when cost is committed, what interrupts each phase, and the outcome of cancellation. One owner handles cleanup on death, hero swap, respawn, or scene exit; remove tethers, traps, barriers, and temporary statuses appropriately. Charge abilities track each charge's recovery.

**Damage record:** source actor, source team, ability ID, cast ID, base damage, damage tags, hit location, and timestamp/tick. The resolver rejects friendly fire and duplicate hits where appropriate. Status records include source, duration, stacking rule, and permitted control restrictions. Slow uses the strongest active slow initially; root blocks movement; knockback uses the displacement resolver. Root and displacement immunity are separate flags.

**Third-person camera:** Third-person is confirmed. Prototype an over-the-shoulder camera with editable distance, height, shoulder offset, aim zoom, and sensitivity. Camera collision must pull the view forward around walls without entering geometry. Keep the crosshair and ability tells readable during hover, dash, and close combat. Camera tuning remains experimental.

**Third-person aiming:** Test camera-to-crosshair aim against weapon-to-target obstruction. A camera that sees over cover must not let a blocked muzzle shoot through it. Use placeholder capsules and explicit collision layers before investing in models.

**Networking path:** Begin offline to validate mechanics, while routing combat through a clear authority boundary. Multiplayer is deferred until the complete offline Nimbus milestone. The later first network spike uses two peers and server-authoritative health, hits, cooldowns, and displacement; clients send input intent, not trusted damage. Verify ownership, repeated requests, death cleanup, and simultaneous tether use. Decide prediction and lag compensation after this spike; they are not solved by clean offline code.

### Sandbox requirements

- First build: select Nimbus, reset cooldowns, refill health, spawn stationary/moving/enemy bots, and toggle hitbox/telegraph visualization. Add hero swapping only when a second hero exists.
- Include a flat firing lane, cover corners, slopes for sliding, low and elevated platforms for Hover, a traversal route, and a projectile emitter. Reserve environmental-kill testing for a later Ahab slice.
- Show HP/shields, active status timers, cast phase, charges, cooldowns, tether state, and current ability values.
- Log cast, hit, damage, status, displacement, death, and reset events with actor and ability IDs. A reset must also clear summons and effects.

## 8. First playable build and milestones

**Established milestone:** A complete Nimbus fighting bots in a test/debug/training mode. This is an offline playable build with the full hero kit, shared movement, and shared close combat. Other heroes remain design references and later content.

### Training mode and bots

**Additional user-requested guard drill:** A stationary melee bot attacks only inside a configurable range so held guard and attacker stagger can be practiced. The current default trigger is 2.4 m, with a visible range ring and 1.6 s strike cadence. This profile suppresses melee travel and all chase movement, while reusing the normal strike, guard, damage and reaction rules.

**User control preference:** dash 3; Ability 1 / Hover Q; Ability 2 / Deflect E; Ability 3 / Pocket Bomb 1; ultimate 2; slide input Shift; melee 5; throw/counter 4; held shield/guard 6. Movement, jump, primary, aim, reload and training controls are unchanged.

Use placeholder meshes with distinguishable umbrella/rifle states, clear effects, functional HUD, and basic sound/impact feedback. Production art is unnecessary, but every move must communicate startup, activity, and recovery. A launchable training scene offers reset and scenario selection.

**Proposed bot profiles:** stationary target; strafing target; ranged attacker using reflectable projectiles; close-range attacker; and a defensive sparring bot that blocks, throws, and counterthrows with configurable reaction delay and error chance. Reuse the same actor actions, damage rules, cooldowns, and control restrictions as the player. Bots generate intent rather than directly applying damage. Start with one active opponent and allow a second for throw-interference tests.

Bots need basic navigation around cover, valid line-of-sight checks, a firing cadence, and recoverable stuck handling. Full roster AI, human-quality tactics, and perfect parkour navigation are deferred. Use authored route points where needed for reliable training scenarios. Bots must not aim through walls or react without configured delay.

**Training controls:** spawn/despawn profiles, bot aggression and reaction settings, player/bot health presets, freeze AI, refill or infinite resources, ultimate refill, cooldown reset, scenario reset, and hitbox/state display. Debug overrides must be visible and switchable so acceptance checks can run under ordinary rules. Log movement transitions, damage source, blocks, throws, counters, deflects, executions, deaths, and resets. Scenario reset clears projectiles, effects, paired interactions, status, and AI state.

| Order | Ticket and deliverable | Done when |
| --- | --- | --- |
| 0 | BOOT-01 Fresh Godot foundation | Project opens into a training scene; engine version, run instructions, folder conventions, and input actions are recorded |
| 1 | MOVE-01 Third-person movement | Camera collision, aiming, jump, acceleration, and air steering work; test route is traversable |
| 2 | MOVE-02 Dash and both slides | Crosshair-directed 3D dash, buildup/decay, ground-dash transition, ordinary speed entry, and downhill sliding pass collision and speed-gain checks |
| 3 | NIM-01 Rifle and shared combat plumbing | Nimbus shoots/reloads; target takes 45 body or 90 head damage once per shot at the proposed rifle baseline, dies, and resets; cover blocks muzzle fire; independent actor state is verified |
| 4 | CQ-01 Melee and guard | Committed umbrella strike, punishable recovery, melee-focused guard, block meter, attacker stagger, proposed unmitigated gunfire, and action exclusions are visible and testable |
| 5 | CQ-02 Throw and counterthrow | Startup punishment, counterthrow, paired mitigation, safe release, and interruption/reset checks pass |
| 6 | NIM-02 Hover and Deflect | Upward burst enters glide; ceilings and movement transitions work; projectile reflection and exclusions are correct |
| 7 | NIM-03 Bomb and Final Notice | Full offensive kit works; bomb respects cover; execute boundary, stance cancellation, and ultimate consumption are verified |
| 8 | TRAIN-01 Bot scenarios and debug controls | All proposed training profiles and reset controls operate through shared combat rules; player can fight a complete bot encounter |
| 9 | NIM-ACCEPT Complete Nimbus milestone | Run the integrated acceptance session below without persistent state errors; record feel issues separately from correctness failures |
| Later | Roster and multiplayer | Revisit order after Nimbus playtesting; scope Slayer, Ahab, Annex, two-peer networking, and team objectives as separate milestones |

### Integrated acceptance session

1. Launch the project using the documented command/editor path and enter training without editing scenes.
2. Complete a route using ordinary slide, downhill slide, dash-to-ground slide, and Hover ascent/glide; repeat while aiming at a moving target.
3. Fight a ranged bot using rifle, bomb, and Deflect, then a sparring bot using melee, guard, throw, and counterthrow. Confirm every move can be demonstrated independently.
4. Test Final Notice just below, at, and above its execution threshold, including shields and invulnerability. Test a second bot shooting both participants during a throw.
5. Die and reset during movement, reload, guard, throw capture, Hover, Deflect, bomb fuse, and ultimate stance. Confirm control, camera, actor state, effects, and resources return to the selected scenario baseline.
6. Repeat the integrated fight with debug cheats disabled. Capture input responsiveness, route/landing control, combo opportunities, and bot readability in the playtest record.

**Combo direction:** Initially test bomb pressure → repositioned rifle angle; dash-slide approach → umbrella strike; block punish → reposition or shot; and Hover ascent → aerial firing angle → controlled landing. These are opportunities to evaluate, not guaranteed true combos or approved animation cancels. Do not add cancel windows without recording their interactions and counterplay.

No production art, matchmaking, accounts, progression, ranked mode, full roster, large map, or multiplayer is required for this first milestone.

## 9. Working with Codex

Lucy owns creative direction and acceptance. Codex inspects the actual project, implements one scoped task, verifies it, and updates the relevant design/task record. Treat proposed design as experiment scope, not permission to silently rewrite established character concepts.

### Copyable implementation request

```text
Read AGENTS.md, docs/DESIGN.md, docs/DECISIONS.md, and the relevant code.
Task: [one observable behavior].
Design status: [established concept / proposed experiment].
Preserve: [fantasy, interaction rules, existing behavior].
Editable values: [named tuning fields].
Acceptance: [3–5 observable checks, including cleanup/failure behavior].
Scope: [systems/files allowed; features deferred].
Inspect the pinned Godot version and use the existing project conventions.
Implement the smallest playable slice. Do not introduce unrelated systems.
Run available checks; report what ran and what needs manual playtesting.
Update the task and any accepted design changes. List changed files.
```

### Example first hero ticket

**NIM-01 — Rifle and range feedback.** After the shared actor and movement scene exist, add Nimbus's data-driven rifle and reload. Acceptance: one valid shot applies damage once; head hits use the established 2× multiplier (45 body / 90 head at the current proposed base); cooldown and reload block invalid fire; muzzle obstruction prevents shooting through cover; HUD shows ammo and reload; two actors do not share runtime cooldowns; death/reset cancels firing and reload. Defer Hover, Deflect, bomb, ultimate, final animation, and networking to their own tickets.

For consequential combat rules, add focused checks: Nimbus's exact execute boundary; one-time axe damage; trap branch exclusivity; tether obstruction and consumption; per-actor cooldown isolation. Use the repository's existing test runner. If none exists, propose the smallest suitable harness rather than claiming tests passed. Manual feel tests remain necessary.

### Iteration record

```text
Experiment ID:
Question:
Build/commit:
Hero and scenario:
Changed values or behavior:
Expected player behavior:
Observed behavior and event counts:
Player explanation of what happened:
Decision: keep / revise / revert
Next single change:
```

Change one important variable at a time when isolating a failure. Keep the last playable baseline available. Record numerical changes beside the observation that motivated them; promote a proposal to an accepted decision only after Lucy agrees.

## 10. Next design decisions

1. **Shared traversal tuning:** dash, dash-to-ground slide, normal speed-based slide, and downhill slide are established. Tune timings, momentum transfer, cooldown, and steering. Low mantle remains proposed.
2. **Movement tuning:** test acceleration, braking, air steering, and landing behavior against the confirmed acrobatic, weighty, skill-demanding direction.
3. **Camera tuning:** third-person is confirmed; test shoulder offset, distance, field of view, and aiming behavior in the sandbox.
4. **First build details:** Nimbus versus bots in training is established. Choose initial controls, melee/throw values, and bot reaction presets during the scoped tickets.
5. **Ahab's emphasis:** how much of his power belongs to rescuing/protecting allies versus isolating an enemy? Prototype the two-stage tether before settling this.
6. **Nimbus's offensive tool:** keep the pocket bomb experiment or replace its displacement function with another spy gadget.
7. **Team fight foundation:** after the kit sandbox, choose team size, objective, sustain, and intended fight duration together.

8. **Annex routing and sustain:** choose tower-door endpoint behavior, passage heal versus overhealth, SKEW inputs, and fixture/tower stacking before combining the full kit.

### Change history

| Version | Change |
| --- | --- |
| 0.11 | Increased proposed melee travel to 3.6 m; added stationary, range-triggered guard trainer and the user's requested key bindings |
| 0.10 | Playtest feedback establishes forward-traveling melee for engages/finishers, larger throw reach, and a fully animated paired throw; initial experiment is 2.2 m lunge / 2.8 m grab |
| 0.9 | Nimbus rifle gains established 2× headshots; Pocket Bomb peak damage becomes 80; Final Notice base damage becomes 150 |
| 0.8 | Established committed melee, melee-focused block, and crosshair-directed dash; updated prototype guard and action-commitment rules |
| 0.7 | Established fresh start, complete Nimbus versus bots training milestone, shooting/movement/melee/ability combat identity, both slide entries and universal dash, and initial close-combat scope; reordered Codex tickets accordingly |
| 0.6 | Nimbus Hover now begins with an established upward flight burst; ascent tuning and repeat-burst restrictions remain prototype proposals |
| 0.5 | Added Lucy’s Annex kit, cleaned starting parameters, identified open portal and terrain rules, and scoped Godot/Codex prototype slices |
| 0.4 | Lucy established limited advanced traversal for every hero; proposed a shared low mantle and momentum slide for testing |
| 0.3 | Lucy established acrobatic, weighty, skill-demanding movement; added proposed movement principles and a focused route test |
| 0.2 | Lucy confirmed third-person; added camera tuning and collision requirements |
| 0.1 | Preserved the three established hero fantasies and reserve kung-fu concept; proposed testable kit details, a Godot structure, and a Codex iteration workflow |
