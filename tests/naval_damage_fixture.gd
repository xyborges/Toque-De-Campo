extends NavalNetwork
var sent: Array[Dictionary]=[]
func _send(id: int,kind: String,payload: Dictionary) -> void: sent.append({"peer":id,"kind":kind,"payload":payload.duplicate(true)})
