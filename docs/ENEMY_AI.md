# Bot AI: play like a person

City, Museum and Sakura Veil bots (enemies and allies) share one pipeline. They see, aim, move and decide under the same rules as the player: identical health, damage, cooldowns, movement and inputs. Nothing reads hidden information, and nothing teleports. This document describes the overhaul delivered in October 2026 and how to inspect, tune and verify it.

## What changed, in one table

| Area | Before | Now |
|---|---|---|
| Vision | 360° line of sight | Focused cone plus a peripheral band that only notices motion or gunfire after a delay; nothing behind is seen |
| Hearing | none | Gunfire, impacts and movement tech produce fuzzed sound cues; bots turn toward unseen attackers |
| Memory | 4 s snapshot | 8 s, with dead-reckoned prediction and growing uncertainty |
| Aim | slerp plus noise | Delayed pursuit (strafe reversals open real miss windows), ballistic flicks that over/undershoot, then a settle |
| Routes | walk only | Baked traversal links: drops, railing hops, mantles, jump-mantles and wall-kick climbs, each dry-run on the real motor |
| Positioning | goal ±2 m | Environment query over ~16 navmesh candidates: range band, sight/cover (peek and hide), height, danger, spacing, objective leash |
| Movement | hold and ±1 m strafe | Irregular ADAD, counter-strafes, crouch-jiggles, jump-strafes, dodges of seen tells and projectiles, purposeful dashes, slides, the air dash-slide, bunny hops with air strafing, slope slides and jump pads |
| Team | fixed per-slot roles | Fight odds, orders (push, hold, cleanup, group up, fall back), focus calls, mobility-based flankers, ult economy |
| Character | identical bots | Eight personalities, confidence and tilt, skill-scaled indecision, team callouts |
| Tuning | hand-set constants | Team weights evolved by self-play under a human-likeness penalty |

## Architecture

```
TeamDirector (2.5 Hz)      fight odds, orders, gather point, focus, flank roster, ult economy,
                           danger map, shared sightings, callouts
BotBrain (5 Hz)            goal utilities x personality x mood x team order -> softmax pick
  BotPerception            cone + peripheral sight, BotHearing cues, felt hits, memory/prediction
  TacticalQuery            where to stand
  BotCombat                per-hero ability scorers (unchanged), ult gate
  BotPersonality           traits; mood lives on the brain
Every physics tick
  BotAim                   human motor model for the crosshair
  BotLocomotion            strafing, dodges, dashes, slides, flair
  TraversalLinks.drive     executes a baked link with ordinary inputs
Map adapters               City / Museum / Temple controllers supply authored routes and objectives
```

All of this lives in `scripts/bots/`. Tunable data lives in `resources/bots/`: `skills/` (difficulty), `heroes/` (range, aggression, mobility), `classes/`, `personalities/` and `tuning/`.

## Senses (`bot_perception.gd`, `bot_hearing.gd`)

- **Focused cone** (half-angle 42 / 50 / 55 / 60° from Beginner to Expert). Targets inside are seen through ordinary line-of-sight rays, using the existing ray budget and round-robin.
- **Peripheral band** (85 to 110°). Only an enemy that is moving (over 2.5 m/s) or has just fired gets noticed, and only after `peripheral_delay` (0.6 to 0.18 s). Enemies within 2.5 m are always felt.
- **Hearing.** `BotHearing` is one hub per resolver. It records attack casts (~38 m), impacts (~20 m) and dashes, slides, wall kicks and mantles (9 to 16 m).
  - Listeners get a position fuzzed by distance and never a live reference, so a heard enemy can't be shot.
  - Sounds from a concealed Stitch who can't be detected are ignored.
- **Felt hits.** Each impact records where it came from. The victim's attention snaps to that direction for about 1.2 s.
- **Memory.** Observations last 8 s.
  - `BotPerception.predicted()` dead-reckons the last seen velocity (capped at 1.2 s), and `uncertainty()` grows by 4 m/s.
  - Radio reports from teammates keep their original timestamps.
- **Attention.** When nothing is in the crosshair, bots look at the most salient cue: a hit, then a sound, then a predicted position.
  - At a skill-dependent interval they glance to check a flank, preferring directions where teammates last called enemies out.
  - Beginners never glance (tunnel vision).

## Aim (`bot_aim.gd`)

