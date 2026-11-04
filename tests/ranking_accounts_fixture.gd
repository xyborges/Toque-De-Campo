extends NavalAccounts
var calls:=0
var response: Dictionary={"ok":false,"error":"Isolated network failure"}
func _ready() -> void:
	api_url="https://ranking.test.invalid/accounts/api.php"
func call_api(action: String,_values: Dictionary={}) -> Dictionary:
	calls+=1
	await get_tree().create_timer(.02).timeout
	return response.duplicate(true) if action=="rankings" else {"ok":false}
