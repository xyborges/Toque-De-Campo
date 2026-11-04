extends SceneTree
const PANEL=preload("res://modes/battle_royale/ui/inventory_panel.gd")
class Actor extends GamePlayer:
	func _ready() -> void:pass
	func _physics_process(_delta: float) -> void:pass
	func _process(_delta: float) -> void:pass
class Context extends Node3D:
	var local_player: GamePlayer
	var ui_focus: GameUIFocus
	var br_hud: Node
	var requests: Array[Dictionary]=[]
	func request_br_select_slot(index: int) -> void:requests.append({"action":"slot","index":index})
	func request_br_drop(weapon: String) -> void:requests.append({"action":"drop_weapon","weapon":weapon})
	func request_br_heal() -> void:requests.append({"action":"heal"})
	func request_br_use_ammo(calibre: String,weapon: String) -> void:requests.append({"action":"use_ammo","calibre":calibre,"weapon":weapon})
	func request_br_attachment(weapon: String,socket: String,id: String,uid: int=-1,position: float=0.) -> void:requests.append({"action":"attachment","weapon":weapon,"socket":socket,"id":id,"uid":uid,"position":position})
	func request_br_drop_attachment(id: String,uid: int=-1) -> void:requests.append({"action":"drop_attachment","id":id,"uid":uid})
	func request_br_drop_ammo(calibre: String,amount: int) -> void:requests.append({"action":"drop_ammo","calibre":calibre,"amount":amount})
	func request_br_drop_protection(kind: String) -> void:requests.append({"action":"drop_protection","kind":kind})
	func request_br_drop_pack() -> void:requests.append({"action":"drop_pack"})
	func request_br_drop_heal() -> void:requests.append({"action":"drop_heal"})
	func br_interact(id: int,part: int=-1) -> void:requests.append({"action":"pickup","id":id,"part":part})
	func request_br_pickup_use(id: int,part: int=-1) -> void:requests.append({"action":"pickup_use","id":id,"part":part})
	func request_br_ground_use(id: int,part: int=-1) -> void:requests.append({"action":"ground_use","id":id,"part":part})
	func _close_inventory() -> void:ui_focus.close_all()
var game: Context
var panel: BRInventoryPanel
var checks:=0
var failures: Array[String]=[]
var captures: Array[String]=[]
var data: Dictionary={"weapons":["fal","ak"],"magazines":{"fal":6,"ak":12},"reserve_by_weapon":{"fal":40,"ak":60},"ammo":{"9mm":24,"76251":40,"76239":60},"medkits":2,"weight":42.,"capacity":140.,"backpack":2,"accessory_items":[{"id":"pso4x","uid":103,"state":{}},{"id":"prism4x","uid":102,"state":{}}],"weapon_attachments":{"fal":{},"ak":{}},"protection":{"helmet":{"level":1,"durability":40.},"vest":{"level":2,"durability":80.}}}
var state: Dictionary={"phase":"active","heal_remaining":0.}
var loot: Array=[{"id":8,"kind":"ammo","calibre":"76251","amount":18,"position":Vector3(1,0,0)},{"id":9,"kind":"container","position":Vector3(1,0,1),"contents":[{"part_id":1,"kind":"heal","amount":1},{"part_id":2,"kind":"attachment","attachment":"pso4x","state":{},"amount":1}]},{"id":10,"kind":"heal","amount":1,"position":Vector3(20,0,0)}]
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures.append(label);push_error(label)
func present() -> void:panel.present(state,data,loot)
func last() -> Dictionary:return game.requests.back() if not game.requests.is_empty() else {}
func select(key: String) -> void:
	var button:=panel.bag_buttons.get(key) as Button
	check(button!=null,"bag item available "+key)
	if button:button.pressed.emit()
func capture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await process_frame;await RenderingServer.frame_post_draw
	var path:="res://work/"+name+".png";root.get_texture().get_image().save_png(path);captures.append(path)
