extends WarGame

func _ready() -> void:
	set_meta("war_test",true);set_meta("war_visual_preview",true);set_meta("test_mode",true)
	super._ready()
	set_physics_process(false);set_process(false)
	offline_operation=true;mode="pvp";map_kind="war";war_clock=100.
	world_root=Node3D.new();add_child(world_root)
	var light:=DirectionalLight3D.new();light.rotation_degrees=Vector3(-42,-30,0);light.light_energy=1.6;world_root.add_child(light)
	var env:=WorldEnvironment.new();var settings:=Environment.new()
	settings.background_mode=Environment.BG_COLOR;settings.background_color=Color("89989a")
	settings.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;settings.ambient_light_color=Color("b1b8b1");settings.ambient_light_energy=.65
	env.environment=settings;world_root.add_child(env)
	var plane:=MeshInstance3D.new();var shape:=PlaneMesh.new();shape.size=Vector2(80,80);plane.mesh=shape
	world_root.add_child(plane)
	for x in [-5,0,5]:
		WarUniform.box(world_root,"RangeReference",Vector3(x,1,-20),Vector3(1.0,2.,.25),EnvironmentKit.material("wood:685d4a"))
	war_fx=WarProjectiles.new();war_fx.game=self;world_root.add_child(war_fx);war_fx.set_physics_process(false)
	vehicle_system=WarVehicles.new();vehicle_system.game=self;world_root.add_child(vehicle_system);vehicle_system.set_physics_process(false)
	for vehicle: WarVehicle in vehicle_system.vehicles.values(): vehicle.hide();vehicle.set_physics_process(false)
	local_player=make_actor(1,true,0,"antitank",Vector3.ZERO)
	make_actor(2,false,1,"soldier",Vector3(20,0,-25))
	join_ready=true;ui_focus.close_all();loading_screen.hide();menu_layer.hide();war_ui.deployment.hide();hud_layer.show()

func make_actor(id: int,local: bool,team: int,role: String,point: Vector3) -> WarPlayer:
	var actor:=_spawn_player(id,local,false,point) as WarPlayer
	actor.hp=100;actor.deployed=true;actor.apply_identity(team,role)
	actor.owned=["broom","glock","fal","sniper"];actor.loadout=actor.owned.duplicate();actor.set_physics_process(false)
	actor.yaw=0;actor.pitch=0;actor.rotation=Vector3.ZERO;actor.weapon_id="fal";actor._refresh_weapon();actor._update_view()
	members[id]={"team":team,"role":role,"deployed":true,"vehicle":"","shield":0.,"charges":4,"ready_at":0.,"last_gadget":-100.,"gadget":"rpg","weapon":"fal"}
	return actor
