# Implementation decisions · Nimbus training slice

## QOL-01 · Current user-directed balance and usability pass

October 17, 2026: [QOL.md](QOL.md) records the implemented movement, concurrent reload, hero, camera, training and menu revision. It supersedes historical numeric defaults and exclusive reload permissions below. Dash is wheel up; slide stays Shift. City hero changes preserve the match and queue outside spawn. Numerical buffs remain editable playtest defaults.

2026-10-16. The attached design remains the source of established creative decisions. This record distinguishes implementation assumptions from accepted balance. No proposed tuning is promoted to an accepted design decision by this build.

## Foundation

- Fresh project in this workspace; no earlier hero projects imported.
- Requested engine family: Godot 4.7. Installed and verified exact engine: **4.7.2.stable.official.ed1daf0bf**. `.godot-version` pins 4.7.2 stable.
- Offline third-person Nimbus versus bots is the implementation scope. Slayer, Ahab, Annex, the reserve heroine, networking and objectives remain deferred.
- Compatibility renderer with 4× MSAA, GodotPhysics3D, 60 Hz physics. Keyboard/mouse, original procedural meshes and short original synth cues. No downloaded art or dependencies.
- Lightweight SceneTree test scripts provide actual Godot physics/ray/actor tests without a third-party runner.

## Proposed defaults selected for unresolved details

All fields live in `HeroTuning`. Values can be changed through the Resource Inspector; important close-combat and movement fields also appear in the training console.

| Experiment | Initial implementation |
| --- | --- |
| Dash | 0.16 s buildup; direction sampled at end; 20 m/s; 26 m/s² decay; 0.38 s burst; two sequentially recharging charges at 4.3 s each; air use allowed; no invulnerability |
| Slide | 5 m/s ordinary entry; slope entry at 8°; 4.0 m/s² friction; gravity acts on floor tangent; 26 m/s global speed cap; fresh crouch on airborne dash landing only; ground dash residual momentum cannot enter slide; mantle exit crouch supplies at least 8 m/s |
| Movement | 6 m/s ground; 30 m/s² acceleration; 24 braking; 5.625 air steering; 8 m/s jump; 22 m/s² gravity; 0.1 s edge forgiveness, 0.12 s jump buffer |
| Hover / umbrella vault | 12 m/s ascent for 0.4 s, then up to 2.5 s glide approaching 1.6 m/s descent; roughly 8 m open-space apex; cooldown after end |
| Mantle | Hold Space + move into a ledge, or deliberate nearby press; 1.15 m forward probe with ±0.2 m side probes; 0.3–2.35 m rise above feet; 0.32 s lift/over; preserve entry horizontal velocity on completion; last 0.12 s buffers a fresh exit jump; full-capsule path checks and live sweeps |
| Wall jump | Press Space in air within 0.72 m of a near-vertical environment wall; face-directed horizontal launch of at least 9 m/s, retaining faster incoming speed within the cap; at least 9.5 m/s upward and 3 m/s outward; 26 m/s combined cap; 0.2 s cooldown; same facing wall cannot rearm until grounded |
| Melee | 75 HP; 2.6 m hit reach plus up to 4.8 m collision-limited travel; 0.24 s startup / 0.2 s active / 0.4 s recovery; no action cancels. Lunge starts at 0.06 s and lasts 0.36 s. Direction is fixed on input. |
| Reload movement | 85% of ordinary ground speed: 5.1 m/s, previously 35% / 2.1 m/s. Aim still caps movement at 60%. Reload duration stays 1.6 s. |
| Guard | 100 meter; 24/s drain; 35/s immediate regen after release; 28 per blocked strike; 2 s re-block cooldown; 15% movement; 0 bullet reduction |
| Throw | 2.8 m; 0.3 s startup; 0.65 s whiff; 0.24 s counter window; 1.1 s pair; 1.05 m lift; impact at 72% of the pair; 95 HP scripted damage; outside damage ×0.1 on both; 0.8 s re-grab grace |
| Ultimate economy | Starts ready for training; +0.8%/s and +0.09% per HP damage. Consumed on stance entry, no cancellation refund. This economy is a sandbox assumption. |
| Rifle head region | One capsule ray hit; upper 1.5–1.9 m is head, lower section body. A single hit record prevents overlapping head/body duplicate damage. |
| Bot response | 0.22 s default, adjustable 0.05–1.5 s; 15% configured counter error; local ray avoidance and stuck recovery. No full navigation mesh or parkour planner. |

