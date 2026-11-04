extends RefCounted
## Tool-only access to existing builders; no replacement global terrain.
const AFGHAN=preload("res://modes/battle_royale/map/afghan_map.gd")
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const BIOME=preload("res://modes/war/scripts/biome_map.gd")
var id: String
var world: Node3D
var biome: RefCounted
var mountain:=0
var limits:=Rect2()
var regional_biome: Image

func configure(key: String,variant:=0) -> void:
	id=key;mountain=variant
	match id:
		"ukraine":limits=Rect2(-1750,-1750,3500,3500);biome=BIOME.new();biome.load_map();WarTerrainEdits.prepare()
		"afghan":
			limits=Rect2(-1000,-1000,2000,2000)
			regional_biome=load("res://modes/battle_royale/map/afghan_biomes.png").get_image()
			if regional_biome.is_compressed():regional_biome.decompress()
		"desert":limits=Rect2(-150,-150,300,300)
		"office":limits=OfficeMap.BOUNDS
		"naval":limits=Rect2(-980,-980,1960,1960)

func build(parent: Node,visuals:=false) -> Node3D:
	world=Node3D.new();parent.add_child(world)
	match id:
		"ukraine":WarWorld.build(world,visuals)
		"afghan":
			var map:=AFGHAN.new();map.render_visuals=visuals;world.add_child(map);map.build()
		"desert":DesertMap.build(world,visuals)
		"office":OfficeMap.build(world,visuals)
		"naval":
			for index in NavalCatalog.ISLANDS.size():NavalIslands.build(world,index,mountain,visuals)
			NavalIslands.seabed(world,visuals,mountain)
	# Builders contain gameplay/weather scripts expecting their game owner.
	# Tools inspect static physics only; keep bodies active but stop callbacks.
	for child: Node in world.find_children("*","Node",true,false):child.set_process(false);child.set_physics_process(false)
	return world

func height_at(x: float,z: float) -> float:
	match id:
		"ukraine":return WarTerrain.height_at(x,z)
		"afghan":return AFGHAN.height_at(x,z)
		"desert":return DesertTerrain.height_at(x,z)
		"naval":
			for i in NavalCatalog.ISLANDS.size():
				var p:=Vector2(x-NavalCatalog.ISLANDS[i].x,z-NavalCatalog.ISLANDS[i].z)
				if p.length()<NavalCatalog.RADII[i]*1.3:return NavalIslands.height_at(p,i,mountain)
			return -36.
	return 0.

func grass_allowed(p: Vector2) -> bool:
	match id:
		"ukraine":return biome.footprint_field(p,1.35) and WarVegetation.clear_site(p,true) and WarRoads.distance(p)>=10. and WarTerrain.trench_distance(p)>=6.
		"afghan":
			# Margins of irrigated parcels, never over cultivated rows, channels or roads.
			var uv: Vector2=(p-limits.position)/limits.size
			var colour:=regional_biome.get_pixel(clampi(int(uv.x*regional_biome.get_width()),0,regional_biome.get_width()-1),clampi(int(uv.y*regional_biome.get_height()),0,regional_biome.get_height()-1))
			if colour.g<.1:return false
			var road:=LAND._near_road(p)
			if road.distance<road.width*.5+3. or absf(p.x-LAND.stream_center(p.y))<12. or LAND.in_farmland(p,2.):return false
			for farm: Dictionary in LAND.farmland_layout():
				var center:=Vector2(farm.position.x,farm.position.z)
				if absf(p.x-center.x)<farm.size.x*.5+9. and absf(p.y-center.y)<farm.size.y*.5+9.:return true
		"desert":
			# Sparse shoulders, no grass across the outpost or spawn aprons.
			if maxf(absf(p.x),absf(p.y))<46. or absf(p.x)<5.:return false
			for pad: Vector2 in DesertMap.SPAWN_PADS:
				if p.distance_to(pad)<8.:return false
			return posmod(int(p.x)*71+int(p.y)*31,13)==0
	return false

func spawns() -> Array[Vector3]:
	var result: Array[Vector3]=[]
	match id:
		"ukraine":
			for base: Vector3 in WarRules.BASES:result.append(base+Vector3(0,.16,-30))
		"afghan":result=AFGHAN.spawn_candidates().duplicate()
		"desert":
			for i in DesertMap.SPAWN_PADS.size():result.append(DesertMap.spawn_pad(i))
		"office":
			result.assign(OfficeMap.SPAWN_PADS)
		"naval":
			for x in [-800.,0.,800.]:
				for z in [-800.,0.,800.]:
					var p:=Vector3(x,0,z)
					if NavalCatalog.safe_point(p,25.):result.append(p)
	return result

func ground_colour(p: Vector2,h: float) -> Color:
	match id:
		"ukraine":return Color("182f3b") if h<3. else [Color("65765b"),Color("69534a"),Color("99885c"),Color("b6ad94")][biome.region(p)]
		"afghan":return Color("748063") if LAND.in_farmland(p) else Color("a3987f")
		"desert":return Color("b7a079")
		"office":return Color("8c9187") if OfficeMap.has_floor(p.x,p.y) else Color("18272c")
		"naval":return Color("7d8973") if h>0. else Color("183d4d")
	return Color.GRAY
