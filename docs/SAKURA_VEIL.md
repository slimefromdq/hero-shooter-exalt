# Sakura Veil

A symmetric, offline 6v6 five-control-point map through an overgrown mountain sanctuary. Root starts at A/B, Cloud at D/E, and Skybell Crossing (C) begins neutral. Both teams push and reverse the same front; taking all five wins.

## Play

Choose **Sakura Veil / Five Control Points** in the main menu, then Root, Cloud, or Explore and a hero. Or run:

```powershell
.\Launch.ps1 -Temple
.\Launch.ps1 -Temple -Defend -Slayer # Cloud team
.\Launch.ps1 -Temple -Explore -Stitch
```

All current heroes, combat controls, pause/settings, hero changes, respawns, and movement tuning carry over. **M** opens the tactical atlas; **B** changes between the lower and upper routes. Explore freezes bots and the objective clock, grants resources, and returns the player to the active safe room after a lethal fall.

## Scale and circulation

The authored playable envelope is **320 × 288 m**, versus Gardens' 144 × 132 m and Museum's 114 × 102 m. Each capture footprint is **40 × 36 m** inside a **72 × 64 m** court. The five centers are A (−48,0,108), B (52,8,62), C (0,16,0), D (−52,8,−62), and E (48,0,−108). The other half rotates 180 degrees, retaining equivalent route lengths, cover, health, and access.

Every adjacent sector retains main, lower, and upper connections, with **12 m main/lower decks and 8 m upper decks**. The enormous courts stay intact; galleries, garden islands, screened rest bays, and through-halls make them useful fighting spaces. Ten galleries provide two elevated positions per court, with stairs at both ends. Capture eligibility remains -0.25 to +2.5 m above court level, so upper floors cannot capture through their ceilings.

Routes use explicit flat junctions and ramps capped at **25 degrees**, with landings between rises no greater than 4 m. Gallery stairs have closed visual treads over continuous collision ramps. Court, route, and veranda paving shares a deduplicated floor grid; overhead decks have visible undersides. Stacked routes retain clearance instead of being lifted into nearby courts. Gallery verandas meet existing ramps through doorway cutouts.

The route network spans -8 to +24 m, with mountains, waterfalls, the suspended Skybell, and real ravines preserving the sense of height. The kill threshold remains **-48 m**. Every essential level has an ordinary walking route; wall kicks, mantles, and launch platforms are optional shortcuts. The obsolete recovery shelves that demanded repeated wall kicks have been removed.

### Wind lifts

Eight gold-and-cyan **directional jump pads** provide one lower-to-court and one court-to-upper shortcut in each sector. Walk onto the marked top surface to launch automatically. Arrows indicate direction and gold 8 x 8 m squares mark arrivals. Normal air steering and shooting remain available; a dash or another movement action can redirect flight. Pads do not restore charges or cooldowns.

A pad launches each user independently, then rearms after that user leaves and a one-second debounce expires. Roots, paired combat, and active scripted movement prevent activation; becoming eligible while standing on the pad allows launch. Death, reset, landing, and interruption retire the scoped launch-speed allowance. Ordinary movement tuning is unchanged.

The atlas shows routes, galleries, stairs, and one-way pad arrows. Bots approach pads, ride their authored arcs, resume navigation at the landing, and fall back to walking after a timeout. Defenders can use galleries through ordinary stair access.

## Match defaults

Twenty seconds of preparation precede a ten-minute clock. Solo capture takes 24 seconds at mid, 18 at second and 10 at last; two/three players give 1.5×/2× speed, capped at three. Any enemy contests. Abandoned progress decays at the solo rate after five seconds, and a newly locked point loses incomplete progress. Captures add two minutes, capped at ten. Activity on an eligible point sustains overtime with three seconds of departure grace; expiry without activity is a stalemate.

Respawns take eight seconds and retain earned ultimate charge. Holding mid activates a room behind own second; holding enemy second activates a room beside mid. Territory loss reverses these stages and evacuates occupants of the deactivated room. Team doors and swept movement exclusion protect active enemy rooms from walking and ability relocation.

Twelve small packs heal 75 HP; six large packs heal 400 HP. Packs sit at the final surface elevation on flank junctions and rotations. Bots use ordinary movement and the shared tactical brain, with authored main, lower and upper route assignments. They retarget when ownership changes and reinforce an owned point under attack.

## Implementation and verification

`scripts/temple` owns this mode; `resources/maps/sakura_veil.tres` contains its immutable definition and `scenes/temple/sakura_veil.tscn` is its entry scene. Ownership, progress, timers, and forward-spawn stages stay in the session, not the shared resource. The original architecture kit batches timber, stone, tiled roofs, blossoms and temple details. Mountains, rock foundations, dawn light and waterfalls establish the setting; scenic geometry is excluded from navigation where appropriate.

Run `tools/verify_temple.ps1` for rules, geometry, bidirectional physical traversal, jump-pad, menu, and integration checks. Add `-Capture` for native engine views and `-Soak` for ten simulated minutes from each team. Results are written beneath `artifacts/temple`.

The geometry audit checks the measured footprint, floor winding, ramp slopes, route navigation, and standing capsules at the center and both sides of each route, including hall and stair passages. Pad arcs are swept at 60 Hz. Traversal drives the real motor without jumping or abilities; pad tests cover every hero with neutral and fast entry, state restrictions, rearming, simultaneous users, redirection, and lifecycle cleanup.

The rebuilt geometry passes 7,446 supported clearance samples, 29,206 continuous capsule sweeps, and 1,052 court-grid samples with zero blocked results, zero authored floor conflicts, and no ramps above 25 degrees. All 108 directional physical walks pass after corrected-route reruns; 660 pad checks pass. Two ten-minute bot simulations recorded 57 and 55 launches, three gallery users each, and no persistent stalls (one accidental fall across both matches). The current measurement record is `docs/validation/sakura-veil.json`; it distinguishes structural checks, simulations, native views, and performance sampling. Older clearance counts described the superseded centerline-only layout.

The procedural art remains a prototype. Automated tests establish collision and routing behavior; human playtesting is still required to accept combat balance, route readability, pacing, and the overall feel of the map.

A sequential native accelerated-combat comparison measured median frame time of 21.6 ms on the original map and 37.2 ms on the rebuild, with p95 times of 44.2 and 111.5 ms. Mean draw calls fell from 1,108 to 972. This single 4x-simulation sample uses matching initial placement and camera, not deterministic combat, and is not a normal-speed FPS benchmark. The measured regression remains an open profiling/optimization item before release.
