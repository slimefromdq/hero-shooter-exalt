class_name MovementHUD
extends RefCounted
static func draw(canvas: Control, actor: HeroActor, font: Font, center: Vector2) -> void:
	var feedback: MovementPresentation = actor.presentation.movement
	if feedback == null or not actor.alive: return
	if feedback.failure_left > 0:
		var color := Color("ffca78")
		color.a = minf(1,feedback.failure_left/.15)
		var width: float = font.get_string_size(feedback.failure,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		var at: Vector2 = center+Vector2(-width*.5,77)
		canvas.draw_style_box(panel(),Rect2(at+Vector2(-9,-17),Vector2(width+18,25)))
		canvas.draw_string(font,at,feedback.failure,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	elif feedback.hud_left > 0:
		var color := Color("c7f6f5")
		color.a = minf(1,feedback.hud_left/.12)
		var at: Vector2 = center+Vector2(-37,31)
		canvas.draw_arc(at,12,-PI/2,-PI/2+TAU*feedback.hud_left/.35,24,color,2,true)
		match feedback.hud_kind:
			"wall_jump":
				canvas.draw_line(at+Vector2(-6,6),at+Vector2(-6,-6),color,2,true)
				canvas.draw_polyline(PackedVector2Array([at+Vector2(0,5),at+Vector2(5,-4),at+Vector2(0,-2)]),color,2,true)
			"dash", "dash_slide":
				for x: float in [-5,2]: canvas.draw_polyline(PackedVector2Array([at+Vector2(x-2,-5),at+Vector2(x+3,0),at+Vector2(x-2,5)]),color,2,true)
				if feedback.hud_kind == "dash_slide": canvas.draw_line(at+Vector2(-7,8),at+Vector2(8,8),color,2,true)
			"slide":
				canvas.draw_line(at+Vector2(-7,4),at+Vector2(7,4),color,2,true)
				canvas.draw_line(at+Vector2(-4,0),at+Vector2(5,-3),color,2,true)

static func panel() -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = Color(.035,.045,.06,.85)
	result.corner_radius_top_left = 4
	result.corner_radius_top_right = 4
	result.corner_radius_bottom_left = 4
	result.corner_radius_bottom_right = 4
	return result
