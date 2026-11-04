extends SceneTree
var mode: NavalMode
func _initialize() -> void: run.call_deferred()
func capture(label: String) -> void:
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/screens/naval-"+label+".png")
func run() -> void:
	mode = NavalMode.new()
	mode.set_meta("test_controls",true)
	root.add_child(mode)
	await capture("menu")
	mode.network.account = {"coins":30000,"owned":NavalCatalog.SHIPS.keys(),"selected":"heavy"}
	mode._refresh_fleet("shop")
	mode._open("shop")
	await capture("shop")
	mode.focus.close_all()
	mode.network.connection.multiplayer_peer = OfflineMultiplayerPeer.new()
	mode.network.room = {"id":"visual","match":"visual","state":"IN_PROGRESS"}
	mode._build_world("visual")
	var states: Array = []
	var peer := 0
	for kind in ["heavy","light","combat","assault","submarine"]:
		peer += 1
		var ship := NavalShip.new()
		mode.world.add_child(ship)
		ship.build(kind,peer,"test-"+str(peer),str(NavalCatalog.SHIPS[kind].name))
		ship.global_position = Vector3((peer-1)*21,0,0)
		ship.heading = 0.0
		ship.rotation = Vector3.ZERO
		var state := ship.snapshot()
		states.append(state)
		ship.free()
	mode._snapshot({"room":"visual","match":"visual","tick":1,"time":0.0,"ships":states,"projectiles":[],"scores":{"a":{"name":"Comandante","kills":2,"deaths":1},"b":{"name":"Alvo","kills":1,"deaths":2}}})
	await capture("combat")
	var inspection := Camera3D.new()
	mode.world.add_child(inspection)
	inspection.current = true
	inspection.position = Vector3(48,37,62)
	inspection.look_at(Vector3(42,0,0))
	await capture("fleet")
	inspection.current = false
	mode.camera.current = true
	mode.camera.zoom = true
	await create_timer(0.5).timeout
	await capture("zoom")
	mode.queue_free()
	await process_frame
	quit()
