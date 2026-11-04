extends RefCounted

# Prototype occupancy accounting: removing one destroyed obstacle must not
# make a cell walkable if steep ground or another obstacle still blocks it.
var terrain: Dictionary={}
var counts: Dictionary={}
var objects: Dictionary={}

func set_terrain(cell: Vector2i,blocked: bool) -> void:
	if blocked: terrain[cell]=true
	else: terrain.erase(cell)

func add_object(id: String,occupied: Array[Vector2i]) -> void:
	assert(not objects.has(id))
	var unique: Dictionary={}
	for cell in occupied: unique[cell]=true
	objects[id]=unique.keys()
	for cell in unique: counts[cell]=int(counts.get(cell,0))+1

func remove_object(id: String) -> Array[Vector2i]:
	var changed: Array[Vector2i]=[]
	if not objects.has(id): return changed
	for cell: Vector2i in objects[id]:
		var next:=int(counts.get(cell,0))-1
		if next<=0: counts.erase(cell)
		else: counts[cell]=next
		changed.append(cell)
	objects.erase(id)
	return changed

func blocked(cell: Vector2i) -> bool:
	return terrain.has(cell) or int(counts.get(cell,0))>0
