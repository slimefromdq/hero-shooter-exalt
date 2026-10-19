class_name MarshalCharacterDriver
extends Node3D
## Blender-authored skin. Reads presentation controls; never owns combat or RNG.
const SCENE_PATH := "res://assets/characters/marshal/marshal.glb"
var presentation: HeroPresentation
var avatar: Node3D
var rig: Skeleton3D
var face: MeshInstance3D
var cannon: MeshInstance3D
var muzzle: Node3D
var right_grip: Node3D
var left_grip: Node3D
var smoke: GPUParticles3D
var bones: Dictionary = {}
var rests: Dictionary = {}
var legacy_meshes: Array[MeshInstance3D] = []
var legacy_visibility: Array[bool] = []
var tool_rest: Transform3D
var cigar_bind: Vector3
var age: float = 0
var active: bool = true

static func attach(p: HeroPresentation) -> MarshalCharacterDriver:
	if not ResourceLoader.exists(SCENE_PATH):
		push_warning("Marshal authored rig unavailable; using procedural visuals")
		return null
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null: return null
	# Validate before hiding anything so a broken asset keeps the fallback usable.
	var candidate := packed.instantiate() as Node3D
	var skeletons := candidate.find_children("*","Skeleton3D",true,false)
	if skeletons.is_empty() or candidate.find_child("Marshal_Face",true,false) == null or candidate.find_child("Marshal_Cannon",true,false) == null:
		candidate.free()
		push_warning("Marshal skin incomplete; using procedural visuals")
		return null
	for socket: String in ["CannonMuzzle","RightGrip","LeftGrip","CigarTip","ShieldSocket"]:
		if candidate.find_child(socket,true,false) == null:
			candidate.free()
			push_warning("Marshal socket missing: "+socket)
			return null
	var candidate_face := candidate.find_child("Marshal_Face",true,false) as MeshInstance3D
	for morph: String in ["Blink","Focused","MouthOpen"]:
		if candidate_face.find_blend_shape_by_name(morph) < 0:
			candidate.free()
			push_warning("Marshal facial morph missing: "+morph)
			return null
	var skeleton := skeletons[0] as Skeleton3D
	for caption: String in ["Root","Spine","Chest","Neck","Head","LeftUpperArm","LeftForearm","LeftHand","RightUpperArm","RightForearm","RightHand","LeftThigh","LeftCalf","LeftFoot","RightThigh","RightCalf","RightFoot","LeftCoatTail","RightCoatTail"]:
		if (skeleton as Skeleton3D).find_bone(caption) < 0:
			candidate.free()
			push_warning("Marshal bone missing: "+caption)
			return null
	var driver := MarshalCharacterDriver.new()
	driver.name = "MarshalCharacterDriver"
	driver.presentation = p
	p.body.add_child(driver)
	driver.install(candidate)
	return driver

func install(candidate: Node3D) -> void:
	var p := presentation
	tool_rest = p.care_tool.transform
	for node: Node in p.body.find_children("*","MeshInstance3D",true,false):
		var visual := node as MeshInstance3D
		if visual == p.shield or visual == p.muzzle_flash or p.umbrella.is_ancestor_of(visual) or p.care_tool.is_ancestor_of(visual): continue
		legacy_meshes.append(visual)
		legacy_visibility.append(visual.visible)
	avatar = candidate
	add_child(avatar)
	rig = avatar.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	face = avatar.find_child("Marshal_Face",true,false) as MeshInstance3D
	for index: int in rig.get_bone_count():
		var caption := rig.get_bone_name(index)
		bones[caption] = index
		rests[caption] = rig.get_bone_global_rest(index)
	for node: Node in avatar.find_children("*","MeshInstance3D",true,false):
		(node as MeshInstance3D).extra_cull_margin = 2.0
	cannon = avatar.find_child("Marshal_Cannon",true,false) as MeshInstance3D
	cannon.reparent(p.rifle,false)
	muzzle = cannon.find_child("CannonMuzzle",true,false) as Node3D
	right_grip = cannon.find_child("RightGrip",true,false) as Node3D
	left_grip = cannon.find_child("LeftGrip",true,false) as Node3D
	# Source socket is an exported bind-space marker, not a second skeleton.
	var tip := avatar.find_child("CigarTip",true,false) as Node3D
	cigar_bind = rig.to_local(tip.global_position)
	create_smoke()
	set_enabled(true)