1. **Delayed pursuit.** The bot sees the target as it was `pursuit_lag` ago (0.32 to 0.10 s) and extrapolates that motion. Steady movement is tracked well; a direction change is only noticed after the lag. That makes ADAD effective against bots, as it is against people.
2. **Flicks.** Corrections over ~9° are planned as one ballistic move that lands with a skill-scaled over/undershoot (`flick_error`), followed by a slower settle (`correction_time`).
3. **Pressure.** Aim worsens when the bot is hit, airborne, sprinting or below 30% health, and improves slightly when standing still.
4. **Reaction time.** Sampled per sighting (log-normal around `acquisition_delay`, bounded to 0.7–1.5×). Bots fire once the crosshair is within `fire_tolerance` (6.5 to 2.8°).

Measured against a synthetic ADAD strafer at 15 m, the time on target is: Beginner 11%, Normal 55%, Hard 64%, Expert 78% (`tests/bot_aim_test.gd`).

## Traversal links (`traversal_links.gd`)

After the navmesh bakes, the boundary is sampled every 2 m and candidate stunts are probed against real collision:

| Link | Rule |
|---|---|
| `drop` | Ledge drops of 0.6 to 6.5 m |
| `hop_drop` | Railing in the way at knee height, clear at head height |
| `mantle` | Vertical face up to about 3.6 m (standing mantle 2.35 m, jump then mantle above that) |
| `gap` | Same-height gaps within jump distance at the slowest running speed |
| `wall_climb` | Continuous wall faces above mantle reach, up to 5.8 m: jump at the wall, kick off it near the apex (head-on kicks go up and back), immediately air-dash toward the wall at the 30° upward cap, then hold jump into the ledge to mantle |

How links are kept honest:
- **Must beat walking.** A link is registered only when the walking route is at least 2.5× the direct distance (or 6 m longer).
- **Dry run.** Every non-drop stunt is tried at bake time by a hidden probe hero on the real motor, using the slowest roster speed and the same `TraversalLinks.drive` routine live bots use. On City this rejects about 60 mantles that look possible but are not. Gap candidates on the temple currently all fail the dry run, so none ship.
- **Async and cached.** The bake runs in the background with a 4 ms per-frame budget (about 9.5 s on City, bots walk meanwhile). Results are cached in `user://bot_links/` by navmesh hash, so later loads are instant.
- **Dash-gated.** Wall climbs spend a dash charge, so they sit on their own navigation layer and a bot only plans through them while it holds a charge. Losing the charge mid-stunt is an abort, not a link failure.
- **Self-healing.** Each link records uses and failures; after three consecutive failures it is disabled. Bots that keep bumping a low lip hop it ("obstacle hop").

Typical counts: City about 630 links (about 90 wall climbs), Museum about 300 (about 60), Temple about 620 (about 95).

## Positioning (`tactical_query.gd`)

The plan depends on the goal:

| Goal | Where candidates are sampled |
|---|---|
| Fight | On a ring around the enemy at the hero's range band |
| Contest / hold | Around the objective (fight from the point, not from max range) |
| Cover | Close by, when reloading, low on ammo, or hurt and recently hit |
| Support | Around the patient, with sight of them |
| Protect | Between the patient and the threat |
| Investigate | Around the predicted enemy position |
| Retreat | Toward allies |
| Gather | Around the team rally point |

Away from the objective, authored waypoints are kept exactly.

Each candidate is scored on:
- range fit
- sight of the target (wanted when fighting, avoided when hiding), which produces natural peek/reload cycles
- exposure to other visible enemies
- height for ranged heroes
- the team danger map
- spacing from allies
- the objective bonus and leash
- reservations
- travel cost and hysteresis

The danger map is a 4 m grid rebuilt from shared sightings (range and facing) and teammate deaths in the last 15 s.

## Locomotion (`bot_locomotion.gd`)

**Strafing.** ADAD with a 0.22–0.7 s rhythm, scaled by consistency and never periodic. It is mixed with counter-strafe stops, crouch-jiggles (Normal+) and jump-strafes (Hard+). While moving, strafing becomes a weave, and every lateral step is ledge-checked.

**Dodges.** Telegraphed attacks (melee windup, Slayer axe, ultimates, March, Wave, Heist) and projectiles flying at the bot inside its field of view trigger a sidestep after reaction time:
- a dash, unless that would spend the escape reserve
- otherwise a jump

