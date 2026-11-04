extends SceneTree
var role:="server"
var game: WarGame
var failures: Array[String]=[]

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role=arg.trim_prefix("--role=")
	run.call_deferred()

func wait_for(test: Callable,seconds: float) -> bool:
	var deadline:=Time.get_ticks_msec()+int(seconds*1000.)
	while Time.get_ticks_msec()<deadline:
		await process_frame
		if test.call(): return true
	return false

func validate_fixture() -> void:
	var lab: Node3D=game.breakage_lab
	if not is_instance_valid(lab): failures.append("missing fixture");return
	if lab.model.broken.size()!=2: failures.append("broken state")
	for group: Dictionary in lab.cells.values():
		if group.body.get_shape_owners().size()!=2: failures.append("shape count changed")
		for record: Dictionary in group.records:
			if not record.collider.disabled: failures.append("collision remains active")
	var tree: RefCounted=game.real_tree_index
	if not tree: failures.append("missing real tree index");return
	if not game.real_tree_errors.is_empty(): failures.append_array(game.real_tree_errors)
	if tree.model.broken.size()!=5: failures.append("real tree broken state")
	for event: Dictionary in tree.model.broken.values():
		var record: Dictionary=tree.cells[event.cell][event.index]
		if not record.shape.disabled: failures.append("real tree collision remains active")
		if DisplayServer.get_name()!="headless":
			var presenter: Object=tree.presentation.get_ref() if tree.presentation else null
			if not is_instance_valid(presenter): failures.append("missing tree debris presenter")
			else:
				var reserved: Dictionary=presenter.reserved[event.cell]
				if reserved.stump.get_instance_transform(event.index).basis.determinant()==0.: failures.append("missing stump")
				if reserved.fallen.get_instance_transform(event.index).basis.determinant()==0.: failures.append("missing settled debris")
			for candidate: Dictionary in tree.visuals.get(tree._position_key(record.position),[]):
				if candidate.cell!=event.cell or candidate.index!=event.index: continue
				if candidate.lod.size()!=2: failures.append("missing real tree LOD")
				for lod: Dictionary in candidate.lod.values():
					if lod.node.multimesh.get_instance_transform(lod.index).basis.determinant()!=0.: failures.append("real tree LOD still visible")

func run() -> void:
	game=load("res://tests/war_breakage_fixture.gd").new()
	game.set_meta("war_test",true);game.set_meta("test_mode",true);game.set_meta("war_host",role=="server")
	root.add_child(game);game.nickname_input.text=role;game.address_input.text="127.0.0.1"
	if role=="server":
		if not await wait_for(func():return is_instance_valid(game.world_root) and game.online and is_instance_valid(game.vehicle_system),120.): failures.append("server world")
		elif not await wait_for(func():return game.breakage_acks.size()==2 and game.breakage_acks.values().all(func(v):return int(v)==2) and game.real_tree_acks.size()==2 and game.real_tree_acks.values().all(func(v):return int(v)==5),150.): failures.append("first and late client acknowledgements")
		else:
			validate_fixture()
			if not game.real_tree_contact_verified: failures.append("real vehicle contact was not exercised")
			if game.real_tree_contact_vehicles.size()!=4: failures.append("not all four vehicles were exercised")
			if game.real_tree_blast_events.size()!=1: failures.append("real explosion entry was not exercised")
			game._broadcast("qa_phase",["breakage_complete"])
			await create_timer(.8).timeout
	else:
		if not await wait_for(func():return game.join_ready and is_instance_valid(game.local_player),130.): failures.append("client joined")
		else:
			game.install_breakage_lab();game.rpc_id(1,"qa_breakage_ready")
			if not await wait_for(func():return game.phase=="breakage_complete",150.): failures.append("authority completion")
			else: validate_fixture()
	var file:=FileAccess.open("res://work/war-breakage-"+role+".json",FileAccess.WRITE)
	var tree: RefCounted=game.real_tree_index
	file.store_string(JSON.stringify({"role":role,"failures":failures,"graphical":DisplayServer.get_name()!="headless","tree_signature":tree.signature if tree else "","indexed_trees":tree.shape_to_id.size() if tree else 0,"broken_trees":tree.model.broken.size() if tree else 0,"vehicle_contacts":game.real_tree_contact_vehicles,"explosion_events":game.real_tree_blast_events.size(),"scope":"actual WarGame map, real four-vehicle simulation and explosion entry, tree colliders/LODs; experimental replication, no production integration"}));file.close()
	print("WAR_BREAKAGE_RESULT ",role," ",failures)
	quit(0 if failures.is_empty() else 1)
