class_name HitImpactPresenter
extends Node
var resolver: CombatResolver
var pending: Dictionary = {}
func _ready() -> void:
	resolver.impact_located.connect(on_impact)
	resolver.feedback_cleared.connect(func(_actor: HeroActor) -> void: pending.clear())
func on_impact(target: HeroActor, amount: float, head: bool, shields: float, cast: int, tag: String, contact: Vector3) -> void:
	if amount <= 0 or tag == "bleed": return
	# Pellet implementations allocate individual cast IDs; same-tick weapon contacts coalesce.
	var key: String = "%d:%d:%s" % [target.get_instance_id(),Engine.get_physics_frames(),tag] if tag in ["shotgun","cannon"] else "%d:%d" % [target.get_instance_id(),cast]
	var at: Vector3 = target.body_point(1.65 if head else 1.1) if contact == Vector3.INF else contact
	if pending.has(key):
		pending[key].amount += amount
		pending[key].shields += shields
	else: pending[key] = {"at":at,"amount":amount,"shields":shields}
func _process(_delta: float) -> void:
	for hit: Dictionary in pending.values():
		var color := Color("63c9ff") if hit.shields >= hit.amount else Color("ff4057")
		var burst := HitSparkBurst.new()
		burst.tint = color
		resolver.get_parent().add_child(burst)
		burst.global_position = hit.at
	pending.clear()