## Action permissions

The actor state table is authoritative; procedural animation never applies damage. State and motion mode are shown by F3.

| State | Permitted actions |
| --- | --- |
| Ready, ground/air/slide/Hover | Rifle, aim, reload, kit, jump, shared combat; dash additionally requires an available charge |
| Dash buildup / dash | Steering intent is suppressed during the burst; no other combat casts |
| Mantle | Fixed climb path and facing; no competing movement/combat casts; stagger, capture, death, reset, removed support or new obstruction can interrupt |
| Melee startup / active / recovery | Swept, committed forward lunge during startup/active; limited normal translation in recovery; no rifle, guard, throw, dash or ability cancels |
| Guard | Slow translation, release; responding counterthrow input; no gun/kit casts |
| Throw startup / whiff | Limited translation, no new casts; damage interrupts startup |
| Captured / throw pair | No translation or unrelated actions; outside damage ×0.1; scripted throw damage bypasses only pair mitigation |
| Deflect / reload | Deflect uses 35% translation; reload uses 85% (60% while aiming); no competing casts |
| Final Notice | Aim and prepared primary shot; X cancels; slow movement |
| Stagger / counter break | Brief explicit control restriction; no casts |
| Release | Clears at next physics update with no added timed stun |
| Dead | No gameplay intents until training reset/refill |

## Collision and combat assumptions

- All actor movement uses CharacterBody3D sweeps. Dash floor contact projects the existing velocity once into slide. Wall and ceiling hits cannot create a floor slide. Slide owns its tangent momentum so the floor solver's normal correction cannot create or destroy downhill momentum each tick.
- Third-person shots first resolve camera aim, then muzzle-to-target obstruction, including a shoulder-to-muzzle check for a barrel already inside cover.
- Friendly fire is off. Explosions do not damage their owner in this prototype. Bombs bounce only on environment geometry; detonation does radial falloff and line-of-sight checks.
- Executions inspect pre-shot HP and require shields already at zero. A shot that depletes shields is ordinary damage. Invulnerability rejects the hit. Pair damage mitigation also applies to Final Notice; it cannot bypass the protected sequence.
- Reflections transfer source/team and aim along the defender's aim; one reflection per Deflect cast per projectile, with two total reflections maximum to bound loops. Hitscan blocks without reflection. Melee and explosions bypass Deflect.
- Throws require facing, range, clear line, a validated full capsule trajectory and a supported landing. A mutual startup is a single counter break. Capture starts at the victim's real position, draws them to the hip, lifts and carries their capsule, then lands them to the attacker's forward right. Only the paired capsules ignore one another during the sequence; environment and other actors still collide. New obstacles abort at the last swept position. An interrupted lift retraces safe travel to separate the pair before restoring normal capsule collision.
- The actual AnimationPlayer library has separate reach, thrower, victim and melee clips with keyed torso, shoulder, elbow, hip, knee and weapon tracks. Physics supplies normalized progress, positioning and the single slam damage event. Keyframes cannot grant damage, mitigation or control. Impact timing stays aligned with the configurable slam point. The victim's keyed get-up completes inside the paired sequence, with no additional release stun.
- Stagger/capture cancels a live stance but does not delete already thrown bombs. Death, despawn and scenario reset remove owned bombs/projectiles. Reset releases both ends of any pair, clears effects and AI state, and restores selected scenario health/resources.
- Crossfire laboratory deliberately adds a **third team** probe that alternates aim between the two participants; ordinary enemy friendly-fire rejection remains intact.
- Bot corpses remain as non-colliding meshes, then respawn after 3.5 s. Player death waits for F5 or F6. AI freeze stops intent; opening the console pauses the simulation.
- Event records include physics tick, actor, ability, cast, hit type and applied damage. Recent 200 events can be exported to `user://combat_events.json`. Runtime state is never stored in shared tuning resources.

## Remaining design choices

All numerical balance, bullet guard reduction, future cancel windows, camera feel, team sizes, long-term ultimate economy, full bot navigation and multiplayer prediction remain open. A human playtest is required before accepting the movement presets or combat timings.

## CQ-FEEL-02 · User-directed revision

The user reported that melee and throws felt bad and requested forward-traveling melee, increased throw range and an actual throw animation. This establishes the new interaction direction, replacing the original in-place strike and simple paired tilts. The numbers above are the first proposed defaults for another feel pass. Melee damage, throw damage, guard rules and counterthrow are preserved.

