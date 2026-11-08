extends SceneTree
const HUD=preload("res://modes/battle_royale/ui/hud.gd")
const VISUALS=preload("res://modes/battle_royale/ui/loot_visuals.gd")
class UIActor extends GamePlayer:
	func _ready() -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _process(_delta: float) -> void:pass
class Context extends Node3D:
	var local_player: GamePlayer
	var ui_focus: GameUIFocus
	var br_hud: BRHUD
	var pause_panel: PanelContainer
	var starts:=0
	var heals:=0
	var drops: Array[String]=[]
	var left:=false
	var slot_actions: Array[int]=[]
	var requests: Array[Dictionary]=[]
	func request_br_start() -> void:starts+=1
	func request_br_heal() -> void:heals+=1
	func request_br_drop(weapon: String) -> void:drops.append(weapon)
	func request_br_drop_ammo(calibre: String,amount: int) -> void:requests.append({"action":"drop_ammo","calibre":calibre,"amount":amount})
	func request_br_drop_protection(kind: String) -> void:requests.append({"action":"drop_protection","kind":kind})
	func request_br_drop_pack() -> void:requests.append({"action":"drop_pack"})
	func request_br_drop_heal() -> void:requests.append({"action":"drop_heal"})
	func request_br_select_slot(index: int) -> void:slot_actions.append(index)
	func request_br_use_ammo(calibre: String,weapon: String) -> void:requests.append({"action":"use_ammo","calibre":calibre,"weapon":weapon})
	func request_br_attachment(weapon: String,socket: String,id: String,uid: int=-1,position: float=0.) -> void:requests.append({"action":"attachment","weapon":weapon,"socket":socket,"id":id,"uid":uid,"position":position})
	func request_br_drop_attachment(id: String,uid: int=-1) -> void:requests.append({"action":"drop_attachment","id":id,"uid":uid})
	func br_interact(id: int,part: int=-1) -> void:requests.append({"action":"pickup","id":id,"part":part})
	func request_br_pickup_use(id: int,part: int=-1) -> void:requests.append({"action":"pickup_use","id":id,"part":part})
	func request_br_ground_use(id: int,part: int=-1) -> void:requests.append({"action":"ground_use","id":id,"part":part})
	func leave_match() -> void:left=true
