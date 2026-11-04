extends WarGame
## QA only: deterministic controls and a surviving observer, ordinary bot combat.
class Observer extends WarPlayer:
	func take_damage(amount: float,region:="chest",killer_id:=0) -> void:
		if is_local:super.take_damage(minf(amount,maxf(0.,hp-1.)*.1),region,killer_id)
		else:super.take_damage(amount,region,killer_id)

func _new_player() -> GamePlayer:return Observer.new()
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:return
	super._input(event)
func gameplay_input_allowed() -> bool:
	return join_ready and not match_ended and is_instance_valid(local_player) and local_player.hp>0 and local_player.deployed and not ui_focus.blocked()
