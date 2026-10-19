class_name TrainingTacticalController
extends BotController
## Deliberately inherits the drill contract; existing training UI keeps working.
var brain: BotBrain
var navagent: NavigationAgent3D
var destination: Vector3
var stuck_time: float = 0.0
var stuck_events: int = 0
var path_timer: float = 0.0
var slot: int = 0

func _ready() -> void:
	super._ready()
	brain = BotBrain.new()
	brain.setup(actor,TeamDirector.obtain(actor.get_parent(),actor.team),9301+slot*107+actor.team*113)
	navagent = NavigationAgent3D.new()
	navagent.path_desired_distance = .6
	navagent.target_desired_distance = 1.0
	navagent.radius = .48
	actor.add_child(navagent)
	think_timer = slot*.03

func gather_intent(delta: float) -> CombatIntent:
	var input := CombatIntent.new()
	input.aim_origin = actor.body_point(1.45)
	input.aim = remembered_aim
	if frozen or not actor.alive: return input
	var region: NavigationRegion3D = actor.get_parent().get_node_or_null("TacticalNavigation") as NavigationRegion3D
	if region == null or region.navigation_mesh.get_polygon_count() == 0 or NavigationServer3D.map_get_iteration_id(navagent.get_navigation_map()) == 0: return input
	think_timer -= delta
	path_timer -= delta
	var fresh: bool = think_timer <= 0
	if fresh:
		think_timer += .2
		brain.decide(actor.get_tree().get_nodes_in_group("actors"),{"position":Vector3(0,0,-2),"radius":10.0,"phase":"sparring","urgency":.5})
		target = brain.target_actor()
		destination = brain.movement.destination(brain,Vector3(0,0,-2),navagent.get_navigation_map(),false)
	if path_timer <= 0:
		path_timer += .5
		navagent.target_position = destination
	if not navagent.is_navigation_finished(): input.move = ((navagent.get_next_path_position()-actor.global_position)*Vector3(1,0,1)).normalized()
	brain.combat.execute(brain,input,delta,fresh)
	brain.movement.apply(brain,input,false)
	if input.move.length() > .2: input.move = StructureAvoidance.steer(actor,input.move,destination)
	if actor.global_position.distance_to(previous_position) < .01 and input.move.length() > .2: stuck_time += delta
	else: stuck_time = 0
	if stuck_time > 1.5:
		var side_step: Vector3 = input.move.cross(Vector3.UP)
		if brain.movement.safe_travel(actor,side_step,1.5): input.move = side_step
		input.jump = actor.motor.grounded() and actor.permits("jump")
		stuck_time = 0
		stuck_events += 1
	previous_position = actor.global_position
	remembered_aim = input.aim
	brain.diagnostics.tick(delta,brain,input)
	return input

func reset_controller() -> void:
	super.reset_controller()
	if brain != null: brain.reset()
	stuck_time = 0
	path_timer = 0
	previous_position = actor.global_position

func _exit_tree() -> void:
	if brain != null:
		brain.diagnostics.detach()
		if is_instance_valid(brain.director): brain.director.release(actor)
	if is_instance_valid(navagent): navagent.queue_free()
