# Slayer · playable hero

The [Phase 1 combat presentation notes](slayer-presentation-phase1.md) cover pooled shotgun effects, layered original audio, replacement asset slots, fallback visuals, and validation/manual checks.

Slayer is playable in Meridian Gardens and the training arena. Both heroes use `HeroActor`, `HeroMotor`, `CloseCombat`, `CombatResolver`, `PlayerController`, and the same ultimate economy. The supplied portraits informed her original geometric layered hair, cropped jacket, silver equipment and reinforced boots. No external models are required.

See the [ability/projectile overhaul notes](SLAYER_ABILITIES_OVERHAUL.md) for limited Boot Rush steering, ballistic silver knives, corrected axe tumble, art, effects and validation.

## Play

Run `Launch.ps1 -Slayer` for the city or `Launch.ps1 -Training -Slayer` for the sandbox. Both pause menus offer **Play Slayer**. City selection applies in spawn or queues for respawn, without restarting the match, and resets the player's ultimate charge; training selection resets the exercise. Selection survives scene transitions. Ordinary launch opens the main menu and dedicated hero selection.

**Tab → Start Slayer hunt** selects Slayer and provides stationary, moving and attacking Slayer targets. F6 restores resources and cleanses statuses; F5 resets; F3 shows state, velocity, actual shot damage, pellet count and recharge timers. The advanced tuning panel exposes Slayer's numeric fields. Reset after changing capacities or base health.

| Input | Action |
| --- | --- |
| Left click / right hold | Street Sweeper / shoulder aim |
| R | Load individual shells concurrently with movement and abilities; firing waits until completion |
| Q | Silver Knife |
| E | Boot Rush |
| 1 | Aim and toss Hunter's Snare; arms on a timer in flight or on the ground; RMB does not change deployment |
| 2 | Heads Will Roll; automatic release after windup |
| Wheel up / Shift / Space | Shared dash / crouch or momentum slide / jump, mantle and wall kick |
| 5 / 6 / 4 | Shared melee / guard / throw and counterthrow |

Internal `hover`, `deflect` and `bomb` action names remain Q/E/1 slots. Slayer's Q cannot activate Nimbus's Hover. Sprint remains undecided in the design; both heroes retain the same 6 m/s baseline and shared traversal.

## Rules and tuning

Defaults are in `resources/slayer.tres` and exported `SlayerTuning` fields. Each actor gets its own resource copy.

| Mechanic | Current tuning |
| --- | --- |
| Health | 275 HP; Nimbus retains 250 HP |
| Shotgun | 6 shells, 10 × 9 body damage, global 2× head multiplier, 1.1 s pump lock, 1.1° fixed disk spread |
| Falloff | Full through 12 m; linear reduction to 40% at 24 m; 35 m trace limit |
| Reload | First shell after 0.15 + 0.22 s; subsequent shells every 0.22 s; firing waits for the full sequence |
| Knives | 2 charges, sequential 7 s recharge, 30 direct damage, 110 m/s, 25 m range, 0.14 m collision radius; 0.09 s hand release, 0.22 s fading silver-blue trail |
| Bleed | 8 DPS for 4 s in eight 4-damage ticks; refresh retains partial tick progress |
| Boot Rush | 0.06 s startup, up to 12 m at 32 m/s, 55 damage once, 0.45 s turning hold then 18 m/s horizontal + 3 m/s upward launch, 9 s cooldown; 0.22 s input buffer |
| Boot recovery | Immediate control; speed returns from 35% to 100% over 0.4 s on hit or 0.7 s on miss/wall; 30% horizontal exit momentum |
| Snare | 2 charges / active traps, sequential 12 s recharge, 0.75 s arm time from release, 1.4 m radius, 15 s lifetime, 25 HP |
| Armed trigger | 25 damage, 1.5 s root and mobility lock; aim and shooting remain available; can trigger in flight |
| Aimed toss | One deployment regardless of RMB; 0.14 s hand release in a 0.36 s keyed throw; 18 m/s launch plus 3 m/s lift, 15 m/s² gravity |
| Instinct | Private 4 s marks within 32 m; wounded warning at 30% effective HP; ordinary visibility/depth tests |
| Axe | 0.55 s windup, 0.2 s release, 0.55 s recovery; 20 m/s, 30 m range, 0.55 m collision radius |
| Axe contact | 110 direct damage, then an 8 s wound reducing effective max HP by 50% of base maximum |

