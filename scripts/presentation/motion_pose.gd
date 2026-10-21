class_name MotionPose
extends RefCounted
## Additive visual pose, evaluated after authored actions and before rig solving.
static func apply(p: HeroPresentation, delta: float) -> void:
	var a: HeroActor = p.actor
	if not a.alive: return
	var local: Vector3 = a.global_basis.inverse()*a.velocity
	var breath: float = sin(p.pose_clock*2.3)*.006
	var stretch: float = breath
	if a.state == "ready":
		p.model.rotation.z += clampf(-local.x*.008,-.08,.08)
		p.model.rotation.x += clampf(-local.z*.006,-.06,.08)
		p.model.rotation.y += sin(p.walk_phase)*minf(.035,a.velocity.length()*.004)
		if not a.motor.grounded() and a.motor.mode == "air" and a.motor.traversal.wall_pose <= 0:
			stretch += clampf(a.velocity.y*.006,-.025,.045)
			p.left_leg.rotation.x = lerpf(.25,-.55,clampf(a.velocity.y/8,.0,1))
			p.right_leg.rotation.x = .5
			(p.right_leg.get_node("Joint") as Node3D).rotation.x = -.8
			p.left_arm.rotation.z -= .12
		if p.movement.jump_left > 0:
			var phase: float = 1-p.movement.jump_left/.16
			stretch = lerpf(-.055,.055,smoothstep(0,.45,phase))*(1-phase)
		if p.movement.landing_left > 0:
			var weight: float = p.movement.landing_left/.22
			stretch -= .055*weight
			p.model.position.y -= .07*weight
			(p.left_leg.get_node("Joint") as Node3D).rotation.x -= .3*weight
			(p.right_leg.get_node("Joint") as Node3D).rotation.x -= .3*weight
	if a.motor.mode == "slide":
		var dash: bool = a.motor.slide_source in ["air_dash","ground_dash"]
		p.model.rotation.z += -.12 if dash else .08
		p.model.rotation.x += .12 if a.motor.slide_source == "mantle" else -.08
		p.left_leg.rotation.x = 1.1 if dash else 1.35
		p.right_leg.rotation.x = 1.65
		(p.left_leg.get_node("Joint") as Node3D).rotation.x = -1.5
		(p.right_leg.get_node("Joint") as Node3D).rotation.x = -.35
		p.left_arm.rotation.z = -.5
		stretch = -.035
	var shot: float = maxf(0,p.weapon_kick)
	if a.last_hit_age < .15: p.model.rotation.x += .05*(1-a.last_hit_age/.15)
	p.rifle.position.z += shot*.11
	p.rifle.rotation.x -= shot*.16
	p.right_arm.rotation.x -= shot*.1
	p.model.rotation.x -= shot*.025
	p.weapon_kick = move_toward(p.weapon_kick,0,delta*8)
	stretch = clampf(stretch,-.06,.06)
	p.model.scale *= Vector3(1-stretch*.5,1+stretch,1-stretch*.5)
	for axis: int in 3: p.model.scale[axis] = clampf(p.model.scale[axis],.94,1.06)

static func torso(p: HeroPresentation) -> Basis:
	return Basis(Vector3.UP,sin(p.walk_phase)*minf(.035,p.actor.velocity.length()*.004))*Basis(Vector3.RIGHT,sin(p.pose_clock*2.3)*.008-p.weapon_kick*.025)
