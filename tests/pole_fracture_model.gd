extends RefCounted

# Isolated authority/state prototype. It is not wired into WarPowerGrid.
# These values are provisional GAMEPLAY values, not real-world ballistics.
const CELL_SIZE:=90.0
const HEIGHT:=8.2
const MIN_BREAK_HEIGHT:=0.70
const MAX_BREAK_HEIGHT:=6.70
const DEFAULT_HP:=120.0
const MIN_VEHICLE_SPEED:=2.0
const VEHICLE_MOMENTUM:=42000.0
const BLAST_ENERGY:=80.0
const MAX_HIT_HORIZONTAL_OFFSET:=0.85

var authoritative:=false
var cells: Dictionary={}
var broken: Dictionary={}

func key(cell: Vector2i,index: int) -> String:
	return "%d:%d:%d"%[cell.x,cell.y,index]

func register(cell: Vector2i,positions: Array) -> bool:
	if cells.has(cell): return false
	var entries: Array=[]
	for value in positions:
		if typeof(value)!=TYPE_VECTOR3: return false
		var p: Vector3=value
		if not p.is_finite() or Vector2i(floori(p.x/CELL_SIZE),floori(p.z/CELL_SIZE))!=cell: return false
		entries.append({"position":p,"hp":DEFAULT_HP})
	cells[cell]=entries
	return true

func _valid(cell: Vector2i,index: int) -> bool:
	return cells.has(cell) and index>=0 and index<cells[cell].size()

func _contact_height(cell: Vector2i,index: int,point: Vector3) -> float:
	var base: Vector3=cells[cell][index].position
	return clampf(point.y-base.y,MIN_BREAK_HEIGHT,MAX_BREAK_HEIGHT)

func _shot_contact_valid(cell: Vector2i,index: int,point: Vector3) -> bool:
	if not point.is_finite(): return false
	var base: Vector3=cells[cell][index].position
	return Vector2(point.x-base.x,point.z-base.z).length()<=MAX_HIT_HORIZONTAL_OFFSET and point.y>=base.y-.15 and point.y<=base.y+HEIGHT+.15

func shot(cell: Vector2i,index: int,damage: float,point: Vector3,direction: Vector3) -> Dictionary:
	# Caller must supply a server-validated collision and weapon damage.
	if not authoritative or not _valid(cell,index) or broken.has(key(cell,index)): return {}
	if not is_finite(damage) or damage<=0 or not _shot_contact_valid(cell,index,point): return {}
	var entry: Dictionary=cells[cell][index]
	entry.hp=maxf(0.,float(entry.hp)-damage)
	if entry.hp>0: return {}
	return _break(cell,index,_contact_height(cell,index,point),direction)

func vehicle_impact(cell: Vector2i,index: int,mass: float,speed: float,point: Vector3,direction: Vector3) -> Dictionary:
	# WarVehicle is kinematic. 'mass' must be an explicit balance value and
	# speed must be captured before collision response, not after braking.
	if not authoritative or not _valid(cell,index) or broken.has(key(cell,index)): return {}
	if not is_finite(mass) or not is_finite(speed) or mass<=0 or speed<MIN_VEHICLE_SPEED: return {}
	if not _shot_contact_valid(cell,index,point) or mass*speed<VEHICLE_MOMENTUM: return {}
	return _break(cell,index,_contact_height(cell,index,point),direction)

func explosion(point: Vector3,energy: float,radius: float,visible: Callable=Callable()) -> Array[Dictionary]:
	# visible, when supplied, must be an authority-side occlusion test. It gets
	# origin, target, cell and index; do not exclude an entire shared cell RID.
	var events: Array[Dictionary]=[]
	if not authoritative or not point.is_finite() or not is_finite(energy) or not is_finite(radius) or energy<=0 or radius<=0: return events
	var first:=Vector2i(floori((point.x-radius)/CELL_SIZE),floori((point.z-radius)/CELL_SIZE))
	var last:=Vector2i(floori((point.x+radius)/CELL_SIZE),floori((point.z+radius)/CELL_SIZE))
	for x in range(first.x,last.x+1):
		for z in range(first.y,last.y+1):
			var cell:=Vector2i(x,z)
			if not cells.has(cell): continue
			for index in cells[cell].size():
				if broken.has(key(cell,index)): continue
				var base: Vector3=cells[cell][index].position
				var height:=clampf(point.y-base.y,MIN_BREAK_HEIGHT,MAX_BREAK_HEIGHT)
				var target:=base+Vector3.UP*height
				var offset:=target-point;var distance:=offset.length()
				if distance>radius or energy*maxf(0.,1.-distance/radius)<BLAST_ENERGY: continue
				if visible.is_valid() and not bool(visible.call(point,target,cell,index)): continue
				events.append(_break(cell,index,height,offset))
	return events

func _break(cell: Vector2i,index: int,height: float,direction: Vector3) -> Dictionary:
	var flat:=Vector3(direction.x,0,direction.z)
	if not flat.is_finite() or flat.length_squared()<.000001: flat=Vector3.FORWARD
	else: flat=flat.normalized()
	# Centimetres preserve the actual break height in snapshots at low cost.
	var event:={"cell":cell,"index":index,"direction":flat,"height_cm":roundi(clampf(height,MIN_BREAK_HEIGHT,MAX_BREAK_HEIGHT)*100.)}
	broken[key(cell,index)]=event.duplicate(true)
	return event

func apply_event(event: Dictionary) -> bool:
	# Network layer must enforce an authority-only reliable RPC and round ID.
	if not event.has_all(["cell","index","direction","height_cm"]): return false
	if typeof(event.cell)!=TYPE_VECTOR2I or typeof(event.index)!=TYPE_INT or typeof(event.direction)!=TYPE_VECTOR3 or typeof(event.height_cm)!=TYPE_INT: return false
	var cell: Vector2i=event.cell;var index: int=event.index;var height_cm: int=event.height_cm
	if not _valid(cell,index) or broken.has(key(cell,index)): return false
	if height_cm<roundi(MIN_BREAK_HEIGHT*100) or height_cm>roundi(MAX_BREAK_HEIGHT*100): return false
	var direction: Vector3=event.direction
	if not direction.is_finite() or Vector2(direction.x,direction.z).length_squared()<.000001: return false
	_break(cell,index,float(height_cm)/100.,direction)
	return true

func snapshot() -> Array[Dictionary]:
	var ids: Array=broken.keys();ids.sort()
	var result: Array[Dictionary]=[]
	for id in ids: result.append(Dictionary(broken[id]).duplicate(true))
	return result
