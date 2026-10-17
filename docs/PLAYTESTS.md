# Verification and playtest record

## Engine and build

2026-10-16 · Godot **4.7.2.stable.official.ed1daf0bf** · Windows · GodotPhysics3D at 60 Hz. Rendered review used the Compatibility OpenGL renderer on an NVIDIA RTX 3080 at 1440 × 900. No human keyboard/mouse game-feel acceptance has been performed.

## Performed verification

- Editor import and class registration completed. The final project parses and launches in the actual pinned engine.
- **79 focused checks, zero failures** in `tests/rules_test.gd`. These use real actors, capsule sweeps, ray queries and simulation time. Coverage includes 45 body / 90 head single-hit rifle damage; muzzle obstruction; ammo/cadence/reload; actor independence; Final Notice just below/at/above 20%, shields and invulnerability; frontal/rear guard; committed melee; throw interruption, whiff, counter and simultaneous requests; both participants' 90% mitigation; full scripted throw damage; release and death cleanup; Hover ascent/glide/ceiling; physical projectile reflection; 80-peak bomb and cover; ultimate charge consumption; ordinary slide, ground dash slide, vertical fixed dash, wall/ceiling collision, downhill acceleration, uphill slowdown and cooldown continuity; reset of persistent combat/motion states.
- **35 integration checks, zero failures** in `tests/integration_test.gd`. Coverage includes ordinary-rule scene launch, all core named actions, physical keyboard/mouse event bindings, actual camera pull-in/restoration around collision, six-shot target elimination and respawn, strafing, freeze, ranged projectile damage and sightline blocking, close bot melee, sparring guard and delayed counterthrow, pair/scenario reset, crossfire probe setup, paused console/resume, route timer and repeated reset cleanup.
- **30 additional close-combat checks, zero failures** in `tests/close_combat_test.gd`. Actual 4.8 m swept lunge travel, a finisher from 7 m, fixed direction, wall/guard stops, reset during travel, capture at 2.6 m, no initial pull teleport, locked pair facing, physical lift with keyed body flip, damage exactly once at slam, supported landing, standing recovery, capsule exception cleanup, low-ceiling rejection, new-obstacle interruption, and reset/separation at three throw phases.
- **38 guard-drill and binding checks** in `tests/guard_drill_test.gd`: all nine requested physical keys, no cross-triggered actions, removal of old bindings, live key captions, no attacks beyond range, guard/stagger, planted bot across repeated damaging attacks, adjustable range/ring, cover, reset, ordinary spawning and one-click recovery from AI freeze.
- **26 block-feedback and reload-mobility checks** in `tests/block_feedback_test.gd`: actual block event, hit deduplication, flash/effect/clang selection, overhead marks, full recoil pose, planted capsule, unchanged lock/recovery, effect expiry, finite unclipped decaying PCM, no success feedback for guard hold/bullets/rear melee, guard break, reset/death cleanup, 5.1 m/s reload, aiming cap, firing exclusion, refill/full-speed recovery and separate guard slowdown.
- **34 traversal checks** in `tests/traversal_test.gd`: ground and aerial mantle, 3.4 m tower via jump/mantle, Hover-to-mantle cooldown, continuous travel, action lock/resource isolation, fixed facing, pose recovery, distant/thin/blocked landing rejection, new obstacle and removed support, stagger/reset/death interruption, upward/outward wall kick and pose, same-wall rejection, alternating and angled walls, grounded rearm, no open-air double jump or actor-wall exploit, roughly 8 m umbrella apex, glide/cooldown and low-ceiling handling.
- **25 traversal-flow checks** in `tests/traversal_flow_test.gd`: physical Space hold/release, held approach and two successive ledges, single held jump-to-mantle, no grab while stationary/moving away/released, standing clearance, left/right diagonal movement, fast/forward/backward momentum, facing independence, inward replacement, stronger outward/upward speeds, combined speed cap, angled-wall projection and press-only kicks.
- **21 mantle-exit checks** in `tests/mantle_exit_test.gd`: faster duration, immediate grounded control, preserved running/diagonal/high-speed momentum, completion-tick displacement, continuous running, slow approach building to running speed, no held-input rooftop jump or stationary-entry boost, buffered and immediate post-climb jumps, early press expiry, speed cap, reset/stagger/obstacle cleanup and an obstacle beyond the landing. Total suite: **288 checks**.
- GPU-rendered arena and training-console images were captured and visually inspected. HUD text, ability rail, enemy labels, resource state and menu layout were reviewed. Lighting and anti-aliasing were adjusted after the first rendered review.
- Initial failures found and corrected: mutual grabs resolving as capture; low-speed slope slide ending before gravity could accelerate it; floor-normal bias opposing downhill motion; persistent audio generator references on shutdown. The final finite synth cues and test shutdowns produce no ObjectDB leak warnings.
- Verification runs keep generated user/editor data under `.tools/runtime`. A task-local editor save setting avoids this sandbox's Windows backup/rename error. The user's normal Godot editor settings are unchanged.

