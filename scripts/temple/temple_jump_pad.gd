class_name TempleJumpPad
extends Node3D
## Feet-on-top activation, per-actor rearming, and authored ballistic arrivals.
signal launched(actor: HeroActor)
var spec: Dictionary
var contacts: Dictionary = {}
var launch_count: int = 0
var sound: AudioStreamPlayer3D
var glow: MeshInstance3D

func _ready() -> void:
	add_to_group("temple_jump_pads")
	sound = AudioStreamPlayer3D.new()
	sound.stream = ProceduralSound.reward_wave("multi",3)
	sound.volume_db = -12
	sound.bus = "Combat"
	sound.max_distance = 60
	add_child(sound)
	glow = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 1.5
	ring.outer_radius = 1.75
	ring.rings = 24
	ring.ring_segments = 8
	glow.mesh = ring
	glow.position.y = .15
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("68e5dc")
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 1.5
	glow.material_override = material
	add_child(glow)

func launch_velocity(actor: HeroActor) -> Vector3:
	var duration: float = spec.flight_time
	# Semi-implicit 60 Hz gravity advances before displacement in the motor.
	return (Vector3(spec.destination)-actor.global_position)/duration+Vector3.UP*actor.tuning.gravity*(duration+1.0/60)/2

func _physics_process(delta: float) -> void:
	glow.rotation.y += delta*.8
	glow.position.y = .18+sin(Time.get_ticks_msec()*.004)*.04
	var present: Dictionary = {}
	for node: Node in get_tree().get_nodes_in_group("actors"):
		var actor := node as HeroActor
		if actor == null: continue
		var id: int = actor.get_instance_id()
		present[id] = true
		var offset: Vector3 = actor.global_position-global_position
		var on_top: bool = absf(offset.x)<=1.8 and absf(offset.z)<=1.8 and offset.y>=-.08 and offset.y<=.3 and actor.velocity.y<=.1
		var state: Dictionary = contacts.get(id,{"armed":true,"cooldown":0.0,"left":true,"life":actor.life_serial})
		if state.life != actor.life_serial: state = {"armed":true,"cooldown":0.0,"left":true,"life":actor.life_serial}
		state.cooldown = maxf(0,state.cooldown-delta)
		if not on_top: state.left = true
		if state.left and state.cooldown<=0: state.armed = true
		if on_top and state.armed and actor.alive and actor.motor.launch_from_pad(launch_velocity(actor),spec.flight_time):
			state.armed = false
			state.left = false
			state.cooldown = 1.0
			launch_count += 1
			sound.play()
			launched.emit(actor)
		contacts[id] = state
	for id: int in contacts.keys():
		if not present.has(id): contacts.erase(id)
