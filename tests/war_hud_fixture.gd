extends WarGame

func _build_desert() -> void:
	_static_box(world_root,"FixtureFloor",Vector3(0,-.25,0),Vector3(180,.5,180),Color("777c71"))
	var sun:=DirectionalLight3D.new();sun.rotation_degrees=Vector3(-55,-25,0);world_root.add_child(sun)
	var environment:=WorldEnvironment.new();environment.environment=Environment.new()
	environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("7b8989")
	environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.65
	world_root.add_child(environment)

func find_spawn(id: int) -> Vector3:
	return Vector3.ZERO if id==1 else Vector3(8,0,-12)

func gameplay_input_allowed() -> bool:
	return mode!="menu" and not ui_focus.blocked()
