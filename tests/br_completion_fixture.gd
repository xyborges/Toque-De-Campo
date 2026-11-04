extends "res://tests/br_loot_network_fixture.gd"

func find_spawn(id: int) -> Vector3:
	return Vector3((id%5)*4,0,4)

func spawn_ragdoll(_pos: Vector3,_killer: int,_source: GamePlayer=null) -> void:pass

func flat_world() -> void:
	world_root=Node3D.new();add_child(world_root)
	spectator=Camera3D.new();world_root.add_child(spectator)
	map_kind="afghan";mode="pvp";phase="active";pvp_spawn_confirmed=true
	var floor_body:=StaticBody3D.new();world_root.add_child(floor_body)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(80,1,80);shape.shape=box;shape.position.y=-.5;floor_body.add_child(shape)
	var view:=MeshInstance3D.new();view.mesh=BoxMesh.new();view.mesh.size=box.size;view.position.y=-.5;view.material_override=EnvironmentKit.material("earth:81795c");floor_body.add_child(view)
	loot_visuals=BRLootVisuals.new();loot_visuals.game=self;world_root.add_child(loot_visuals)
	grenades_system=GameGrenades.new();grenades_system.game=self;world_root.add_child(grenades_system)
	if DisplayServer.get_name()!="headless":BRAfghanAtmosphere.install(world_root)
	ui_focus.close_all();third_person=false
	hud_layer.show()
	br_zone.configure(712907,[Vector3.ZERO]);br_zone.begin(_now())
