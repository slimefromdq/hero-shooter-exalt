class_name StitchPresentation
extends RefCounted
## Procedural placeholders; named parts and kit cues are animation replacement hooks.
static var click_wave: AudioStreamWAV

static func joint_wave() -> AudioStreamWAV:
	if click_wave != null: return click_wave
	var pcm := PackedByteArray()
	pcm.resize(1544)
	for index: int in 772:
		var time: float = float(index)/22050.0
		var value: float = (sin(time*TAU*1700)+sin(time*TAU*2630)*.4)*exp(-time*160)*.3
		pcm.encode_s16(index*2,int(value*32767))
	click_wave = AudioStreamWAV.new()
	click_wave.format = AudioStreamWAV.FORMAT_16_BITS
	click_wave.mix_rate = 22050
	click_wave.data = pcm
	return click_wave

static func build(p: HeroPresentation) -> void:
	for mesh: MeshInstance3D in p.body.find_children("*","MeshInstance3D",true,false): mesh.visible = false
	var doll := Node3D.new()
	doll.name = "StitchDoll"
	p.body.add_child(doll)
	p.roster_parts["doll"] = doll
	RosterVisuals.orb(doll,Vector3(0,1.1,0),Vector3(.5,.7,.37),"75616a")
	var head := Node3D.new()
	head.name = "PorcelainHead"
	doll.add_child(head)
	head.position = Vector3(0,1.73,0)
	p.roster_parts["head"] = head
	RosterVisuals.orb(head,Vector3.ZERO,Vector3(.5,.51,.43),"efe5d7")
	for side: float in [-1.0,1.0]:
		RosterVisuals.orb(head,Vector3(side*.105,.04,-.2),Vector3(.095,.11,.04),"2c1722")
		RosterVisuals.orb(head,Vector3(side*.105,.04,-.225),Vector3(.025,.03,.01),"ff345b",2)
		Geometry.box(doll,Vector3(.13,.55,.14),Vector3(side*.34,1.2,0),Color("d8cec3"),false)
		Geometry.box(doll,Vector3(.16,.72,.16),Vector3(side*.15,.42,0),Color("aa8c8e"),false)
		RosterVisuals.orb(doll,Vector3(side*.34,1.4,0),Vector3(.17,.17,.17),"3c2931")
		for y: float in [.95,1.1,1.25]:
			Geometry.box(doll,Vector3(.11,.025,.025),Vector3(side*.11,y,-.193),Color("b51e44"),false).rotation.z = side*.55
	Geometry.box(head,Vector3(.19,.025,.03),Vector3(0,-.1,-.208),Color("8e314d"),false)
	var shears := Node3D.new()
	shears.name = "Shears"
	doll.add_child(shears)
	shears.position = Vector3(.38,1.25,-.45)
	p.roster_parts["shears"] = shears
	for side: float in [-1.0,1.0]:
		var blade: Node3D = Geometry.box(shears,Vector3(.055,.06,.65),Vector3(side*.08,0,-.22),Color("dce3e3"),false)
		blade.rotation.y = side*.22
		p.roster_parts["blade_left" if side < 0 else "blade_right"] = blade
		RosterVisuals.orb(shears,Vector3(side*.09,0,.16),Vector3(.13,.08,.2),"b02d4e")
	var needle: Node3D = Geometry.box(doll,Vector3(.02,.02,.55),Vector3(.35,1.35,-.6),Color("efdfd3"),false)
	needle.name = "Needlepoint"
	p.roster_parts["needle"] = needle
	for key: String in ["seam","hook"]:
		var line := MeshInstance3D.new()
		line.name = "CurtainSeam" if key == "seam" else "SewingHook"
		line.mesh = BoxMesh.new()
		(line.mesh as BoxMesh).size = Vector3.ONE
		line.material_override = Geometry.material(Color("ff1942"),2)
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		p.add_child(line)
		p.roster_parts[key] = line
	p.roster_parts["doll_meshes"] = doll.find_children("*","MeshInstance3D",true,false)
	p.roster_parts["body_meshes"] = p.body.find_children("*","MeshInstance3D",true,false)
	p.roster_parts["mesh_cache_ready"] = false
	p.roster_parts["joint_clock"] = 0.0
	p.roster_parts["snap_left"] = 0.0
	var joints := AudioStreamPlayer3D.new()
	joints.name = "PorcelainJoints"
	joints.bus = "Combat"
	joints.stream = joint_wave()
	joints.max_distance = (p.actor.tuning as StitchTuning).detection_range
	joints.unit_size = 1.5
	joints.volume_db = -12
	p.add_child(joints)
	p.roster_parts["joints"] = joints