## CQ-FEEL-03 · Longer engagement and guarding practice

The user requested more melee travel, a stationary bot that strikes at a specific range, and personal key bindings. Lunge travel increases from 2.2 to 3.6 m, with its duration extended from 0.28 to 0.34 s. A normal strike can finish an injured target initially 5.75 m away in the focused check; obstacles and frontal guard still stop travel.

The Guard trainer profile issues zero movement intent and requests a stationary version of the shared melee action. This suppresses that cast's lunge without modifying shared tuning resources. It strikes inside the smaller of its configured trigger range and actual melee hit reach. Default range is 2.4 m; interval 1.6 s; both are editable. Normal windup, hit deduplication, facing, line of sight, damage, guard and stagger all apply. The range ring and bot/HUD prompts expose the exercise rules. The dedicated start button resets the exercise and enables AI.

Saved bindings are now 3 dash; Q Hover; E Deflect; 1 bomb; 2 ultimate; Shift slide; 5 melee; 4 throw/counter; 6 guard. The old V/C/F/G/X/Ctrl combat bindings are removed. Runtime defaults and the persisted project map agree; ability cards, guard/counter prompts and preview labels derive their keys from the actual InputMap.

## CQ-FEEL-04 · Block impact, readable stagger and freer reloads

The user requested stronger successful-block feedback, a more obvious attacking-bot stagger, further melee travel and less reload slowdown. Melee now travels 4.8 m over 0.36 s; its 75 damage, reach and commitment timings stay the same. A focused physics check finishes a damaged target initially 7 m away. Reload retains 85% movement, with the ordinary aim cap still applying; this is exposed as `reload_move_multiplier` in live tuning.

The resolver emits `confirmed_block` only after a frontal melee block passes hit deduplication. The defender plays a dedicated original 0.36 s metallic clang on a separate sound channel, flashes its translucent shield, braces and spawns a 0.32 s world-space ring/spark burst. Guard hold, gunfire, rear hits and duplicate cast resolution cannot trigger success feedback. A meter-exhausting block still receives feedback. Transient presentation clears on reset/death; audio players explicitly stop and release their streams on exit.

The attacker uses an authored AnimationPlayer recoil with backward torso displacement/lean, outward arms, buckled knees and weapon knockback, plus rotating overhead daze markers and a STAGGERED label. Only the visual model recoils; the stationary trainer's collision capsule stays planted. Gameplay stagger remains 0.55 s. Shield opacity is reduced so the response remains visible from the shoulder camera. Presentation never applies damage or extends control locks.

## MOVE-03 · Mantle, wall jump and higher umbrella vault

The user requested these three traversal changes. Space keeps its ordinary jump and gains contextual mantle / airborne wall-kick behavior. Mantling takes priority when the requested movement or flat aim faces a reachable ledge. A low wall probe and top-down ray locate a walkable roof; five support rays and a standing-capsule overlap check reject narrow or blocked landings. The entire lift-then-over path is validated before commitment, and every actual move is swept. A new obstacle, removed support or combat interruption releases the actor safely. Physics controls position; a keyed two-arm pull-up poses the body and stows the rifle behind it. Camera freelook cannot redirect the path or facing.

Wall jumps use nearby environment walls, excluding actors and horizontal surfaces. They provide an explicit upward/outward kick and short authored leg pose. A 0.2 s cooldown and last-normal comparison prevent repeated kicks from the same flat wall; a wall facing at least 60 degrees differently can rearm, allowing alternating jumps. Real grounded support rearms the jump. `is_on_floor()` is confirmed with a short downward body sweep because teleports and mantle's `move_and_collide` can otherwise leave its old cached result. Coyote time still applies to ordinary departures from a floor.

Nimbus's ascent changes from 8.5 m/s × 0.3 s to 12 m/s × 0.4 s. Remaining upward velocity naturally decays into the existing glide; the measured rendered height near its apex is 8.17 m. Duration, cooldown lifecycle, ceiling handling and other kit values remain intact. Mantling out of the ascent ends Hover and starts its normal cooldown. A marked 2 m ledge and 5.5 m kick wall sit beside the existing east-side tower route, with Space/Q instructions in its HUD.

## MOVE-04 · Held mantle and carried wall-kick momentum