Machine-readable results and rendered PNGs are written to the ignored `artifacts/` directory. Event export through the console writes the latest 200 events to `user://combat_events.json`.

## Human acceptance still required

1. Play the east-side route through the gap, narrow platforms and finish deck; use ordinary slide, the west ramp downhill slide, dash-to-ground slide and Hover. Compare the responsive and weighty presets. Record time, falls, overshoots and landing accuracy.
2. Repeat while aiming at a moving target. Judge mouse sensitivity, shoulder placement, camera comfort near cover, landing readability and perceived weight independently of response time.
3. Fight ranged and sparring bots with debug overrides off. Demonstrate rifle, bomb, Hover, Deflect, melee, guard, throw and counter separately, then test the suggested combinations.
4. Use the console's 19/20/21% HP, shield and invulnerability controls to inspect Final Notice tells and outcomes. In the crossfire exercise, observe damage during both ends of the paired throw.
5. Die/reset interactively during reload, guard, capture, dash, slide, Hover, Deflect, bomb fuse and ultimate stance. Automated cleanup is covered; this pass checks presentation and input restoration.
6. Assess sound, startup/recovery tells, bot fairness and whether aerial firing dominates. Record concrete observations before changing balance.

## Known prototype limits

Original geometric characters and procedural poses stand in for authored animation and art. The slide keeps the standing collision capsule; low-clearance crouch traversal is not implemented. Bot navigation uses local obstacle rays, simple routes and stuck recovery; complex navigation and parkour remain deferred. Route overshoots are a rough floor-return metric, not an automatic judgment of player error. The stage has a safe continuous foundation beneath the route, so platform misses usually cost route time rather than lives. No networking, objective play, other heroes or final balance is claimed.

## Next experiment

**MOVE-FEEL-01** — Compare the two movement presets with the same route and ranged opponent. Record completion/landing metrics and player explanations. Hold kit values constant. Choose the next single adjustment from observed loss of control, missed readability or dominant aerial angles.

## CQ-FEEL-02 · Revision after user feedback

**Observed feedback supplied by the user:** throws and melee feel very bad. Requested forward melee travel to reward engages/finishers, greater throw reach and a real throw animation.

**Implemented:** 2.2 m committed lunge; startup/active/recovery 0.24/0.2/0.4 s; grab reach 1.8 → 2.8 m; paired duration 0.85 → 1.1 s. Articulated AnimationPlayer clips now pose both characters through reach, draw-in, hip lift, turn, slam and get-up. A shared physics path moves the victim and checks landing/clearance; damage triggers at 72% impact. Holding a camera direction cannot redirect either committed motion.

**Rendered verification:** inspected the actual engine's reach, draw-in, inverted lift, slam, get-up and release frames, plus the moving melee finisher. The rendered throw ended at 155 HP and returned both actors to ready; the melee preview finished a 50 HP target after 2.2 m of travel. Preview capture uses frozen AI and scripted input; it is a visual check, not a claim of human gameplay feel testing. A preview setup issue (detaching the bot controller while the training manager still expected it) was corrected by disabling the manager during capture.

**Next feel pass (updated controls):** use 5 from around 5 m against an injured moving target, then try a miss and a frontal guard. Use 4 from 2–2.8 m against a guarding bot, then test a counterthrow and nearby cover. Judge whether the commitment and slam read clearly in the normal shoulder camera before changing damage.

## CQ-FEEL-03 / TRAIN-GUARD · Further user request

Melee travel is now 3.6 m over 0.34 s, with damage and the startup/active/recovery commitment unchanged. Added Guard drill with a stationary bot that attacks only inside a 2.4 m visible ring at a default 1.6 s interval. It uses the shared melee resolver with travel disabled for that training cast. Input mappings and all live prompts follow the user's requested number/ability layout.