Pellets trace from the muzzle with a shoulder obstruction check, individual resolver cast IDs, and one collision each. HUD feedback sums actual damage for the shot; events retain individual pellet/headshot/shield attribution. Existing team, spawn-room, invulnerability and paired-throw rules apply.

Reload cancels preserve inserted shells. Knives can follow gunfire after 0.25 s. Knife/trap casts take 0.28/0.36 s, release at the keyed hand frame, and retain ordinary movement. Cancels never reset the pump lock. Boot startup/travel remain committed, but recovery immediately permits aiming, shooting, steering and other legal actions while its movement slow decays. Axe recovery remains committed. Boot never replenishes dash, wall-jump or coyote-jump permissions.

E is buffered briefly near the end of another action, can intentionally leave guard, and interrupts shell reload. A blocked input explains safe-room protection, cooldown or mobility disable on screen. Safe-room protections remain authoritative. Native input tests cover real E presses, movement during the fading slow, and the 4 throw input.

Boot moves the existing CharacterBody through normal collision response. Ground entry uses flat camera aim; air entry retains committed 3D direction. Walls stop it, slopes use capsule sliding, and ledges lead to falls. Frontal guard uses the shared cost and attacker stagger. Successful unblocked hits apply attributed knockback through the resolver. The motor sweeps and decays the impulse after every movement branch, including root, melee and offensive mobility, so those branches cannot swallow displacement. Paired throws, invulnerability, protected rooms and friendly fire retain their protections.

Deployment validates clear release space rather than requiring nearby ground. Slayer draws and tosses the device along her sampled aim with an upward arc. Its 0.75 s arming clock starts at release, independent of landing. An armed airborne trap can catch a nearby enemy; an unarmed trap has no direct-impact attack. The device sweeps from shoulder to hand and along flight, bounces from steep surfaces and settles on valid floors. A release blocked during anticipation refunds the charge. Friends cannot trigger/damage traps. Character capsules walk over the device; a dedicated shootable collision layer keeps it hittable by hitscan, projectiles, axes and bombs without blocking players or bots. New deployments above the active limit retire the oldest trap. Death, reset, selection and scene teardown remove owned attacks. Root cancels active mobility while retaining cooldowns and preserving unrelated reloads and axe windups.

The lower-screen HUD uses a broad green health strip with shields above it and a purple disabled-capacity segment for wounds. Both heroes also see current/magazine ammo beside the crosshair, with empty and loading prompts. Damage numbers are larger, outlined and longer-lived; floating target numbers combine pellets from one shot. Reset clears stale hit feedback. Knife flight has a fading trail and a small silver-blue glint. Dedicated animation clips show the knife and trap in hand before release. The 4 throw stows the shotgun, reaches with both hands, crouches into the lift, pivots and slams at the existing physical impact frame. Shared throw reach is 3.2 m, retaining facing, visibility, startup, counterthrow and safe-path checks. The shared shoulder camera defaults to 1.85 m at a 1.75 m pivot height, cropping the lower legs while preserving its normal 76-degree field of view, collision response and aim zoom.

The piercing axe hits each actor once and stops at walls. It follows projectile defense rules: ordinary guard defaults to zero bullet reduction; Nimbus's frontal Deflect stops axe and wound. Invulnerability and protected rooms reject both. Remaining shields prevent the wound. Paired throw participants take existing 10% direct damage and cannot receive a full wound. Windup interruption spends the ultimate without refund.