func run() -> void:
	root.content_scale_size=Vector2i.ZERO;root.size=Vector2i(1280,800);root.gui_embed_subwindows=true
	game=Context.new();root.add_child(game);game.ui_focus=GameUIFocus.new();game.add_child(game.ui_focus);game.br_hud=game
	game.local_player=Actor.new();game.add_child(game.local_player);game.local_player.hp=70.;game.local_player.weapon_id="fal"
	panel=PANEL.new();panel.game=game;game.add_child(panel);await process_frame
	game.ui_focus.open(panel);present();await process_frame;await process_frame
	check(panel.bag_list.get_child_count()==6,"one mixed bag list includes ammo, heal and two accessory instances")
	var names: Array[String]=[]
	for child in panel.bag_list.get_children():
		check(child is Button,"mixed list has item rows without category section labels")
		if child is Button:names.append(child.text)
	var sorted:=names.duplicate();sorted.sort_custom(func(a: String,b: String):return a.naturalnocasecmp_to(b)<0)
	check(names==sorted,"mixed bag sorts visible names alphabetically")
	check(panel.ground_list.get_child_count()==3,"ground expands nearby corpse contents and excludes distant loot")
	check(panel.cards.size()==2 and panel.cards[0].weapon=="fal" and panel.cards[1].weapon=="ak","two generic weapon cards")
	for card in panel.cards:
		check(card.silhouette.texture!=null and card.silhouette.texture.resource_path=="res://assets/ui/weapons/"+card.weapon+".png","actual gameplay mesh silhouette "+card.weapon)
		check(card.slots.has("optic_top") and card.slots.has("muzzle") and card.slots.has("magazine") and card.slots.has("stock"),"resource-defined mounts "+card.weapon)
	panel.cards[1].header.pressed.emit();check(last()=={"action":"slot","index":1},"weapon number selects authority slot")
	select("heal");check(panel.item_popup.visible and panel.item_popup.get_item_text(0)=="USAR","clicking carried curative opens use/drop menu")
	await capture("br-inventory-use-menu")
	panel.item_popup.id_pressed.emit(0);panel.item_popup.hide();check(last().get("action","")=="heal","curative menu use requests healing")
	panel.use_button.pressed.emit();check(last().get("action","")=="heal","selected curative use button requests healing")
	game.local_player.hp=100.;present();check(panel.use_button.disabled,"full health disables curative use");game.local_player.hp=70.
	select("ammo:76251");panel.use_button.pressed.emit();check(last()=={"action":"use_ammo","calibre":"76251","weapon":"fal"},"ammo use targets compatible currently held weapon")
	select("ammo:76239");panel.use_button.pressed.emit();check(last()=={"action":"use_ammo","calibre":"76239","weapon":"ak"},"ammo use targets compatible second weapon")
	check(panel.item_popup.get_item_text(0)=="RECARREGAR","carried ammunition menu uses contextual reload action")
	select("ammo:9mm");check(panel.use_button.disabled,"no owned compatible firearm disables ammo use")
	select("attachment:102");check(not panel.use_button.disabled and panel.use_button.text=="EQUIPAR","carried module exposes equip action")
	var highlighted:=panel.cards[0].slots.optic_top.get_theme_stylebox("normal") as StyleBoxFlat
	var incompatible:=panel.cards[0].slots.magazine.get_theme_stylebox("normal") as StyleBoxFlat
	check(highlighted.bg_color!=incompatible.bg_color,"compatible mount visually differs from incompatible mount")
	panel.cards[1].slots.optic_top.pressed.emit();check(last().get("weapon","")=="ak" and last().get("socket","")=="optic_top" and last().get("id","")=="prism4x" and int(last().get("uid",0))==102,"socket click passes chosen weapon and exact bag instance")
	data.accessory_items.remove_at(1);data.weapon_attachments.ak={"optic_top":{"id":"prism4x","state":{},"position":0.}};present()
	check(not panel.bag_buttons.has("attachment:102") and panel.selected.is_empty(),"installed module leaves mixed bag and clears vanished selection")
	panel.cards[1].slots.optic_top.pressed.emit();check(panel.popup.item_count>=1 and panel.popup.get_item_text(0)=="Retirar","installed mount opens remove menu")
	panel.popup.id_pressed.emit(0);panel.popup.hide();check(last().get("action","")=="attachment" and last().get("weapon","")=="ak" and last().get("id","x")=="","remove menu requests module detachment")
	select("attachment:103");panel.use_button.pressed.emit();check(last().get("weapon","")=="fal" and last().get("id","")=="pso4x" and int(last().get("uid",0))==103,"equip action prioritizes held compatible weapon with exact instance")
	game.local_player.reload_left=2.;present();check(panel.use_button.disabled and panel.cards[0].slots.optic_top.disabled,"reload locks module actions and mounts")
	game.local_player.reload_left=0.;present();panel.drop_button.pressed.emit();check(last()=={"action":"drop_attachment","id":"pso4x","uid":103},"drop action preserves chosen accessory instance")
	panel.body_rows.helmet.drop.pressed.emit();check(last()=={"action":"drop_protection","kind":"helmet"},"helmet drop authority request")
	panel.body_rows.vest.drop.pressed.emit();check(last()=={"action":"drop_protection","kind":"vest"},"vest drop authority request")
	panel.body_rows.pack.drop.pressed.emit();check(last().get("action","")=="drop_pack","backpack drop authority request")
	check(panel.body_rows.helmet.root.global_position.y<panel.body_rows.pack.root.global_position.y and panel.body_rows.pack.root.global_position.y<panel.body_rows.vest.root.global_position.y,"equipment column orders helmet, backpack and vest")
	data.weight=90.;present();check(panel.body_rows.pack.drop.disabled,"overfull pockets prevent dropping backpack")
	data.weight=42.;present();panel.selected={};panel._update_selection();panel._update_cards()
	panel.item_popup.hide();panel.popup.hide()
	var before_ground:=game.requests.size();(panel.ground_list.get_child(0) as Button).pressed.emit()
	check(panel.ground_popup.visible and game.requests.size()==before_ground,"ground click opens action menu before mutating ownership")
	panel.ground_popup.id_pressed.emit(0);panel.ground_popup.hide();check(last()=={"action":"pickup","id":8,"part":-1},"ground pickup menu sends loot identifier")
	(panel.ground_list.get_child(1) as Button).pressed.emit();panel.ground_popup.id_pressed.emit(1);panel.ground_popup.hide()
	check(last()=={"action":"ground_use","id":9,"part":1},"corpse curative use preserves container part identifier")
	(panel.ground_list.get_child(2) as Button).pressed.emit();check(panel.ground_popup.get_item_text(1)=="Equipar","ground module exposes contextual equip action");panel.ground_popup.hide()
	await capture("br-inventory-modular-1280")
	for size in [Vector2i(1280,800),Vector2i(960,640)]:
		root.size=size;await process_frame;await process_frame;game.ui_focus._resize_panels();await process_frame
		var viewport_rect:=root.get_visible_rect();check(viewport_rect.encloses(panel.get_global_rect()),"inventory fits viewport "+str(size)+" modal="+str(panel.get_global_rect()))
		for card in panel.cards:
			check(panel.get_global_rect().encloses(card.get_global_rect()),"weapon card stays within modal "+str(size))
			for button: Button in card.slots.values():check(card.stage.get_global_rect().encloses(button.get_global_rect()),"mount button stays within weapon stage "+str(size))
		if size.x==960:await capture("br-inventory-modular-960")
	var report:={"ok":failures.is_empty(),"checks":checks,"failures":failures,"captures":captures,"scope":"Production modular inventory panel controls with request-capturing context. Mixed alphabetical bag, precise module UID/target actions, remove popup, ammo/heal use, locks, equipment placement, static mesh silhouettes and viewport bounds. Actual server mutations validated separately by modular network suite."}
	var file:=FileAccess.open("res://work/br-inventory-modular-ui-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("BR_INVENTORY_MODULAR_UI_VALIDATION ",JSON.stringify(report));game.free();await process_frame;quit(0 if failures.is_empty() else 1)
