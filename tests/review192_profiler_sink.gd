extends SceneTree
# Local receiver for the engine's ordinary remote-debugger profiler stream.
# PacketPeerStream decodes Godot Variants; object decoding stays disabled.
var server:=TCPServer.new()
var stream: StreamPeerTCP
var packets:=PacketPeerStream.new()
var port:=39631
var file:="res://work/perf192/godot-profiler-server.json"
var frames: Array=[]
var signatures: Dictionary={}
var counts: Dictionary={}
var started:=0
var last_saved:=0
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-port="): port=int(arg.trim_prefix("--capture-port="))
		if arg.begins_with("--capture-file="): file=arg.trim_prefix("--capture-file=")
	if server.listen(port,"127.0.0.1")!=OK: quit(1);return
	packets.set_input_buffer_max_size(8388608);started=Time.get_ticks_msec();print("PROFILER_LISTEN ",port)
func _process(_delta: float) -> bool:
	if stream==null and server.is_connection_available():
		stream=server.take_connection();packets.stream_peer=stream
	if stream:
		stream.poll()
		while packets.get_available_packet_count()>0:
			var message=packets.get_var(false)
			if not message is Array or message.size()!=3: continue
			var kind:=str(message[0]);counts[kind]=int(counts.get(kind,0))+1
			if kind=="servers:function_signature":
				var args: Array=message[2]
				if args.size()==2: signatures[str(args[1])]=args[0]
			elif kind=="servers:profile_frame" or kind=="servers:profile_total":
				if frames.size()<12000: frames.append({"at_ms":Time.get_ticks_msec()-started,"kind":kind,"data":message[2]})
	if Time.get_ticks_msec()-last_saved>1000:
		last_saved=Time.get_ticks_msec();save()
	if FileAccess.file_exists(file+".stop") or Time.get_ticks_msec()-started>220000:
		save();quit(0 if not frames.is_empty() else 1)
	return false
func save() -> void:
	NavalStorage.write_json(file,{"engine_profiler":true,"frames":frames,"signatures":signatures,"message_counts":counts})
