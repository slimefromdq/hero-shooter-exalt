class_name MarshalOrbitalEffect
extends Node3D
## Bounded mesh effect, no particles/lights/colliders. Physics alone triggers impact.
const MAX_WORLD: int = 40
var age: float = 0
var delay: float = .4
var impact_age: float = -1
var marker: MeshInstance3D
var ray_mesh: MeshInstance3D
var column: Node3D
var ring: MeshInstance3D
var dust: Array[MeshInstance3D] = []
var radius: float = 2
var height: float = 16

func _ready() -> void:
	add_to_group("transient")
	add_to_group("marshal_orbital_effects")
	var torus := TorusMesh.new()
	torus.inner_radius = .96
	torus.outer_radius = 1.0
	marker = Geometry.mesh(self,torus,Vector3.UP*.045,Geometry.material(Color("d7ad6a"),1.2))
	marker.scale = Vector3(radius,.08,radius)
	for side: float in [-1.0,1.0]:
		Geometry.box(marker,Vector3(.04,.02,.28),Vector3(side*.72,0,0),Color("f3dfac"),false)
	var needle := CylinderMesh.new()
	needle.top_radius = .018
	needle.bottom_radius = .018
	needle.height = height*.25
	ray_mesh = Geometry.mesh(self,needle,Vector3.UP*height*.875,Geometry.material(Color("69dcf5"),1.3))
	ray_mesh.visible = false
	column = Node3D.new()
	add_child(column)
	for width: float in [.065,.2]:
		var beam := CylinderMesh.new()
		beam.top_radius = width
		beam.bottom_radius = width*1.4
		beam.height = height
		var mat := Geometry.material(Color("fff6d7") if width < .1 else Color("78d8f0"),3.0)
		if width > .1:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = .2
		Geometry.mesh(column,beam,Vector3.UP*height*.5,mat)
	column.visible = false
	ring = Geometry.mesh(self,torus,Vector3.UP*.06,Geometry.material(Color("a2e5ef"),1.4))
	ring.visible = false
	for index: int in 6:
		var puff := SphereMesh.new()
		puff.radius = .15
		puff.height = .14
		var mat := Geometry.material(Color("a69e8f"))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = .28
		var mesh: MeshInstance3D = Geometry.mesh(self,puff,Vector3.ZERO,mat)
		mesh.visible = false
		dust.append(mesh)

func strike() -> void:
	impact_age = 0
	marker.visible = false
	ray_mesh.visible = false
	column.visible = true
	ring.visible = true
	for puff: MeshInstance3D in dust: puff.visible = true

func _process(delta: float) -> void:
	age += delta
	if impact_age < 0:
		ray_mesh.visible = age >= delay-.12
		ray_mesh.position.y = lerpf(height*.875,height*.125,clampf((age-delay+.12)/.12,0,1))
		if age > delay+1.0: queue_free()
		return
	impact_age += delta
	column.visible = impact_age < .14
	column.scale.x = maxf(.04,1-impact_age/.14)
	column.scale.z = column.scale.x
	var progress: float = clampf(impact_age/.42,0,1)
	ring.scale = Vector3(1,.04,1)*maxf(.05,radius*progress)
	for index: int in dust.size():
		var angle: float = index*TAU/dust.size()
		dust[index].position = Vector3(cos(angle),.1,sin(angle))*radius*progress+Vector3.UP*sin(progress*PI)*.25
		dust[index].scale = Vector3.ONE*(.4+progress*1.7)
		(dust[index].material_override as StandardMaterial3D).albedo_color.a = .28*(1-progress)
	if impact_age >= .45: queue_free()