The user requested automatic ledge catches while holding Space and moving into a ledge, plus wall kicks that retain the incoming direction of travel. `CombatIntent.jump_held` now carries the sustained action independently of the existing press edge. The motor keeps checking ledges while held movement points into one, including after the initial jump buffer expires and through successive climbs. No movement or movement away from the ledge cannot trigger the held path. A deliberate nearby press remains supported. Ordinary jumps and wall kicks still require the press/buffer, so holding Space does not create repeated jumps or involuntary kicks. Existing action restrictions, clearance checks, fixed climb path and interruption rules still apply.

Wall kicks project actual horizontal velocity onto the wall tangent, retain that component, and replace inward motion with the outward kick. Stronger existing outward and upward speeds are retained; the ordinary combined speed cap still applies. The previous fixed 2 m/s tangent contribution from movement intent is removed. For a left wall and 6 m/s forward motion, the kick gives 7.5 m/s rightward plus the same 6 m/s forward travel before ordinary subsequent air steering. Facing or releasing movement cannot overwrite that travel. The HUD and marked practice ledge explain holding for mantle versus pressing for wall kicks.

## MOVE-05 · Faster mantle with a moving exit

The user requested faster mantling and preserved momentum into running or jumping. Default climb duration is reduced from 0.55 to 0.32 s. The entry horizontal velocity is stored before scripted traversal takes over, then restored on successful completion. Its direction is preserved through camera turns and its speed is not reduced to the run-speed preset; ordinary steering/braking resumes afterward. Continuing movement in the approach direction can build a slow entry up to running speed during the climb, so a wall contact does not force another acceleration from rest at the top. Without movement input, a stationary entry produces no artificial boost. The exit is moved with `move_and_slide` in the completion tick, so grounded movement resumes immediately and nearby obstacles still block it. The global speed limit applies at capture and handoff.

Fresh jump presses continue to update the existing 0.12 s buffer during a committed mantle. A valid buffered press launches at the checked landing on the completion tick, with the carried horizontal speed and ordinary jump impulse. Holding Space for automatic ledge catches does not create a rooftop jump. Early presses expire; a press immediately after completion can jump without a separate settling frame. Interrupted climbs, reset and stagger discard the stored exit velocity.

## MAP-01 · Meridian Gardens

The approved city is a separate scene/session with a data resource for spawns, hill, pickups, districts and navigation. Training retains its own manager and scenarios. Both sessions use the existing actor, motor, Nimbus kit, close combat, resolver and camera; `game_session` supplies the shared UI/input context. City bots request normal shared combat intents and finite resources. Tactical decisions run at staggered 5 Hz, navigation retargets at no more than 2 Hz, and physical steering remains at 60 Hz.

The 144×132 m district has real segmented ground openings to a −5 m subway loop. Smooth collision ramps under visible stairs connect 2/4/6.5 m tactical heights. Decorative railings, buildings and cover are included only where needed in collision/nav baking. The match waits for a complete, registered navigation mesh, and clears setup-time ultimate charge when it becomes ready. Team gates use separate physics layers; room protection is queried from current positions in the resolver and close-combat acquisition, covering both outgoing and incoming attacks. Safe-room roofs are solid against umbrella vault entry.

The objective owns pure height-aware capture/scoring rules. Six 75 HP/10 s small pickups and two 400 HP/15 s large pickups share availability between teams, clamp to missing health and never replenish other resources. Respawn retains earned ultimate; round restart restores every actor and pickup, clears transient attacks, resets ownership/scores and starts ultimate at zero. Exploration restores a dead player before pausing respawn clocks.

Forward+ renders the batched original kit, storm-blue sky, magical rail arches, turning orrery and scenic trains. Static indirect lamp illumination uses a deterministic three-height world-space irradiance bake, not LightmapGI. The sun owns combat shadows; local mist, restrained glow, masonry variation and wet paving provide atmosphere. Original synthesized wind/transit ambience is separate from distance-attenuated combat cues. Apartment interiors remain limited, trains scenic and multiplayer deferred.

## MAP-02 · Physical architecture and underground shopping

Substantial architectural slabs now create collision by default; structural arches, closed gables, vaulted roofs, balcony rails, large storefront panes and street trunks/stems are physical. Paint, tiny trim, foliage and magic remain presentation detail over supporting collision. Custom closed meshes receive the same static illumination as batched boxes. Moving train geometry updates on physics ticks. The conservatory canopy follows its supporting ribs; railway spandrels carry the track onto the arches, and raised walkways/study floors have visible supports.

