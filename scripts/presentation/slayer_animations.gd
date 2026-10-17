class_name SlayerAnimations
extends RefCounted
## Keyed anticipation, hand release and follow-through. Physics owns all contacts.
static func library() -> AnimationLibrary:
	var result := AnimationLibrary.new()
	var knife := Animation.new()
	knife.length = 1.0
	var keys: Array = [0,.18,.32,.58,1]
	CloseCombatAnimations.track(knife,"Model:rotation",keys,[Vector3.ZERO,Vector3(-.08,-.45,-.1),Vector3(.08,.2,.06),Vector3(.17,.4,.1),Vector3.ZERO])
	CloseCombatAnimations.track(knife,"Model/Geometry/RightArm:rotation",keys,[Vector3(1.1,0,0),Vector3(2.7,-.6,.5),Vector3(1.65,.1,-.25),Vector3(.6,.4,-.2),Vector3(1.1,0,0)])
	CloseCombatAnimations.track(knife,"Model/Geometry/RightArm/Joint:rotation",keys,[Vector3.ZERO,Vector3(-1.5,0,0),Vector3(-.15,0,0),Vector3(.2,0,0),Vector3.ZERO])
	CloseCombatAnimations.track(knife,"Model/Geometry/LeftArm:rotation",keys,[Vector3(1,0,.3),Vector3(.5,0,-.6),Vector3(.6,0,-.8),Vector3(.2,0,-.4),Vector3(1,0,.3)])
	result.add_animation("knife",knife)
	var drop := Animation.new()
	drop.length = 1.0
	keys = [0,.2,.39,.7,1]
	CloseCombatAnimations.track(drop,"Model:position",keys,[Vector3(0,1,0),Vector3(0,.96,0),Vector3(0,1,-.05),Vector3(0,.98,0),Vector3(0,1,0)])
	CloseCombatAnimations.track(drop,"Model:rotation",keys,[Vector3.ZERO,Vector3(-.12,-.35,-.06),Vector3(.12,.2,.08),Vector3(.18,.3,0),Vector3.ZERO])
	CloseCombatAnimations.track(drop,"Model/Geometry/RightArm:rotation",keys,[Vector3(1.1,0,0),Vector3(2.5,-.3,.4),Vector3(1.7,.1,.15),Vector3(.7,.3,.05),Vector3(1.1,0,0)])
	CloseCombatAnimations.track(drop,"Model/Geometry/RightArm/Joint:rotation",keys,[Vector3.ZERO,Vector3(-1.25,0,0),Vector3(-.1,0,0),Vector3(.1,0,0),Vector3.ZERO])
	CloseCombatAnimations.track(drop,"Model/Geometry/LeftArm:rotation",keys,[Vector3(1,0,.3),Vector3(.5,0,-.5),Vector3(.65,0,-.6),Vector3(.4,0,-.2),Vector3(1,0,.3)])
	CloseCombatAnimations.track(drop,"Model/Geometry/RightLeg/Joint:rotation",keys,[Vector3.ZERO,Vector3(.25,0,0),Vector3(.6,0,0),Vector3(.2,0,0),Vector3.ZERO])
	result.add_animation("toss",drop)
	var grab := Animation.new()
	grab.length = 1
	keys = [0,.35,.7,1]
	CloseCombatAnimations.track(grab,"Model:rotation",keys,[Vector3.ZERO,Vector3(.12,-.25,-.05),Vector3(.25,-.12,0),Vector3(.2,0,0)])
	CloseCombatAnimations.track(grab,"Model/Geometry/LeftArm:rotation",keys,[Vector3(1,0,.3),Vector3(1.2,-.25,-.4),Vector3(1.6,0,-.18),Vector3(1.65,0,-.1)])
	CloseCombatAnimations.track(grab,"Model/Geometry/RightArm:rotation",keys,[Vector3(1.1,0,0),Vector3(1.35,.2,.45),Vector3(1.6,0,.2),Vector3(1.65,0,.1)])
	result.add_animation("grab",grab)
	var slam := Animation.new()
	slam.length = 1
	keys = [0,.2,.46,.6,.72,.84,1]
	CloseCombatAnimations.track(slam,"Model:position",keys,[Vector3(0,1,0),Vector3(0,.72,-.08),Vector3(0,1.08,0),Vector3(0,.98,0),Vector3(0,.68,-.18),Vector3(0,.82,-.06),Vector3(0,1,0)])
	CloseCombatAnimations.track(slam,"Model:rotation",keys,[Vector3(.2,0,0),Vector3(.32,-.4,0),Vector3(-.25,-.8,-.1),Vector3(.15,.35,.05),Vector3(.85,.7,.1),Vector3(.4,.25,0),Vector3.ZERO])
	CloseCombatAnimations.track(slam,"Model/Geometry/LeftArm:rotation",keys,[Vector3(1.65,0,-.1),Vector3(1.3,-.3,-.4),Vector3(2.8,-.3,-.2),Vector3(2,.2,-.2),Vector3(.4,.4,-.3),Vector3(.15,0,-.2),Vector3(1,0,.3)])
	CloseCombatAnimations.track(slam,"Model/Geometry/RightArm:rotation",keys,[Vector3(1.65,0,.1),Vector3(1.3,.3,.4),Vector3(2.7,.1,.2),Vector3(2,.15,.2),Vector3(.35,.2,.3),Vector3(.1,0,.2),Vector3(1.1,0,0)])
	for side: String in ["Left","Right"]:
		CloseCombatAnimations.track(slam,"Model/Geometry/%sArm/Joint:rotation" % side,keys,[Vector3(-.2,0,0),Vector3(-1.1,0,0),Vector3(-.75,0,0),Vector3(-.3,0,0),Vector3(.15,0,0),Vector3.ZERO,Vector3.ZERO])
		CloseCombatAnimations.track(slam,"Model/Geometry/%sLeg/Joint:rotation" % side,keys,[Vector3.ZERO,Vector3(.75,0,0),Vector3(.1,0,0),Vector3(.3,0,0),Vector3(.85,0,0),Vector3(.4,0,0),Vector3.ZERO])
	result.add_animation("thrower",slam)
	return result