Wounds are per-life runtime statuses. Direct damage resolves first; HP then clamps to the new ceiling without a second damage event. Wounds refresh without recursive stacking. Expiry/cleanse restore the ceiling without granting health. Respawn clears wounds and restores full HP. Health packs respect effective maximum. Purple health-bar segments, opponent timers and floor rings expose the effect.

Bleed ticks through the shared resolver with its originating attacker, including after attacker death. Cleansing, invulnerability, team rules and respawn apply. Marks clear on either participant's death/reset, including immediate respawns. Only the viewing Slayer sees her pursuit indicator; it cannot reveal enemies through walls or on the tactical map.

## Implementation and validation

Completed plan: inspect and preserve the architecture; implement kit/status rules; connect selection, AI, presentation and training; verify engine physics and rendered output.

- `tests/slayer_test.gd`: **110 checks** covering weapons, cancels, deterministic bleed, boot/trap collision and interruption, wounds, defenses, healing, marks and cleanup. Includes thin walls, clear release space, airborne tosses, doorways, slopes, ledges, falling momentum, moving/airborne enemies and a 500 HP target.
- `tests/slayer_integration_test.gd`: **28 checks** using real scenes, paused selection, live bot attacks, finite resources, respawn economy, aggregate hit feedback and transition cleanup.
- `tests/slayer_revision_test.gd`: **47 checks**, run headlessly and under Forward+. Covers actual E/4 input, buffering, guard/reload exits, rejection feedback, movement during recovery, no stale airborne coyote jump, timed hand release, trails, coalesced numbers, the keyed slam, and physically walking over a friendly but shootable trap. Also measures over 1.5 m of actual kick displacement against grounded/rooted targets, roots applied after kick contact, thin-wall safety, arming and triggering in flight, 275 HP on launch/reset, closer camera distance, and the wider throw reach and whiff boundary for both heroes.
- All **530 previous checks** and **1,358 structural collision probes** pass. Native fullscreen adds **20 checks** with Slayer selected; its test now locates the actual display button instead of a positional index.
- `tests/city_simulation_test.gd`: the latest 600-second mixed-roster run passes **15 checks** with 8/7 captures, 265 contested seconds, 163 deaths and 101 health collections. Both teams use subway, arcade and high decks, and one round completes/restarts. Longest temporary stall is 2 s; persistent stalls, falls and recovery teleports are zero.
- `tests/capture_slayer.gd` produces eighteen Forward+ renders covering silhouette, shotgun/damage feedback, knife windup/trail, boot, trap hand release/drop, snare, axe, wound HUD, grab/lift/slam and console. These were inspected. Original finite WAV cues and an `audio_cue` signal provide sound and replacement hooks. Final capture exits without script errors or leaked audio instances.

Correctness: **715 headless checks**, **47 native input checks**, **20 native display checks**, plus **1,358 collision probes**. The simulation contributes a separate 15-check stability report. Verified in installed Godot **4.7.2 stable**. The camera restoration regression compares against configured distance, allowing the closer camera without weakening obstruction checks.

Run `tools/verify.ps1`, adding `-Capture` for rendered checks. Reproduce the mixed-hero simulation with:

```text
godot --headless --path . --fixed-fps 60 --script res://tests/city_simulation_test.gd -- --hero=slayer --seconds=600 --seed=76
```

Logs, JSON, WAV and PNG evidence are in ignored `artifacts/`. Focused reports: `slayer-results.json`, `slayer-integration-results.json`, `slayer-revision-results.json`; real-input evidence is in `slayer-tuning-native.log` and `slayer-revision-native-results.json`. Latest simulation report: `slayer-tuning-simulation-results.json`. The combined record is `slayer-tuning-validation-summary.json`.

## Human acceptance

The complete loop is connected and engine-tested. Art/action poses use articulated primitives and sound uses synthesized effects. Human playtesting remains necessary for recoil comfort, kick commitment, trap visibility, sound quality and competitive balance. Networking remains outside this offline project's scope. No permanent speed bonus, lifesteal or damage-amplification passive was added.
