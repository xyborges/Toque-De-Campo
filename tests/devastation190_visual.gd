extends "res://tests/library190_visual.gd"
func run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	viewport=SubViewport.new();viewport.size=Vector2i(1920,1080);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;viewport.own_world_3d=true;root.add_child(viewport)
	var display:=TextureRect.new();display.texture=viewport.get_texture();display.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root.add_child(display)
	game=WarGame.new();game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_visual_preview",true);viewport.add_child(game)
	game.online=false;game.mode="pvp";game.map_kind="desert";game._enter_match_world()
	game.set_process(false);game.set_physics_process(false);game.vehicle_system.set_process(false);game.vehicle_system.set_physics_process(false)
	game.soundscape.set_process(false);game.hud_layer.hide();game.menu_layer.hide()
	camera=Camera3D.new();camera.fov=58;camera.far=4200;game.world_root.add_child(camera)
	for entry in [["FachadaAtingida*","facade",Vector3(17,9,-22),Vector3(0,3,0)],["CarroCarbonizado*","car",Vector3(5,2.5,-5),Vector3(0,.6,0)],["CargaPortuaria*","cargo",Vector3(7,4,8),Vector3(0,1,0)],["CrateraImpacto*","crater",Vector3(6,4,6),Vector3.ZERO]]:
		var object:=game.world_root.find_child(entry[0],true,false) as Node3D
		await view("details-"+entry[1],object.global_position+entry[3],entry[2])
	var port: Vector3=WarCoast.PORTS[0]
	await view("details-west-port",port+Vector3(45,4,125),Vector3(-65,30,60))
	viewport.queue_free();display.queue_free();await create_timer(.8).timeout;quit()
