extends SceneTree
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var broker:=BRMatchBroker.new();root.add_child(broker)
	var ready:=broker.start_listening(39595,6,2)==OK
	broker.pool.rooms["fixture"]={"status":{"humans":3}}
	broker.pool.assignments["pending"]=true
	broker._publish_health()
	var record:=NavalStorage.read_json(NavalStorage.folder().path_join("br-broker-status.json"))
	var okay:=ready and int(record.get("connections",-1))==4 and int(record.get("humans",0))==3 and int(record.get("rooms",0))==1 and absf(Time.get_unix_time_from_system()-float(record.get("updated",0)))<2.
	broker.pool.rooms.clear();broker.pool.assignments.clear();broker._publish_health()
	var empty:=NavalStorage.read_json(NavalStorage.folder().path_join("br-broker-status.json"))
	okay=okay and int(empty.get("connections",-1))==0
	broker.free();await process_frame
	print("BR_BROKER_HEALTH ",okay);quit(0 if okay else 1)
