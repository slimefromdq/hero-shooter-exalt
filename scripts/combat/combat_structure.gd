class_name CombatStructure
extends StaticBody3D
## Physical cover: both teams collide, only enemies can damage it.
var source: HeroActor
var health: float = 250.0
var maximum: float = 250.0
var size: Vector3 = Vector3(2,4,.5)
var received: Dictionary = {}
var plate: Label3D
var stone: MeshInstance3D

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	add_to_group("structures")
	var bounds := BoxShape3D.new()
	bounds.size = size
	var collision := CollisionShape3D.new()
	collision.shape = bounds
	add_child(collision)
	var box := BoxMesh.new()
	box.size = size-Vector3(.035,.02,.015)
	stone = Geometry.mesh(self,box,Vector3.ZERO,Geometry.material(Color("354451")))
	for z: float in [-1.0,1.0]:
		for y: float in [-.3,.3]:
			Geometry.box(self,Vector3(size.x*.75,.065,.035),Vector3(0,size.y*y,z*(size.z/2+.025)),Color("d6b36f"),false)
		var rune: Node3D = Geometry.box(self,Vector3(.06,.6,.04),Vector3(0,.05,z*(size.z/2+.03)),Color("a9dfff"),false)
		rune.rotation.z = PI/4
	plate = Geometry.text3d(self,"",Vector3(0,size.y/2+.15,0),22,Color("ffdfa0"))
	plate.billboard = BaseMaterial3D.BILLBOARD_ENABLED

func _process(_delta: float) -> void:
	plate.text = "%d" % ceili(health)
	stone.scale = Vector3(1,1,1)
	stone.material_override.albedo_color = Color("354451").lerp(Color("a5675b"),1-health/maximum)

func nearest_point(origin: Vector3) -> Vector3:
	var at: Vector3 = to_local(origin)
	return to_global(at.clamp(-size/2,size/2))

func receive_damage(attacker: HeroActor, amount: float, id: int) -> void:
	if health <= 0 or not is_instance_valid(source) or not is_instance_valid(attacker): return
	if attacker.team == source.team or attacker.resolver.attack_locked(attacker) or received.has(id): return
	received[id] = true
	health = maxf(0,health-amount*attacker.resolver.cast_multiplier(id,attacker))
	CombatEffect.pulse(get_parent(),global_position,Color("b1dfff"),.35)
	if health <= 0:
		# Physics retires the collider after this cast; splash snapshots cover first.
		queue_free()
