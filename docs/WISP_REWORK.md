# Wisp · initial phantom thief rework

This records the first phantom-thief revision. The current hero is named **Rogue** and has a higher leap, short dodge, explosive right-click and suction Heist; see [current Rogue tuning and validation](ROGUE_REWORK.md).

Implemented October 19, 2026 in the existing `wisp` registration. Inputs and shared movement bindings are unchanged. This revision deliberately replaces Spectral Lift and Death Ballet with the accepted Majestic Leap and Grand Heist design.

## Before / after tuning

| Mechanic | Before | After |
| --- | --- | --- |
| Primary | 14 body damage, 12 shots/s | 13 body damage, same firing mechanics |
| Primary resources | 36 rounds, 1.1 s reload, 55 m, 1.5x headshots | Unchanged |
| Marks | Four maximum, 3 s duration, 12 damage each | Unchanged; cards in presentation, source-specific soul storage retained |
| Burst core | 20 damage, exact ray | 20 damage; exact ray first, then 0.18 m swept assistance on misses |
| Burst pellets | Six x 8, single 6-degree ring | Eight x 6, alternating 4/8-degree rings |
| Burst reach / recovery | 24 m / 0.65 s | Unchanged |
| Burst falloff | None | Full through 8 m, linear to 50% at 24 m; includes marks |
| Phantom Step (Q) | Three 7 m / 30 m/s dashes, 4 s sequential recharge | Same; first 0.15 s damage immunity, bounded by travel termination |
| Q shells | One per completed dash, two maximum | Unchanged; blocked travel gives no shell |
| Q presentation | Thin spectral streak | Violet trail and 0.35 s cosmetic thief afterimage |
| Vanishing Act (E) | 0.65 s phase, ordinary movement/gravity | 1.0 s, collision-aware horizontal hover at 3 m/s |
| Vanishing cooldown / control defense | 10 s / control immunity | Unchanged; pre-existing statuses remain |
| Vanishing exit | Immediate readiness | Second E can cancel; visible/audio return and 0.20 s vulnerable attack/ability lock on either exit |
| Majestic Leap (1) | Vertical 12 m/s launch | 12 m/s up plus 10 m/s horizontal launch, 8 s cooldown |
| Float | Hold Jump; 1.5 s descent opportunity at 2 m/s | Retained |
| Dive | None | Fresh second 1 sets 24 m/s downward motion; horizontal steering capped at ground speed |
| Ultimate (2) | Death Ballet: 0.45 s preparation, 4 s aimed aerial barrage and finale | Grand Heist: 0.35 s throw, 32 m/s calling card, 28 m travel, 0.80 s impact warning |
| Ultimate damage | Barrage and 80-damage / 4 m finale | 100 base + 12 per owned mark; 5 m blast, full through 2 m, linear to 40% at 5 m |

225 HP, 6.5 m/s ground movement, 9 air steering, shared scrollwheel dash, slide, close combat, roster membership and character ID remain unchanged.

## Combat and movement rules

- Exact burst core hits retain headshots. Assisted hits cannot headshot; terrain, intervening bodies, spawn doors and hostile barriers obstruct assistance. Pellets never detonate marks. Marks are consumed only after successful core or Heist damage. The maximum raw pellet total remains 48.
- Q's damage-only immunity starts on an accepted cast. Travel completion, collision, root/slow/stagger and other interruptions clear it. Repeated requests cannot refresh an active dash. Crowd-control counterplay remains available.
- Vanishing blocks attacks, incoming damage/control, and ability activation while allowing slow hover movement. Existing root/slow effects are not cleansed or bypassed. Second-press cancellation requires a fresh input edge. Reappearance is vulnerable immediately, but attacks/abilities wait 0.20 s.
- Both Wisp immunity windows reject outgoing damage at the resolver, including already released projectiles, Heist and damage-over-time ticks. They exclude capture, contest and escort contribution. Training invulnerability is independent.
- Leap samples horizontal aim, with a facing fallback for vertical aim. It retains gravity, air steering and airborne activation. The float opportunity decreases during descent even when Jump is released. A fresh second press dives during cooldown without another cost or refund. Landing retires the recast; Q, Vanishing, movement replacement, disabling control and life reset retire old leap/dive state.
- Primary and burst firing remain available during ascent, float and dive. The dive has no damage, immunity, shockwave or landing recovery, and uses ordinary body collision.

## Grand Heist

Preparation blocks attacks and preserves charge if interrupted. Release consumes charge, restores ordinary actions and snapshots the card as ultimate damage so it cannot charge its successor; ordinary follow-up weapons can.

The card has no direct-hit damage, health or targeting behavior. It stops at the first surface/barrier/actor other than its owner, or at maximum range. It plants at a fixed location, including enemy impacts, and displays a violet blast boundary with accelerating audio cues for 0.80 s.

Detonation snapshots targets and cover before damage. Each enemy receives at most one combined base-plus-mark hit with distance falloff and no headshots. Terrain, hostile barriers, friendly-fire rules and protected rooms apply. Destroyed cover still protects against the cast that broke it. Covered, immune and out-of-radius enemies retain their marks; expired marks add nothing. Owner death, hero switch and reset retire cards immediately. Vanishing or Q immunity at detonation suppresses the outgoing blast.

## Presentation and bots

The procedural character now has an ivory mask, opaque violet clothes, tailored lapels, silk tails and calling cards. Purple smoke, card flourishes, afterimages, burst confirmation tones and a theatrical reappearance use existing procedural geometry and tone synthesis. The updated portrait is generated from the actual model; no external art dependency was introduced.

HUD/menu/training labels expose Phantom Step, Vanishing Act, Majestic Leap and Grand Heist in their existing slots. Resource telemetry includes immunity/recovery, shells, charges, leap/float recast, dive and planted-card warning time. Private enemy marks appear as cards.

Tactical bots choose marked bursts and conservative lethal unmarked bursts, prioritize Vanishing when hurt, move toward safe escape/cover during it, and use Q against observed pressure/tells. They check leap paths and dive ground support, float for aerial fire, and lead Heist throws using travel/warning time. Training tactics use the same tuning, finishing estimate and ground/escape helpers.

## Verification

`tools/verify.ps1` includes `tests/wisp_rework_test.gd`. The dedicated suite covers immunity at 30/60/144 Hz, interruption, repeated inputs, outgoing damage, objective consumers, cancellation/recovery, movement, assisted core/falloff/mark ownership, projectile placement, warnings, cover destruction, charge accounting, lifecycle cleanup, bot choices and cosmetic decoys. Native-input coverage also checks pause, second E, second 1 and firing during leap/dive.

Recorded results: full repository verification passed; **173/173 focused checks**, **33/33 native-input checks**, city **17/17** and museum **16/16** simulation checks. Both 600-second runs used seed 971 and had no terrain falls or persistent stalls. Eight Wisp engine frames were reviewed. City Wisp used Soulbreaker 22 times with 22 successful casts and Grand Heist 17 times with six successful casts; this establishes real bot usage, not balance.

Persistent measured results are in [validation/wisp-results.json](validation/wisp-results.json). Logs, JSON simulation reports and rendered frames are under `artifacts/`; regenerate the updated Wisp portrait and gameplay captures with:

```powershell
$taskEngine = & .\tools\find_godot.ps1
$env:APPDATA = Join-Path (Get-Location) '.tools/runtime'
& $taskEngine --path . --fixed-fps 60 --script res://tests/capture_roster.gd -- --wisp-only
```

Automated tests and simulations establish mechanics and stability. Human playtesting is still needed to judge responsiveness, readability under real pressure, and competitive balance.
