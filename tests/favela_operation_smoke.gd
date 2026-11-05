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
	ensure(WarTerrain.height_at(650,-700)-WarRules.BASES[0].y>125.0,
		"Desnível entre o acesso e a mata insuficiente")
	ensure(ResourceLoader.exists("res://modes/war/library/favela_casa_laje.tscn"),
		"Prefab casa ausente")
	ensure(ResourceLoader.exists("res://modes/war/library/favela_barricada_pneus.tscn"),
		"Prefab pneus ausente")
	for id in ["favela_pixacao","favela_lixo_calcada","favela_comercio_fachada","favela_poste_cabos","favela_rede_aerea","favela_moto_estacionada"]:
		var prefab:=WarPrefabFactory.create(id)
		ensure(WarPrefabFactory.ITEMS.has(id) and prefab.get_meta("library_id","")==id,
			"Objeto ausente no catálogo: "+id)
		prefab.free()
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
	ensure(map_def.current("favela") and int(identity.version)>0,"Manifesto do mapa ausente")
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
	ensure(tactical.road_paths.size()>=18,"Minimapa não mostra as mini-ruas da Favela")
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
		ensure(int(stats.get("houses",0))>=3500,"Densidade insuficiente")
		ensure(int(stats.get("stacked_houses",0))>=1000,"Faltam casas escalonadas")
		ensure(int(stats.get("walkable_roofs",0))>=60 and int(stats.get("roof_bridges",0))>=10,
			"Faltam acessos e ligações físicas entre lajes")
		ensure(int(stats.get("storefronts",0))>=50 and int(stats.get("wire_spans",0))>=200
			and int(stats.get("parked_bikes",0))>=10,"Faltam elementos de rua da Favela")
		ensure(int(stats.get("wall_tags",0))>1000 and int(stats.get("litter_clusters",0))>300,
			"Faltam marcas de uso nas paredes e bordas das ruas")
		ensure(int(stats.get("collision_shapes",0))>950,"Coberturas sem colisão")
		print("FAVELA_LAYOUT ",JSON.stringify(stats))
		if visuals:
			var tile:=map.get_node("FavelaTerrain_00_00/Surface") as MeshInstance3D
			var surface:=tile.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array=surface[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array=surface[Mesh.ARRAY_INDEX]
			var a:=vertices[indices[0]]
			ensure((vertices[indices[1]]-a).cross(vertices[indices[2]]-a).y<0.0,
				"Chão deve ter face frontal voltada para cima")
	await physics_frame
	await physics_frame
	_check_lane_clear(WarFavelaMap.PRIMARY,1.5,"Avenida")
	for i in WarFavelaMap.MINI_STREETS.size():
		_check_lane_clear(WarFavelaMap.MINI_STREETS[i],.36,"Mini-rua "+str(i+1))
	print("FAVELA_ROUTES ",path.size()," build_ms=",Time.get_ticks_msec()-terrain_clock)
	if problems.is_empty():
		print("FAVELA_SMOKE PASS")
		quit(0)
	else:
		for error in problems:printerr("FAVELA_SMOKE FAIL: "+error)
		quit(1)

func _check_lane_clear(route: Array,half_clearance: float,label: String) -> void:
	var space:=root.world_3d.direct_space_state
	var blocks:=0
	var first_block:=Vector2.INF
	for i in route.size()-1:
		var a: Vector2=route[i]
		var b: Vector2=route[i+1]
		var side: Vector2=(b-a).normalized().orthogonal()
		var samples:=ceili(a.distance_to(b))
		for step in samples+1:
			for offset: float in [-half_clearance,0.0,half_clearance]:
				var p:=a.lerp(b,float(step)/samples)+side*offset
				var ground:=WarTerrain.point(p.x,p.y)
				var ray:=PhysicsRayQueryParameters3D.create(ground+Vector3.UP*2.5,
					ground+Vector3.UP*.35,1)
				ray.hit_from_inside=true
				if not space.intersect_ray(ray).is_empty():
					blocks+=1
					if not first_block.is_finite():first_block=p
	ensure(blocks==0,"%s bloqueada (%d amostras, primeira em %s)"%[label,blocks,first_block])