Lower Meridian Exchange occupies the 42 × 42 m room beneath the park at −5 m, with six shops connecting gallery and perimeter aisles. A structural drum beneath the orrery, tall kiosk backs and low counters give different cover choices. It keeps four street stairs, two protected station connections and the existing two 75 HP caches, with no direct access or capture onto the hill. Subway bot assignments cross the central gallery rather than bypassing it. The map definition stores its bounds and shop centres; the M atlas selects the underground layer below ground, and B switches layers.

Stair geometry renders the same complete volume used for collision. The inner flights terminate at square, level landings instead of overlapping a promenade side below deck height, and they stop short of the open subway trenches. Progress recovery measures net displacement from a stable anchor, including empty steering results, so crowd oscillation cannot indefinitely suppress a navigation detour. It preserves ordinary finite resources, shared movement and the 5 Hz / 2 Hz scheduling limits.

## MAP-03 · Open point and fast Exchange rotations

Remove the conservatory glass canopy and its overhead ribs to expose the hill to the accessible 6.5 m promenades. Lower a four-metre firing section of each inner promenade railing to 0.45 m so standing shots clear it. Preserve perimeter arches, the orrery and existing cover so high-ground pressure still has counters. Add two mirrored 5.6 m wide, 14 m long stairs from the underground gallery to the north/south hill approaches. Segment both ground and mall ceiling at the actual openings. Thin stair slabs keep the existing station passages usable beneath the upper flights; shorten their ceilings and split crossing beams for head clearance. Retain four corner street stairs, two station connections, all shops and health caches. Subway bot routes exit through the opposite hill stair; the atlas marks both openings. Capture remains restricted to the original street-level rectangle.

The physical acceptance test covers ascent/descent of both new flights, station passage beneath them, open sky, and promenade-to-point fire lanes alongside existing mall and stair routes. Competitive fight frequency and team coordination require human playtesting.


## ROSTER-02 - User-directed main tank and main support

October 17, 2026. The user requested two new characters, separate from Annex/Ahab: a male arcane team leader with a magnificent moustache and large held shield, and a prim Edwardian female doctor with an accessible beam-healing role. The revised approved plan establishes a heavy short-range tank gun, 8 x 4.5 m / 1,200-durability barrier, enemy-launching advance, progressing 3D explosion line and 10 m slam. The doctor uses right-hold healing and left-hold shooting, lingering care plus team pulse, 4 s ally escape, cleanse plus brief heavy resistance, and an independent single-target damage/speed/resistance ultimate. Names and all tuning remain proposed defaults. Full behavior, integration and validation commands are in MARSHAL_DOCTOR.md.

## ROSTER-03 · Huddle colony off-tank

Implemented October 17, 2026 from the accepted revised kit: 600 health without personal shield HP; RMB Regroup healing; two 10 m Scatterbound charges with sequential five-second recharge; a short-lived ally/self screen; radial wingbeat; and Nobody Gets Squished!, a steerable ground-following wave. No resistance aura or ultimate flight refill. The shared barrier interface supports Marshal and Huddle; healing can opt out of charge awards. Full rules and controls are in [HUDDLE.md](HUDDLE.md).

Teams now use Marshal/Huddle/Doctor/Nimbus/Slayer/Slayer. Keep a Nimbus subway runner when possible, with a Slayer fallback when Nimbus is the player. Huddle uses the existing actor, traversal and combat authority; scattering and transforming preserve its single hitbox and health pool.

## ROSTER-04 · Relay, Dynamo and Wisp

Implemented October 17, 2026 from the accepted three-hero plan and increased ability values. Relay is a 250-HP offensive engineer with an indestructible battery-managed drone, 6 m shock and 80 HP/s team overclock. Dynamo is a 650-HP minigun tank with chain lightning, physical segmented walls, a 28 m / 4 m magnetic pull and a 35 m / 40-per-tick storm. Wisp is a 225-HP aerial burst DPS with source-specific soul marks, dash-loaded shotgun shells, phase, lift/glide and a four-second barrage ultimate.

This supersedes ROSTER-03's fixed team composition. New matches select seeded 2 tank / 2 support / 2 DPS teams from all eight heroes and include the selected player. A DPS covers the subway; a second DPS or mobile tank/support retains the high-ground route. Existing bots and progress remain intact during mid-match hero changes; restarting a round refreshes composition.

