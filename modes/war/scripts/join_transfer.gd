extends RefCounted
class_name WarJoinTransfer

const STALL_MS:=30000
const TOTAL_MS:=120000
var token:=Crypto.new().generate_random_bytes(12).hex_encode()
var started:=Time.get_ticks_msec()
var waiting_since:=0
var nonce:=""
var acknowledged:=false
var failed:=false
var dirty: Dictionary={}
var drones: Dictionary={}
var known_drones: Dictionary={}
var actor_ms:=0.
var wait_ms:=0.
var batches:=0

func queue(id: int) -> void:dirty[id]=true
func take_pair() -> Array:
	var result:=dirty.keys().slice(0,2)
	for id in result:dirty.erase(id)
	return result
func begin_chunk() -> String:
	batches+=1;nonce=str(batches)+":"+Crypto.new().generate_random_bytes(8).hex_encode()
	acknowledged=false;waiting_since=Time.get_ticks_msec();return nonce
func accept(transfer: String,chunk: String) -> bool:
	if failed or transfer!=token or chunk!=nonce or nonce.is_empty() or acknowledged:return false
	acknowledged=true;return true
func expired(now: int) -> String:
	if now-started>=TOTAL_MS:return "total"
	if waiting_since>0 and now-waiting_since>=STALL_MS:return "progress"
	return ""

func queue_drone(id: String,removed:=false) -> void:
	if removed or not known_drones.has(id):drones[id]=true
func take_drone_pair() -> Array:
	var result:=drones.keys().slice(0,2)
	for id in result:drones.erase(id);known_drones[id]=true
	return result
