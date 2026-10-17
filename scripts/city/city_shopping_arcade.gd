class_name MeridianShoppingArcade
extends RefCounted
## Lower Meridian Exchange occupies the space directly below the conservatory.
## Six through-shops sit between a central gallery and the original perimeter loop.

static func build(kit: MeridianArchitecture) -> void:
	kit.box(Vector3(42, .4, 42), Vector3(0, -5.2, 0), "paving", true)
	# Ceiling openings match the surface holes and the two direct hill stairs.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(18, .25, 42), Vector3(side * 12, -.825, 0), "stone_dark", true)
	kit.box(Vector3(6, .25, 20), Vector3(0, -.825, 0), "stone_dark", true)
	# Retaining walls close the underground volume. Openings align with the six stairs.
	for side: float in [-1.0, 1.0]:
		kit.box(Vector3(.4, 4.3, 42), Vector3(side * 21, -2.85, 0), "blue", true)
		for x: float in [-9.0, 9.0]:
			kit.box(Vector3(11.8, 4.3, .4), Vector3(x, -2.85, side * 21), "blue", true)
		for x: float in [-20.65, -15.35, -3.25, 3.25, 15.35, 20.65]:
			kit.box(Vector3(.35, 4.1, .5), Vector3(x, -2.95, side * 20.75), "ivory", true)
		kit.box(Vector3(42, .24, .26), Vector3(0, -1.05, side * 20.65), "trim")
		kit.box(Vector3(.26, .24, 42), Vector3(side * 20.65, -1.05, 0), "trim")
	# The orrery's load-bearing drum visibly continues through the floor above.
	kit.cylinder(3.15, 4.05, Vector3(0, -2.975, 0), "ivory", true)
	kit.cylinder(3.4, .25, Vector3(0, -4.875, 0), "stone_dark", true)
	kit.cylinder(3.4, .25, Vector3(0, -1.075, 0), "brass", true)
	kit.piece("ring", Vector3(8.2, .04, 8.2), Vector3(0, -4.96, 0), "brass")
	for z: float in [-15.5, 15.5]:
		for x: float in [-6.8, 6.8]:
			kit.box(Vector3(.8, 4.05, .8), Vector3(x, -2.975, z), "ivory", true)
			kit.box(Vector3(1.15, .25, 1.15), Vector3(x, -4.875, z), "stone_dark")
			kit.box(Vector3(1.15, .22, 1.15), Vector3(x, -1.06, z), "trim")
		for side: float in [-1.0, 1.0]:
			kit.box(Vector3(4, .4, .55), Vector3(side * 5.25, -1.2, z), "ivory", true)
	# Recessed ceiling coffers and connected structural beams leave four metres of headroom.
	for x: float in [-6.8, 6.8]:
		kit.box(Vector3(.45, .32, 31.5), Vector3(x, -1.13, 0), "ivory", true)
	for z: float in [-10.0, 0.0, 10.0]:
		if z == 0:
			kit.box(Vector3(42, .3, .45), Vector3(0, -1.1, z), "ivory", true)
		else:
			for side: float in [-1.0, 1.0]:
				kit.box(Vector3(18, .3, .45), Vector3(side * 12, -1.1, z), "ivory", true)
		for x: float in [-5.2, 5.2, -18.0, 18.0]:
			kit.box(Vector3(.24, .06, 2.4), Vector3(x, -1.31, z), "lamp")
			kit.lamp_positions.append(Vector3(x, -2.0, z))
	for x: float in [-5.0, 5.0]:
		for z: float in [-11.0, 11.0]:
			var light := OmniLight3D.new()
			light.position = Vector3(x, -1.65, z)
			light.light_color = Color("ffd2a1")
			light.light_energy = 1.0
			light.omni_range = 10
			kit.owner_node.add_child(light)
	var names: Array[String] = ["MOON & QUILL", "STARLING TAILORS", "ASTRA PATISSERIE", "BOTANICA GIFTS", "THAUMA WORKSHOP", "MERIDIAN MAPS"]
	var shop_index: int = 0
	for side: float in [-1.0, 1.0]:
		for z: float in [-10.0, 0.0, 10.0]:
			_shop(kit, side, z, names[shop_index], shop_index)
			shop_index += 1
	# Staggered kiosks create short crossfire breaks without sealing the central gallery.
	for side: float in [-1.0, 1.0]:
		var center := Vector3(side * 5.1, -5, side * 7)
		kit.box(Vector3(2.8, 1.25, 2.1), center + Vector3.UP * .625, "rose", true)
		kit.box(Vector3(3.0, .14, 2.3), center + Vector3.UP * 1.32, "brass", true)
		kit.box(Vector3(2.8, 2.25, .28), center + Vector3(0, 1.125, side * .9), "stone_dark", true)
		kit.box(Vector3(2.35, 1.2, .08), center + Vector3(0, 1.5, side * 1.07), "glass")
		kit.label("NIGHT MARKET", center + Vector3(0, 1.85, side * 1.12), 15, Color("d5b8e9"), 0 if side > 0 else PI)
		kit.box(Vector3(2.4, 1.1, 1.4), Vector3(-side * 5.0, -4.45, side * 9), "ivory", true)
		kit.box(Vector3(2.5, .12, 1.5), Vector3(-side * 5.0, -3.84, side * 9), "trim")
		# Opaque alcove returns shelter the existing subway health cache, off the throughline.
		kit.box(Vector3(2.0, 2.4, .4), Vector3(side * 4.7, -3.8, side * 17.2), "blue", true)
		kit.label("STATION  ↗", Vector3(0, -1.95, side * 20.4), 17, Color("a8d6e4"), 0 if side < 0 else PI)
	# Flush brass borders distinguish the three generous pedestrian aisles.
	for x: float in [-15.7, -8.3, 8.3, 15.7]:
		kit.box(Vector3(.05, .015, 40), Vector3(x, -4.99, 0), "brass")

