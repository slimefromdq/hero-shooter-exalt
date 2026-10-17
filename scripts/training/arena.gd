extends Node3D

var player: HeroActor
var resolver: CombatResolver
var training: TrainingManager

func _ready() -> void:
	TrainingInputs.install()
	resolver = CombatResolver.new()
	add_child(resolver)
	build_environment()
	player = preload("res://scenes/actors/hero_actor.tscn").instantiate() as HeroActor
	player.position = Vector3(0, 0.1, 11)
	player.tuning = HeroRoster.tuning_for(HeroRoster.selected)
	player.actor_id = HeroRoster.selected
	add_child(player)
	var controller := PlayerController.new()
	controller.actor = player
	player.add_child(controller)
	player.controller = controller
	training = TrainingManager.new()
	training.arena = self
	training.player = player
	add_child(training)

func build_environment() -> void:
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("a7bdc3")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("b9d1db")
	settings.ambient_light_energy = 0.35
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.environment = settings
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -28, 0)
	sun.light_color = Color("fff0da")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	add_child(sun)
	Geometry.box(self, Vector3(56, 1, 62), Vector3(0, -0.5, 0), Color("aeb5a5"))
	Geometry.box(self, Vector3(18, 0.018, 49), Vector3(0, 0.01, -3), Color("8c9b93"), false)
	for x: float in [-28.0, 28.0]:
		Geometry.box(self, Vector3(1, 5, 62), Vector3(x, 2.0, 0), Color("384e57"))
	Geometry.box(self, Vector3(56, 8, 1), Vector3(0, 3.5, -31), Color("293f4a"))
	Geometry.box(self, Vector3(56, 3, 1), Vector3(0, 1, 31), Color("384e57"))
	Geometry.text3d(self, "FIELD DIVISION", Vector3(0, 5.3, -30.4), 150, Color("dce8dc"))
	Geometry.text3d(self, "01   /   HEROES     •     LIVE EXERCISE", Vector3(0, 3.7, -30.35), 42, Color("72d2c5"))
	for x: float in [-9.0, 9.0]:
		Geometry.box(self, Vector3(0.07, 0.015, 47), Vector3(x, 0.012, -3), Color("f4e7bf"), false)
	for z: float in [8.0, 0.0, -8.0, -16.0, -24.0]:
		Geometry.box(self, Vector3(18, 0.015, 0.045), Vector3(0, 0.014, z), Color("e7e3d3"), false)
		var mark := Geometry.text3d(self, "%02d m" % int(10 - z), Vector3(8, 0.025, z + 0.5), 30, Color("506568"))
		mark.rotation_degrees.x = -90
	for at: Vector3 in [Vector3(-5, 1.1, -6), Vector3(5.2, 1.1, -15), Vector3(-3, 1.1, -22)]:
		Geometry.box(self, Vector3(3.8, 2.2, 1.4), at, Color("61767a"))
		Geometry.box(self, Vector3(3.85, 0.08, 1.45), at + Vector3(0, 1.12, 0), Color("8be0c4"), false)
	Geometry.box(self, Vector3(5, 2.4, 6), Vector3(-18, 1.2, -12), Color("7b8d8d"))
	var ramp := Geometry.box(self, Vector3(5, 0.5, 10), Vector3(-18, 1.1, -4), Color("719e99"))
	ramp.rotation_degrees.x = 14
	Geometry.box(self, Vector3(4, 1, 5), Vector3(18, 0.5, 3), Color("8da39e"))
	Geometry.box(self, Vector3(3, 2.4, 4), Vector3(18, 1.2, -4), Color("829896"))
	Geometry.box(self, Vector3(2.2, 3.5, 4), Vector3(18, 1.75, -11), Color("617d80"))
	Geometry.box(self, Vector3(6, 4.5, 6), Vector3(18, 2.25, -20), Color("506b73"))
	Geometry.text3d(self, "02   /   TRAVERSAL", Vector3(18, 5.5, -23), 45, Color("d7f4dc"))
	# A reachable ledge and a taller kick wall beside the existing tower route.
	Geometry.box(self,Vector3(3,2,3),Vector3(12,1,6),Color("617d80"))
	Geometry.box(self,Vector3(3.08,.06,3.08),Vector3(12,2.03,6),Color("8be0c4"),false)
	Geometry.text3d(self,"HOLD SPACE + MOVE\nMANTLE",Vector3(12,2.8,6),24,Color("d7f4dc"))
	Geometry.box(self,Vector3(.5,5.5,5),Vector3(11,2.75,-2),Color("506b73"))
	var kick_sign := Geometry.text3d(self,"AIR + SPACE\nWALL JUMP",Vector3(11.3,4,-2),23,Color("d7f4dc"))
	kick_sign.rotation_degrees.y = 90
	Geometry.text3d(self, "03   /   MOMENTUM", Vector3(-18, 3.6, -15), 45, Color("d7f4dc"))
	for x: float in [-25.0, 25.0]:
		for z: float in [-24.0, -4.0, 16.0]:
			Geometry.box(self, Vector3(0.4, 7, 0.4), Vector3(x, 3.5, z), Color("233d47"))
			Geometry.box(self, Vector3(1.6, 0.15, 0.6), Vector3(x, 7, z), Color("edeee0"), false)
