class_name WispEffects
extends Node3D
## Short-lived procedural cards, silk-colored smoke and collision-free decoys.
var source: HeroActor
var source_life: int
var meshes: Array[Node] = []
var remaining: float = .35
var duration: float = .35
var spin: float = 1.5

static func afterimage(actor: HeroActor) -> void:
	var effect := WispEffects.new()
	effect.source = actor
	actor.get_parent().add_child(effect)
	effect.global_transform = actor.global_transform
	for mesh: MeshInstance3D in actor.presentation.body.find_children("*","MeshInstance3D",true,false):
		if not mesh.is_visible_in_tree(): continue
		var copy := MeshInstance3D.new()
		copy.mesh = mesh.mesh
		var mat := Geometry.material(Color("aa65ed"),.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = .45
		copy.material_override = mat
		effect.add_child(copy)
		copy.global_transform = mesh.global_transform
	effect.meshes = effect.find_children("*","MeshInstance3D",true,false)
	effect.spin = 0

static func flourish(actor: HeroActor, at: Vector3, size: float) -> void:
	var effect := WispEffects.new()
	effect.source = actor
	actor.get_parent().add_child(effect)
	effect.global_position = at
	effect.scale = Vector3.ONE*size
	for i: int in 4:
		var angle: float = i*TAU/4
		var card: Node3D = Geometry.box(effect,Vector3(.13,.2,.012),Vector3(cos(angle)*.35,.08*i,sin(angle)*.35),Color("f4dfff"),false)
		card.rotation = Vector3(.2,angle,.4)
		Geometry.box(card,Vector3(.06,.07,.018),Vector3(0,0,-.01),Color("9d40d7"),false).rotation.z = PI/4
		var puff: MeshInstance3D = RosterVisuals.orb(effect,Vector3(cos(angle)*.2,0,sin(angle)*.2),Vector3.ONE*.45,"7e35b0")
		(puff.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		(puff.material_override as StandardMaterial3D).albedo_color.a = .3

	effect.meshes = effect.find_children("*","MeshInstance3D",true,false)

func _ready() -> void:
	source_life = source.life_serial
	add_to_group("transient")
	add_to_group("owned_attacks")

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0 or not is_instance_valid(source) or not source.alive or source.life_serial != source_life or not source.kit is WispKit:
		queue_free()
		return
	rotation.y += delta*spin
	for mesh: MeshInstance3D in meshes:
		var mat := mesh.material_override as StandardMaterial3D
		if mat.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = minf(mat.albedo_color.a,remaining/duration*.45)
