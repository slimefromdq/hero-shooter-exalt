class_name PracticeRange
extends Node3D
var training: TrainingManager
var groups: Dictionary = {}
var buttons: Array[Dictionary] = []
var firing: bool = false
var prompt: String = ""
var selected_button: int = -1
const CENTERS := {"aoe":Vector3(-15,.1,-43),"moving":Vector3(15,.1,-43),"shooting":Vector3(-15,.1,-59),"allies":Vector3(15,.1,-59)}

func _ready() -> void:
	for station: String in CENTERS:
		var center: Vector3 = CENTERS[station]
		groups[station] = []
		var sign: Label3D = Geometry.text3d(self,station.to_upper()+" / PRACTICE",center+Vector3(0,4.2,-3),36,Color("c8eee0"))
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		var count: int = 6 if station == "aoe" else 3
		for index: int in count:
			var offset := Vector3((index%3-1)*1.5,0,-floorf(index/3.0)*1.5) if station == "aoe" else Vector3((index-1)*3.0,0,0)
			var dummy: HeroActor = training.spawn_bot(0,center+offset,true,training.player.team if station == "allies" else 1-training.player.team)
			dummy.set_meta("station",station)
			dummy.actor_id = station.capitalize()+"_%d" % (index+1)
			if station == "allies":
				dummy.team = training.player.team
				dummy.health = dummy.tuning.max_health*.5
			var previous: Node = dummy.controller
			dummy.remove_child(previous)
			previous.queue_free()
			var controller := PracticeDummyController.new()
			controller.actor = dummy
			controller.target = training.player
			controller.station = station
			dummy.add_child(controller)
			dummy.controller = controller
			groups[station].append(dummy)
		var at := Vector3(-6 if center.x < 0 else 6,.7,center.z+3)
		add_button(at,"RESET "+station.to_upper(),reset_group.bind(station))
		if station == "allies":
			add_button(at+Vector3(0,0,2),"INJURE ALLIES",injure)
			add_button(at+Vector3(0,0,4),"TEST DEBUFFS",debuff)
		else:
			add_button(at+Vector3(0,0,2),"250 HP / "+station.to_upper(),set_health.bind(station,250.0))
			add_button(at+Vector3(0,0,4),"25 HP / "+station.to_upper(),set_health.bind(station,25.0))
			if station == "shooting": add_button(at+Vector3(0,0,6),"TOGGLE FIRING",toggle_firing)
	add_button(Vector3(0,.7,-34),"RESET KILL FEEDBACK",training.feedback.reset)

func add_button(at: Vector3, caption: String, action: Callable) -> void:
	Geometry.box(self,Vector3(.65,.9,.45),at-Vector3.UP*.25,Color("334d5c"))
	Geometry.box(self,Vector3(.5,.3,.04),at+Vector3(0,.15,.25),Color("d6b781"),false)
	var text: Label3D = Geometry.text3d(self,caption,at+Vector3.UP*.8,20,Color("f9e8bb"))
	text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Aim just in front of the physical panel so its own housing cannot occlude F.
	buttons.append({"at":at+Vector3(0,.15,.3),"caption":caption,"action":action})

func _process(_delta: float) -> void:
	prompt = ""
	selected_button = -1
	if training.menu_open or not training.player.alive: return
	var player: HeroActor = training.player
	var origin: Vector3 = player.global_position+Vector3.UP*1.5
	var closest: float = 2.5
	for index: int in buttons.size():
		var button: Dictionary = buttons[index]
		var distance: float = origin.distance_to(button.at)
		var aim: float = player.aim_direction.dot((button.at-origin).normalized())
		if distance < closest and aim > .65 and player.resolver.ray(origin,button.at,[player.get_rid()],1).is_empty():
			closest = distance
			selected_button = index
			prompt = "[F] "+str(button.caption)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and selected_button >= 0 and not training.menu_open:
		buttons[selected_button].action.call()
		get_viewport().set_input_as_handled()

func reset_group(station: String) -> void:
	for dummy: HeroActor in groups[station]:
		dummy.reset_actor()
		training.death_timers.erase(dummy.get_instance_id())
		if station == "allies": dummy.health = dummy.tuning.max_health*.5
	if station == "shooting":
		firing = false
		for dummy: HeroActor in groups.shooting: dummy.controller.enabled = false
	training.show_notice(station.to_upper()+" RESET")

func set_health(station: String, amount: float) -> void:
	for dummy: HeroActor in groups[station]: dummy.tuning.max_health = amount
	reset_group(station)

func toggle_firing() -> void:
	firing = not firing
	for dummy: HeroActor in groups.shooting: dummy.controller.enabled = firing
	training.show_notice("RANGE FIRING "+("ON" if firing else "OFF"))

func injure() -> void:
	for dummy: HeroActor in groups.allies:
		if dummy.alive: dummy.health = dummy.effective_max_health()*.5

func debuff() -> void:
	var source: HeroActor = groups.aoe[0]
	for index: int in groups.allies.size():
		var dummy: HeroActor = groups.allies[index]
		dummy.statuses.apply(["bleed","slow","root"][index],source,6,6 if index == 0 else .5)