Keep physical cover separate from the friendly-pass-through analytic shield contract. All weapon families, melee and explosions can damage hostile wall sections; cover is sampled before section destruction. Bounded pull displacement uses collision and grants no stun. Active new ultimates cannot charge themselves; delayed ultimate casts retain this restriction after expiry. Per-life cleanup stops old effect physics before deferred deletion.

See [complete kits and validation](RELAY_DYNAMO_WISP.md) and [recorded results](validation/roster-results.json). Remaining reserved concepts and multiplayer remain deferred.


## MOVE-05 · Shared movement overhaul · October 19, 2026

Supersedes the movement tuning and wall-kick direction in MOVE-04. All eight heroes use two shared dash charges, sequential 4.3 s recharge, 20 m/s initial dash speed and WASD direction sampled after buildup. Air W/S follows camera pitch; A/D strafes horizontally; no movement falls back to aim. Ground dashes remain horizontal. Direction stays fixed during the burst. Dash slide conversion needs an airborne start and fresh crouch within 0.12 s before downward floor impact. Releasing/repressing crouch cannot turn residual dash speed into an ordinary slide; independent running/downhill slides remain.

Slide friction is 4.0. A fresh crouch during the last 0.15 s of mantle or the first 0.2 s afterward launches a forward mantle slide at the greater of 8 m/s or carried forward speed; buffered exit jumps win. Mantle reach is 1.15 m, maximum rise 2.35 m, approach tolerance 60 degrees, with ±0.2 m side probes. Full standing clearance, supported landing and continuous capsule collision checks remain authoritative.

Wall jumps follow facing while preserving at least 3 m/s outward clearance and at least 9 m/s horizontal launch before the combined speed cap. Shared air steering falls 25%, including Wisp's override (12 to 9). Gravity and ordinary jump impulse are unchanged. Melee retains 6 m travel and existing action timing, allows 3D aim until lunge begins after 0.06 s, and commits thereafter. Airborne melee suspends falling for 0.25 s; grounded movement remains horizontal. Stationary training melee has neither lunge nor suspension.

`tests/movement_overhaul_test.gd` covers charge lifecycle, roster tuning, directional dashes, slide gating and distance, real mantle slide handoff, jump priority, forgiving acquisition with clearance, wall constraints, airborne melee and pause. Existing traversal, close-combat, hero and map suites remain part of `tools/verify.ps1`.

## STITCH-01 · Doll assassin

October 19, 2026. Implemented the accepted revised Stitch plan: 225 HP; 18-damage needles every 0.15 s out to 45 m; source-owned stacks consumed by shears; visible movement-only Red Thread leash; 20-second Play Dead with a 12-second cooldown starting on exit; 13-second Spoolstep cooldown on launch; and a telegraphed seam ultimate with marked-target execution at 25% pre-hit HP. No blindness. Preserve standard controls and existing movement/combat outside explicit ability interactions. Reuse shared damage, benefits, per-life cleanup and tactical perception. See [Stitch](STITCH.md) for rules, validation and limitations.

## WISP-REWORK · Phantom thief

October 19, 2026: targeted rework preserves Wisp's ID, bindings, primary mechanics, source-specific marks, dash-loaded shells and roster. Primary becomes 13 damage; wider 8-pellet burst gains bounded core assistance and distance falloff. Q gains 0.15 s damage immunity and a cosmetic afterimage. E becomes 1 s horizontal Vanishing hover with second-press cancellation and 0.20 s vulnerable recovery. Both immunity windows block outgoing damage and objective contribution.

The subsequent accepted revision explicitly replaces Spectral Lift with forward/up Majestic Leap, hold-Jump float and second-press non-damaging dive, allowing fire throughout. It also explicitly replaces Death Ballet with the thrown, telegraphed Grand Heist calling-card blast. See [full tuning and verification](WISP_REWORK.md).

## ROGUE-02 · Height, dodge, explosions and suction

The follow-up renames Wisp to Rogue in presentation while retaining the internal ID and bindings. Majestic Leap rises at 18 rather than 12 m/s; measured apex more than doubles at 30/60/144 Hz. Q becomes a 2.5 m / 12.5 m/s dodge with a 2 m/s exit cap, preserving charges, loading, collision and bounded immunity. Right-click becomes one 32 m / 3 m-radius explosion with 80 base damage, radial falloff and owned mark detonation. Grand Heist grows to 6 m and 220 base damage, with a strong horizontal suction during its final 0.25 s. Full values, compatibility and evidence are in [Rogue rework](ROGUE_REWORK.md).
