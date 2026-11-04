extends RefCounted

# Authority-side deterministic state model, kept outside the game until the
# rendering, physics and network integration has passed its acceptance tests.
const CELL_SIZE:=90.0
const MIN_COLLISION_SPEED:=2.0
const MOMENTUM:={"pole":42000.0,"thin":65000.0,"thick":170000.0,"burnt":35000.0}
const BLAST_ENERGY:={"pole":80.0,"thin":120.0,"thick":270.0,"burnt":65.0}
var cells: Dictionary={}
var broken: Dictionary={}

func cell_for(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x/CELL_SIZE),floori(point.z/CELL_SIZE))

func register(cell: Vector2i,items: Array) -> void:
	# Each entry's position, kind and index must be generated deterministically
	# and match the exact visual and collider owner used by the same build.
	assert(not cells.has(cell))
	for item in items:
		assert(MOMENTUM.has(item.kind))
		assert(cell_for(item.position)==cell)
	cells[cell]=items.duplicate(true)

func key(cell: Vector2i,index: int) -> String:
	return "%d:%d:%d"%[cell.x,cell.y,index]

func impact(cell: Vector2i,index: int,mass: float,speed: float,direction: Vector3) -> Dictionary:
	if not is_finite(mass) or not is_finite(speed) or mass<=0 or speed<MIN_COLLISION_SPEED: return {}
	if not cells.has(cell) or index<0 or index>=cells[cell].size() or broken.has(key(cell,index)): return {}
	var kind: String=cells[cell][index].kind
	if mass*speed<float(MOMENTUM[kind]): return {}
	return _break(cell,index,direction)

func explosion(point: Vector3,calibre: float,radius: float) -> Array[Dictionary]:
	var events: Array[Dictionary]=[]
	if not is_finite(calibre) or not is_finite(radius) or calibre<=0 or radius<=0: return events
	var first:=cell_for(point-Vector3(radius,0,radius));var last:=cell_for(point+Vector3(radius,0,radius))
	for x in range(first.x,last.x+1):
		for z in range(first.y,last.y+1):
			var cell:=Vector2i(x,z)
			if not cells.has(cell): continue
			for index in cells[cell].size():
				if broken.has(key(cell,index)): continue
				var item: Dictionary=cells[cell][index];var offset: Vector3=item.position-point
				var distance:=offset.length()
				if distance>radius: continue
				var local_energy:=calibre*maxf(0.0,1.0-distance/radius)
				if local_energy>=float(BLAST_ENERGY[item.kind]): events.append(_break(cell,index,offset))
	return events

func _break(cell: Vector2i,index: int,direction: Vector3) -> Dictionary:
	var flat:=Vector3(direction.x,0,direction.z)
	if not flat.is_finite() or flat.length_squared()<.000001: flat=Vector3.FORWARD
	else: flat=flat.normalized()
	var event:={"cell":cell,"index":index,"direction":flat}
	broken[key(cell,index)]=event
	return event

func snapshot() -> Array:
	return broken.values().duplicate(true)

func apply_event(event: Dictionary) -> bool:
	# The client only accepts an authority event, never an asserted hit. Caller
	# must enforce RPC authority, build compatibility and snapshot ordering.
	if not event.has_all(["cell","index","direction"]): return false
	var cell: Vector2i=event.cell;var index:=int(event.index)
	if not cells.has(cell) or index<0 or index>=cells[cell].size() or broken.has(key(cell,index)): return false
	_break(cell,index,event.direction)
	return true
