class_name ControlFeedback
extends RefCounted
## Read-only snapshots: UI never grants or extends control restrictions.
static func snapshot(actor: HeroActor) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for kind: String in actor.statuses.effects:
		var effect: Dictionary = actor.statuses.effects[kind]
		if kind == "root": result.append(entry("root","[#] ROOTED","Movement locked; attacks available",effect.remaining,Color("d9b4ff"),220))
		elif kind == "slow": result.append(entry("slow","[~] SLOWED","Movement reduced; mobility disabled",effect.remaining,Color("91d6ff"),330))
	for thread: RedThread in actor.get_tree().get_nodes_in_group("red_threads"):
		if thread.target == actor and thread.valid(): result.append(entry("thread","RED THREAD","Outward mobility limited to 16m; walk or break sight",thread.remaining,Color("ff4968"),180))
	var state: String = actor.state
	if state in ["stagger","counterthrow","throw_release"]:
		result.append(entry(state,"[!] STAGGER" if state == "stagger" else "[X] COUNTER BREAK","Actions locked",actor.state_time,Color("ffca78"),160 if state == "stagger" else 260))
	if state in ["captured","throw_pair"]:
		var left: float = actor.tuning.throw_duration * (1-actor.close.pair_progress)
		result.append(entry("throw","[<>] THROW CAPTURE","Paired action; controls locked",left,Color("ff99a9"),120))
	if actor.boot_pair != null:
		result.append(entry("boot","[>] BOOT ATTACHED" if state == "boot_attached" else "[>] BOOT CAPTURE","Turn to aim release" if state == "boot_attached" else "Actions locked; cleanse releases",actor.boot_pair.remaining,Color("ffd18c"),95))
	if actor.motor.external_velocity.length() > .2:
		result.append(entry("push","[>>] DISPLACED","External push; no added action lock",actor.motor.external_velocity.length()/actor.tuning.braking,Color("a9f3df"),440))
	return result

static func entry(kind: String, label: String, detail: String, remaining: float, color: Color, tone: int) -> Dictionary:
	return {"kind":kind,"label":label,"detail":detail,"remaining":maxf(0,remaining),"color":color,"tone":tone}

static func caption(actor: HeroActor) -> String:
	var lines := PackedStringArray()
	for item: Dictionary in snapshot(actor): lines.append("%s  %.1fs" % [item.label,item.remaining])
	return "\n".join(lines)

static func draw(canvas: Control, actor: HeroActor, font: Font, at: Vector2) -> void:
	for item: Dictionary in snapshot(actor):
		canvas.draw_style_box(panel(),Rect2(at,Vector2(355,37)))
		canvas.draw_string(font,at+Vector2(8,15),"%s  %.1fs" % [item.label,item.remaining],HORIZONTAL_ALIGNMENT_LEFT,-1,13,item.color)
		canvas.draw_string(font,at+Vector2(8,30),item.detail,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("e4eadf"))
		at.y += 40

static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.02,.04,.065,.9)
	return style
