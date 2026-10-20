class_name CombatHUD
extends RefCounted
const SHIELD_COLOR: Color = Color("55bdfc")
## Horizontal health + shield strip shared by training and city HUDs.
static func vitals(canvas: Control, actor: HeroActor, regular: Font, heavy: Font, at: Vector2, width: float = 400.0) -> void:
	var green := Color("80f54e")
	var paper := Color("fbfff3")
	var background := Color(.025,.06,.085,.86)
	canvas.draw_rect(Rect2(at + Vector2(-4,-4),Vector2(width + 8,30)),background)
	canvas.draw_rect(Rect2(at,Vector2(width,22)),Color("25452d"))
	var fraction: float = clampf(actor.health / actor.tuning.max_health,0,1)
	canvas.draw_rect(Rect2(at,Vector2(width * fraction,22)),green if actor.health > 50 else Color("ff6e55"))
	var ceiling: float = actor.effective_max_health() / actor.tuning.max_health
	if ceiling < 1:
		canvas.draw_rect(Rect2(at + Vector2(width * ceiling,0),Vector2(width * (1-ceiling),22)),Color("a166cc"))
		canvas.draw_string(heavy,at + Vector2(190,-12),"MAX %d / %d" % [actor.effective_max_health(),actor.tuning.max_health],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("e8baff"))
	var health_text: String = "%d  /  %d" % [ceili(actor.health),actor.effective_max_health()]
	canvas.draw_string_outline(heavy,at + Vector2(12,17),health_text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,3,Color("14301a"))
	canvas.draw_string(heavy,at + Vector2(12,17),health_text,HORIZONTAL_ALIGNMENT_LEFT,-1,18,paper)
	canvas.draw_string_outline(heavy,at + Vector2(0,-12),HeroRoster.display_name(actor.tuning.hero_id).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,20,4,background)
	canvas.draw_string(heavy,at + Vector2(0,-12),HeroRoster.display_name(actor.tuning.hero_id).to_upper(),HORIZONTAL_ALIGNMENT_LEFT,-1,20,paper)
	canvas.draw_string(regular,at + Vector2(0,44),"HEALTH",HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color("c5d7c4"))
	if actor.shields > 0:
		canvas.draw_rect(Rect2(at + Vector2(0,-44),Vector2(width,11)),background)
		canvas.draw_rect(Rect2(at + Vector2(0,-44),Vector2(width * clampf(actor.shields / actor.tuning.max_health,0,1),11)),SHIELD_COLOR)
		canvas.draw_string(heavy,at + Vector2(width - 75,-50),"+%d" % ceili(actor.shields),HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("9bdeff"))

	var temporary: float = actor.overhealth.value()
	if temporary > 0:
		canvas.draw_rect(Rect2(at+Vector2(0,27),Vector2(width,7)),background)
		canvas.draw_rect(Rect2(at+Vector2(0,27),Vector2(width*clampf(temporary/actor.tuning.max_health,0,1),7)),ActorOverhealth.COLOR)
		canvas.draw_string(heavy,at+Vector2(width-180,49),"+%d OVERHEALTH" % ceili(temporary),HORIZONTAL_ALIGNMENT_LEFT,-1,14,ActorOverhealth.COLOR)
static func hit(canvas: Control, font: Font, caption: String, center: Vector2, head: bool, remaining: float) -> void:
	var color := Color("ffe47b") if head else Color("fbfff4")
	color.a = minf(1.0,remaining * 4.0)
	var at: Vector2 = center + Vector2(36,-30 - (1.0 - minf(1.0,remaining / .8)) * 15)
	canvas.draw_string_outline(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,30,5,Color(0.03,.05,.07,color.a))
	canvas.draw_string(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,30,color)

static func ammo(canvas: Control, actor: HeroActor, font: Font, center: Vector2) -> void:
	var caption: String = "∞" if actor.kit is RelayKit else "%d / %d" % [actor.kit.ammo,actor.tuning.magazine]
	var color := Color("ffe080") if actor.kit.ammo == 0 or actor.kit.reloading else Color("fbfff4")
	var at: Vector2 = center + Vector2(40,23)
	canvas.draw_string_outline(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,22,4,Color(.025,.04,.06,.95))
	canvas.draw_string(font,at,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,22,color)
	if not actor.kit is RelayKit and (actor.kit.reloading or actor.kit.ammo == 0):
		var prompt: String = "LOADING %.1fs" % actor.kit.reload_remaining if actor.kit.reloading else "R  RELOAD"
		canvas.draw_string_outline(font,at + Vector2(0,17),prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,Color(.025,.04,.06,.95))
		canvas.draw_string(font,at + Vector2(0,17),prompt,HORIZONTAL_ALIGNMENT_LEFT,-1,11,color)

	if actor.kit is RelayKit and (actor.kit as RelayKit).volley_charging:
		var k := actor.kit as RelayKit
		canvas.draw_rect(Rect2(at+Vector2(0,8),Vector2(100,5)),Color("193b43"))
		canvas.draw_rect(Rect2(at+Vector2(0,8),Vector2(100*k.volley_age/k.data().volley_charge,5)),Color("a5ffe9"))

	if actor.kit.free_slide_ammo():
		canvas.draw_string_outline(font,at+Vector2(0,18),"SLIDE / FREE AMMO",HORIZONTAL_ALIGNMENT_LEFT,-1,11,3,Color("10252e"))
		canvas.draw_string(font,at+Vector2(0,18),"SLIDE / FREE AMMO",HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("9dfbe2"))
	if actor.state == "ultimate" and actor.kit is NimbusKit:
		canvas.draw_string_outline(font,center+Vector2(-130,100),"%d SHOTS / %.1fs" % [(actor.kit as NimbusKit).ultimate_remaining,actor.state_time],HORIZONTAL_ALIGNMENT_LEFT,-1,20,4,Color("10252e"))
		canvas.draw_string(font,center+Vector2(-130,100),"%d SHOTS / %.1fs" % [(actor.kit as NimbusKit).ultimate_remaining,actor.state_time],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("9dfbe2"))
