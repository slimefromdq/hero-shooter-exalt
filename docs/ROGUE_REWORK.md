# Rogue · higher leap, short dodge and explosive burst

Rogue is the existing Wisp hero, renamed in presentation without replacing her registration. `hero_id = "wisp"`, resource paths, existing bindings, marks and burst ammunition remain compatible. Use `Launch.ps1 -Rogue -Training` or `--hero=rogue`; the existing Wisp launcher/argument also works.

## Before / after

| Mechanic | Previous phantom-thief revision | Rogue revision |
| --- | --- | --- |
| Display name | Wisp | Rogue across selection, HUD, player nameplates, training and match feedback |
| Majestic Leap upward speed | 12 m/s | 18 m/s; unchanged gravity, forward launch, float, dive and cooldown |
| Measured apex at 60 Hz | 3.1733 m above launch | 7.2139 m, **2.2733x** higher |
| Q travel | 7 m at 30 m/s | **2.5 m at 12.5 m/s** |
| Q exit momentum | Up to 30 m/s | **2 m/s maximum** on completion or collision |
| Right-click | 24 m core + eight pellet rays | **32 m aimed impact explosion**, 3 m radius, no pellets or headshots |
| Burst base damage | 20 core + up to 48 pellet damage | **80** within 1 m, radial falloff to **48** at 3 m |
| Grand Heist radius | 5 m; full damage through 2 m | **6 m**; full damage through **2.5 m** |
| Grand Heist base damage | 100 | **220**; up to **268** with four owned marks |
| Pre-explosion suction | None | Final **0.25 s** of warning; **20 m/s** horizontal pull, up to 5 m total |

The physical apex regression measured 3.0756 -> 7.0667 m at 30 Hz (2.2977x), 3.1733 -> 7.2139 m at 60 Hz (2.2733x), and 3.2307 -> 7.3010 m at 144 Hz (2.2599x). These are actual engine movement measurements, not just a comparison of launch velocities. Ordinary gravity and the shared speed cap are unchanged.

## Controls and retained mechanics

- **LMB:** unchanged 13-damage alternating pistols, 12 shots/s, 36 rounds and 1.1 s reload. Marks remain source-specific, capped at four, lasting 3 s, with 12 damage per mark.
- **Q — Phantom Dodge:** short, aim-directed evasive movement with existing collision rules, three sequentially recharging charges at 4 s each, 0.15 s bounded damage immunity and a cosmetic afterimage. Successful completion still loads one burst, maximum two. Blocked travel loads none. Low exit speed removes the old movement carryover. The separate scrollwheel dash is unchanged.
- **E — Vanishing Act:** unchanged 1 s collision-aware horizontal hover, 3 m/s movement, second-press cancellation and 0.20 s vulnerable exit recovery. Existing statuses are not cleansed. Both Rogue immunity windows reject outgoing damage and objective contribution.
- **1 — Majestic Leap:** 18 m/s up and the retained 10 m/s horizontal launch. Hold Jump to float during the 1.5 s descending opportunity; press 1 again to dive at 24 m/s. Existing 8 s cooldown, airborne activation and firing throughout ascent/float/dive remain.
- **2 — Grand Heist:** retained 0.35 s preparation, 32 m/s calling card, 28 m travel and 0.80 s warning. The last 0.25 s gathers enemies before the stronger blast.

## Explosive right-click

One aimed ray determines an impact, or the endpoint at 32 m. It produces one spherical explosion, rather than a shotgun pattern. The 3 m blast can catch targets beyond the ray's endpoint and alongside an impact, giving it its deceptive reach. There is no weapon-distance falloff inside the travel range; damage falls off radially from the explosion center. Every successfully damaged enemy detonates only this Rogue's marks.

The burst retains one ammunition charge per press and 0.65 s recovery. Terrain, hostile barriers, spawn protection and friendly-fire rules apply. Exact direct impacts receive no extra damage or headshot multiplier. Shared blast resolution snapshots all cover before applying damage, uses one cast ID and damages each victim at most once. Cover destroyed by the explosion still protects against that cast. Immune/covered targets retain their marks. Violet impact VFX and confirmed-hit audio replace pellet feedback.

## Suction and explosion

A second inward-moving ring and a bass cue signal the final suction phase while the full-radius warning remains visible. Pull time is clipped to the final 0.25 s, including frames that cross its start or the detonation boundary; it cannot run early or continue after the explosion.

Eligible enemies inside the 6 m sphere move horizontally toward the card at 20 m/s, stopping 0.8 m from its center. Body and world collision remain authoritative, so targets cluster without overlapping or moving through terrain. The pull does not levitate enemies toward aerial cards. Cover, hostile barriers, spawn doors, protected rooms and invulnerability block it; paths crossing a spawn boundary are rejected. Captured/paired actors are excluded. Owner death, reset or hero change immediately retires the effect, and owner immunity suppresses outgoing suction and damage.

The blast then snapshots cover and target positions after suction. Damage falls from 220 within 2.5 m to 88 at the 6 m edge, with the same multiplier applied to owned mark damage. Damage is once per target; ordinary follow-up shots can charge the next ultimate, but the released Heist cannot.

## Bots, presentation and validation

Bots use the new burst range and conservative damage estimate, favor lateral dodges to load ammunition instead of forward travel, and retain an escape reserve. Their preferred engagement range changes from 5-14 m to 8-22 m. Heist uses the larger damage zone and existing predicted throws. HUD labels distinguish **DODGE**, **BURSTS** and the **SUCTION** phase; damage/range summaries read tuning values. Hero selection, training, city and museum presentation show Rogue while keeping the internal Wisp identity.

Recorded results: full repository verification passed; **210/210 focused checks** (including the Rogue argument alias), **36/36 native-input checks**, **283/283 roster checks**, and **83/83 tactical bot checks**. Seed 971 passed city **17/17** and museum **16/16** checks over 600 seconds each, with no terrain falls or persistent stalls.

Validation is recorded in [validation/rogue-results.json](validation/rogue-results.json). The focused suite covers measured apex height at 30/60/144 Hz, Q travel and exit momentum, long-range multi-target explosion/mark/deduplication rules, frame-clipped suction, clustering, collision, cover, immunity, protection and lifecycle cleanup. Existing roster, bot and native-input suites cover connected integration. Rendered frames and combat simulations supplement these checks.

Automated checks establish mechanics and stability. Human playtesting is still needed for competitive balance, movement feel and final visual polish.
