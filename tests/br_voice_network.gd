extends SceneTree
const FIXTURE=preload("res://tests/br_voice_network_fixture.gd")
var role:="server"
var context: Node3D
var checks:=0
var failures: Array[String]=[]
var ids: Array=[]
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="):role=arg.trim_prefix("--role=")
	run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func wait_for(test: Callable,label: String,seconds:=10.) -> bool:
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<seconds*1000:
		if test.call():return true
		await create_timer(.02).timeout
	failures.append("timeout "+label);return false
func run() -> void:
	context=FIXTURE.new();root.add_child(context)
	var peer:=ENetMultiplayerPeer.new();var error: Error
	if role=="server":
		error=peer.create_server(39587,5)
		if error==OK:error=GameSecureTransport.server(peer)
	else:
		error=peer.create_client("127.0.0.1",39587,4)
		if error==OK:error=GameSecureTransport.client(peer,"localhost")
	if error!=OK:push_error("DTLS "+error_string(error));quit(1);return
	context.network_api.multiplayer_peer=peer
	if role!="server":await create_timer(65.).timeout;quit(1);return
	if await wait_for(func():return context.multiplayer.get_peers().size()==4,"four clients",30.):await scenario()
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"accepted":context.voice.accepted,"rejected":context.voice.rejected,"relayed_frames":context.voice.delivered,"relayed_bytes":context.voice.bytes_relayed,"scope":"Headless server and four ENet/DTLS clients with dedicated unreliable channel3. Payload routing, proximity, mute, death, sequence/replay, round/life/size/rate checks. Does not decode Opus or capture microphone; codec/playback tested separately."}
	NavalStorage.write_json("res://work/br-voice-network.json",report);print("BR_VOICE_NETWORK ",JSON.stringify(report))
	for id in context.multiplayer.get_peers():context.rpc_id(id,"qa_finish")
	await create_timer(.3).timeout;peer.close();context.free();quit(0 if failures.is_empty() else 1)
func send(sequence: int,speaker: int,life:=1,generation:=4,length:=50) -> void:
	context.rpc_id(speaker,"qa_send",sequence,life,generation,length)
	await wait_for(func():return context.acknowledgements.has(str(speaker)+":sent:%d"%sequence),"send %d"%sequence)
	await create_timer(.15).timeout
	var label:="frames:%d"%sequence
	for id in ids:context.rpc_id(id,"qa_report",label)
	await wait_for(func():return ids.all(func(id):return context.reports.has(str(id)+":"+label)),"reports "+label)
func heard(listener: int,sequence: int) -> bool:
	var records: Array=context.reports.get(str(listener)+":frames:%d"%sequence,[])
	return records.any(func(record):return int(record[2])==sequence)
func presence(id: int,label: String,enabled: bool,radius: float,mutes: Array=[]) -> void:
	context.rpc_id(id,"qa_presence",label,enabled,radius,mutes)
	await wait_for(func():return context.acknowledgements.has(str(id)+":"+label),label)
func scenario() -> void:
	ids=Array(context.multiplayer.get_peers());ids.sort()
	context.qa_setup(ids,[Vector3.ZERO,Vector3(4,0,0),Vector3(50,0,0),Vector3(80,0,0)])
	for id in ids:context.rpc_id(id,"qa_setup",ids,[Vector3.ZERO,Vector3(4,0,0),Vector3(50,0,0),Vector3(80,0,0)])
	await wait_for(func():return ids.all(func(id):return context.acknowledgements.has(str(id)+":setup")),"setup")
	await create_timer(.6).timeout
	await send(1,ids[0])
	check(heard(ids[1],1) and heard(ids[2],1),"near living listeners receive")
	check(not heard(ids[0],1) and not heard(ids[3],1),"no echo or distant listeners")
	check(context.voice.guards.has(ids[0]),"authenticated sender determines voice ID")
	await presence(ids[1],"mute",true,40.,[ids[0]])
	await send(2,ids[0]);check(not heard(ids[1],2) and heard(ids[2],2),"server respects per-listener mute")
	await presence(ids[2],"short",true,10.)
	await send(3,ids[0]);check(heard(ids[2],3),"legacy short range cannot override fixed 55 m voice range")
	check(float(context.voice.recipient_settings[ids[2]].radius)==GameVoiceSettings.radius(),"authority stores the shared player voice range")
	await presence(ids[3],"excessive",true,1000.)
	await send(31,ids[0]);check(not heard(ids[3],31),"client cannot extend voice beyond the fixed server range")
	await presence(ids[1],"unmute",true,40.)
	await presence(ids[2],"wide",true,40.)
	context.players[ids[2]].hp=0.
	for id in ids:context.rpc_id(id,"qa_health",ids[2],0.)
	await send(4,ids[0]);check(heard(ids[1],4) and not heard(ids[2],4),"dead listeners excluded; two living nearby remain")
	context.players[ids[0]].hp=0.
	for id in ids:context.rpc_id(id,"qa_health",ids[0],0.)
	context.voice.silence(ids[0])
	await send(5,ids[0]);check(not heard(ids[1],5),"dead speaker discarded")
	context.players[ids[0]].hp=100.
	for id in ids:context.rpc_id(id,"qa_health",ids[0],100.)
	# Keep the same life tombstoned on purpose; new life/round is the only reset.
	await send(6,ids[0],0);check(not heard(ids[1],6),"stale life discarded")
	await send(7,ids[0],1,3);check(not heard(ids[1],7),"old round discarded")
	await send(8,ids[0],1,4,300);check(not heard(ids[1],8),"oversized packet discarded")
	var before: int=context.voice.rejected
	var packet:=PackedByteArray();packet.resize(50)
	for index in 40:context.voice._accept_frame(ids[0],1,4,100+index,packet)
	check(context.voice.rejected>before,"rate limit rejects packet bursts")
	before=context.voice.accepted
	context.voice._accept_frame(ids[0],1,4,100,packet)
	check(context.voice.accepted==before,"duplicate sequence cannot replay")
	context.phase="finished";before=context.voice.accepted;context.voice._accept_frame(ids[0],1,4,200,packet)
	check(context.voice.accepted==before,"finished round has no speech")
	context.voice.forget(ids[0]);check(not context.voice.guards.has(ids[0]) and not context.voice.roster.has(ids[0]),"disconnect clears session identity/rate state")
	context.voice.reset();check(context.voice.talking.is_empty() and context.voice.stopped.is_empty(),"round reset clears speaking state")
