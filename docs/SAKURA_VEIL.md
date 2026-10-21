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

Every adjacent sector has a **28 m main connection**, a **16 m lower flank**, and a **16 m upper flank**. These are actual separate surfaces with substantial screening, bends, alternate exits and intermediate cross-connections. Gallery walls conceal travel until an exposed arrival; they are not decorative foliage or wide open side lanes. Crossings are cut out of corridor walls, so the navigation and visible circulation agree. The atlas draws the authored paths and their height layers.

Capture eligibility stays within −0.25 to +2.5 m of the court surface. Roofs and underpasses do not capture through floors. Solid pavilions and low stone plinths split sightlines on courts; bridge cover is recessed outside the principal movement lanes. The floor surface joins overlapping ramps continuously, rather than stacking flat slabs over descending approaches. Navigation additionally carves solid cover footprints with capsule clearance.

Main connections cross actual voids. Recovery shelves at −12 m and below the inner bridges provide alternating wall-kick surfaces; the map's lethal threshold is **−48 m**. The shared actor queries this session's threshold; other maps keep their existing −8 m behavior. A side courtyard offers a mantle chain without obstructing a principal route. Upper circuits reach approximately +32 m.

## Match defaults

Twenty seconds of preparation precede a ten-minute clock. Solo capture takes 24 seconds at mid, 18 at second and 10 at last; two/three players give 1.5×/2× speed, capped at three. Any enemy contests. Abandoned progress decays at the solo rate after five seconds, and a newly locked point loses incomplete progress. Captures add two minutes, capped at ten. Activity on an eligible point sustains overtime with three seconds of departure grace; expiry without activity is a stalemate.

Respawns take eight seconds and retain earned ultimate charge. Holding mid activates a room behind own second; holding enemy second activates a room beside mid. Territory loss reverses these stages and evacuates occupants of the deactivated room. Team doors and swept movement exclusion protect active enemy rooms from walking and ability relocation.

Twelve small packs heal 75 HP; six large packs heal 400 HP. Packs sit at the final surface elevation on flank junctions and rotations. Bots use ordinary movement and the shared tactical brain, with authored main, lower and upper route assignments. They retarget when ownership changes and reinforce an owned point under attack.

## Implementation and verification

`scripts/temple` owns this mode; `resources/maps/sakura_veil.tres` contains its immutable definition and `scenes/temple/sakura_veil.tscn` is its entry scene. Ownership, progress, timers, and forward-spawn stages stay in the session, not the shared resource. The original architecture kit batches timber, stone, tiled roofs, blossoms and temple details. Mountains, rock foundations, dawn light and waterfalls establish the setting; scenic geometry is excluded from navigation where appropriate.

Run `tools/verify_temple.ps1` for focused rules, geometry, real capsule traversal, menu and live-match checks. Add `-Capture` for engine screenshots of every court, both gallery types, bridges, atlas layers and a shoulder view. Results are written beneath `artifacts/temple`.

The geometry audit samples supported routes, navigation between all points and spawn stages, eye-height concealment, and defensive views across ingress families. Each builder audit entry records its visibility, movement, and cover purpose. Traversal runs the real motor over collision geometry, including ordinary walking, dash movement, a ravine wall kick and a mantle. The live simulation uses both six-player teams and the existing kits.

Automated checks establish structural behavior and reproducibility; competitive balance, route mastery and match pacing still require human playtesting.

The October 21 validation run passed 71 rules, 1,897 geometry, seven traversal, 12 menu, and 13 integration checks. The measured floor envelope was 320 × 288 m. All 7,216 route samples had standing clearance; 3,320 of 3,680 flank samples were screened from the destination court. None of twenty sampled defensive positions saw all three approach families. These are sampled checks, not an exhaustive visibility proof.

The final 180-second live match moved all eleven bots, used six lower and six upper route assignments, and captured mid. The longest recorded stuck interval was 2.13 seconds. City, Museum, menu, movement, mantle, traversal and shared bot regressions passed. The tracked measurements and validation limits are in `docs/validation/sakura-veil.json`.

Native views, both atlas layers, the shoulder view, and `geometry-purpose-audit.json` are in `artifacts/temple`. `presentation-profile.json` records still-view CPU/draw snapshots; it is not a sustained combat benchmark. The procedural art remains a prototype. Longer matches, additional hero shortcuts, sustained performance and competitive balance require further playtesting.
