class_name MuseumPayload
extends StaticBody3D
## Collision remains authoritative. Each short path step transports riders and
## clears pedestrians before the cart moves; actors never vote on progress.
var session: MuseumMatch
var distance: float = 0

func _ready() -> void:
	name = "ArtifactTransport"
	collision_layer = 1
	collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.4,.5,3.4)
	shape.shape = box
	shape.position.y = .25
	add_child(shape)
	var platform := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = box.size
	platform.mesh = mesh
	platform.position.y = .25
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("263d50")
	material.metallic = .6
	platform.material_override = material
	add_child(platform)
	var core_shape := CollisionShape3D.new()
	var core_box := BoxShape3D.new()
	core_box.size = Vector3(1.3,2,1.3)
	core_shape.shape = core_box
	core_shape.position.y = 1.5
	add_child(core_shape)
	var core := MeshInstance3D.new()
	# The solid monolith matches its cover collider and provides a flat rider
	# surface; a tapered visual over this box would create invisible bullet cover.
	var crystal := BoxMesh.new()
	crystal.size = core_box.size
	core.mesh = crystal
	core.position.y = 1.5
	var crystal_mat := StandardMaterial3D.new()
	crystal_mat.albedo_color = Color("7bcac2")
	crystal_mat.emission_enabled = true
	crystal_mat.emission = Color("224b58")
	core.material_override = crystal_mat
	add_child(core)

func reset_cart() -> void:
	distance = 0
	global_position = session.museum_definition().path_position(0)

func move_to_distance(next_distance: float) -> void:
	var definition: MuseumMapDefinition = session.museum_definition()
	while absf(next_distance-distance) > .00001:
		var step: float = clampf(next_distance-distance,-.12,.12)
		var next: Vector3 = definition.path_position(distance+step)
		var motion: Vector3 = next-global_position
		for actor: HeroActor in session.actors:
			if not actor.alive: continue
			var local: Vector3 = actor.global_position-global_position
			actor.add_collision_exception_with(self)
			var platform_rider: bool = absf(local.x) < 1.95 and absf(local.z) < 1.95 and local.y >= .42 and local.y < .8
			var artifact_rider: bool = absf(local.x) < 1.03 and absf(local.z) < 1.03 and local.y >= 2.42 and local.y < 2.8
			if platform_rider or artifact_rider:
				# Checked movement preserves a rider's position on the platform.
				actor.move_and_collide(motion)
			elif absf(actor.global_position.x-next.x) < 2.1 and absf(actor.global_position.z-next.z) < 2.1 and local.y > -.5 and local.y < 2.5:
				var outward: Vector3 = local*Vector3(1,0,1)
				if outward.length_squared() < .01: outward = Vector3.RIGHT
				# Search capsule-clear sides before using the broad open track shoulder.
				var escaped: bool = false
				for direction: Vector3 in [outward.normalized(),Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]:
					var target: Vector3 = next+direction*2.35
					target.y = maxf(actor.global_position.y,next.y+.05)
					var displacement: Vector3 = target-actor.global_position
					if not actor.test_move(actor.global_transform,displacement):
						actor.move_and_collide(displacement)
						escaped = true
						break
				if not escaped:
					# Vertical evacuation is swept, never a recovery teleport.
					actor.move_and_collide(Vector3.UP*maxf(0,next.y+2.55-actor.global_position.y))
			actor.remove_collision_exception_with(self)
		global_position = next
		force_update_transform()
		distance += step