func create_smoke() -> void:
	smoke = GPUParticles3D.new()
	smoke.name = "CigarSmoke"
	smoke.amount = 8
	smoke.lifetime = 1.3
	smoke.preprocess = 0
	smoke.visibility_aabb = AABB(Vector3(-1,-1,-1),Vector3(2,3,2))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 18
	process.gravity = Vector3(.015,.035,0)
	process.initial_velocity_min = .06
	process.initial_velocity_max = .12
	process.scale_min = .3
	process.scale_max = 1.0
	var gradient := Gradient.new()
	gradient.set_color(0,Color(.70,.72,.74,.18))
	gradient.set_color(1,Color(.70,.72,.74,0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	smoke.process_material = process
	var puff := SphereMesh.new()
	puff.radius = .025
	puff.height = .05
	puff.radial_segments = 8
	puff.rings = 4
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1,1,1,.65)
	puff.material = mat
	smoke.draw_pass_1 = puff
	add_child(smoke)

func set_enabled(value: bool) -> void:
	active = value
	avatar.visible = value
	cannon.visible = value
	for index: int in legacy_meshes.size():
		if is_instance_valid(legacy_meshes[index]): legacy_meshes[index].visible = legacy_visibility[index] and not value
	reset_feedback()
	if not value: presentation.care_tool.transform = tool_rest

func rotate_bone(caption: String, delta_basis: Basis) -> void:
	# glTF retains Blender bone rest bases. Work in skeleton space explicitly.
	var index: int = bones[caption]
	var parent: int = rig.get_bone_parent(index)
	var parent_pose: Basis = rig.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
	var desired: Basis = delta_basis * (rests[caption] as Transform3D).basis
	var local: Basis = parent_pose.inverse() * desired
	rig.set_bone_pose_rotation(index,local.orthonormalized().get_rotation_quaternion())

func relative_rotation(caption: String, delta_basis: Basis) -> void:
	var rest_basis: Basis = rig.get_bone_rest(bones[caption]).basis
	rig.set_bone_pose_rotation(bones[caption],(delta_basis*rest_basis).get_rotation_quaternion())

func solve_arm(side: String, target: Vector3, grip: Node3D = null) -> void:
	var upper := side+"UpperArm"
	var lower := side+"Forearm"
	var hand := side+"Hand"
	var start: Vector3 = rig.get_bone_global_pose(bones[upper]).origin
	var first_rest: Vector3 = (rests[lower] as Transform3D).origin-(rests[upper] as Transform3D).origin
	var second_rest: Vector3 = (rests[hand] as Transform3D).origin-(rests[lower] as Transform3D).origin
	var first := first_rest.length()
	var second := second_rest.length()
	var difference := target-start
	if difference.length() < .001: return
	var distance := clampf(difference.length(),absf(first-second)+.002,first+second-.002)
	var forward := difference.normalized()
	var hint := Vector3(-.7 if side=="Left" else .7,-1,.3)
	var bend := (hint-forward*hint.dot(forward)).normalized()
	var along := (first*first-second*second+distance*distance)/(2*distance)
	var elbow := start+forward*along+bend*sqrt(maxf(0,first*first-along*along))
	var end := start+forward*distance
	rotate_bone(upper,Basis(Quaternion(first_rest.normalized(),(elbow-start).normalized())))
	rotate_bone(lower,Basis(Quaternion(second_rest.normalized(),(end-elbow).normalized())))
	if grip != null:
		rotate_bone(hand,rig.global_basis.inverse()*grip.global_basis*Basis(Vector3.RIGHT,PI/2))

func update(delta: float) -> void:
	if not active or not is_instance_valid(rig): return
	age += delta
	var p := presentation
	var a := p.actor
	rig.reset_bone_poses()
	for side: String in ["Left","Right"]:
		var arm: Node3D = p.left_arm if side=="Left" else p.right_arm
		var leg: Node3D = p.left_leg if side=="Left" else p.right_leg
		relative_rotation(side+"UpperArm",arm.basis)
		relative_rotation(side+"Forearm",(arm.get_node("Joint") as Node3D).basis)
		relative_rotation(side+"Thigh",leg.basis.orthonormalized())
		rig.set_bone_pose_scale(bones[side+"Thigh"],leg.scale)
		var offset := Vector3(0,leg.position.y-.8,0)
		rig.set_bone_pose_position(bones[side+"Thigh"],rig.get_bone_rest(bones[side+"Thigh"]).origin+offset)
		relative_rotation(side+"Calf",(leg.get_node("Joint") as Node3D).basis)
		relative_rotation(side+"CoatTail",Basis(Vector3.RIGHT,-.12-absf(leg.rotation.x)*.55-(.6 if a.motor.crouched else 0)))
		if a.motor.crouched or a.motor.mode=="slide":
			relative_rotation(side+"Foot",Basis(Vector3.RIGHT,-leg.rotation.x-(leg.get_node("Joint") as Node3D).rotation.x))
	if a.alive:
		if a.state=="ready":
			solve_arm("Right",rig.to_local(right_grip.global_position),right_grip)
			var target := left_grip.global_position
			if a.kit.reloading:
				var progress := 1-a.kit.reload_remaining/maxf(.01,a.kit.reload_total)
				target = p.rifle.to_global(Vector3(-.16,-.11-.08*sin(progress*PI),.02))
			solve_arm("Left",rig.to_local(target),left_grip)
		elif a.state=="marshal_shield":
			solve_arm("Left",rig.to_local(p.body.to_global(Vector3(-.35,1.43,-.38))))
		elif a.state=="marshal_march":
			solve_arm("Right",rig.to_local(right_grip.global_position),right_grip)
			solve_arm("Left",rig.to_local(p.body.to_global(Vector3(-.30,1.45,-.40))))
		elif a.state=="guard":
			solve_arm("Right",rig.to_local(right_grip.global_position),right_grip)
		var pitch := asin(clampf(a.aim_direction.y,-1,1))
		relative_rotation("Head",Basis(Vector3.RIGHT,clampf(pitch,-.35,.35)*.4))
	if p.care_tool.visible:
		var hand: Transform3D = rig.global_transform*rig.get_bone_global_pose(bones["RightHand"])
		p.care_tool.global_transform = hand*Transform3D(Basis.IDENTITY,Vector3(0,-.07,0))
	var head_delta: Transform3D = rig.get_bone_global_pose(bones["Head"])*(rests["Head"] as Transform3D).affine_inverse()
	smoke.global_position = rig.to_global(head_delta*cigar_bind)
	smoke.emitting = a.alive and active
	smoke.visible = a.alive and active
	var blink := maxf(0,1-absf(fmod(age,5.1)-4.9)/.085)
	face.set_blend_shape_value(face.find_blend_shape_by_name("Blink"),blink if a.alive else .9)
	face.set_blend_shape_value(face.find_blend_shape_by_name("Focused"),.65 if a.state!="ready" or p.fire_flash>0 else .25)
	face.set_blend_shape_value(face.find_blend_shape_by_name("MouthOpen"),.6 if a.overhealth.value()>0 else .08)

func reset_feedback() -> void:
	age = 0
	if is_instance_valid(rig): rig.reset_bone_poses()
	if is_instance_valid(smoke):
		smoke.restart()
		smoke.emitting = false
		smoke.visible = false
	if is_instance_valid(face):
		for index: int in face.mesh.get_blend_shape_count(): face.set_blend_shape_value(index,0)

func _exit_tree() -> void:
	if is_instance_valid(cannon): cannon.queue_free()
