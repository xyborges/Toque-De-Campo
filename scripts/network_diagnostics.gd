extends RefCounted
class_name GameNetworkDiagnostics

# Pose ordering is always enforced per actor/life, independently of ENet's
# shared channels. Metrics are opt-in and never contain accounts or addresses.
const SAMPLE_LIMIT := 600
const REPORT_USEC := 5000000
const PEER_SAMPLE_USEC := 500000
var enabled := "--network-diagnostics" in OS.get_cmdline_user_args()
var sent: Dictionary = {}
var received: Dictionary = {}
var streams: Dictionary = {}
var peers: Dictionary = {}
var broadcasts: Dictionary = {}
var tick_gaps: Array[float] = []
var process_times: Array[float] = []
var physics_times: Array[float] = []
var started_usec := 0
var last_tick_usec := 0
var next_peer_usec := 0
var next_report_usec := 0
var ticks := 0
var late_ticks := 0

func next_pose_sequence(id: int, life: int) -> int:
	var state: Dictionary = sent.get(id,{"life":life,"sequence":0})
	if int(state.life)!=life: state={"life":life,"sequence":0}
	state.sequence=int(state.sequence)+1
	sent[id]=state
	return int(state.sequence)

func accept_pose(id: int, life: int, sequence: int, now_usec := -1) -> bool:
	var state: Dictionary = received.get(id,{"life":life,"sequence":0})
	var accepted := sequence>=0 and life>=int(state.life)
	if life==int(state.life) and int(state.sequence)>0 and sequence<=int(state.sequence): accepted=false
	if enabled: _observe("pose",id,life,sequence,accepted,now_usec)
	if accepted: received[id]={"life":life,"sequence":sequence}
	return accepted

func observe_input(id: int, life: int, sequence: int, now_usec := -1) -> void:
	if not enabled or sequence<1: return
	var key := "input:"+str(id)
	var previous: Dictionary = streams.get(key,{})
	var accepted := previous.is_empty() or life>int(previous.life) or (life==int(previous.life) and sequence>int(previous.sequence))
	_observe("input",id,life,sequence,accepted,now_usec)

func _observe(route: String, id: int, life: int, sequence: int, accepted: bool, now_usec: int) -> void:
	if now_usec<0: now_usec=Time.get_ticks_usec()
	var key := route+":"+str(id)
	var state: Dictionary = streams.get(key,{"route":route,"id":id,"life":life,"sequence":0,"accepted":0,"stale_or_duplicate":0,"sequence_skips":0,"at":0,"interval_ms":[]})
	if not accepted:
		state.stale_or_duplicate=int(state.stale_or_duplicate)+1
		streams[key]=state
		return
	if life==int(state.life) and int(state.at)>0:
		_append(state.interval_ms,(now_usec-int(state.at))*.001)
		if sequence>0 and int(state.sequence)>0: state.sequence_skips=int(state.sequence_skips)+maxi(0,sequence-int(state.sequence)-1)
	state.life=life;state.sequence=sequence;state.at=now_usec
	state.accepted=int(state.accepted)+1
	streams[key]=state

func observe_broadcast(method: String, arguments: Array, recipients: int) -> void:
	if not enabled: return
	var state: Dictionary = broadcasts.get(method,{"calls":0,"recipient_copies":0,"variant_payload_bytes":0})
	state.calls=int(state.calls)+1
	state.recipient_copies=int(state.recipient_copies)+recipients
	# This is a payload estimate, excluding RPC/ENet/UDP/DTLS headers. Only
	# diagnostic runs pay for this additional serialization.
	state.variant_payload_bytes=int(state.variant_payload_bytes)+var_to_bytes(arguments).size()*recipients
	broadcasts[method]=state

func tick(api: MultiplayerAPI, context: String, delta: float, now_usec := -1) -> void:
	if not enabled: return
	if now_usec<0: now_usec=Time.get_ticks_usec()
	if started_usec==0:
		started_usec=now_usec;next_peer_usec=now_usec;next_report_usec=now_usec+REPORT_USEC
	if last_tick_usec>0:
		var elapsed_ms := (now_usec-last_tick_usec)*.001
		_append(tick_gaps,elapsed_ms)
		if elapsed_ms>maxf(.001,delta)*1500.: late_ticks+=1
	last_tick_usec=now_usec;ticks+=1
	_append(process_times,Performance.get_monitor(Performance.TIME_PROCESS)*1000.)
	_append(physics_times,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.)
	if now_usec>=next_peer_usec:
		next_peer_usec=now_usec+PEER_SAMPLE_USEC
		_sample_peers(api)
	if now_usec>=next_report_usec:
		next_report_usec=now_usec+REPORT_USEC
		print("NETWORK_DIAGNOSTICS "+JSON.stringify(report(context,now_usec)))