static func line(p: HeroPresentation, key: String, from: Vector3, to: Vector3, width: float = .025) -> void:
	var mesh: MeshInstance3D = p.roster_parts[key]
	mesh.scale = Vector3(width,.025,maxf(.01,from.distance_to(to)))
	mesh.global_position = (from+to)*.5
	if from.distance_to(to) > .001: mesh.look_at(to,Vector3.UP if absf((to-from).normalized().y) < .99 else Vector3.RIGHT)

static func animate(p: HeroPresentation, delta: float) -> void:
	var a: HeroActor = p.actor
	var k := a.kit as StitchKit
	# Team badges are attached after the doll is built. Cache once after ready,
	# so proximity concealment also fades those later attachments.
	if not bool(p.roster_parts["mesh_cache_ready"]):
		p.roster_parts["doll_meshes"] = (p.roster_parts["doll"] as Node3D).find_children("*","MeshInstance3D",true,false)
		p.roster_parts["body_meshes"] = p.body.find_children("*","MeshInstance3D",true,false)
		p.roster_parts["mesh_cache_ready"] = true
	p.rifle.visible = false
	p.umbrella.visible = false
	var session: Node = a.get_tree().get_first_node_in_group("game_session")
	var viewer: HeroActor = session.player if session != null else null
	p.visible = a.detectable_by(viewer)
	var proximity: bool = k.concealed and is_instance_valid(viewer) and viewer.team != a.team
	var doll: Node3D = p.roster_parts["doll"]
	doll.rotation.x = -.8 if k.concealed else 0.0
	doll.position.y = .15 if k.concealed else 0.0
	(p.roster_parts["shears"] as Node3D).visible = k.shears_mode and not k.concealed
	(p.roster_parts["needle"] as Node3D).visible = not k.shears_mode and not k.concealed
	for mesh: MeshInstance3D in p.roster_parts["doll_meshes"]:
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = .32 if proximity else .65 if k.concealed else 1.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if k.concealed else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Team badges and auxiliary effects must not remain opaque in proximity stealth.
	for mesh: MeshInstance3D in p.roster_parts["body_meshes"]:
		if doll.is_ancestor_of(mesh): continue
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null and mesh.visible:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color.a = .32 if proximity else .65 if k.concealed else 1.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if k.concealed else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	p.roster_parts["joint_clock"] = float(p.roster_parts["joint_clock"])+delta
	var clock: float = float(p.roster_parts["joint_clock"])
	(p.roster_parts["head"] as Node3D).rotation.y = .65 if fmod(clock,4.0) < .18 else 0
	if clock >= 4:
		p.roster_parts["joint_clock"] = 0.0
		if k.concealed and is_instance_valid(viewer) and viewer.global_position.distance_to(a.global_position) <= k.data().detection_range:
			(p.roster_parts["joints"] as AudioStreamPlayer3D).play()
	var seam: MeshInstance3D = p.roster_parts["seam"]
	seam.visible = k.ultimate_active()
	if seam.visible:
		line(p,"seam",k.seam_origin+Vector3.UP*.08,k.seam_origin+k.seam_direction*k.seam_distance+Vector3.UP*.08,k.data().seam_width)
	var hook: MeshInstance3D = p.roster_parts["hook"]
	hook.visible = k.hook_flying or a.state in ["stitch_reel","stitch_hang"]
	if hook.visible: line(p,"hook",a.body_point(1.2),k.hook_position)
	if k.cue != "":
		p.sound.play_tone(75 if k.cue == "curtain_snap" else 160 if k.cue == "shears_hit" else 1100,.12,.14)
		if k.cue in ["shears_hit","shears_swing","lunge"]: p.roster_parts["snap_left"] = .18
		if k.cue == "curtain_snap":
			p.roster_parts["snap_left"] = .22
			CombatEffect.pulse(a.get_parent(),a.body_point(1),Color("ff2856"),2)
		k.cue = ""
	var snap: float = maxf(0,float(p.roster_parts["snap_left"])-delta)
	p.roster_parts["snap_left"] = snap
	var shears: Node3D = p.roster_parts["shears"]
	shears.scale = Vector3.ONE*(3.5 if snap > 0 and k.ultimate_active() else 1.25 if snap > 0 else 1.0)
	if snap > 0 and not k.concealed: shears.visible = true
	var aperture: float = .06 if snap > .08 else .5 if snap > 0 else .22
	(p.roster_parts["blade_left"] as Node3D).rotation.y = -aperture
	(p.roster_parts["blade_right"] as Node3D).rotation.y = aperture
	shears.rotation.x = -.6 if snap > .08 else 0.0
