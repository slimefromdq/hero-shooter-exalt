class_name OverhealthVisual
extends Node3D
## Universal armor accents: thin teal bands leave the face and aim silhouette clear.
var actor: HeroActor
var armor: Node3D
var fracture: Node3D
var break_left: float = 0
var voice: ProceduralSound
var pulses: Array[CombatEffect] = []

func _ready() -> void:
	armor = Node3D.new()
	add_child(armor)
	fracture = Node3D.new()
	fracture.visible = false
	add_child(fracture)
	var mat := Geometry.material(ActorOverhealth.COLOR,1.1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for side: float in [-1.0,1.0]:
		var shoulder := BoxMesh.new()
		shoulder.size = Vector3(.06,.06,.42)
		Geometry.mesh(armor,shoulder,Vector3(side*.43,1.47,0),mat)
		var shard := BoxMesh.new()
		shard.size = Vector3(.035,.2,.035)
		Geometry.mesh(fracture,shard,Vector3(side*.5,1.25,-.2),mat).rotation.z = side*.6
	for height: float in [.85,1.2]:
		var ring := TorusMesh.new()
		ring.inner_radius = .375
		ring.outer_radius = .395
		Geometry.mesh(armor,ring,Vector3(0,height,0),mat).scale = Vector3(1,.4,.7)
	voice = ProceduralSound.new()
	voice.spatial_owner = actor
	add_child(voice)
	actor.overhealth_changed.connect(refresh)
	actor.overhealth_broken.connect(broken)
	actor.overhealth_cleared.connect(clear)
	refresh(actor.overhealth.value())
	if actor.tuning.hero_id == "marshal" and is_instance_valid(actor.presentation.marshal_model):
		armor.scale = Vector3(1.26,1.04,1.22)

func refresh(amount: float) -> void:
	armor.visible = actor.alive and amount > 0
	armor.position.y = -actor.motor.posture_lowering()

func broken() -> void:
	break_left = .22
	fracture.visible = true
	voice.play_tone(720,.13,.18)

func command(radius: float) -> void:
	voice.play_rally_shout()
	var pulse := CombatEffect.new()
	pulse.expanding = true
	pulse.radius = radius
	pulse.lifetime = .55
	pulse.initial_lifetime = .55
	actor.get_parent().add_child(pulse)
	pulse.global_position = actor.global_position+Vector3.UP*.06
	var ring := TorusMesh.new()
	ring.inner_radius = .985
	ring.outer_radius = 1.0
	var mat := Geometry.material(ActorOverhealth.COLOR,1.2)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = .65
	pulse.visual = Geometry.mesh(pulse,ring,Vector3.ZERO,mat)
	pulse.visual.scale.y = .2
	pulses.append(pulse)

func _process(delta: float) -> void:
	refresh(actor.overhealth.value())
	break_left = maxf(0,break_left-delta)
	fracture.visible = actor.alive and break_left > 0
	fracture.scale = Vector3.ONE*(1+(1-break_left/.22)*.6)
	for index: int in range(pulses.size()-1,-1,-1):
		if not is_instance_valid(pulses[index]): pulses.remove_at(index)

func clear() -> void:
	break_left = 0
	if is_instance_valid(armor): armor.visible = false
	if is_instance_valid(fracture): fracture.visible = false
	if is_instance_valid(voice): voice.stop()
	for pulse in pulses:
		if is_instance_valid(pulse): pulse.queue_free()
	pulses.clear()

func _exit_tree() -> void:
	clear()