func _sample_peers(api: MultiplayerAPI) -> void:
	var transport := api.multiplayer_peer as ENetMultiplayerPeer
	if transport==null or transport.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	for id in api.get_peers():
		var peer := GameNetworkPeers.connected(transport,id)
		if peer==null or peer.get_state()!=ENetPacketPeer.STATE_CONNECTED: continue
		var state: Dictionary = peers.get(id,{"rtt_ms":[],"rtt_variation_ms":[],"last_rtt_ms":[]})
		var rtt := peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)
		if rtt>0:
			_append(state.rtt_ms,rtt)
			_append(state.rtt_variation_ms,peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME_VARIANCE))
			_append(state.last_rtt_ms,peer.get_statistic(ENetPacketPeer.PEER_LAST_ROUND_TRIP_TIME))
		state.reliable_packet_loss_ratio=peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS)/float(ENetPacketPeer.PACKET_LOSS_SCALE)
		state.loss_epoch_ms=peer.get_statistic(ENetPacketPeer.PEER_PACKET_LOSS_EPOCH)
		state.unreliable_throttle_ratio=peer.get_statistic(ENetPacketPeer.PEER_PACKET_THROTTLE)/float(ENetPacketPeer.PACKET_THROTTLE_SCALE)
		peers[id]=state

func report(context := "", now_usec := -1) -> Dictionary:
	if now_usec<0: now_usec=Time.get_ticks_usec()
	var transport_rows: Array = []
	for id in peers:
		var state: Dictionary = peers[id]
		transport_rows.append({"id":id,"rtt_ms":stats(state.rtt_ms),"rtt_variation_ms":stats(state.rtt_variation_ms),"last_rtt_ms":stats(state.last_rtt_ms),"reliable_packet_loss_ratio":state.reliable_packet_loss_ratio,"loss_epoch_ms":state.loss_epoch_ms,"unreliable_throttle_ratio":state.unreliable_throttle_ratio})
	var stream_rows: Array = []
	for state: Dictionary in streams.values():
		stream_rows.append({"route":state.route,"id":state.id,"life":state.life,"sequence":state.sequence,"ordered_arrivals":state.accepted,"stale_or_duplicate":state.stale_or_duplicate,"sequence_skips":state.sequence_skips,"arrival_interval_ms":stats(state.interval_ms),"silence_ms":maxi(0,now_usec-int(state.at))*.001})
	return {"schema":1,"mode":context,"pid":OS.get_process_id(),"elapsed_seconds":maxi(0,now_usec-started_usec)*.000001 if started_usec>0 else 0.,"ticks":ticks,"late_ticks":late_ticks,"tick_gap_ms":stats(tick_gaps),"engine_process_ms":stats(process_times),"engine_physics_ms":stats(physics_times),"peers":transport_rows,"streams":stream_rows,"broadcasts":broadcasts.duplicate(true),"sample_limit":SAMPLE_LIMIT,"notes":"ENet loss covers reliable packets only; sequence skips include loss/reordering, not a packet-loss measurement. Input arrivals precede movement validation. Silence is time since local receipt, not one-way latency. Engine timings are sampled monitors, not additive script CPU. Payload bytes exclude transport overhead."}

static func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"n":0}
	var sorted := values.duplicate();sorted.sort()
	var total := 0.
	for value in sorted: total+=float(value)
	return {"n":sorted.size(),"mean":total/sorted.size(),"p50":sorted[int(sorted.size()*.5)],"p95":sorted[maxi(0,ceili(sorted.size()*.95)-1)],"max":sorted[-1]}

func _append(values: Array, value: float) -> void:
	if values.size()>=SAMPLE_LIMIT: values.pop_front()
	values.append(value)

func forget(id: int) -> void:
	sent.erase(id);received.erase(id);peers.erase(id)
	streams.erase("pose:"+str(id));streams.erase("input:"+str(id))

func clear() -> void:
	sent.clear();received.clear();streams.clear();peers.clear();broadcasts.clear()
	tick_gaps.clear();process_times.clear();physics_times.clear()
	started_usec=0;last_tick_usec=0;next_peer_usec=0;next_report_usec=0;ticks=0;late_ticks=0
