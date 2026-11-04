extends "res://tests/combat183_network.gd"
var remote_lean_seen:=false
func _process(_delta: float) -> bool:
	if is_instance_valid(game):
		for actor: GamePlayer in game.players.values():
			if not actor.is_local and absf(actor.lean)>.8: remote_lean_seen=true
	return false
func burst(actor: GamePlayer,label: String,seconds:=.8) -> void:
	if int(actor.ammo[actor.weapon_id])<ceili(seconds/float(GameWeapons.ITEMS[actor.weapon_id].cooldown))+1:
		actor.start_reload()
		check(await wait_for(func():return actor.reload_weapon.is_empty() and int(actor.ammo[actor.weapon_id])==int(GameWeapons.ITEMS[actor.weapon_id].mag),9),"Desert refills magazine through normal reload before "+label)
	var action: String="lean_left" if role=="alpha" else "lean_right"
	Input.action_press(action);await create_timer(.35).timeout
	check(absf(actor.lean)>.95,"Desert Q/E posture before "+label)
	await super.burst(actor,label,seconds)
	Input.action_release(action);await create_timer(.35).timeout
	check(absf(actor.lean)<.02,"Desert stance returns to center after "+label)
func client_flow() -> void:
	game.local_player.pitch=.6;game.local_player.camera_pivot.rotation.x=.6
	await super.client_flow()
	check(remote_lean_seen,"Desert observer receives another player's stance")
func server_flow() -> void:
	await super.server_flow()
	check(remote_lean_seen,"Desert authority applies validated lean to hit regions")
