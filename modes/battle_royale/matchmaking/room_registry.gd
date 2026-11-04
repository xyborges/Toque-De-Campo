extends RefCounted
class_name BRRoomRegistry
## Local broker/child mailbox. Secrets never travel through status snapshots.
const CAPACITY:=12

static func argument(name: String,fallback: String="") -> String:
	for value in OS.get_cmdline_user_args():
		if value.begins_with(name+"="):return value.trim_prefix(name+"=")
	return fallback

static func is_hex(value: String,length: int) -> bool:
	if value.length()!=length:return false
	for character in value:
		if not character in "0123456789abcdef":return false
	return true

static func room_id() -> String:return argument("--br-room-id")
static func room_folder() -> String:return argument("--br-room-dir",NavalStorage.folder())

static func atomic_json(path: String,data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var temporary:=path+".tmp-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var file:=FileAccess.open(temporary,FileAccess.WRITE)
	if not file:return false
	file.store_string(JSON.stringify(data));file.close()
	if DirAccess.rename_absolute(temporary,path)==OK:return true
	DirAccess.remove_absolute(temporary);return false

static func read_status(folder: String) -> Dictionary:
	var path:=folder.path_join("status.json")
	if not FileAccess.file_exists(path):return {}
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>8192:return {}
	var data: Variant=JSON.parse_string(file.get_as_text());file.close()
	return data if data is Dictionary else {}

static func publish_status(phase: String,accounts: Array,join_deadline_unix: float=0.,ready: bool=true) -> bool:
	var id:=room_id()
	if not is_hex(id,32):return false
	var humans: Array[String]=[]
	for account in accounts:
		var value:=str(account)
		if is_hex(value,32) and not value in humans and humans.size()<CAPACITY:humans.append(value)
	return atomic_json(room_folder().path_join("status.json"),{"room_id":id,"phase":phase,"accounts":humans,"humans":humans.size(),"capacity":CAPACITY,"ready":ready,"join_deadline":join_deadline_unix,"heartbeat":Time.get_unix_time_from_system(),"pid":OS.get_process_id()})

static func pending_admissions() -> Array[Dictionary]:
	var result: Array[Dictionary]=[];var folder:=room_folder().path_join("admissions")
	if room_id().is_empty() or not DirAccess.dir_exists_absolute(folder):return result
	for filename in DirAccess.get_files_at(folder):
		if not filename.ends_with(".json"):continue
		var row: Variant=JSON.parse_string(FileAccess.get_file_as_string(folder.path_join(filename)))
		if row is Dictionary and float(row.get("expires",0))>Time.get_unix_time_from_system():result.append(row)
	return result

static func create_admission(folder: String,id: String,account: String,expires: float) -> String:
	if not is_hex(id,32) or not is_hex(account,32):return ""
	var token:=Crypto.new().generate_random_bytes(32).hex_encode()
	if not atomic_json(folder.path_join("admissions").path_join(token+".json"),{"room_id":id,"account_id":account,"expires":expires,"issued":Time.get_unix_time_from_system(),"token_hash":token.sha256_text()}):return ""
	return token

static func revoke_admission(folder: String,token: String) -> void:
	if is_hex(token,64):DirAccess.remove_absolute(folder.path_join("admissions").path_join(token+".json"))

static func claim_admission(account_id: String,token: String,now: float=-1.) -> bool:
	return claim_at(room_folder(),room_id(),account_id,token,Time.get_unix_time_from_system() if now<0. else now)

static func claim_at(folder: String,id: String,account_id: String,token: String,now: float) -> bool:
	if not is_hex(id,32) or not is_hex(account_id,32) or not is_hex(token,64) or not is_finite(now):return false
	var status:=read_status(folder)
	if str(status.get("room_id",""))!=id or not bool(status.get("ready",false)) or str(status.get("phase","")) not in ["waiting","preparing"]:return false
	var deadline:=float(status.get("join_deadline",0.))
	if deadline>0. and now>=deadline+60.:return false
	if account_id in status.get("accounts",[]):return false
	var path:=folder.path_join("admissions").path_join(token+".json")
	if not FileAccess.file_exists(path):return false
	var file:=FileAccess.open(path,FileAccess.READ)
	if not file or file.get_length()>1024:return false
	var data: Variant=JSON.parse_string(file.get_as_text());file.close()
	if not data is Dictionary or str(data.get("room_id",""))!=id or str(data.get("account_id",""))!=account_id or str(data.get("token_hash",""))!=token.sha256_text():return false
	if deadline>0. and float(data.get("issued",0.))>=deadline:return false
	var expires:=float(data.get("expires",0.))
	if not is_finite(expires) or expires<now or expires>now+125.:return false
	# Atomic consume: two attempts cannot both admit the same reservation.
	var consumed:=path+".claimed"
	if DirAccess.rename_absolute(path,consumed)!=OK:return false
	DirAccess.remove_absolute(consumed);return true
