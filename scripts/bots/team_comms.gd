class_name TeamComms
extends CanvasLayer
## On-screen team chat for the human player's side: short bot callouts ("Ult ready",
## "Fall back!", "Wisp flanking left") and the player's own V ping ("Need healing").
## Only the player's own team is shown; enemy bots still talk to their director silently.

const MAX_LINES: int = 4
const LINE_SECONDS: float = 6.0
var director: TeamDirector
var player: HeroActor
var lines: Array[Dictionary] = []
var box: VBoxContainer

static func attach(owner: TeamDirector, human: HeroActor) -> TeamComms:
	var parent: Node = owner.get_parent()
	var existing: TeamComms = parent.get_node_or_null("TeamComms%d" % owner.team) as TeamComms
	if existing != null: return existing
	var comms := TeamComms.new()
	comms.name = "TeamComms%d" % owner.team
	comms.director = owner
	comms.player = human
	comms.layer = 5
	parent.add_child(comms)
	owner.team_comms.connect(comms.on_message)
	return comms

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	box = VBoxContainer.new()
	box.name = "Lines"
	box.anchor_top = .42
	box.anchor_bottom = .42
	box.offset_left = 24
	box.offset_right = 520
	box.add_theme_constant_override("separation",4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

func on_message(speaker: String, hero: String, text: String, _kind: String) -> void:
	var label := Label.new()
	label.text = "%s (%s): %s" % [speaker,hero.capitalize(),text] if speaker != "" else text
	label.add_theme_color_override("font_color",Color("9fe7f5"))
	label.add_theme_color_override("font_outline_color",Color(0,0,0,.85))
	label.add_theme_constant_override("outline_size",5)
	label.add_theme_font_size_override("font_size",17)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	lines.append({"label":label,"age":0.0})
	while lines.size() > MAX_LINES:
		lines.pop_front().label.queue_free()

func _process(delta: float) -> void:
	for entry: Dictionary in lines.duplicate():
		entry.age += delta
		var label: Label = entry.label
		label.modulate.a = clampf((LINE_SECONDS-float(entry.age))/1.0,0,1)
		if float(entry.age) >= LINE_SECONDS:
			lines.erase(entry)
			label.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if InputMap.has_action("team_ping") and event.is_action_pressed("team_ping") and is_instance_valid(player) and player.alive and is_instance_valid(director):
		director.player_ping(player)
