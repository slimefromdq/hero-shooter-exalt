class_name MovementBurst
extends Node3D
## Bounded procedural world-space effects; no particles or gameplay RNG.
var kind: String = "jump"
var direction: Vector3 = Vector3.FORWARD
var normal: Vector3 = Vector3.UP
var intensity: float = 1
var age: float = 0
var duration: float = .3
var materials: Array[StandardMaterial3D] = []
var expanding: bool = false

static func spawn(parent: Node, type: String, at: Vector3, travel: Vector3, surface: Vector3, strength: float) -> MovementBurst:
	if parent.get_tree().get_nodes_in_group("movement_effect").size() >= 64: return null
	var result := MovementBurst.new()
	result.kind = type
	result.direction = travel.normalized() if not travel.is_zero_approx() else Vector3.FORWARD
	result.normal = surface.normalized() if not surface.is_zero_approx() else Vector3.UP
	result.intensity = strength
	result.top_level = true
	parent.add_child(result)
	result.global_position = at
	return result

func _ready() -> void:
	add_to_group("transient")
	add_to_group("movement_effect")
	var energy: StandardMaterial3D = material(Color("c7f6f5"),.8)
	var dust: StandardMaterial3D = material(Color("dfd6be"),.28)
	var forward: Vector3 = direction.slide(normal).normalized()
	if forward.is_zero_approx(): forward = normal.cross(Vector3.RIGHT).normalized()
	if forward.is_zero_approx(): forward = normal.cross(Vector3.FORWARD).normalized()
	var side: Vector3 = forward.cross(normal).normalized()
	match kind:
		"jump", "landing", "wall_jump":
			expanding = true
			duration = .32
			ring(normal,.28 if kind == "jump" else .44,energy if kind == "wall_jump" else dust)
			for i: int in 7:
				var radial: Vector3 = forward.rotated(normal,TAU*i/7.0)
				stroke(radial*.15,radial*(.5 if kind == "jump" else .85)+normal*.1,.035,energy if kind == "wall_jump" else dust)
		"dash":
			duration = .23
			ring(direction,.5,energy)
			for sign_value: float in [-1,1]: stroke(side*.4*sign_value-direction*.7,side*.4*sign_value+direction*.45,.045,energy)
		"dash_trail", "air_melee":
			duration = .18
			for sign_value: float in [-1,1]: stroke(side*.25*sign_value,direction*-.7+side*.25*sign_value,.028,energy)
		"slide_dust":
			duration = .22
			for sign_value: float in [-1,1]: stroke(side*.25*sign_value,-forward*.5+side*.4*sign_value+normal*.06,.045,dust)
		"slide", "dash_slide", "mantle_slide":
			duration = .34
			for i: int in 7:
				var offset: float = (i-3)*.12
				stroke(side*offset,forward*(1.15 if kind != "slide" else .65)+side*offset*2+normal*.04,.035,energy if kind != "slide" else dust)
		"mantle", "mantle_hands":
			duration = .19
			for sign_value: float in [-1,1]:
				stroke(side*.28*sign_value+normal*.04,side*.28*sign_value+normal*.2,.035,energy)
		"melee":
			duration = .23
			# Arc lies across the actual aimed strike, including vertical attacks.
			var axis: Vector3 = direction.cross(Vector3.UP).normalized()
			if axis.is_zero_approx(): axis = Vector3.RIGHT
			var up: Vector3 = axis.cross(direction).normalized()
			for i: int in 9:
				var a: float = lerpf(-1.1,1.1,i/9.0)
				var b: float = lerpf(-1.1,1.1,(i+1)/9.0)
				stroke(direction*.65+(axis*sin(a)+up*cos(a))*.7,direction*.65+(axis*sin(b)+up*cos(b))*.7,.045,energy)
	scale = Vector3.ONE*(.7 if intensity < .7 else 1)

func material(color: Color, alpha: float) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.albedo_color.a = alpha*intensity
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.no_depth_test = false
	result.emission_enabled = true
	result.emission = color
	result.emission_energy_multiplier = .65
	materials.append(result)
	return result

func stroke(from: Vector3, to: Vector3, width: float, mat: StandardMaterial3D) -> void:
	var shape := BoxMesh.new()
	shape.size = Vector3(width,width,from.distance_to(to))
	var mesh: MeshInstance3D = Geometry.mesh(self,shape,(from+to)*.5,mat)
	mesh.basis = Basis.looking_at((to-from).normalized(),Vector3.RIGHT if absf((to-from).normalized().y) > .99 else Vector3.UP)

func ring(surface: Vector3, radius: float, mat: StandardMaterial3D) -> void:
	var shape := TorusMesh.new()
	shape.inner_radius = radius-.025
	shape.outer_radius = radius+.025
	shape.rings = 20
	shape.ring_segments = 5
	var mesh: MeshInstance3D = Geometry.mesh(self,shape,Vector3.ZERO,mat)
	mesh.quaternion = Quaternion(Vector3.UP,surface)

func _process(delta: float) -> void:
	age += delta
	var fade: float = maxf(0,1-age/duration)
	for mat: StandardMaterial3D in materials:
		mat.albedo_color.a = (.8 if mat == materials[0] else .28)*intensity*fade
	if expanding: scale = Vector3.ONE*(.7+age*2.8)*(.7 if intensity < .7 else 1)
	if age >= duration: queue_free()
