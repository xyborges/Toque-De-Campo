extends NavalAccounts
## No network or stored credentials: exercise the real menu/queue route.
var allow_profile:=false
var calls:=0
func _ready() -> void:
	token="queue-screen-fixture";ticket={};persist_session=false
func _exit_tree() -> void:pass
func call_api(_action: String,_values: Dictionary={}) -> Dictionary:
	calls+=1
	await get_tree().process_frame
	return {"ok":allow_profile,"error":"Sessão expirada."}