Success scales with consistency: in the test, Experts dodged 9 of 12 telegraphs and Beginners 6. Projectiles from behind are never dodged.

**Dashes.** Dashes follow the movement direction, not the aim, which fixes a gate that made bots almost never dash. Reasons:
- escape (followed by a dash-slide)
- closing in when committing
- reaching cover after being hit
- the occasional rotation dash

**Air dash-slide.** On rotations, skilled bots chain the advanced slide tech:
1. Jump.
2. Near the apex, dash downward, holding a 35° downward aim through the 0.16 s windup (the motor locks the dash direction at its end).
3. Freshly press crouch from the predicted impact time, so the press lands inside the motor's 0.12 s `dash_slide_window`.
4. Ride the slide out at about 14 m/s, against 6 m/s running.

Normal difficulty and up use it, high-flair personalities more often. The landing zone is ledge-checked, and the move is abandoned if a fight appears.

**Slope slides.** When the route runs down a slope steeper than the motor's `slide_slope` (8°, plus 1° margin) and the bot is already near running speed, it drops into a slide. Gravity outpaces slide friction, so the bot speeds up (10.7 m/s down a 15° test ramp). It releases when the slope ends, the route turns or the slide dies. On a downhill this takes priority over rotation dash tricks.

**Jump pads.** Sakura Veil's wind lifts are used in two ways:
- **Shortcuts toward the goal.** Temple routes go waypoint to waypoint, so the controller picks pads against the goal. Flankers and mobile heroes take any pad heading the right way; everyone else takes one that lands at least 20 m closer to the goal.
- **Navigation links.** Pads are also registered as links (`TraversalLinks.register_pads`), so any long off-route trip, such as regrouping, plans through them.

In a 3-minute temple match bots launch about 13 times. The bot steers its flight toward the landing and keeps fighting in the air.

**Bunny hop and air strafe.** On long open rotations, bots chain bunny hops. Normal difficulty and up do it, more often at higher skill and flair.
- They re-jump inside the motor's 0.12 s jump buffer before touchdown, so ground friction barely applies.
- In the air they angle their move direction just past the `air_wish_cap` projection angle (about 70° from velocity at 6 m/s, 80° at 12 m/s), on the side of the route. When the route is straight ahead they zigzag.
- That harvests the motor's 0.75 m/s-per-second air gain up to 12 m/s: 11 hops build from 6 to about 10.6 m/s in the test.
- Hard+ bots slide-hop straight out of an air dash-slide to keep its speed.
- Chains end near the destination, at ledges or walls along the velocity, or when a fight starts.

**Flair.** Occasional travel hops, scaled by hero mobility and personality.

## Team brain (`team_director.gd`)

- **Fight odds.** A Lanchester-style estimate (total health × total damage) of teammates against shared sightings near the objective. Enemies known to be alive but unseen count partially.
- **Orders.**

  | Order | When |
  |---|---|
  | `push` | Default |
  | `hold` | Objective secured |
  | `cleanup` | Odds over 0.72 and ahead on numbers |
  | `fall_back` | Outnumbered by `regroup_margin`, or odds under 0.26 |
  | `group_up` | Rally until `push_fraction` of the team has gathered |

  Orders hold for at least 2 s. A `desperate` flag (enemy at 80% score in City, overtime in Museum and Temple) forces a push. A human teammate standing on the objective pulls the bots in unless the fight is hopeless.
- **Gather point.** A spot between the team's spawns and the objective, used for regrouping. After regrouping, bots rejoin their authored route at the nearest waypoint ahead.
- **Focus.** The team names a shared target (low health, supports, channelers, isolated enemies). Target choice gets a bonus scaled by coordination.
- **Flankers.** Chosen by hero mobility, aggression, personality and health, and kept for 10 s or more. That means one flanker, or two in a full-strength push. Museum and Temple flank routes use this roster instead of slot numbers; Temple flankers split upper and lower.
- **Ult economy.** Ultimates are held when the fight is already won or the team is regrouping. Following a nearby teammate's ultimate within 2.5 s gets a bonus, which produces combos.
- **Health packs.** The threshold rises without a healer nearby or outside combat, falls for a lone defender on a hot point, and shifts with personality.

## Personalities and mood (`bot_personality.gd`)