var checks:=0
var errors: Array[String]=[]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:errors.append(label);push_error(label)
func run() -> void:
	var game:=Context.new();root.add_child(game);game.ui_focus=GameUIFocus.new();game.add_child(game.ui_focus)
	game.pause_panel=PanelContainer.new();game.ui_focus.add_child(game.pause_panel);game.pause_panel.hide()
	game.local_player=UIActor.new();game.add_child(game.local_player)
	game.local_player.weapon_id="fal";game.local_player.ammo={"fal":6};game.local_player.reserves={"fal":40};game.local_player.hp=73
	var hud:=HUD.new();hud.game=game;game.br_hud=hud;game.add_child(hud)
	var panel:=hud.inventory_panel as BRInventoryPanel
	var state:={"phase":"waiting","total":1,"alive":1,"kills":0,"zone":{},"can_start":true,"roster":[{"id":1,"name":"Jogador","local":true,"bot":false}]}
	var inventory:={"weapons":["fal","glock"],"magazines":{"fal":6,"glock":3},"reserve_by_weapon":{"fal":40,"glock":12},"ammo":{"76251":40,"9mm":12},"medkits":2,"weight":23.5,"capacity":60.,"accessory_items":[],"weapon_attachments":{"fal":{},"glock":{}}}
	hud.refresh(state,inventory,[])
	check(hud.waiting.visible and hud.start_button.visible and not hud.start_button.disabled,"one human can enter bot-filled matchmaking")
	state.total=3;state.alive=3;state.countdown=30.;state.can_start=false;state.roster.append({"id":2,"name":"Sobrevivente 1","bot":true});hud.refresh(state,inventory,[])
	check(not hud.start_button.visible and hud.waiting_count.text=="Começa em 30 s" and hud.waiting_roster.get_child_count()==2,"queue shows fixed countdown and human/bot roster")
	check(hud.waiting_total.text=="3 / 12" and not hud.health.is_visible_in_tree(),"waiting separates roster from live gameplay HUD")
	state.countdown=0.;state.can_start=true;state.map_status="Mapa em preparação";hud.refresh(state,inventory,[])
	check(hud.start_button.disabled and hud.waiting_count.text=="Mapa em preparação","unready map blocks start with short status")
	state.erase("map_status");hud.refresh(state,inventory,[]);hud.start_button.pressed.emit();check(game.starts==1,"start uses authority request")
	var leave:=hud.waiting.find_children("*","Button",true,false).filter(func(button):return button.text=="SAIR")
	check(leave.size()==1,"waiting exposes one leave action")
	if not leave.is_empty():leave[0].pressed.emit();check(game.left,"waiting leave action exits room")
	state.phase="active";state.kills=2;state.zone={"center":Vector2.ZERO,"radius":850.,"target_radius":500.,"target_center":Vector2(80,-40),"remaining":42.,"closing":false}
	var loot:=[{"id":4,"kind":"ammo","calibre":"9mm","amount":12,"position":Vector3(1,0,0)}]
	hud.refresh(state,inventory,loot)
	check(not hud.waiting.visible and not hud.result_panel.visible,"active hides queue and result")
	check(hud.health.text=="+ 73" and is_equal_approx(hud.health_bar.value,73),"live health display")
	check(hud.ammunition.text=="FAL\n6 / 40" and hud.match_dashboard.view=="survival" and hud.match_dashboard._clock_text()=="00:42","actual magazine and zone countdown")
	game.local_player.position=Vector3(0,0,-1000);state.zone.radius=500.;hud.refresh(state,inventory,loot)
	check(hud.alert.text.begins_with("↓") and hud.zone_overlay.visible,"zone behind north-facing player points backward")
	game.local_player.position=Vector3(-1000,0,0);hud.refresh(state,inventory,loot);check(hud.alert.text.begins_with("→"),"zone to east points right")
	game.local_player.position=Vector3.ZERO;state.zone.radius=850.;hud.refresh(state,inventory,loot)
	check(not hud.zone_overlay.visible and "9mm" in hud.prompt.text and "12" in hud.prompt.text,"safe tint clears and pickup prompt stays available")
	var event:=InputEventKey.new();event.keycode=KEY_I;event.pressed=true;hud._unhandled_input(event)
	check(panel!=null and game.ui_focus.blocked() and panel.is_visible_in_tree(),"I opens modular panel through shared focus")
	check(panel.cards.size()==2 and panel.cards[0].weapon=="fal" and panel.cards[0].ammo.text=="6 / 40" and panel.cards[1].weapon=="glock","HUD forwards canonical weapon data to modular cards")
	check(panel.capacity.text=="23 / 60" and panel.ground_list.get_child_count()==1,"HUD forwards capacity and nearby loot")
	panel.cards[1].header.pressed.emit();panel.cards[1].drop.pressed.emit()
	check(game.slot_actions==[1] and game.drops==["glock"],"modular card selection and drop reach authority requests")
	hud._unhandled_input(event);check(not game.ui_focus.blocked(),"I closes modular inventory")
	inventory.backpack=2;inventory.capacity=140.;inventory.protection={"vest":{"level":2,"durability":60.},"helmet":{"level":1,"durability":30.}};hud.refresh(state,inventory,loot)
	check(panel.capacity_bar.max_value==140. and "Colete 2" in hud.protection_text.text and "Capacete 1" in hud.protection_text.text,"gear and tier capacity update both HUD and panel")
	var tab:=InputEventKey.new();tab.keycode=KEY_TAB;tab.pressed=true;hud._input(tab)
	check(panel.is_visible_in_tree() and panel.bag_buttons.has("heal"),"Tab opens mixed inventory panel")
	hud._input(tab);check(not game.ui_focus.blocked(),"Tab closes focused modular panel")
	game.ui_focus.open(game.pause_panel);hud._input(tab);check(not panel.is_visible_in_tree() and game.ui_focus.stack.back()==game.pause_panel,"Tab cannot open inventory over settings/pause")
	game.ui_focus.close_all();game.local_player.hp=20.;hud.refresh(state,inventory,loot);check(hud.health.get_theme_color("font_color")==FieldTheme.BAD,"critical health emphasized")
	game.local_player.hp=0;hud.refresh(state,inventory,loot);check("ELIMINADO" in hud.death_text.text and hud.prompt.text.is_empty(),"eliminated player sees cause without pickup prompt")
	hud._input(tab);check(not panel.is_visible_in_tree(),"dead player cannot reopen inventory")
	state.view_position=Vector3(55,8,120);state.view_yaw=1.2;hud.refresh(state,inventory,loot)
	check(hud.minimap.player_position==state.view_position and is_equal_approx(hud.minimap.player_yaw,state.view_yaw),"spectator minimap follows only observed actor")
	hud._open_statistics();check(hud.statistics_panel.is_visible_in_tree() and game.ui_focus.blocked(),"own results accessible after death")
	state.phase="finished";state.winner_name="Lider";state.result={"placement":1,"kills":2,"shots":0,"hits":0,"survival_seconds":91,"favorite":"fal"};hud.refresh(state,inventory,[])
	check(hud.result_panel.visible and hud.result_heading.text=="VITÓRIA","winner result shown")
	check("0% precisão" in hud.result_detail.text and hud.result_detail.text.count("Mais usada")==1,"zero-shot result safe and favorite appears once")
	state.result.placement=2;state.death_notice="FORA DA ZONA";hud.refresh(state,inventory,[]);check("FORA DA ZONA" in hud.result_detail.text,"final result retains elimination cause")
	await validate_pool(game,loot)
	await process_frame
	var report:={"ok":errors.is_empty(),"checks":checks,"errors":errors,"scope":"HUD/queue/results integration with production modular inventory panel, TAB/I focus/death locks and loot pooling including canonical modules and corpse exclusion; detailed modular menu actions covered by separate UI suite. No FPS claim."}
	NavalStorage.write_json("res://work/br-ui-validation.json",report);print("BR_UI_VALIDATION ",JSON.stringify(report))
	game.queue_free();await process_frame;quit(0 if errors.is_empty() else 1)