The rendered drill showed the new range ring, key labels and a blocked strike leaving Nimbus at 250 HP and the bot staggered. Keyboard events verified 3/Q/E/1/2/Shift/5/4/6 independently. These checks establish behavior and presentation; evaluation of the longer melee's feel remains a human playtest.

## CQ-FEEL-04 · Stronger blocks and longer melee

User requested impactful block sound/effects, obvious attacker stagger, still more melee travel and reduced reload slow. Implemented 4.8 m travel over 0.36 s, 85% reload movement, a dedicated clang and radial impact burst, defender brace, attacker recoil and rotating daze markers. Stagger remains 0.55 s and the trainer remains stationary.

Actual GPU captures `guard-impact.png` and `guard-block.png` were inspected in the normal shoulder camera. The first flash obscured the attacker; reduced shield opacity and wider rings/sparks corrected visibility. The bot's outstretched arms and overhead marks now show through and above the shield. A playback/stream shutdown warning was fixed by explicitly stopping audio and releasing streams on exit; the final verbose rendered capture exits without leak warnings.

The clang waveform was checked for duration, sample rate, amplitude, clipping and decay, and exported as `artifacts/guard-clang.wav` for listening. Rendered capture uses the Dummy audio driver; subjective sound quality and perceived impact still require listening during play. Next pass: block repeated strikes with 6, lunge with 5 from roughly 7 m against a damaged enemy, and strafe through a reload with R.

## MOVE-03 · Mantle, wall jump and vault height

User requested close-wall/tower mantling, wall jumps and increased umbrella-vault height. Implemented contextual Space actions and a stronger Q ascent with live tuning exports. The first focused pass exposed a one-frame pose-sampling issue in the test and stale grounded state after an aerial training teleport; the pose check now samples its visible kick and grounded rearming requires actual nearby support.

`tests/capture_traversal.gd` rendered the real arena in the normal shoulder camera. Inspected `mantle-pull.png`, `wall-jump.png` and `umbrella-vault.png`: two arms reach/pull with the rifle stowed, the character clears the lip and returns to standing, the wall jump has a visible split-leg pose, and the open umbrella carries Nimbus well above the towers. The captured mantle landed at (12, 2.00, 6.95), wall kick retained outward/upward velocity, and vault reached 8.17 m at the sampled frame. The run exited without errors or audio leak warnings. These scripted captures do not replace a human control/feel playtest.

## MOVE-04 · Automatic ledge catches and momentum-preserving kicks

User requested held-Space automatic mantling while moving into ledges and wall kicks that keep approach momentum. The flow suite passes both headless and under the real OpenGL renderer. Because the headless display cannot capture a mouse, its physical action state is checked directly; the rendered run verifies the actual captured PlayerController returns sustained `jump_held` after the edge expires and clears it on release.

The updated real-arena capture approached the practice ledge with `held=true`, `press=false`, entered the climb automatically and continued forward after landing. The left-wall kick capture reported velocity (7.0, 8.03, -6.0) after four subsequent air-steering frames: outward plus unchanged forward travel. The mantle and diagonal wall-kick screenshots were inspected, including revised hold/press HUD instructions. The run exits without errors or leak warnings. Human acceptance of traversal feel remains pending.

## MOVE-05 · Faster mantle and continuous running/jumping

User requested a quicker climb that preserves momentum into running or a jump. The default is now 0.32 s, down from 0.55 s. The captured 60 Hz climb finishes in 0.333 s and retains (0, 0, -6) m/s at the grounded handoff; a fresh buffered exit jump produces (0, 8, -6) m/s in its completion tick. Inspected the actual shoulder-camera `mantle-run.png` and `mantle-exit-jump.png` captures. The engine run exits without errors or leak warnings.

The existing repeated-ledges check now samples the second completed climb rather than waiting long enough for preserved momentum to run off its small test platform. The dynamic obstruction fixture is inserted earlier so the faster character has not already entered that space. Focused tests verify that interruptions discard stored velocity and restored movement still collides beyond the landing. Perceived flow and the new duration remain a human playtest judgment.

## MAP-01 · Meridian Gardens — 16 October 2026

The city launches as a separate offline 6v6 match while retaining the training scene. All 288 previous checks pass under Godot 4.7.2. City rules add 33 checks, full-city integration 70, physical traversal 17 and city/training transitions 32: **440 passing checks** in total. These include 400 HP capped tank healing, height-aware capture, ownership scoring/contest/decay, team gates and solid safe-room roofs, damage/throw protection, zero-charge start after asynchronous setup, eight-second respawns with ultimate retention, complete resets and reviving a dead player when entering exploration. Scene transitions while paused and before navigation setup completes release the old actors, resolver, pickups and collision geometry cleanly.

