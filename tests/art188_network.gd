extends "res://tests/bugs187_network.gd"
var reload_extents: Dictionary={}
func _process(delta: float) -> bool:
	super._process(delta)
	if is_instance_valid(game) and game.join_ready:
		for actor: WarPlayer in game.players.values():
			if actor.is_local or actor.reload_left<=0 or actor.reload_weapon!=actor.weapon_id or actor.weapon_id not in ["fal","glock"]: continue
			var model:=actor.weapon_root.get_node_or_null("Imported_"+actor.weapon_id) as Node3D
			if model==null or not model.has_node("Magazine"): continue
			var y: float=model.get_node("Magazine").position.y
			var extent: Vector2=reload_extents.get(actor.weapon_id,Vector2(y,y))
			reload_extents[actor.weapon_id]=Vector2(minf(extent.x,y),maxf(extent.y,y))
	return false
func client() -> void:
	await super.client()
	var glock: Vector2=reload_extents.get("glock",Vector2.ZERO)
	check(glock.y-glock.x>.12,"observer sees actual Glock magazine extraction from replicated reload time")
	if role=="alpha":
		var fal: Vector2=reload_extents.get("fal",Vector2.ZERO)
		check(fal.y-fal.x>.18,"observer sees actual FAL magazine extraction from replicated reload time")
