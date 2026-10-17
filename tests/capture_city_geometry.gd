extends "res://tests/capture_city.gd"
## Close views for stair faces, soffits, deck joints and underground opening rims.

func run() -> void:
	arena = load("res://scenes/city/meridian_gardens.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	session = arena.match_controller
	session.freeze_ai = true
	arena.player.controller.active = false
	camera = Camera3D.new()
	camera.far = 500
	arena.add_child(camera)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/city-frames"))
	while not session.navigation_ready: await frames(1)
	session.hud.visible = false
	await photograph("geometry-01-inner-stair-top", Vector3(-17.7,10,-1), Vector3(-17.7,2,10), 76)
	await photograph("geometry-02-station-stair", Vector3(0,2.1,57), Vector3(0,-1,36), 76)
	await photograph("geometry-03-outer-stair-side", Vector3(-49,2.2,37), Vector3(-41,3.8,31), 76)
	await photograph("geometry-04-hill-stair-rim", Vector3(6,2.2,26), Vector3(0,-2,15), 76)
	await photograph("geometry-05-garden-terrace", Vector3(-52,5,32), Vector3(-45,2,22), 76)
	await photograph("geometry-06-study-north-join", Vector3(43,6,13), Vector3(48,4.2,25), 76)
	await photograph("geometry-07-study-south-join", Vector3(43,5,44), Vector3(48,4.2,30), 76)
	await photograph("geometry-08-promenade-corner", Vector3(-40,9,-24), Vector3(-23,6.5,-20), 76)
	await photograph("geometry-09-arcade-approach", Vector3(24,2.1,37), Vector3(26,3,26), 76)
	await photograph("geometry-10-exchange-shop-join", Vector3(-18,-2,5), Vector3(-13,-2,-1), 76)
	await photograph("geometry-11-courtyard-stair-entry", Vector3(37.5,2.1,17), Vector3(39,3.5,32), 76)
	await photograph("geometry-12-switchback-landing", Vector3(32,12,40), Vector3(40,4,31), 76)
	await photograph("geometry-13-spawn-stair-width", Vector3(2,2.1,57), Vector3(0,-2,43), 76)
	arena.queue_free()
	await process_frame
	quit()
