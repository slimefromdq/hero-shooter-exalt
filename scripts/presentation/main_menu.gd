extends Node

func _ready() -> void:
	TrainingInputs.install()
	if HeroRoster.consume_direct_entry():
		get_tree().change_scene_to_file.call_deferred("res://scenes/city/meridian_gardens.tscn")
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(GameMenu.new())
