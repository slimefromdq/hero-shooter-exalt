class_name TrainingParkour
extends Node3D
## Independent route: existing tower exercise remains unchanged.
const START: Vector3 = Vector3(36,.1,20)
const CHECKPOINTS: Array[Vector3] = [Vector3(70,.1,20),Vector3(118,2.1,20),Vector3(164,3.1,20),Vector3(164,.1,-23),Vector3(112,.1,-23),Vector3(40,.1,-23)]
const TITLES: Array[String] = ["JUMP RHYTHM","MANTLE STEPS","WALL KICK","DIRECTIONAL DASH","MOMENTUM SLIDE","COMBINED FINISH"]
var training: TrainingManager
var running: bool = false
var checkpoint: int = 0
var elapsed: float = 0
var best: float = 0
var recovery: Vector3 = START
var markers: Array[Node3D] = []
var marker_materials: Array[StandardMaterial3D] = []
func _ready() -> void:
	Geometry.box(self,Vector3(147,1,65),Vector3(99,-.5,0),Color("829a94"))
	Geometry.text3d(self,"EXTENDED PARKOUR / TRAINING CONSOLE TO START",Vector3(36,4,16),25,Color("d7f4dc"))
	# Six broad lanes; safe floor beneath each obstacle supports retrying any hero.
	for index: int in CHECKPOINTS.size():
		var at: Vector3 = CHECKPOINTS[index]
		var marker: Node3D = Geometry.box(self,Vector3(4,.06,4),at+Vector3.UP*.02,Color("ffcd74"),false)
		markers.append(marker)
		marker_materials.append((marker.get_child(0) as MeshInstance3D).material_override)
		var sign := Geometry.text3d(self,"%d / %s" % [index+1,TITLES[index]],at+Vector3(0,3,-3),24,Color("e7f5d7"))
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var previous: Vector3 = START if index == 0 else CHECKPOINTS[index-1]
		var flat := Vector3(at.x,.03,at.z)
		previous.y = .03
		var guide: Node3D = Geometry.box(self,Vector3(.12,.025,previous.distance_to(flat)),(previous+flat)*.5,Color("cee1b0"),false)
		guide.look_at(flat,Vector3.UP)
	# Low hurdles followed by raised landing pads.
	for x: float in [45.0,53.0,61.0]:
		Geometry.box(self,Vector3(1,.8,8),Vector3(x,.4,20),Color("617d80"))
	# Mantle sequence: each rise is within shared mantle reach.
	for step: int in 4:
		Geometry.box(self,Vector3(4,(step+1)*.5,7),Vector3(102+step*4,(step+1)*.25,20),Color("617d80"))
	Geometry.box(self,Vector3(8,2,8),Vector3(118,1,20),Color("506b73"))
	# Wall kick corridor and a reachable final ledge, with lower retry platforms.
	Geometry.box(self,Vector3(24,5,.5),Vector3(148,2.5,15),Color("506b73"))
	Geometry.box(self,Vector3(5,1.3,5),Vector3(143,.65,19),Color("617d80"))
	Geometry.box(self,Vector3(5,2.1,5),Vector3(152,1.05,19),Color("617d80"))
	Geometry.box(self,Vector3(7,3,8),Vector3(164,1.5,20),Color("506b73"))
	# Direction changes and short platforms encourage aimed dashes without requiring abilities.
	for z: float in [8.0,-2.0,-12.0]:
		Geometry.box(self,Vector3(6,.8,4),Vector3(164,.4,z),Color("617d80"))
	# Approach steps reach the high end; runners never enter the ramp underside.
	Geometry.box(self,Vector3(4,1,7),Vector3(158,.5,-23),Color("617d80"))
	Geometry.box(self,Vector3(4,2,7),Vector3(154,1,-23),Color("617d80"))
	# Long, shallow ramp carries momentum into the marked slide lane.
	var ramp := Geometry.box(self,Vector3(25,.4,7),Vector3(141,1.6,-23),Color("719e99"))
	ramp.rotation_degrees.z = 7
	for x: float in [128.0,118.0]:
		Geometry.box(self,Vector3(4,.4,7),Vector3(x,2.0,-23),Color("506b73"))
		for z: float in [-27.0,-19.0]: Geometry.box(self,Vector3(.4,2,.4),Vector3(x,1,z),Color("506b73"))
	# Final combination of low jump, mantle and wall-jump opportunities.
	for x: float in [96.0,80.0,64.0,48.0]:
		Geometry.box(self,Vector3(3,1,6),Vector3(x,.5,-23),Color("617d80"))
	Geometry.box(self,Vector3(18,4,.5),Vector3(70,2,-28),Color("506b73"))
func start() -> void:
	checkpoint = 0
	elapsed = 0
	recovery = START
	running = true
	training.player.reset_actor(START)
	training.show_notice("PARKOUR / FOLLOW CHECKPOINTS 1–6 / SAFE FLOOR FOR RETRIES")
func recover() -> void:
	if not running: return
	training.player.reset_actor(recovery)
	training.player.health = 1 if training.prevent_death else training.player.effective_max_health()
	training.show_notice("CHECKPOINT RECOVERY / TIMER CONTINUES")
func reach_checkpoint(at: Vector3) -> bool:
	if not running or checkpoint >= CHECKPOINTS.size(): return false
	var destination: Vector3 = CHECKPOINTS[checkpoint]
	if Vector2(at.x-destination.x,at.z-destination.z).length() > 2.5 or absf(at.y-destination.y) > .65: return false
	recovery = CHECKPOINTS[checkpoint]+Vector3(0,.15,0)
	checkpoint += 1
	if checkpoint == CHECKPOINTS.size():
		running = false
		if best == 0 or elapsed < best: best = elapsed
		training.show_notice("PARKOUR COMPLETE / %.2fs / BEST %.2fs" % [elapsed,best])
	else: training.show_notice("CHECKPOINT %d/6 / %s" % [checkpoint,TITLES[checkpoint]])
	return true
func _process(delta: float) -> void:
	for index: int in marker_materials.size():
		marker_materials[index].albedo_color = Color("62efcf") if index < checkpoint else Color("ffcd74") if index == checkpoint else Color("697c80")
	if not running or training.menu_open: return
	elapsed += delta
	if not training.player.alive:
		recover()
		return
	reach_checkpoint(training.player.global_position)