Actual baked navigation routes take 10.12–10.16 s for main approaches and 13.45–13.72 s for flanks at walking speed. Real capsule traversal reaches the terrace, wizard's study, promenade and subway without parkour, and returns from underground with camera clearance. A ramp/deck intersection lip, misplaced railing and planter-induced detours were corrected before acceptance.

Two full 600-second simulations pass 14 checks each. Seeds 76 and 971 respectively record 6/6 and 5/7 ownership changes, 235 and 286 contested seconds, 164 and 169 deaths, and 100 and 106 health collections. Both teams use the subway and physically reach the covered 6.5 m deck. Neither run records persistent eight-second stalls, falls or teleport recovery. Strategy/path frequency limits also pass. The player slot uses the ordinary AI controller for unattended simulation.

Inspected all nine final in-engine captures, including the overhead layout, resource atlas, underground view and live shoulder-camera fight. Clean capture exits without errors or leak warnings. The rendered RTX 3080 benchmark at 1920×1080 averages 136.5 FPS (p95 8.98 ms, p99 9.34 ms), using real elapsed time and twelve live combatants with benchmark-only enlarged health pools. Human competitive balance and movement comfort remain playtest judgments. Gallery, raw metrics and reproduction commands are in `docs/MERIDIAN_GARDENS.md`.

## MAP-02 · Structural audit and Lower Meridian Exchange — 16 October 2026

Rebuilt the area under the point as a finished 42 × 42 m shopping concourse with six through-shops, two perimeter aisles, central drum and kiosk cover, sheltered existing health caches, four street stairs and two station connections. Repaired open/unsupported roofs, missing balcony and storefront collision, railway spandrels, stair undersides and level promenade landings. A newly solid apartment cornice exposed a narrow navigation pinch; moving the spawn-side building footprints leaves approximately five metres of alley clearance. Trees no longer intersect the inner stairs.

The full verification command now passes **530 checks**: the original 440, 84 arcade/traversal checks and six bot-recovery checks. Independent physics rays sample **1,358 exposed structural faces with zero missing contacts**. Real Nimbus capsule walks traverse all six shops, every concourse exit and both inner stairs uphill and downhill. Actual roof drops land on the conservatory, apartment and garden pavilion. Cover tests distinguish low counters from full-height kiosk walls; camera and atlas-layer checks also pass.

Long simulations found a recovery case where a bot seeking health oscillated near an approach without making useful progress. The watchdog now includes zero-steering failures and measures net movement from a stable anchor before choosing a short navigation detour. It does not teleport or increase tactical/path frequency limits. The focused regression verifies stationary recovery followed by ordinary travel to the requested health cache.

Final 600-second seeds 76 / 971 pass **15 checks each**: captures 6/7 and 9/9, contested seconds 253 / 251, deaths 164 / 161, health collections 109 / 116, and completed/reset rounds 1 / 1. Both teams cross the central shopping gallery and reach the actual 6.5 m promenade. Longest temporary stalls are two seconds in both runs; persistent eight-second stalls, falls and recovery teleports are zero. Decision/path budgets pass.

Inspected the updated engine gallery, including the shopping gallery, through-shops, supported stair landing and underground atlas. Captures and both benchmarks exit without engine errors or leak warnings. Clean Forward+ / RTX 3080 / 1920×1080 benchmarks use twenty real seconds after five seconds of warmup, twelve active actors and enlarged benchmark-only health pools: surface **103.0 FPS**, p95 **11.58 ms**, p99 **12.11 ms**; underground **105.9 FPS**, p95 **11.01 ms**, p99 **11.32 ms**. The underground fixture holds bot destinations within the arcade while retaining shared combat decisions. These current measurements supersede MAP-01 performance and route records; human balance and control-feel acceptance remain pending.

## DISPLAY-01 · Fullscreen and aspect compatibility — 16 October 2026

Added a shared always-processing display controller with borderless native-resolution fullscreen, F11 / Alt+Enter and display buttons in both pause menus. Saved fullscreen/windowed preferences apply on ordinary launch; explicit engine window flags and scripted captures keep their requested configuration. Windowed size/position and maximized state survive a round trip. A uniform HUD transform replaces separate horizontal/vertical scaling; the viewport expands across other aspect ratios while aim stays centred and training debug projections use the inverse HUD transform.

