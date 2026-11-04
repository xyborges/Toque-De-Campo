extends RefCounted
const DEFINITIONS=preload("res://scripts/maps/definition.gd")
const DATA=preload("res://scripts/maps/navigation_data.gd")
static var cache: Dictionary={}

static func install(director: RefCounted,id: String) -> bool:
	if "--map-uncached" in OS.get_cmdline_user_args():return false
	if not DEFINITIONS.current(id):return false
	var path:=DEFINITIONS.ROOT+id+"/navigation.res"
	if not ResourceLoader.exists(path):return false
	if not cache.has(id):cache[id]=load(path)
	var data: DATA=cache[id]
	if data.source_hash!=DEFINITIONS.get_definition(id).get("source_hash","") or data.map_id!=id:return false
	if data.blocked.size()!=data.region.size.x*data.region.size.y:return false
	director.cell=data.cell_size.x;director.origin=data.offset
	director.grid.region=data.region;director.grid.cell_size=data.cell_size;director.grid.offset=data.offset
	director.grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	director.grid.update()
	for z in data.region.size.y:
		for x in data.region.size.x:
			var index:=z*data.region.size.x+x;var point:=data.region.position+Vector2i(x,z)
			director.grid.set_point_solid(point,data.blocked[index]!=0)
			if data.weights[index]!=1.:director.grid.set_point_weight_scale(point,data.weights[index])
	if id=="ukraine":director.heights=data.heights
	return true
