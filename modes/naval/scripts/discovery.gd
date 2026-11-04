extends Node
class_name NavalDiscovery
signal changed
const DISCOVERY_PORT := 3013
var service: NavalNetwork
var socket := PacketPeerUDP.new()
var found: Dictionary = {}
var targets: Dictionary = {}
var last_scan := -10.0
var signature := ""
var discovery_port := DISCOVERY_PORT
var nonce := ""
var next_reply: Dictionary = {}
var lookup_room := ""
var next_bind_retry := 0.0
func start(server: NavalNetwork = null) -> Error:
	service = server
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--naval-discovery-port="): discovery_port = int(arg.trim_prefix("--naval-discovery-port="))
	var error := socket.bind(discovery_port if service != null else 0,"0.0.0.0")
	if error == OK: socket.set_broadcast_enabled(true)
	return error
func scan(address := "") -> void:
	if service != null or not socket.is_bound(): return
	nonce = NavalCatalog.uid()
	last_scan = Time.get_ticks_msec()*0.001
	if not address.is_empty(): targets[address] = true
	var destinations: Dictionary = targets.duplicate()
	destinations["255.255.255.255"] = true
	destinations["127.0.0.1"] = true
	for address_value in local_addresses():
		var pieces := str(address_value).split(".")
		destinations["%s.%s.%s.255" % [pieces[0],pieces[1],pieces[2]]] = true
	var packet := JSON.stringify({"game":"toque-naval","protocol":NavalCatalog.PROTOCOL,"query":nonce,"lookup":lookup_room}).to_utf8_buffer()
	for destination in destinations:
		if socket.set_dest_address(str(destination),discovery_port) == OK: socket.put_packet(packet)
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()*0.001
	if not socket.is_bound():
		# A previous game version may briefly own discovery while its last room
		# closes. Keep the new server discoverable without forcing another restart.
		if service != null and now>=next_bind_retry:
			next_bind_retry = now+2.0
			if socket.bind(discovery_port,"0.0.0.0")==OK: socket.set_broadcast_enabled(true)
		return
	if service == null and now-last_scan>1.0: scan()
	var budget := 24
	while socket.get_available_packet_count()>0 and budget>0:
		budget -= 1
		var packet := socket.get_packet()
		var address := socket.get_packet_ip()
		var port := socket.get_packet_port()
		if packet.size()>7000: continue
		var parser := JSON.new()
		if parser.parse(packet.get_string_from_utf8()) != OK or not parser.data is Dictionary: continue
		var data: Dictionary = parser.data
		if data.get("game") != "toque-naval" or int(data.get("protocol",-1)) != NavalCatalog.PROTOCOL: continue
		if service != null:
			if not data.get("query") is String or str(data.query).length()!=32: continue
			var id := address+":"+str(port)
			if now < float(next_reply.get(id,0.0)): continue
			next_reply[id] = now+0.25
			if next_reply.size()>128: next_reply.erase(next_reply.keys()[0])
			var rooms: Array = []
			for room: Dictionary in service.rooms.values():
				if not room.private and room.state != "CLOSING": rooms.append({"id":room.id,"name":room.name,"players":room.members.size(),"limit":room.limit,"state":room.state,"late":room.late})
			var answer := {"game":"toque-naval","protocol":NavalCatalog.PROTOCOL,"query":data.query,"port":service.port,"rooms":rooms}
			# Private rooms stay unlisted. An exact code lookup only discloses existence;
			# authentication, capacity and password are still checked by the ENet server.
			var lookup := str(data.get("lookup",""))
			if lookup.length()==32 and service.rooms.has(lookup): answer["resolved"] = lookup
			socket.set_dest_address(address,port)
			socket.put_packet(JSON.stringify(answer).to_utf8_buffer())
		else:
			if data.get("query") != nonce or not data.get("rooms") is Array or data.rooms.size()>8: continue
			var game_port := int(data.get("port",0))
			if game_port<1024 or game_port>65535: continue
			var rooms: Array = []
			for room: Variant in data.rooms:
				if room is Dictionary and room.get("id") is String and str(room.id).length()==32 and room.get("name") is String:
					rooms.append({"id":room.id,"name":str(room.name).left(32),"players":clampi(int(room.get("players",0)),0,6),"limit":clampi(int(room.get("limit",6)),2,6),"state":str(room.get("state","")).left(20),"late":bool(room.get("late",false))})
			var endpoint := address+":"+str(game_port)
			var resolved := str(data.get("resolved",""))
			if resolved != lookup_room: resolved = ""
			found[endpoint] = {"address":address,"port":game_port,"endpoint":endpoint,"rooms":rooms,"resolved":resolved,"seen":now}
	if service == null:
		for id in found.keys():
			if now-float(found[id].seen)>4.0: found.erase(id)
		var visible: Dictionary = {}
		for id in found: visible[id] = found[id].rooms
		var current := JSON.stringify(visible)
		if current != signature:
			signature = current
			changed.emit()
func resolve(address: String) -> Dictionary:
	for data: Dictionary in found.values():
		if data.address == address or (address in ["localhost","127.0.0.1"] and data.address == "127.0.0.1"): return data
	return {}
func find_room(room_id: String) -> Dictionary:
	for data: Dictionary in found.values():
		if data.get("resolved","") == room_id: return data
		for room: Dictionary in data.rooms:
			if room.id == room_id: return data
	return {}
static func local_addresses() -> Array[String]:
	var result: Array[String] = []
	for interface: Dictionary in IP.get_local_interfaces():
		var label := str(interface.get("friendly",interface.get("name",""))).to_lower()
		if "virtual" in label or "vethernet" in label or "vmware" in label or "loopback" in label: continue
		for value in interface.addresses:
			var address := str(value)
			if address.is_valid_ip_address() and address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254.") and address != "0.0.0.0": result.append(address)
	result.sort_custom(func(a: String,b: String): return a.begins_with("192.168.") and not b.begins_with("192.168."))
	return result
func _exit_tree() -> void: socket.close()