`tests/fullscreen_test.gd` passes **20 native Windows / Forward+ checks**, including 2560×1440 fullscreen, keyboard input while paused, both menu buttons, cursor capture, saved preference reload/defaults, scene transition, key-repeat rejection, window geometry restoration, a 1600×675 ultrawide viewport and 1080×810 console. Reviewed actual fullscreen menu, fullscreen play, ultrawide training and 4:3 console captures. No engine errors or leaked signal callbacks remain. Training integration **35 checks** and city/training transitions **32 checks** also pass. `tools/verify.ps1 -Capture` includes native fullscreen verification; its isolated test preference file does not change the player's saved display choice.

## SLAYER-01 · Complete playable hunter

Slayer's complete kit, selection, AI, presentation and training loop are connected. The existing shared controller, collision, damage, close-combat and ultimate economy remain authoritative. `tests/slayer_test.gd` passes **108 checks**; actual training/city scene integration adds **28**. All original **530 checks** and **1,358 structural probes** pass. Native display verification adds **20** with Slayer selected. A **600-second mixed-hero simulation** passes **15** further stability checks. Controls, exact defensive/status policies, configuration and reproduction commands are in [SLAYER.md](SLAYER.md).

Reviewed actual Forward+ renders for the dark streetwear/hair silhouette, carried shotgun/axe, muzzle flash, leading-leg boot, snare root, axe windup/flight, wound indication, victim's blocked health capacity and training console. Shrunk overhead status text, hid the player's own overhead label, added status rings, made shotgun hit feedback aggregate pellet damage, and reduced the kick trail after review. A freed shared shield node, stale trap references, a self-overlap during thrown-trap landing, repeated knockback velocity accumulation, pursuit marks surviving immediate respawn, and horizontal boot suppressing a fall were found and corrected. Final focused tests/captures exit without script errors or leaked audio instances.

Human acceptance remains a control-feel and balance exercise: practice shotgun → knife → boot, punish a boot miss with an opponent, compare placed and directly thrown snares, dodge the telegraphed axe, observe an eight-second wound expiring without free healing, then repeat against the Slayer hunter profile. Art and action poses are an original articulated primitive prototype. Audio verification uses finite PCM and rendered capture with Dummy audio; subjective sound quality needs listening during play.

## SLAYER-FEEL-02 · Playtest revision, 17 October 2026

User requested a longer boot with a fading self-slow instead of its recovery lock, more reliable activation, one downward trap deployment, stronger close/midrange shotgun damage, knife trails, larger damage numbers, a horizontal lower-screen health bar and a proper throw.

Implemented a 12 m kick, 0.22 s E buffer, deliberate guard exit and shell-reload interruption. After travel, speed ramps from 35% to full over 0.4 s on hit / 0.7 s on miss, with aiming, firing, steering and other legal actions available. Protected-room, cooldown and mobility-disable rejections now explain themselves. The longer airborne travel keeps falling momentum and advances coyote time rather than granting an extra jump.

Street Sweeper now uses ten 10-damage pellets, 1.1° spread and full damage through 12 m, reaching 40% at 24 m. Q releases from the throwing hand after its anticipation, with a silver-blue glint and fading flight trail. The single 1 action holds and throws the snare down, then settles/arms normally; RMB does not select another mode. Dedicated keyed clips stow the shotgun for knife/trap release and the two-handed crouch, lift, pivot and impact of the 4 throw. Existing throw timing, 95 impact damage and victim path remain authoritative.

Both HUDs use the shared wide green health strip with shields above it and a purple wound-capacity segment. Damage numbers are larger, outlined, longer-lived and also float above targets; shotgun pellets coalesce into one total per target. Reset clears old feedback. E and 4 were tested through the actual PlayerController using physical keyboard events under Forward+, including buffered activation, leaving guard, interrupted reload, blocked-state feedback and movement during recovery.

Final validation: **698 headless checks**, **32 native input checks**, **20 native fullscreen checks**, and **1,358 structural collision probes**, all passing. The 32-check revision suite includes a real capsule walking over its friendly trap and a combat ray still hitting that trap. A first stress run exposed physically blocking friendly snares; they now use a shootable deployable layer separate from character movement. The final 600-second mixed-roster run passes **15 checks**: 6/7 captures, 253 contested seconds, 170 deaths, 90 health collections, no persistent stalls/falls/teleports and a two-second worst temporary stall. The failed pre-fix report is retained for comparison.