func validate_pool(game: Context,loot: Array) -> void:
	var views:=VISUALS.new();views.set_meta("test_visuals",true);game.add_child(views);views.prepare()
	check(views.models.has("fal") and views.models.has("glock"),"procedural loot meshes prepared during loading")
	var attached:=GameAttachmentState.from_legacy("ak","pso4x")
	var module_loot:=[{"id":800,"kind":"attachment","attachment":"prism4x","state":{},"position":Vector3.ZERO},{"id":801,"kind":"weapon","weapon":"ak","weapon_attachments":attached,"position":Vector3.ONE}]
	views.update_visible(module_loot,Vector3.ZERO)
	for frame in 3:views._process(0.)
	check(views.active.has(800) and views.active.has(801),"loose module and canonical attached weapon get pooled visuals")
	var installed: Array=views.active[801].find_children("*","Node3D",true,false).filter(func(node):return node.get_meta("attachment_id","")=="pso4x")
	check(installed.size()==1 and installed[0].get_meta("attachment_socket","")=="optic_top","dropped weapon mounts exactly one canonical module")
	var module_node: Node3D=views.active[800];var weapon_node: Node3D=views.active[801]
	views.update_visible([{"id":900,"kind":"container","corpse_key":"round:1:victim:7","position":Vector3.ZERO,"contents":[]}],Vector3.ZERO);views._process(0.)
	check(views.active.is_empty() and views.pending.is_empty() and not module_node.visible and not weapon_node.visible,"corpse loot does not create duplicate bag proxy")
	var created:=views.created
	views.update_visible([{"id":901,"kind":"container","position":Vector3.ZERO,"contents":[]}],Vector3.ZERO);views._process(0.)
	check(views.active.has(901) and views.created==created+1,"ordinary non-corpse container still has bag visual")
	views.clear();views.free()
	views=VISUALS.new();views.set_meta("test_visuals",true);game.add_child(views);views.prepare()
	views.update_visible(loot,Vector3.ZERO);views._process(0.)
	check(views.active.size()==1 and views.created==1,"near loot rendered")
	var first: Node3D=views.active[4]
	views.update_visible(loot,Vector3(100,0,0));check(views.active.is_empty() and not first.visible,"far loot released")
	views.update_visible(loot,Vector3.ZERO);views._process(0.);check(views.active[4]==first and views.created==1,"pool reuses same loot instance")
	var dense: Array=[]
	for i in 140:dense.append({"id":i+100,"kind":"heal","position":Vector3((i%10)*.2,0,(i/10)*.2)})
	views.update_visible(dense,Vector3.ZERO);views._process(0.)
	check(views.active.size()<=VISUALS.CREATIONS_PER_FRAME,"dense loot respects per-frame creation budget")
	for frame in 110:views._process(0.)
	var pickup_count:=0
	for record: Dictionary in dense:
		if Vector3.ZERO.distance_squared_to(record.position)<=9.: pickup_count+=1
	var expected_visible:=mini(maxi(VISUALS.LIMIT,pickup_count),dense.size())
	check(views.active.size()==expected_visible,"loot preserves every nearby pickup and caps only distant visuals")
	views.update_visible(loot,Vector3.ZERO);views.clear();views._process(0.)
	check(views.active.is_empty() and views.pending.is_empty(),"cleanup cancels pending creations")
