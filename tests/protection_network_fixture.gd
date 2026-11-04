extends "res://scripts/main.gd"

func _ready() -> void:
	set_meta("test_mode",true);online=true;mode="pvp";set_process(false);set_physics_process(false)
	world_root=Node3D.new();add_child(world_root)
	var actor:=_spawn_player(7,false,false,Vector3.ZERO)
	actor.set_process(false);actor.set_physics_process(false);actor.life_id=42;actor.hp=1000.
	actor.last_impact_weapon="ak"
	actor.set_meta("approved_loadout",{"vest":"vest_1","helmet":"helmet_2"})
