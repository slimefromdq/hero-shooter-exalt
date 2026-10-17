class_name CloseCombatAnimations
extends RefCounted

# Authored, normalized keyframes. Physics supplies progress; tracks never deal damage.
static func library() -> AnimationLibrary:
	var result := AnimationLibrary.new()
	var swing := Animation.new()
	swing.length = 1.0
	track(swing, "Model:rotation", [0,.12,.26,.39,.55,1], [Vector3.ZERO, Vector3(0,-.5,-.08), Vector3(-.16,-.8,-.12), Vector3(.24,1.0,.08), Vector3(.12,.6,.04), Vector3.ZERO])
	track(swing, "Model/Geometry/Rifle:rotation", [0,.12,.26,.39,.55,1], [Vector3.ZERO, Vector3(.1,-.6,-.7), Vector3(.1,-1.25,-.9), Vector3(-.2,1.4,-.4), Vector3(-.1,1.0,0), Vector3.ZERO])
	track(swing, "Model/Geometry/RightArm:rotation", [0,.26,.39,.6,1], [Vector3(1.1,0,0), Vector3(.5,-.8,-1.0), Vector3(1.4,.7,-.3), Vector3(.9,.4,0), Vector3(1.1,0,0)])
	track(swing, "Model/Geometry/LeftArm:rotation", [0,.26,.39,1], [Vector3(.1,0,-.15), Vector3(.8,0,.8), Vector3(.4,0,.3), Vector3(.1,0,-.15)])
	track(swing, "Model/Geometry/LeftLeg:rotation", [0,.15,.36,.6,1], [Vector3.ZERO,Vector3(-.3,0,0),Vector3(.75,0,0),Vector3(.3,0,0),Vector3.ZERO])
	track(swing, "Model/Geometry/RightLeg:rotation", [0,.26,.45,1], [Vector3.ZERO,Vector3(.4,0,0),Vector3(-.45,0,0),Vector3.ZERO])
	result.add_animation("melee", swing)
	var stagger := Animation.new()
	stagger.length = 1.0
	var recoil: Array = [0,.12,.28,.56,.8,1]
	track(stagger,"Model:position",recoil,[Vector3(0,1,0),Vector3(0,.83,.32),Vector3(0,.77,.38),Vector3(0,.8,.26),Vector3(0,.9,.1),Vector3(0,1,0)])
	track(stagger,"Model:rotation",recoil,[Vector3.ZERO,Vector3(-.8,-.2,.18),Vector3(-.7,-.25,.15),Vector3(-.5,-.1,-.12),Vector3(.16,0,-.06),Vector3.ZERO])
	track(stagger,"Model/Geometry/LeftArm:rotation",recoil,[Vector3(.1,0,-.15),Vector3(.45,0,-1.5),Vector3(.3,-.2,-1.3),Vector3(.2,0,-1.0),Vector3(.4,0,-.4),Vector3(.1,0,-.15)])
	track(stagger,"Model/Geometry/RightArm:rotation",recoil,[Vector3(1.1,0,0),Vector3(.3,0,1.5),Vector3(.15,.3,1.3),Vector3(.2,0,1),Vector3(.5,0,.4),Vector3(1.1,0,0)])
	track(stagger,"Model/Geometry/LeftLeg:rotation",recoil,[Vector3.ZERO,Vector3(.55,0,-.15),Vector3(.65,0,-.12),Vector3(.45,0,-.08),Vector3(-.2,0,0),Vector3.ZERO])
	track(stagger,"Model/Geometry/RightLeg:rotation",recoil,[Vector3.ZERO,Vector3(-.45,0,.15),Vector3(-.35,0,.12),Vector3(-.2,0,.08),Vector3(.15,0,0),Vector3.ZERO])
	track(stagger,"Model/Geometry/LeftLeg/Joint:rotation",recoil,[Vector3.ZERO,Vector3(.9,0,0),Vector3(1.0,0,0),Vector3(.8,0,0),Vector3(.3,0,0),Vector3.ZERO])
	track(stagger,"Model/Geometry/RightLeg/Joint:rotation",recoil,[Vector3.ZERO,Vector3(.65,0,0),Vector3(.8,0,0),Vector3(.5,0,0),Vector3(.2,0,0),Vector3.ZERO])
	track(stagger,"Model/Geometry/Rifle:rotation",recoil,[Vector3.ZERO,Vector3(-.4,.3,1.1),Vector3(-.3,.25,.9),Vector3(-.1,0,.7),Vector3(.15,0,.3),Vector3.ZERO])
	result.add_animation("stagger",stagger)
	var block := Animation.new()
	block.length = 1.0
	track(block,"Model:position",[0,.16,.45,1],[Vector3(0,1,0),Vector3(0,.93,.12),Vector3(0,.95,.06),Vector3(0,1,0)])
	track(block,"Model:rotation",[0,.16,.45,1],[Vector3.ZERO,Vector3(-.16,0,.06),Vector3(-.08,0,0),Vector3.ZERO])
	track(block,"Model/Geometry/LeftArm:rotation",[0,.16,.45,1],[Vector3(.1,0,-.15),Vector3(1.3,0,-.35),Vector3(1.1,0,-.2),Vector3(.1,0,-.15)])
	result.add_animation("block",block)
	var mantle := Animation.new()
	mantle.length = 1
	var climb: Array = [0,.2,.6,.8,1]
	track(mantle,"Model:rotation",climb,[Vector3(.15,0,0),Vector3(.28,0,0),Vector3(.4,0,0),Vector3(.2,0,0),Vector3.ZERO])
	track(mantle,"Model/Geometry/LeftArm:rotation",climb,[Vector3(1.6,0,-.2),Vector3(2.7,0,-.2),Vector3(1.9,0,-.3),Vector3(.8,0,-.2),Vector3(.1,0,-.15)])
	track(mantle,"Model/Geometry/RightArm:rotation",climb,[Vector3(1.6,0,.2),Vector3(2.7,0,.2),Vector3(1.9,0,.3),Vector3(.8,0,.2),Vector3(1.1,0,0)])
	track(mantle,"Model/Geometry/LeftArm/Joint:rotation",climb,[Vector3.ZERO,Vector3(-.2,0,0),Vector3(-1.1,0,0),Vector3(-.5,0,0),Vector3.ZERO])
	track(mantle,"Model/Geometry/RightArm/Joint:rotation",climb,[Vector3.ZERO,Vector3(-.2,0,0),Vector3(-1.1,0,0),Vector3(-.5,0,0),Vector3.ZERO])
	track(mantle,"Model/Geometry/LeftLeg:rotation",climb,[Vector3.ZERO,Vector3(.3,0,0),Vector3(1.1,0,0),Vector3(.7,0,0),Vector3.ZERO])
	track(mantle,"Model/Geometry/LeftLeg/Joint:rotation",climb,[Vector3.ZERO,Vector3(.4,0,0),Vector3(1.3,0,0),Vector3(.5,0,0),Vector3.ZERO])
	track(mantle,"Model/Geometry/RightLeg:rotation",climb,[Vector3.ZERO,Vector3(-.2,0,0),Vector3(.3,0,0),Vector3(.8,0,0),Vector3.ZERO])
	result.add_animation("mantle",mantle)
	var kick := Animation.new()
	kick.length = 1
	track(kick,"Model:rotation",[0,.2,.6,1],[Vector3.ZERO,Vector3(-.3,0,-.15),Vector3(-.15,0,0),Vector3.ZERO])
	track(kick,"Model/Geometry/LeftLeg:rotation",[0,.2,.6,1],[Vector3.ZERO,Vector3(1.25,0,0),Vector3(.5,0,0),Vector3.ZERO])
	track(kick,"Model/Geometry/RightLeg:rotation",[0,.2,.6,1],[Vector3.ZERO,Vector3(-.6,0,0),Vector3(-.2,0,0),Vector3.ZERO])
	track(kick,"Model/Geometry/LeftArm:rotation",[0,.2,.6,1],[Vector3(.1,0,-.15),Vector3(.6,0,-.9),Vector3(.3,0,-.5),Vector3(.1,0,-.15)])
	result.add_animation("wall_jump",kick)
	var grab := Animation.new()
	grab.length = 1.0
	track(grab,"Model:rotation",[0,.45,1],[Vector3.ZERO,Vector3(.12,-.1,0),Vector3(.18,-.15,0)])
	track(grab,"Model/Geometry/LeftArm:rotation",[0,.5,1],[Vector3(.1,0,-.15),Vector3(1.45,0,-.2),Vector3(1.55,0,-.15)])
	track(grab,"Model/Geometry/RightArm:rotation",[0,.5,1],[Vector3(1.1,0,0),Vector3(1.5,0,.2),Vector3(1.55,0,.15)])
	result.add_animation("grab",grab)
	var thrower := Animation.new()
	thrower.length = 1.0
	var keys: Array = [0,.2,.46,.6,.72,.8,1]
	track(thrower,"Model:position",keys,[Vector3(0,1,0),Vector3(0,.84,0),Vector3(0,1.04,0),Vector3(0,.96,0),Vector3(0,.76,0),Vector3(0,.8,0),Vector3(0,1,0)])
	track(thrower,"Model:rotation",keys,[Vector3(.18,0,0),Vector3(.3,-.4,0),Vector3(-.15,-.95,-.08),Vector3(.15,.3,.12),Vector3(.6,.65,.08),Vector3(.48,.5,0),Vector3.ZERO])
	track(thrower,"Model/Geometry/LeftArm:rotation",keys,[Vector3(1.55,0,-.15),Vector3(1.4,-.4,-.3),Vector3(2.5,-.5,-.3),Vector3(1.9,.2,-.3),Vector3(.65,.4,-.25),Vector3(.4,0,-.15),Vector3(.1,0,-.15)])
	track(thrower,"Model/Geometry/RightArm:rotation",keys,[Vector3(1.55,0,.15),Vector3(1.25,.2,.4),Vector3(2.4,.1,.25),Vector3(1.8,.1,.1),Vector3(.55,0,.2),Vector3(.4,0,0),Vector3(1.1,0,0)])
	track(thrower,"Model/Geometry/LeftArm/Joint:rotation",[0,.2,.46,.72,1],[Vector3(-.1,0,0),Vector3(-.8,0,0),Vector3(-1.15,0,0),Vector3(-.25,0,0),Vector3.ZERO])
	track(thrower,"Model/Geometry/RightArm/Joint:rotation",[0,.2,.46,.72,1],[Vector3(-.1,0,0),Vector3(-.85,0,0),Vector3(-1.0,0,0),Vector3(-.25,0,0),Vector3(-.3,0,0)])
	track(thrower,"Model/Geometry/LeftLeg:rotation",[0,.2,.46,.72,1],[Vector3.ZERO,Vector3(-.25,0,0),Vector3(-.15,-.4,0),Vector3(-.4,0,0),Vector3.ZERO])
	track(thrower,"Model/Geometry/RightLeg/Joint:rotation",[0,.2,.46,.72,1],[Vector3.ZERO,Vector3(.4,0,0),Vector3(.15,0,0),Vector3(.65,0,0),Vector3.ZERO])
	result.add_animation("thrower",thrower)
	var victim := Animation.new()
	victim.length = 1.0
	track(victim,"Model:position",[0,.2,.46,.6,.72,.82,.9,1],[Vector3(0,1,0),Vector3(0,1,0),Vector3(0,1,0),Vector3(0,.8,0),Vector3(0,.3,0),Vector3(0,.3,0),Vector3(0,.65,0),Vector3(0,1,0)])
	track(victim,"Model:rotation",[0,.2,.46,.6,.72,.82,.9,1],[Vector3.ZERO,Vector3(.4,0,.1),Vector3(-2.6,0,.3),Vector3(-2.9,0,.2),Vector3(-PI/2,0,0),Vector3(-PI/2,0,0),Vector3(-.6,0,0),Vector3.ZERO])
	track(victim,"Model/Geometry/LeftArm:rotation",[0,.2,.46,.72,.82,1],[Vector3(.1,0,-.15),Vector3(.5,0,-.6),Vector3(-.4,0,-1.1),Vector3(-.1,0,-.7),Vector3(-.1,0,-.7),Vector3(.1,0,-.15)])
	track(victim,"Model/Geometry/RightArm:rotation",[0,.2,.46,.72,.82,1],[Vector3(1.1,0,0),Vector3(.6,0,.6),Vector3(-.5,0,1.1),Vector3(-.1,0,.7),Vector3(-.1,0,.7),Vector3(1.1,0,0)])
	track(victim,"Model/Geometry/LeftLeg:rotation",[0,.3,.46,.72,.82,.92,1],[Vector3.ZERO,Vector3(.3,0,0),Vector3(.7,0,.1),Vector3(-.2,0,-.2),Vector3(-.2,0,-.2),Vector3(-.6,0,0),Vector3.ZERO])
	track(victim,"Model/Geometry/RightLeg:rotation",[0,.3,.46,.72,.82,.92,1],[Vector3.ZERO,Vector3(.6,0,0),Vector3(1.1,0,-.1),Vector3(.1,0,.2),Vector3(.1,0,.2),Vector3(.5,0,0),Vector3.ZERO])
	track(victim,"Model/Geometry/LeftLeg/Joint:rotation",[0,.46,.72,.82,1],[Vector3.ZERO,Vector3(1.0,0,0),Vector3(.2,0,0),Vector3(.2,0,0),Vector3.ZERO])
	track(victim,"Model/Geometry/RightLeg/Joint:rotation",[0,.46,.72,.82,1],[Vector3.ZERO,Vector3(1.4,0,0),Vector3(.15,0,0),Vector3(.15,0,0),Vector3.ZERO])
	result.add_animation("victim",victim)
	return result

static func track(animation: Animation, path: String, times: Array, values: Array) -> void:
	var index: int = animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(index, NodePath(path))
	animation.track_set_interpolation_type(index, Animation.INTERPOLATION_LINEAR)
	for key: int in times.size():
		animation.track_insert_key(index, times[key], values[key])
