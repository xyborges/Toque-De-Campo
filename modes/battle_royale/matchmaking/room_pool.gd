extends RefCounted
class_name BRRoomPool
const REGISTRY=preload("res://modes/battle_royale/matchmaking/room_registry.gd")
const PROTOCOL:=10
const CAPACITY:=12
const MIN_PORT:=3020
const MAX_PORT:=3035
var rooms: Dictionary={}
var assignments: Dictionary={}
var base_folder: String
var max_rooms:=4
var launcher: Callable
var running: Callable
var stopper: Callable
var closed:=false

func configure(folder: String,limit: int=4,launch: Callable=Callable(),alive: Callable=Callable(),stop: Callable=Callable()) -> void:
	base_folder=folder;max_rooms=clampi(limit,1,16);launcher=launch;running=alive;stopper=stop
	DirAccess.make_dir_recursive_absolute(base_folder)

func request(account: String,now: float,display_name: String="Jogador") -> Dictionary:
	if closed or not REGISTRY.is_hex(account,32):return {"ok":false,"error":"Conta inválida."}
	if assignments.has(account):return {"ok":true,"pending":true}
	if assignments.size()>=64:return {"ok":false,"error":"Fila ocupada. Tente novamente."}
	for record: Dictionary in rooms.values():
		if account in record.status.get("accounts",[]):return {"ok":false,"error":"Você já está em uma partida."}
	var selected: Dictionary={};var best:=-1
	for record: Dictionary in rooms.values():
		if not _accepts(record,now):continue
		var occupancy: int=int(record.status.get("humans",0))+record.pending.size()
		if occupancy>=CAPACITY:continue
		var score: int=occupancy+1000*int(bool(record.status.get("ready",false)))
		if score>best:selected=record;best=score
	if selected.is_empty():
		if rooms.size()>=max_rooms:return {"ok":false,"error":"Todas as partidas estão ocupadas. Tente novamente."}
		selected=_create_room(now)
		if selected.is_empty():return {"ok":false,"error":"Não foi possível preparar uma partida."}
	selected.pending[account]={"expires":now+120.,"token":"","delivered":false,"name":display_name.left(24)}
	assignments[account]=selected.id;_publish_expected(selected)
	return {"ok":true,"pending":true}

func _accepts(record: Dictionary,now: float) -> bool:
	var status: Dictionary=record.status
	if status.is_empty():return now-float(record.created)<90.
	if str(status.get("phase","")) not in ["loading","waiting"]:return false
	var deadline:=float(status.get("join_deadline",0.))
	return deadline<=0. or now<deadline-3.

func result(account: String,now: float) -> Dictionary:
	if not assignments.has(account):return {"ok":false,"error":"Busca encerrada."}
	var id: String=assignments[account]
	if not rooms.has(id):assignments.erase(account);return {"ok":false,"error":"Partida indisponível. Tente novamente."}
	var record: Dictionary=rooms[id]
	if not _accepts(record,now):
		cancel(account)
		var next:=request(account,now)
		return next if not bool(next.get("ok",false)) else {"ok":true,"pending":true}
	if not bool(record.status.get("ready",false)):return {"ok":true,"pending":true}
	var reservation: Dictionary=record.pending.get(account,{})
	if reservation.is_empty():return {"ok":false,"error":"Reserva encerrada."}
	if str(reservation.token).is_empty():
		reservation.expires=now+90.
		reservation.token=REGISTRY.create_admission(record.folder,id,account,float(reservation.expires))
		if str(reservation.token).is_empty():cancel(account);return {"ok":false,"error":"Não foi possível reservar a partida."}
	reservation.delivered=true
	return {"ok":true,"port":int(record.port),"room_id":id,"reservation":str(reservation.token),"expires":float(reservation.expires),"protocol":PROTOCOL}

func cancel(account: String,undelivered_only: bool=false) -> void:
	if not assignments.has(account):return
	var id: String=assignments[account]
	if rooms.has(id):
		var record: Dictionary=rooms[id];var reservation: Dictionary=record.pending.get(account,{})
		if undelivered_only and bool(reservation.get("delivered",false)):return
		REGISTRY.revoke_admission(record.folder,str(reservation.get("token","")))
		record.pending.erase(account);_publish_expected(record)
	assignments.erase(account)

func pump(now: float) -> void:
	for id: String in rooms.keys():
		var record: Dictionary=rooms[id]
		if running.is_valid() and not bool(running.call(int(record.pid))):_remove(id);continue
		var status:=REGISTRY.read_status(record.folder)
		if str(status.get("room_id",""))==id and int(status.get("pid",0))==int(record.pid):record.status=status
		status=record.status
		var humans: Array=status.get("accounts",[])
		for account: String in record.pending.keys():
			if account in humans or float(record.pending[account].expires)<=now:cancel(account)
		var phase:=str(status.get("phase","loading"));var age:=now-float(record.created)
		var stale:=not status.is_empty() and now-float(status.get("heartbeat",0.))>(45. if bool(status.get("ready",false)) else 90.)
		var empty: bool=humans.is_empty() and record.pending.is_empty()
		if empty and float(record.get("empty_since",-1.))<0.:record.empty_since=now
		if not empty:record.empty_since=-1.
		if phase in ["cancelled","closed"] or stale or (not bool(status.get("ready",false)) and age>90.) or (empty and now-float(record.empty_since)>20.):
			if stopper.is_valid():stopper.call(int(record.pid))
			_remove(id)

func _create_room(now: float) -> Dictionary:
	var used: Array=[]
	for record: Dictionary in rooms.values():used.append(int(record.port))
	var port:=MIN_PORT
	while port in used and port<=MAX_PORT:port+=1
	if port>MAX_PORT:return {}
	var id:=Crypto.new().generate_random_bytes(16).hex_encode();var folder:=base_folder.path_join(id)
	DirAccess.make_dir_recursive_absolute(folder)
	var pid:=int(launcher.call(port,id,folder)) if launcher.is_valid() else -1
	if pid<=0:return {}
	var record:={"id":id,"port":port,"folder":folder,"pid":pid,"created":now,"pending":{},"status":{},"empty_since":-1.}
	rooms[id]=record;return record

func _remove(id: String) -> void:
	if not rooms.has(id):return
	for account: String in rooms[id].pending.keys():cancel(account)
	rooms.erase(id)

func shutdown() -> void:
	closed=true
	for record: Dictionary in rooms.values():
		if stopper.is_valid():stopper.call(int(record.pid))
	for id: String in rooms.keys():_remove(id)

func _publish_expected(record: Dictionary) -> void:
	var rows: Array=[]
	for account in record.pending:
		var entry: Dictionary=record.pending[account]
		rows.append({"account":account,"name":str(entry.get("name","Jogador")).left(24),"expires":float(entry.expires)})
	REGISTRY.atomic_json(str(record.folder).path_join("expected.json"),{"players":rows})