Reviewed eighteen actual engine captures, including knife windup/flight, physical downward trap release, enlarged 100-damage feedback, new health layout/wound capacity, and the synchronized grab/lift/slam. Final captures exit without script errors or leaked instances. Subjective sound quality and competitive balance remain human playtests; the revised controls and values are ready for that pass.

## 2026-10-17 · Faster Slayer attacks and aimed snare toss

User feedback requested enemy knockback on Boot Rush, slightly lower shotgun damage, faster knives/kick, a shorter axe windup, a farther trap toss with delayed activation, crosshair ammunition, a closer camera, 25 more Slayer HP and more forgiving shared throws.

Street Sweeper now deals 90 full body damage (ten 9-damage pellets), retaining 1.1° spread and the previous falloff curve. Knives travel at 50 m/s; the 12 m boot travels at 32 m/s. The axe windup is 0.55 s. Slayer has 275 HP in the city and on direct training launch, selection and reset. Both heroes use a 4 m camera and 3.2 m throw reach. The grab retains facing, sightline, startup, counterthrow and collision-safe choreography checks.

Boot hits now route an 11 m/s impulse through the shared resolver, with attribution and defensive checks. Root, melee and ability movement previously returned before external displacement; the shared motor now applies the swept, decaying impulse after each branch. Root/slow application also preserves an existing enemy push. Physical checks measure over 1.5 m displacement against grounded and rooted enemies, apply root after kick contact, and confirm a thin wall stops the target.

The single snare action samples aim and releases at its keyed hand frame, launching at 11 m/s plus 3 m/s lift. No nearby ground is required. Arming begins at release and completes after 0.75 s, including during flight; an armed airborne device can trigger before landing. Swept flight, valid surface settling, destruction, teams, lifetime and active limits remain. The animation now throws forward. Both HUDs display current/magazine ammunition beside the crosshair, with empty/reloading prompts. Native renders confirm the closer camera, 275 HP, 90-damage feedback, toss release, and crosshair counter in training, city and ultrawide views.

Final checks: **715 headless**, **47 native input**, **20 native display**, **1,358 structural probes**, all passing. The seeded 600-second mixed-roster simulation passes **15 checks** with 8/7 captures, 265 contested seconds, 163 deaths and 101 health collections; no persistent stalls, falls or recovery teleports. A camera regression initially compared against the former distance; it now checks restoration to the actual configured distance and passes. Reports and rendered evidence use the `artifacts/slayer-tuning-*` prefix. Subjective control feel and balance remain human acceptance work.

## 2026-10-17 · Huddle colony off-tank

Implemented the accepted revised Huddle kit: 600 HP, Regroup self-healing, two 10 m Scatterbound charges with five-second sequential recharge, an ally/self interception screen, wingbeat displacement and Nobody Gets Squished!, a steerable bug wave. Includes original procedural character/portrait, effects, sound, bot tactics, both menus, launcher and rescue exercise. See [Huddle](HUDDLE.md) for controls and full authority rules.

Final focused checks: **101 headless**, **105 native**, **28 camera regressions**, all passing. Full verification completed with **1,266 checks** across 23 suites plus **2,516 structural surface probes** and **4,420 winding checks**; the final expanded Huddle suite and nine-check navigation regression were rerun after follow-up fixes. Rendered review covers every ability, wave displacement and both city/training menus. Two colonies add about 1.6% to draw calls compared with two Nimbuses from the same city camera; CPU timing was not an isolated benchmark.

Stress testing exposed short casts repeatedly clearing navigation recovery progress and a physically inaccessible street detour from an underground stair pocket. Recovery now checks capsule clearance and uses an ordinary, clearance-checked jump when needed. The exact recorded position is retained as a regression. No teleport or extra jump height is granted. Regroup also bypasses the shared generic casting slowdown so its actual running speed is the specified 3.6 m/s.

The final **600-second simulation**, seed 76, passes **17 checks**: 4/3 captures, 391 contested seconds, 97 deaths, 44 health collections and a completed/restarted match. Both teams use underground and elevated routes; there are no persistent stalls, falls or recovery teleports, with a three-second worst temporary stall. Failed pre-fix logs remain under `artifacts/huddle-city-*`. Competitive balance and subjective controls/sound still need human playtesting.
