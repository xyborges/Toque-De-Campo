extends SceneTree
const LAND=preload("res://modes/battle_royale/map/afghan_landform.gd")
const DATA=preload("res://modes/battle_royale/map/prepared_terrain.gd")
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var data:=DATA.new();data.source_hash=FileAccess.get_sha256("res://modes/battle_royale/map/afghan_landform.gd")
	data.heights.resize(data.side*data.side)
	var start:=Time.get_ticks_msec()
	for z in data.side:
		for x in data.side:data.heights[z*data.side+x]=LAND.rawheight((x+data.minimum)*data.spacing,(z+data.minimum)*data.spacing)
	DirAccess.make_dir_recursive_absolute("res://modes/battle_royale/map/prepared")
	var result:=ResourceSaver.save(data,"res://modes/battle_royale/map/prepared/afghan_heights.res",ResourceSaver.FLAG_COMPRESS)
	print("PREPARED_TERRAIN ",result," samples=",data.heights.size()," ms=",Time.get_ticks_msec()-start);quit(result)
