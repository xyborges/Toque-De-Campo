extends "res://tests/br_completion_fixture.gd"

func _physics_process(delta: float) -> void:
	if not is_instance_valid(motorbikes):return
	if multiplayer.is_server():motorbikes._physics_process(delta)
	else:
		for bike: WarVehicle in motorbikes.bikes.values():bike.render(delta)
		for actor: GamePlayer in players.values():
			if motorbikes.occupied(actor):motorbikes.pose(actor)

func add_test_bikes() -> void:
	motorbikes=load("res://tests/br_motorbikes_fixture.gd").new();motorbikes.game=self;world_root.add_child(motorbikes)

@rpc("authority","call_remote","reliable")
func qa_bike_command(label: String,action: String,data: Dictionary) -> void:
	if action=="enter":motorbikes.rpc_id(1,"server_interact",str(data.bike),int(data.life),int(data.generation))
	elif action=="control":motorbikes.rpc_id(1,"server_control",int(data.sequence),int(data.life),int(data.generation),float(data.throttle),float(data.steer),str(data.bike),int(data.epoch))
	elif action=="direct_client":
		var before: int=motorbikes.bikes[str(data.bike)].driver
		motorbikes._interact(local_player.peer_id,str(data.bike),local_player.life_id,br_generation)
		qa_ack.rpc_id(1,label if motorbikes.bikes[str(data.bike)].driver==before else "FAIL:"+label)
		return
	elif action=="disconnect":
		qa_ack.rpc_id(1,label)
		await get_tree().create_timer(.2).timeout
		voice.shutdown();network_api.multiplayer_peer.close();get_tree().quit();return
	qa_ack.rpc_id(1,label)

@rpc("authority","call_remote","reliable")
func qa_bike_check(label: String,bike_id: String,driver_id: int,exited_id: int=0) -> void:
	var bike: WarVehicle=motorbikes.bikes[bike_id]
	var rider: GamePlayer=players.get(driver_id)
	var okay: bool=bike.driver==driver_id
	if driver_id>0:okay=okay and rider!=null and rider.vehicle_id==bike_id and rider.body_collision.disabled and absf(angle_difference(rider.rotation.y,bike.rotation.y))<.02
	if driver_id==multiplayer.get_unique_id():okay=okay and not local_player.view_root.visible and local_player.camera.global_position.distance_to(local_player.camera_pivot.global_position)>2.5
	if exited_id>0 and players.has(exited_id):
		var old: GamePlayer=players[exited_id]
		okay=okay and old.vehicle_id.is_empty() and not old.body_collision.disabled and absf(old.camera_pivot.rotation.y)<.001
		if old.is_local:okay=okay and old.view_root.visible
	qa_ack.rpc_id(1,label if okay else "FAIL:"+label)

@rpc("authority","call_remote","reliable")
func qa_bike_finish() -> void:
	voice.shutdown();qa_ack.rpc_id(1,"finished")
	await get_tree().create_timer(.5).timeout
	network_api.multiplayer_peer.close();get_tree().quit()