The eight archetypes in `resources/bots/personalities/` are hothead, anchor, lurker, guardian, showoff, turtle, shotcaller and wildcard.

- **Traits.** Each bot rolls a seeded archetype plus ±0.1 jitter:
  - aggression, caution, teamplay, flank, patience: shift goal scores, flank selection and order-following
  - flair: strafe tricks and hops
  - chattiness: how often the bot talks
  - tilt-proneness: how much repeated deaths rattle it
- **Confidence** rises with kills and assists, falls with deaths, and decays over about 45 s. Confident bots are bolder.
- **Tilt** builds when the same enemy kills the bot repeatedly. It adds revenge targeting and recklessness, and is capped by difficulty: Beginner 1.0, Normal 0.6, Hard 0.35, Expert 0.2.
- **Indecision.** Near-equal goals (within 0.2) are chosen by a softmax with temperature `decision_noise` (0.10 to 0.015, plus tilt). Beginners waver between close options; the best option still usually wins.

## Team callouts (`team_comms.gd`)

Bots announce orders, focus targets, flank intent, "ult ready" and "need healing", flankers spotted behind the team, and kill or tilt lines. Callouts are limited to one every 1.8 s per team with a per-kind cooldown, and each bot has a distinct name.

The player's team appears on the left of the HUD. Press **V** to ping for help: a support acknowledges ("On my way!") and prioritises you for 5 s. Enemy chatter never reaches the screen.

## Difficulty knobs (`resources/bots/skills/*.tres`)

| | Beginner | Normal | Hard | Expert |
|---|---|---|---|---|
| Acquisition delay (s) | 0.60 | 0.38 | 0.26 | 0.18 |
| View cone / peripheral (°) | 42 / 85 | 50 / 100 | 55 / 105 | 60 / 110 |
| Peripheral delay (s) | 0.60 | 0.35 | 0.25 | 0.18 |
| Hearing scale | 0.6 | 0.85 | 1.0 | 1.15 |
| Flank glance interval (s) | never | 5 | 3.5 | 2.4 |
| Pursuit lag (s) | 0.32 | 0.20 | 0.15 | 0.10 |
| Flick error | 0.30 | 0.18 | 0.12 | 0.07 |
| Fire tolerance (°) | 6.5 | 5.0 | 3.8 | 2.8 |
| Decision noise | 0.10 | 0.06 | 0.035 | 0.015 |
| Tilt cap | 1.0 | 0.6 | 0.35 | 0.2 |

## Self-play tuning (`bot_tuning.gd`, `tools/tune_bots.py`)

`BotTuning` holds team-wide weights:
- objective, danger, sight and cover weights
- aggression and retreat biases
- regroup margin and push fraction
- weave, strafe tempo and dodge eagerness

Each `TeamDirector` carries one, so two weight sets can play each other.

`tools/tune_bots.py` runs a (1+λ) evolution strategy. Mutants play the champion in headless City matches on several seeds, both sides. Fitness is objective score, round wins and kill share, **minus a human-likeness penalty**:
- standing still more than 22% of fight time
- fewer than 4 movement-tech uses per bot-minute
- deaths per bot-minute outside 0.25–1.0
- more than 20% of deaths with no teammate nearby

Without the penalty the search drifts toward campers or kamikazes. The champion is written to `resources/bots/tuning/default.tres` and the run is recorded in `docs/validation/bot-tuning.json`.

```bash
tools/tune_bots.py --generations 6 --mutants 4 --seconds 150 --seeds 76,971
```

**Status:** the tuning pipeline is complete and smoke-tested, but a full evolution run has been deferred. `resources/bots/tuning/default.tres` currently ships the hand-set values, which are the `BotTuning` defaults. A full run (6 generations × 4 mutants × 2 seeds × both sides at 150 s) takes about 2 hours on a 4-core machine and resumes from `artifacts/tuning/state.json` if stopped. Review the resulting `docs/validation/bot-tuning.json` before committing the new `default.tres`.

## Inspect

- **F3** shows the diagnostics panel; **[ / ]** select a bot. The panel adds:
  - persona and mood
  - senses (cone, sounds heard, peripheral pickups)
  - query mode and candidate count
  - movement counters
  - team order, odds, focus and flankers
  - the last callouts
  - link state
