extends SceneTree
## Imported Blender skin, live actors, cosmetic lifecycle and rendered pose checks.
var checks: int = 0
var failures: Array[String] = []
var world: Node3D
var camera: Camera3D
var actor: HeroActor
var twin: HeroActor
var capture: bool = false
const OUT := "res://artifacts/marshal-character/"

func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	print("PASS  " if ok else "FAIL  ",caption)
	if not ok: failures.append(caption)
func step(count: int = 1) -> void:
	for i: int in count:
		await physics_frame
		await process_frame
func spawn(team: int, at: Vector3) -> HeroActor:
	var result := HeroActor.new()
	result.tuning = HeroRoster.tuning_for("marshal")
	result.actor_id = "Marshal"
	result.team = team
	result.position = at
	world.add_child(result)
	return result
func image(label: String) -> void:
	if not capture: return
	await process_frame
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OUT+label+".png")==OK,"rendered "+label)
func bone_point(driver: MarshalCharacterDriver, name: String) -> Vector3:
	return driver.rig.get_bone_global_pose(driver.bones[name]).origin

func run() -> void:
	capture = DisplayServer.get_name() != "headless"
	DirAccess.make_dir_recursive_absolute(OUT)
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var resolver := CombatResolver.new()
	world.add_child(resolver)
	Geometry.box(world,Vector3(40,1,40),Vector3(0,-.5,0),Color("424d59"))
	var light := DirectionalLight3D.new()
	world.add_child(light)
	light.rotation_degrees = Vector3(-45,-35,0)
	light.light_energy = 1.5
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("202c3d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("bdcddd")
	env.environment.ambient_light_energy = .7
	world.add_child(env)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(3.2,2.5,-5.5)
	camera.look_at(Vector3(0,1.32,0))
	camera.current = true
	camera.fov = 38
	actor = spawn(0,Vector3(0,.01,0))
	twin = spawn(1,Vector3(-3,.01,0))
	await step(5)
	var p := actor.presentation
	var driver := p.marshal_model
	check(is_instance_valid(driver) and driver.active,"Marshal uses the authored Blender model by default")
	if not is_instance_valid(driver): quit(1); return
	check(driver.rig.get_bone_count()==19,"nineteen Blender bones survive GLB import")
	check(driver.face.mesh.get_blend_shape_count()==3,"all three facial morphs survive import")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/marshal/model-report.json"))
	check(report.source_sha256==FileAccess.get_sha256("res://assets/characters/marshal/marshal.glb") and report.triangles<=95000,"validation report matches the current GLB and geometry budget")
	check(driver.cannon.get_parent()==p.rifle,"authored cannon follows the existing weapon anchor")
	check(driver.muzzle!=null and driver.left_grip!=null and driver.right_grip!=null,"named muzzle and grip sockets survive import")
	check(p.marshal_combat.flash_mesh.position.distance_to(p.rifle.to_local(driver.muzzle.global_position))<.001,"muzzle flash aligns with the authored barrel")
	check(driver.face.mesh==twin.presentation.marshal_model.face.mesh and driver.rig!=twin.presentation.marshal_model.rig,"actors share immutable meshes and own independent skeletons")
	var all_valid := true
	var skinned := 0
	for node: Node in driver.avatar.find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		if visual.skin==null: all_valid=false; continue
		skinned += 1
		for s: int in visual.mesh.get_surface_count():
			var arrays := visual.mesh.surface_get_arrays(s)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var values: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var ids: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			all_valid = all_valid and values.size()==points.size()*4 and ids.size()==values.size()
			for i: int in points.size():
				var total: float = 0
				for slot: int in 4:
					var value := values[i*4+slot]
					total += value
					all_valid = all_valid and is_finite(value) and value>=0 and ids[i*4+slot]<visual.skin.get_bind_count()
				all_valid = all_valid and absf(total-1)<4.0/65535.0 and points[i].is_finite()
	check(skinned>=15 and all_valid,"all imported body meshes retain finite normalized four-slot skin weights")
	var capsule := (actor.get_node("BodyCollision") as CollisionShape3D).shape as CapsuleShape3D
	check(is_equal_approx(capsule.height,1.9) and is_equal_approx(capsule.radius,.38),"gameplay capsule remains 1.9 m by .38 m")
	check(bone_point(driver,"RightHand").distance_to((driver.rests.RightHand as Transform3D).origin)>.1,"ready cannon pose actually articulates the hand")
	check(absf(bone_point(driver,"LeftFoot").x-bone_point(driver,"RightFoot").x)>.25,"leg root poses retain their authored stance width")
	check(driver.rig.to_global(bone_point(driver,"LeftHand")).distance_to(driver.left_grip.global_position)<.035,"support hand reaches the cannon grip")
	check(driver.rig.to_global(bone_point(driver,"RightHand")).distance_to(driver.right_grip.global_position)<.035,"trigger hand reaches the cannon grip")
	var rest_foot := bone_point(driver,"RightFoot")
	p.right_leg.rotation.x = 1.0
	driver.update(0)
	check(bone_point(driver,"RightFoot").distance_to(rest_foot)>.3,"existing locomotion controls articulate the Blender leg")
	p.right_leg.rotation.x = 0
	driver.update(0)
	check(driver.smoke.emitting and driver.smoke.amount==8,"cigar uses a bounded cosmetic particle emitter")
	seed(13579)
	var expected := randf()
	seed(13579)
	driver.update(.016)
	check(is_equal_approx(expected,randf()),"animation and smoke consume no gameplay RNG")
	driver.face.set_blend_shape_value(driver.face.find_blend_shape_by_name("MouthOpen"),1)
	check(twin.presentation.marshal_model.face.get_blend_shape_value(driver.face.find_blend_shape_by_name("MouthOpen"))<.2,"facial expressions remain independent between actors")
	# Exercise the actual kit before freezing deterministic review poses.
	twin.position = Vector3(-6,0,-8)
	actor.intent.aim = Vector3.FORWARD
	actor.spawn_protected = false
	actor.intent.primary = true
	await step(1)
	actor.intent.primary = false
	check(actor.kit.ammo==actor.tuning.magazine-1,"authored cannon still fires the real kit")
	await image("firing")
	actor.intent.secondary_held = true
	await step(3)
	check(actor.state=="marshal_shield" and (actor.kit as MarshalKit).barrier.active(),"real shield raises with imported rig")
	await image("shield")
	actor.intent.secondary_held = false
	await step(2)
	actor.kit.start_reload()
	await step(20)
	check(actor.kit.reloading,"existing reload remains active with authored cannon")
	await image("reload")
	actor.set_physics_process(false)
	twin.visible = false
	actor.kit.reloading = false
	actor.presentation.set_process(false)
	for pose: String in ["ready","walk","jump","crouch","slide","march","rally","verdict","melee","guard","throw","mantle","stagger","death"]:
		actor.state = "ready"
		actor.alive = true
		actor.motor.mode = "ground"
		actor.motor.set_crouched(false)
		actor.velocity = Vector3.ZERO
		if pose=="walk": actor.velocity = Vector3(3,0,0); p.walk_phase = .8
		elif pose=="jump": actor.motor.mode = "air"
		elif pose=="crouch": actor.motor.set_crouched(true)
		elif pose=="slide": actor.motor.set_crouched(true); actor.motor.mode = "slide"
		elif pose=="march": actor.state = "marshal_march"; (actor.kit as MarshalKit).march_age = .10; (actor.kit as MarshalKit).march_left = 3
		elif pose=="rally": actor.overhealth.grant(actor,175,5)
		elif pose=="verdict": actor.state = "marshal_verdict"; (actor.kit as MarshalKit).verdict_age = .5
		elif pose=="melee": actor.state = "melee_windup"; actor.close.melee_age = .12
		elif pose=="guard": actor.state = "guard"
		elif pose=="throw": actor.state = "throw_startup"; actor.state_time = .15
		elif pose=="mantle": actor.state = "mantle"
		elif pose=="stagger": actor.state = "stagger"; actor.state_time = .25
		elif pose=="death": actor.alive = false
		p._process(.016)
		var finite := true
		for i: int in driver.rig.get_bone_count(): finite = finite and driver.rig.get_bone_global_pose(i).is_finite()
		check(finite,"finite imported bone poses: "+pose)
		if pose=="death": check(not driver.smoke.emitting and not driver.smoke.visible,"death immediately stops and hides cigar smoke")
		await image(pose)
	# Inspect face and both team palettes without review-only morphs leaking out.
	actor.alive = true
	actor.state = "ready"
	p._process(.016)
	camera.position = Vector3(.75,1.95,-3)
	camera.look_at(Vector3(0,1.8,0))
	camera.fov = 23
	await image("face")
	driver.set_enabled(false)
	check(not driver.avatar.visible and not driver.cannon.visible and not driver.smoke.emitting,"fallback disables authored meshes and particles")
	var fallback_visible := false
	for mesh: MeshInstance3D in driver.legacy_meshes: fallback_visible = fallback_visible or mesh.visible
	check(fallback_visible,"procedural fallback geometry can be restored")
	driver.set_enabled(true)
	actor.reset_actor(Vector3(0,.01,0))
	check(driver.age==0 and not driver.smoke.emitting,"reset clears transient rig feedback")
	actor.presentation.set_process(true)
	await step(2)
	check(driver.smoke.emitting,"living reset actor resumes cosmetic smoke")
	var old_smoke: WeakRef = weakref(driver.smoke)
	var old_cannon: WeakRef = weakref(driver.cannon)
	actor.select_hero("doctor")
	await step(3)
	check(old_smoke.get_ref()==null and old_cannon.get_ref()==null,"hero switching frees smoke and reparented cannon")
	check(actor.presentation.marshal_model==null,"Doctor retains its own presentation")
	actor.select_hero("marshal")
	await step(3)
	check(is_instance_valid(actor.presentation.marshal_model),"switching back installs a clean Marshal rig")
	world.queue_free()
	await step(4)
	var output := FileAccess.open(OUT+("native" if capture else "headless")+"-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks":checks,"failures":failures,"engine":Engine.get_version_info().string},"\t"))
	print("RESULT: %d checks, %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