static func _shop(kit: MeridianArchitecture, side: float, z: float, caption: String, index: int) -> void:
	var front: float = side * 9.0
	var back: float = side * 15.0
	var center: float = side * 12.0
	var key: String = "rose" if index % 2 == 0 else "blue"
	kit.box(Vector3(5.7, .018, 6.7), Vector3(center, -4.99, z), "paving_light")
	kit.box(Vector3(6.3, .3, 7.4), Vector3(center, -1.05, z), "slate", true)
	for end: float in [-1.0, 1.0]:
		kit.box(Vector3(6.0, 3.8, .3), Vector3(center, -3.1, z + end * 3.5), key, true)
		kit.box(Vector3(.55, 3.8, .55), Vector3(front, -3.1, z + end * 3.35), "ivory", true)
		# Front displays leave a 3.4 m open doorway; rear doors create real through-shops.
		kit.box(Vector3(.2, 2.6, 1.35), Vector3(front, -3.35, z + end * 2.5), "glass", true)
		kit.box(Vector3(.35, 3.8, 1.7), Vector3(back, -3.1, z + end * 2.65), key, true)
	kit.box(Vector3(.5, .52, 7.2), Vector3(front, -1.24, z), "brass", true)
	kit.box(Vector3(.4, .45, 3.6), Vector3(back, -1.3, z), "ivory", true)
	kit.label(caption, Vector3(front - side * .29, -1.76, z), 19, Color("f1d4a3"), -side * PI * .5)
	kit.label("EXCHANGE  /  " + ("WEST" if side < 0 else "EAST"), Vector3(back + side * .22, -1.84, z), 12, Color("a7c8d9"), side * PI * .5)
	# Counters and shelves occupy one side, leaving the front/rear doorway line open.
	kit.box(Vector3(3.2, 1.05, 1.0), Vector3(center, -4.475, z + 2.3), "brick", true)
	kit.box(Vector3(3.35, .12, 1.1), Vector3(center, -3.89, z + 2.3), "brass", true)
	kit.box(Vector3(3.4, 2.4, .45), Vector3(center, -3.8, z - 3.1), "stone_dark", true)
	for shelf: int in 3:
		kit.box(Vector3(3.5, .08, .65), Vector3(center, -4.2 + shelf * .7, z - 2.95), "brass")
		for item: int in 6:
			var at := Vector3(center - 1.4 + item * .55, -4.02 + shelf * .7, z - 2.9)
			if index == 0 or index == 5:
				kit.box(Vector3(.18, .28, .35), at, "rose" if item % 2 == 0 else "blue")
			elif index == 4:
				kit.piece("sphere", Vector3(.23, .32, .23), at, "violet" if item % 3 == 0 else "brass")
			elif index == 1:
				kit.box(Vector3(.32, .14, .38), at, "rose" if item % 2 else "blue")
			elif index == 3:
				kit.cylinder(.1, .16, at, "brick")
				kit.piece("sphere", Vector3(.2, .18, .2), at + Vector3.UP * .13, "leaf")
				kit.piece("sphere", Vector3(.08, .08, .08), at + Vector3.UP * .24, "flower")
			else:
				kit.cylinder(.12, .24, at, "cream")
				kit.piece("sphere", Vector3(.08, .06, .08), at + Vector3.UP * .14, "flower")
	kit.box(Vector3(3, .06, .22), Vector3(center, -1.25, z), "lamp")
	kit.lamp_positions.append(Vector3(center, -2, z))
