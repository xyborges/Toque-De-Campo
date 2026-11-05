extends SceneTree
const APP=preload("res://scripts/main.gd")
const ACCOUNTS=preload("res://tests/br_queue_screen_accounts.gd")
const ROUTER=preload("res://modes/battle_royale/matchmaking/router.gd")
const POOL=preload("res://modes/battle_royale/matchmaking/room_pool.gd")
var checks:=0
var failures: Array[String]=[]
var app: Node3D
var game: BattleRoyaleGame
var account: NavalAccounts
var route_observations: Array[Dictionary]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func on_root_child(node: Node) -> void:
	if node is BRMatchRouter:
		node.ready.connect(func():
			route_observations.append({"root":node.get_parent()==root,"path":str(node.get_path()),"custom":node.multiplayer==node.network_api,"separate":node.multiplayer!=game.multiplayer})
		,CONNECT_ONE_SHOT)
func find_exit() -> Button:
	for node in game.br_hud.waiting.find_children("*","Button",true,false):
		if node.text=="SAIR":return node
	return null
func assert_screen(label: String) -> void:
	check(game.hud_layer.visible and game.br_hud.visible and game.br_hud.waiting.is_visible_in_tree(),label+" waiting hierarchy visible")
	check(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,label+" mouse available")
	check(not game.br_hud.start_button.visible,label+" cannot bypass automatic queue")
	check(is_instance_valid(find_exit()) and find_exit().is_visible_in_tree(),label+" leave available")
func capture() -> void:
	if DisplayServer.get_name()=="headless":return
	root.size=Vector2i(1280,800);root.content_scale_size=Vector2i(1280,800);root.content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for frame in 3:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://work/br-queue-screen-regression.png")
func pending_router() -> BRMatchRouter:
	var router:=ROUTER.new();root.add_child(router);router.pending=true;router.request_started=Time.get_ticks_msec();game.queue_router=router;return router
func run() -> void:
	check(BattleRoyaleGame.BR_PROTOCOL==10 and ROUTER.PROTOCOL==BattleRoyaleGame.BR_PROTOCOL and POOL.PROTOCOL==BattleRoyaleGame.BR_PROTOCOL,"game/router/pool agree on release protocol 10")
	app=APP.new();app.set_meta("test_mode",true);root.add_child(app)
	var previous: NavalAccounts=app.main_accounts
	account=ACCOUNTS.new();root.add_child(account);app.main_accounts=account;previous.queue_free()
	root.child_entered_tree.connect(on_root_child)
	app.open_battle_royale(false);game=app.war_mode
	check(is_instance_valid(game) and game is BattleRoyaleGame and game.get_parent()==app,"production main-menu action creates BR child")
	check(not app.menu_layer.visible and not app.hud_layer.visible,"parent menu/game HUD hidden on BR entry")
	assert_screen("initial menu entry")
	game.hud_layer.hide();game.br_hud.hide();game.queue_status="Buscando partida";game._show_queue_status()
	assert_screen("recover hidden layers")
	for frame in 4:await process_frame
	check(account.calls==1 and not game.route_pending,"production join_game completes mocked profile failure")
	check(game.queue_status=="Sessão expirada." and game.br_hud.waiting_count.text==game.queue_status,"profile failure stays visible in waiting panel")
	check(route_observations.is_empty() and game.queue_router==null,"failed profile allocates no router")
	assert_screen("profile rejection")
	# Profile succeeds, but no device ticket exists: the production router is
	# instantiated and closes immediately before any ENet connection is made.
	account.allow_profile=true;game.join_game("pvp")
	for frame in 5:await process_frame
	check(account.calls==2 and route_observations.size()==1,"production join creates real router after profile success")
	if not route_observations.is_empty():
		var observed: Dictionary=route_observations[0]
		check(observed.root and observed.path.begins_with("/root/MatchRouter"),"production router is ROOT sibling outside game branch")
		check(observed.custom and observed.separate,"router owns independent MultiplayerAPI without nested custom branches")
	check(game.queue_router==null and not game.route_pending,"ticket rejection closes production router and releases reference")
	check(root.find_children("MatchRouter*","BRMatchRouter",false,false).is_empty(),"ticket rejection leaves no ROOT router")
	assert_screen("ticket rejection")
	game.queue_status="Buscando partida";game._show_queue_status();await capture()
	var router:=pending_router();var held: WeakRef=weakref(router)
	game._close_queue_router()
	check(game.queue_router==null and router.terminal and not router.pending and router.response.error=="Busca cancelada.","close cancels pending router before disposal")
	check(router.is_queued_for_deletion(),"closed ROOT router queued for disposal")
	game._close_queue_router();await process_frame
	check(held.get_ref()==null,"repeated close leaves no orphan")
	# SAIR follows the real HUD callback and the application's deferred menu
	# return, disposing a pending router outside the game's own subtree.
	router=pending_router();held=weakref(router);var game_ref: WeakRef=weakref(game)
	find_exit().pressed.emit()
	check(game.closing and game.queue_router==null and not router.pending,"waiting SAIR invokes leave_match and cancels route")
	for frame in 4:await process_frame
	check(held.get_ref()==null and game_ref.get_ref()==null and app.war_mode==null,"leave frees ROOT router and BR game")
	check(app.menu_layer.visible and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"leave returns to main menu")
	# A second entry tests exit_tree cleanup independently of the SAIR path.
	account.allow_profile=false;app.open_battle_royale(false);game=app.war_mode
	for frame in 4:await process_frame
	router=pending_router();held=weakref(router);game_ref=weakref(game)
	app.free();await process_frame
	check(held.get_ref()==null and game_ref.get_ref()==null,"application teardown also frees sibling router")
	check(root.find_children("MatchRouter*","BRMatchRouter",false,false).is_empty(),"all queue exits leave ROOT clean")
	account.queue_free();await process_frame
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"routes":route_observations,"scope":"Production main menu and BR join_game/HUD with account-only fixture. Profile rejection, ROOT router creation/ticket rejection, hidden-HUD recovery, pending cancellation, SAIR and application teardown. No external networking, server, deployment or FPS measurement."}
	NavalStorage.write_json("res://work/br-queue-screen-validation.json",report);print("BR_QUEUE_SCREEN_VALIDATION ",JSON.stringify(report));quit(0 if failures.is_empty() else 1)