- The 3D overlay draws:
  - the view cone (focused and peripheral)
  - query candidates coloured by score
  - remembered enemies with uncertainty rings
  - the gather point
  - the active link
- **Settings → Export Bot Diagnostics** writes `user://bot_metrics.json`. Each bot's `metrics.human` holds alive and combat time, idle-in-combat ratio, mean speed, movement events, tech and jumps per minute, engagements, outnumbered engagements and deaths alone.

## Verify

```bash
tools/verify.sh               # bot suites (Linux, headless): tactics, integration, senses, aim,
                              # positioning, locomotion, team, personality, traversal links
tools/verify.sh --full        # plus city/museum/temple integration, navigation, traversal, roster soak
tools/bench_bots.sh LABEL 180 76 971 2024   # headless behaviour benchmark, all maps
tools/bench_table.py baseline LABEL         # compare with docs/validation/bot-overhaul-baseline.json runs
```

`tools/verify.ps1` remains the Windows entry point for the whole project.

## Results

The headless behaviour benchmark runs every slot as a bot at Normal difficulty. The baseline is the pre-overhaul AI (3 seeds × 300 s, `docs/validation/bot-overhaul-baseline.json`); the final run uses seeds 76 and 971 at 180 s (`docs/validation/bot-overhaul-final.json`). Rates are normalised per minute.

| Metric | City before → after | Museum before → after | Temple before → after |
|---|---|---|---|
| Movement tech per bot-minute | 0.2 → 9.4 | 0.4 → 11.2 | 0.0 → 10.7 |
| Jumps per bot-minute | 0.1 → 5.6 | 0.2 → 7.6 | 0.7 → 8.5 |
| Standing still in fights | 18% → 16% | 22% → 20% | 33% → 20% |
| Time in combat | 59% → 58% | 53% → 63% | 7% → 28% |
| Time on the objective | 21% → 26% | 44% → 54% | 1% → 13% |
| Deaths with no teammate near | 9% → 8% | 8% → 4% | 81% → 61% |
| Mean speed (m/s) | 4.4 → 4.6 | 3.8 → 4.1 | 3.6 → 4.9 |
| Match deaths per minute | 11.5 → 4.8 | 11.8 → 5.5 | 1.4 → 3.0 |
| Stuck recoveries per minute | 2.1 → 3.8 | 16.4 → 9.7 | 69.5 → 9.3 |

Read with care:
- **Lethality** fell sharply. Moving targets plus human aim make fights longer, and teams back off and regroup instead of trading.
- **City stuck recoveries** rose slightly: bots now attempt parkour and hops that occasionally need a recovery. Museum and Temple fell a lot.
- **Temple deaths-alone** stays high because there are very few deaths (about 9 per match), mostly far-flung skirmishes.

Test coverage is 220 bot checks across 9 suites (`tools/verify.sh`), plus the existing city, museum and temple integration, navigation, traversal and pad suites.

## Limits and follow-ups

- **No human playtest yet.** Automated tests and benchmarks establish behaviour, not fun. Whether bots *feel* human, whether difficulty steps feel fair, and how readable callouts are all need playtesting. Use F3 to watch decisions.
- **Lethality dropped.** Strafing bots with human aim kill each other far less often than the old bots (see the deaths column). That is closer to human play than the old aimbot-ish trades, but the overall time-to-kill feel needs a playtest. The self-play bands target 0.25–1.0 deaths per bot-minute.
- **Temple pacing is a map issue.** The route chain A → B → C is about 300 m, so the first mid fight starts 80–90 s into a match. Bots now use pads, slides and hops to get there faster, but the map length dominates.
- **Gap jumps are rare.** Every temple gap candidate failed the motor dry run, so few or no gap links ship. The dry run is the arbiter: if a gap looks jumpable but has no link, the slowest hero cannot reliably make it.
- **No hero-specific mobility links.** Hero mobility (Rogue leap, Huddle flight, Stitch hook, Seeker spirit jump, Nimbus hover) is still used only through the existing ability scorers, not as route links.
- **Wall climbs fail more in combat.** In a 2 × 3-minute City sample, 3 live wall climbs succeeded and 3 failed, versus every one succeeding in an empty dry run. Each link disables itself after three consecutive failures.
- **Bake time on first load.** The first load of a map bakes links in the background (City about 10 s, Temple about 6 s) while bots walk normal routes; later loads use the on-disk cache.
