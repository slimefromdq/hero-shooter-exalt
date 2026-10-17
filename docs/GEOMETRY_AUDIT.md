# Meridian Gardens: geometry and Exchange revision

This revision audits the physical city and rebuilds the space beneath the control point as **Lower Meridian Exchange**, a covered shopping concourse at Y = −5 m.

## Structural corrections

| Area | Corrected structure |
| --- | --- |
| Conservatory | A continuous, solid glazed barrel roof meets its ribs and corner piers. The disconnected roof wings and intersecting side vaults are removed. |
| Railway | Masonry above each arch connects it to the deck. Decks, roofs and train bodies have physical surfaces. Transit transforms update on physics ticks. |
| Apartments | Closed gabled roofs replace floating roof panels. Balcony decks and three-sided railings are solid; balcony windows use door-height proportions. |
| Garden pavilion | Its vaulted roof follows the supporting arches and eave beams. |
| Market and study | Roof elevations meet walls and columns; market columns sit at the arch springing points. The raised study floor has ground-level supports. |
| Stairs and promenades | Stair volumes have visible undersides and cheeks matching collision. Promenade cross-bridges have piers. Both inner flights end at square, level landings, clear of the subway trenches. Trees no longer intersect those flights. |
| Neighbourhood alleys | Spawn-side apartment footprints leave an approximately five-metre lane, including cornices and balconies. |
| Underground | Retaining walls and finished ceilings enclose the concourse and station approaches. Four corner stair trenches have solid retaining cheeks. |

The architecture kit makes substantial slabs, balcony decks, roofs and counter tops tangible by default. Structural arches, tree trunks, lampposts and large storefront panes also have matching collision. Small paint, foliage, sign lettering and magical ornament retain their normal decorative treatment over the surrounding structural collision.

## Lower Meridian Exchange

The 42 × 42 m room sits directly beneath the park. The orrery's structural drum continues down through the concourse, while columns and beams visibly support the ceiling. The original perimeter route remains available on both sides.

Six shops connect the central gallery to the perimeter aisles through open front and rear doors:

- **West:** Moon & Quill, Starling Tailors, Astra Patisserie.
- **East:** Botanica Gifts, Thauma Workshop, Meridian Maps.

Shelves, display windows, counters and merchandise distinguish the stores. A full-height central drum, two tall kiosk backboards, two low counters and the shop walls provide different cover heights. The two existing underground 75 HP caches remain at the entry recesses. Four corner stairs connect to the streets; the north and south tunnels connect to spawn rooms. There is no hatch onto the hill, and underground occupants cannot capture through the floor.

Subway-assigned bots cross the shopping gallery and emerge on the opposing approach. The **M** atlas selects the underground page automatically below ground; **B** switches between the surface and concourse plans.

## Verification method

The first exposed-slab pass found 202 missing contacts. The final audit samples the actual authored MultiMesh transforms and custom closed meshes, then compares exposed floors, roofs, ceilings and major wall faces with independent physics rays. Buried faces and surfaces occluded by another solid are excluded. Headless verification retains the authored instance matrices because the dummy renderer cannot read GPU MultiMesh buffers back.

`tests/city_arcade_test.gd` drives an actual Nimbus capsule through all six stores, the central gallery, all four street exits, both station connections and both inner stairs in both directions. It also tests camera clearance, standing/crouching cover, unobstructed door lines, capture-height exclusion and real landings on the repaired conservatory, apartment and pavilion roofs.

`tests/city_navigation_regression.gd` verifies recovery from an empty navigation steering result without teleporting, exceeding path-update limits or granting resources. Progress monitoring uses a stable position anchor so back-and-forth crowd motion cannot keep resetting the watchdog indefinitely.

Run `tools/verify.ps1` for the regression suites, structural audit and arcade acceptance. Long simulations and renderer benchmarks use the commands in [the field guide](MERIDIAN_GARDENS.md). Raw current-state records are saved under [validation/meridian](validation/meridian).

The final build passes **530 regression checks** and **1,358 exposed structural surface probes**, with no failures or missing contacts. Both seeded ten-minute simulations pass fifteen checks, including both teams using the shopping gallery and promenade, with no persistent eight-second stalls, falls or recovery teleports. Rendered 1080p twelve-actor samples average **103.0 FPS above ground** and **105.9 FPS underground** on the current RTX 3080. Actual engine captures below were inspected for roof continuity, supporting structure, store clearance and map readability.

## In-engine views

![The shopping gallery and its central cover](media/meridian/10-meridian-exchange.png)

![Through-shops connecting the gallery and outer aisle](media/meridian/11-exchange-shops.png)

![Supported promenade and level landing](media/meridian/12-supported-promenade.png)

![Underground route and resource atlas](media/meridian/13-arcade-atlas.png)
