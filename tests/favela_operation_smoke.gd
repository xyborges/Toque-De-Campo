extends SceneTree
## Execute: godot --headless --path <worktree> --script res://tests/favela_operation_smoke.gd
## Smoke de layout e regras sem multiplayer, sem publicar build.
var problems: Array[String] = []
func ensure(value: bool,description: String) -> void:
	if not value:problems.append(description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	ensure(WarRules.CURRENT_OPERATION==WarOperation.FAVELA,"Operação incorreta")
	ensure(WarOperation.half(WarOperation.FAVELA)==750.0,"Dimensão incorreta")
	ensure(WarRules.team_name(0)=="Polícia","Equipe 1 incorreta")
	ensure(WarRules.team_name(1)=="Bandidos","Equipe 2 incorreta")
	ensure(WarRules.launcher_for_team(0)=="","Polícia recebeu lançador")
	ensure(not WarRules.launcher_allowed(0,"rpg"),"Polícia tem RPG")
	ensure(not WarRules.launcher_allowed(0,"stinger"),"Polícia tem Stinger")
	ensure(WarRules.launcher_allowed(1,"rpg"),"Equipe 2 não possui RPG")
	ensure(WarRules.vehicle_count("guarani")==2,"Guaranis deveriam ser dois")
	ensure(WarRules.vehicle_enabled("bike_0") and WarRules.vehicle_enabled("bike_1"),"Motos removidas")
	for kind in ["bmp2","abrams","t90"]:
		ensure(not WarRules.vehicle_enabled(kind),kind+" apareceu na Favela")
	ensure(WarRules.OBJECTIVES.size()==5,"Cinco objetivos ausentes")
	for id in WarRules.OBJECTIVES:
		var objective: Dictionary=WarRules.OBJECTIVES[id]
		ensure(bool(objective.active),"Objetivo "+id+" desativado")
		ensure(WarFavelaMap.accessible(objective.position),"Objetivo "+id+" fora de circulação")
	for team in 2:
		ensure(WarFavelaMap.accessible(WarRules.BASES[team]),"Base inacessível "+str(team))
	ensure(ResourceLoader.exists("res://modes/war/library/favela_casa_laje.tscn"),
		"Prefab casa ausente")
	ensure(ResourceLoader.exists("res://modes/war/library/favela_barricada_pneus.tscn"),
		"Prefab pneus ausente")
	# Determinismo e aclive da via de entrada principal.
	for p in WarFavelaMap.PRIMARY:
		ensure(absf(WarTerrain.height_at(p.x,p.y)-WarFavelaMap.height_at(p.x,p.y))<.001,
			"Terreno do servidor diverge da Favela")
	for i in WarFavelaMap.PRIMARY.size()-1:
		var a: Vector2=WarFavelaMap.PRIMARY[i]
		var b: Vector2=WarFavelaMap.PRIMARY[i+1]
		var grade:=absf(WarTerrain.height_at(a.x,a.y)-WarTerrain.height_at(b.x,b.y))/a.distance_to(b)
		ensure(grade<.19,"Rampa principal excessiva: "+str(i))
	var transit:=WarBotTransit.new()
	ensure(transit.vehicle_graph.get_point_count()>20,"Grafo de veículos incompleto")
	var path:=transit.path(WarRules.BASES[0],WarRules.BASES[1],true)
	ensure(path.size()>4,"Rota viária entre bases ausente")
	var map_def:=load("res://scripts/maps/definition.gd")
	var identity: Dictionary=map_def.identity("favela")
	ensure(map_def.current("favela") and int(identity.version)==1,"Manifesto do mapa ausente")
	ensure(map_def.compatible("favela",identity),"Mapa incompatível com identidade anunciada")
	var source_data: Dictionary=map_def.get_definition("favela")
	ensure(map_def.source_hash(source_data.get("sources",[]))==str(source_data.get("source_hash","")),"Fontes do manifesto divergentes")
	var police_loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"antitank",0)
	ensure(str(police_loadout.get("equipment",""))=="","Loadout policial ganhou lançador")
	ensure(bool(GameLoadouts.validate(police_loadout,"war",GameWeapons.INFANTRY_IDS,"antitank",0).ok),"Loadout policial inválido")
	var bandit_loadout:=GameLoadouts.defaults("war",GameWeapons.INFANTRY_IDS,"antitank",1)
	ensure(str(bandit_loadout.get("equipment",""))=="rpg","Loadout bandido sem RPG")
	var tactical:=WarTacticalMap.new()
	tactical._prepare()
	ensure(tactical.road_paths.size()>=12,"Minimapa não mostra rede viária da Favela")
	ensure(tactical.land[0]==1,"Minimapa ainda usa oceano ucraniano")
	tactical.free()
	var terrain_clock:=Time.get_ticks_msec()
	var world:=Node3D.new()
	root.add_child(world)
	var visuals: bool="--favela-visuals" in OS.get_cmdline_user_args()
	WarWorld.build(world,visuals)
	var map:=world.get_node_or_null("FavelaWar") as WarFavelaMap
	ensure(map!=null,"Favela não construída")
	if map!=null:
		var stats: Dictionary=map.build_metrics
		ensure(int(stats.get("terrain_tiles",0))==225,"Malha incompleta")
		ensure(int(stats.get("houses",0))>=950,"Densidade insuficiente")
		ensure(int(stats.get("collision_shapes",0))>950,"Coberturas sem colisão")
		print("FAVELA_LAYOUT ",JSON.stringify(stats))
	print("FAVELA_ROUTES ",path.size()," build_ms=",Time.get_ticks_msec()-terrain_clock)
	if problems.is_empty():
		print("FAVELA_SMOKE PASS")
		quit(0)
	else:
		for error in problems:printerr("FAVELA_SMOKE FAIL: "+error)
		quit(1)
