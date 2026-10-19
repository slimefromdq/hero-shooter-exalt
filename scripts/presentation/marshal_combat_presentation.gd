class_name MarshalCombatPresentation
extends Node3D
## Marshal-only presentation. Never applies combat damage or changes cooldowns.
var presentation: HeroPresentation
var flash_mesh: MeshInstance3D
var report: ProceduralSound
var mechanism: ProceduralSound
var impact_voice: ProceduralSound
var orbital_voices: Array[ProceduralSound] = []
var orbital_anchors: Array[Node3D] = []
var voice_cursor: int = 0
var reload_was_active: bool = false
var previous_state: String = ""
var barrier_was_broken: bool = false
var shot_age: float = 99
var last_impact: String = ""

func voice(parent: Node, owner: Node3D) -> ProceduralSound:
	var sound := ProceduralSound.new()
	sound.spatial_owner = owner
	parent.add_child(sound)
	return sound

func _ready() -> void:
	report = voice(self,presentation.actor)
	mechanism = voice(self,presentation.actor)
	impact_voice = voice(self,presentation.actor)
	for index: int in 4:
		var anchor := Node3D.new()
		add_child(anchor)
		anchor.top_level = true
		orbital_anchors.append(anchor)
		orbital_voices.append(voice(anchor,anchor))
	var mesh := TorusMesh.new()
	mesh.inner_radius = .11
	mesh.outer_radius = .32
	flash_mesh = Geometry.mesh(presentation.rifle,mesh,Vector3(0,.04,-.91),Geometry.material(Color("ffe1a3"),2.8))
	flash_mesh.rotation.x = PI/2
	flash_mesh.visible = false

func fire() -> void:
	shot_age = 0
	flash_mesh.visible = true
	report.play_marshal("cannon")

func projectile_impact(at: Vector3, category: String) -> void:
	last_impact = category
	impact_voice.play_marshal("cannon_blast")
	CombatEffect.pulse(presentation.actor.get_parent(),at,Color("dcb277") if category == "world" else Color("96e2ed"),.45)

func orbital_marker(entry: Dictionary, radius: float) -> MarshalOrbitalEffect:
	if not bool(entry.valid) or get_tree().get_nodes_in_group("marshal_orbital_effects").size() >= MarshalOrbitalEffect.MAX_WORLD: return null
	var effect := MarshalOrbitalEffect.new()
	effect.radius = radius
	effect.delay = entry.delay
	presentation.actor.get_parent().add_child(effect)
	effect.global_position = entry.position
	effect.marker.quaternion = Quaternion(Vector3.UP,entry.normal)
	effect.ring.quaternion = Quaternion(Vector3.UP,entry.normal)
	return effect

func orbital_impact(at: Vector3) -> void:
	orbital_anchors[voice_cursor].global_position = at
	orbital_voices[voice_cursor].play_marshal("orbital")
	voice_cursor = (voice_cursor+1)%orbital_voices.size()

func orbital_block(at: Vector3) -> void:
	CombatEffect.streak(presentation.actor.get_parent(),at+Vector3.UP*16,at,.08,.12)
	orbital_impact(at)

func barrier_hit(broken: bool) -> void:
	impact_voice.play_marshal("barrier_break" if broken else "barrier_hit")

func _process(delta: float) -> void:
	var a: HeroActor = presentation.actor
	shot_age += delta
	flash_mesh.visible = a.alive and a.state != "marshal_shield" and shot_age < .065
	flash_mesh.scale = Vector3.ONE*(.85+maxf(0,1-shot_age/.065)*.25)
	if not a.alive: return
	if a.state != previous_state:
		if a.state == "marshal_shield": mechanism.play_marshal("barrier_raise")
		elif previous_state == "marshal_shield" and (a.kit as MarshalKit).break_remaining <= 0: mechanism.play_marshal("barrier_lower")
	previous_state = a.state
	var broken: bool = (a.kit as MarshalKit).break_remaining > 0
	if broken: barrier_was_broken = true
	elif barrier_was_broken and (a.kit as MarshalKit).barrier_hp > 0:
		mechanism.play_marshal("barrier_ready")
		barrier_was_broken = false
	if a.kit.reloading != reload_was_active:
		mechanism.play_marshal("reload_start" if a.kit.reloading else "reload_end")
	reload_was_active = a.kit.reloading

func clear() -> void:
	shot_age = 99
	last_impact = ""
	previous_state = ""
	reload_was_active = false
	barrier_was_broken = false
	if is_instance_valid(flash_mesh): flash_mesh.visible = false
	for sound in [report,mechanism,impact_voice]+orbital_voices:
		if is_instance_valid(sound): sound.stop()

func _exit_tree() -> void:
	clear()
