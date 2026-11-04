@tool
extends EditorPlugin
const MAP:="res://modes/war/scenes/map_additions.tscn"
const LIB:="res://modes/war/library/"
const AFGHAN_MAP:="res://modes/battle_royale/scenes/map_additions.tscn"
const AFGHAN_CATALOG:="res://modes/battle_royale/library/catalog_v2.json"
var IDS: Array=[]
var TITLES: Array=[]
var SCENES: Array[String]=[]
var palette_generation:=0
var afghan_palette:=false
var dock: VBoxContainer
var list: ItemList
var context: Node3D
var height_image: Image
var terrain_preview: Node3D
var terrain_clock:=0.
var terrain_signature:=0
var preview_sectors: Dictionary={}
var feedback: Label
var context_generation:=0
var other_records: Array[Dictionary]=[]

func _enter_tree() -> void:
	IDS=WarPrefabFactory.ITEMS.keys();TITLES=WarPrefabFactory.ITEMS.values()
	add_to_group("war_map_authoring")
	dock=VBoxContainer.new();dock.name="Guerra"
	var buttons:=HBoxContainer.new();dock.add_child(buttons)
	for entry in [["Mapa",MAP],["Referências","res://editor/war/biblioteca.tscn"]]:
		var button:=Button.new();button.text=entry[0];button.pressed.connect(func():EditorInterface.open_scene_from_path(entry[1]));buttons.add_child(button)
	var afghan_buttons:=HBoxContainer.new();dock.add_child(afghan_buttons)
	for entry in [["Afeganistão",AFGHAN_MAP],["Objetos afegãos","res://modes/battle_royale/library/catalog_v2.tscn"]]:
		var button:=Button.new();button.text=entry[0];button.pressed.connect(func():EditorInterface.open_scene_from_path(entry[1]));afghan_buttons.add_child(button)
	list=ItemList.new();list.custom_minimum_size=Vector2(220,250);list.size_flags_vertical=Control.SIZE_EXPAND_FILL;list.fixed_icon_size=Vector2i(56,56)
	_populate_palette(false)
	list.item_activated.connect(insert)
	dock.add_child(list)
	var add:=Button.new();add.text="Inserir";add.pressed.connect(func():
		var selected:=list.get_selected_items()
		if not selected.is_empty(): insert(selected[0]))
	dock.add_child(add)
	var snap:=Button.new();snap.text="Encaixar";snap.pressed.connect(snap_selected);dock.add_child(snap)
	feedback=Label.new();feedback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;dock.add_child(feedback)
	var play:=Button.new();play.text="Testar Guerra Offline";play.pressed.connect(func():EditorInterface.play_custom_scene("res://editor/war/play_war.tscn"));dock.add_child(play)
	add_control_to_dock(DOCK_SLOT_RIGHT_BL,dock)
	scene_changed.connect(func(scene):call_deferred("_scene_changed",scene))
	call_deferred("_scene_changed",EditorInterface.get_edited_scene_root())
	if "--war-library-qa" in OS.get_cmdline_user_args(): call_deferred("_run_qa")
	if "--afghan-library-qa" in OS.get_cmdline_user_args(): call_deferred("_run_afghan_qa")

func _populate_palette(afghan: bool) -> void:
	if not is_instance_valid(list): return
	afghan_palette=afghan;palette_generation+=1
	IDS.clear();TITLES.clear();SCENES.clear();list.clear()
	if afghan:
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(AFGHAN_CATALOG))
		if parsed is Dictionary:
			var entries: Array=parsed.get("buildings",[])+parsed.get("props",[])
			for entry: Dictionary in entries:
				var id:=str(entry.get("id",""));var path: String=str(entry.get("scene","res://modes/battle_royale/library/"+id+".tscn"))
				if id.is_empty() or not ResourceLoader.exists(path): continue
				IDS.append(id);TITLES.append(str(entry.get("label",id)));SCENES.append(path)
		for entry in [["market_stall","Banca de mercado"],["rock_outcrop","Afloramento rochoso"],["dry_shrub","Arbusto seco"]]:
			IDS.append(entry[0]);TITLES.append(entry[1]);SCENES.append("res://modes/battle_royale/library/"+entry[0]+".tscn")
	else:
		IDS=WarPrefabFactory.ITEMS.keys();TITLES=WarPrefabFactory.ITEMS.values()
		for id in IDS: SCENES.append(LIB+str(id)+".tscn")
	for i in IDS.size(): list.add_item(TITLES[i])
	call_deferred("_request_previews")

func _thumbnail(_path: String,preview: Texture2D,_small: Texture2D,data: Variant) -> void:
	if not data is Dictionary or int(data.generation)!=palette_generation: return
	var index:=int(data.index)
	if is_instance_valid(list) and preview and index>=0 and index<list.item_count: list.set_item_icon(index,preview)

func _request_previews() -> void:
	var generation:=palette_generation
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	await get_tree().process_frame
	if generation!=palette_generation: return
	for i in SCENES.size(): EditorInterface.get_resource_previewer().queue_resource_preview(SCENES[i],self,"_thumbnail",{"generation":generation,"index":i})

func _scene_changed(scene: Node) -> void:
	var afghan:=is_instance_valid(scene) and scene.scene_file_path.begins_with("res://modes/battle_royale/")
	if afghan!=afghan_palette: _populate_palette(afghan)
	if DisplayServer.get_name()=="headless": return
	context_generation+=1
	var generation:=context_generation
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	await get_tree().process_frame
	if generation!=context_generation or scene!=EditorInterface.get_edited_scene_root(): return
	if is_instance_valid(context): context.queue_free()
	context=null
	terrain_preview=null;preview_sectors.clear();other_records.clear();terrain_signature=0;terrain_clock=0
	if not is_instance_valid(scene) or scene.scene_file_path not in [MAP,"res://modes/war/scenes/east_port.tscn"]: return
	if not ResourceLoader.exists("res://editor/war/referencia_mundo.scn"): return
	context=load("res://editor/war/referencia_mundo.scn").instantiate() as Node3D
	context.name="ContextoDoMapa"
	if scene.scene_file_path.ends_with("east_port.tscn"): context.position=Vector3(-1190,-4,-470)
	# No owner: this is an editor reference, not another copy of the world in
	# the saved map. Runtime always builds the authoritative terrain once.
	scene.add_child(context,false,Node.INTERNAL_MODE_BACK)
	if scene.scene_file_path==MAP:
		var east: Node3D=load("res://modes/war/scenes/east_port.tscn").instantiate();east.position=Vector3(1190,4,470);context.add_child(east)
	var editing_east:=scene.scene_file_path.ends_with("east_port.tscn")
	var other:=load(MAP if editing_east else "res://modes/war/scenes/east_port.tscn").instantiate() as Node3D
	WarTerrainEdits.collect(other,Transform3D(Basis.IDENTITY,Vector3.ZERO if editing_east else Vector3(1190,4,470)),other_records);other.free()
	terrain_edit_changed()

func insert(index: int) -> void:
	var scene:=EditorInterface.get_edited_scene_root() as Node3D
	if scene==null or index<0 or index>=SCENES.size(): return
	var prefab:=load(SCENES[index]) as PackedScene
	if prefab==null: return
	var object:=prefab.instantiate() as Node3D
	var camera:=EditorInterface.get_editor_viewport_3d(0).get_camera_3d()
	var point:=camera.global_position-camera.global_basis.z*16.
	var parent: Node3D=scene
	var selected:=EditorInterface.get_selection().get_selected_nodes()
	if not selected.is_empty() and selected[0] is Node3D:
		var current: Node3D=selected[0]
		point=current.global_position
		if current==scene or current.get_child_count()>0 and not current.has_meta("library_id"): parent=current
	if height_image==null and ResourceLoader.exists("res://editor/war/terrain_height.res"): height_image=load("res://editor/war/terrain_height.res") as Image
	if scene.scene_file_path==MAP and height_image:
		point.y=WarTerrain._base(point.x,point.z) if object is WarTrenchModule else WarTerrain.height_at(point.x,point.z)
	elif scene.scene_file_path==AFGHAN_MAP:
		point.y=BRAfghanMap.height_at(point.x,point.z)
	object.position=parent.to_local(point)
	var history:=get_undo_redo();history.create_action("Adicionar "+TITLES[index])
	history.add_do_method(parent,"add_child",object,true)
	history.add_do_property(object,"owner",scene)
	history.add_do_reference(object)
	history.add_undo_method(parent,"remove_child",object)
	history.commit_action()
	EditorInterface.get_selection().clear();EditorInterface.get_selection().add_node(object)
	if WarModuleSnap.nearest(object,scene).has("transform"): snap_selected()
	terrain_edit_changed()

func snap_selected() -> void:
	var scene:=EditorInterface.get_edited_scene_root() as Node3D
	var selection:=EditorInterface.get_selection().get_selected_nodes()
	if scene==null or selection.size()!=1 or not selection[0] is Node3D: return
	var object:=selection[0] as Node3D
	var solution:=WarModuleSnap.nearest(object,scene)
	if solution.is_empty(): feedback.text="Nenhum encaixe próximo.";return
	var pose: Transform3D=object.get_parent().global_transform.affine_inverse()*Transform3D(solution.transform)
	var history:=get_undo_redo();history.create_action("Encaixar módulo")
	history.add_do_property(object,"transform",pose);history.add_undo_property(object,"transform",object.transform);history.commit_action()
	feedback.text="";terrain_edit_changed()

func terrain_edit_changed() -> void:
	terrain_clock=.15

func _process(delta: float) -> void:
	if DisplayServer.get_name()=="headless" or not is_instance_valid(context): return
	terrain_clock-=delta
	if terrain_clock>0: return
	terrain_clock=.5
	refresh_terrain()

func refresh_terrain() -> void:
	var scene:=EditorInterface.get_edited_scene_root() as Node3D
	if scene==null or scene.scene_file_path not in [MAP,"res://modes/war/scenes/east_port.tscn"]: return
	var records: Array[Dictionary]=[]
	var east:=scene.scene_file_path.ends_with("east_port.tscn")
	WarTerrainEdits.collect(scene,Transform3D(Basis.IDENTITY,Vector3(1190,4,470) if east else Vector3.ZERO),records)
	records.append_array(other_records)
	var signature:=hash(records)
	if signature==terrain_signature: return
	# Include old holes as well: deleting/moving a stamp restores its old sector.
	if terrain_signature==0:
		WarTerrainEdits.prepare()
		for edit in WarTerrainEdits.edits: remember_sector(edit.bounds)
	for edit in records:
		if edit.has("bounds"): remember_sector(edit.bounds)
	terrain_signature=signature;WarTerrainEdits.configure(records)
	if is_instance_valid(terrain_preview): context.remove_child(terrain_preview);terrain_preview.queue_free()
	terrain_preview=Node3D.new();terrain_preview.name="TerrenoEditado";context.add_child(terrain_preview)
	for child in context.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("WarTerrainVisualSector"):
			var key:=Vector2i(roundi((child.position.x+1750)/200),roundi((child.position.z+1750)/200))
			if preview_sectors.has(key): child.hide()
	var selection: Array[Vector2i]=[]
	for key: Vector2i in preview_sectors:
		for z in 2:
			for x in 2:
				var tile:=key*2+Vector2i(x,z)
				if tile.x>=0 and tile.y>=0 and tile.x<35 and tile.y<35: selection.append(tile)
	if not selection.is_empty(): WarTerrain.build(terrain_preview,true,selection)
	# The editor preview is render-only and never belongs to the saved scene.
	for body in terrain_preview.find_children("*","StaticBody3D",true,false): body.queue_free()

func remember_sector(rect: Rect2) -> void:
	var low:=Vector2i(floori((rect.position.x+1750)/200),floori((rect.position.y+1750)/200))
	var high:=Vector2i(floori((rect.end.x+1750)/200),floori((rect.end.y+1750)/200))
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1): preview_sectors[Vector2i(x,z)]=true

func _exit_tree() -> void:
	if is_instance_valid(context): context.queue_free()
	if is_instance_valid(dock): remove_control_from_docks(dock);dock.queue_free()

func _run_qa() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	await get_tree().create_timer(1.).timeout
	EditorInterface.open_scene_from_path(MAP)
	while not is_instance_valid(context): await get_tree().process_frame
	await get_tree().create_timer(1.).timeout
	var scene:=EditorInterface.get_edited_scene_root() as Node3D
	var checks: Dictionary={"palette":list.item_count==WarPrefabFactory.ITEMS.size(),"map_open":scene.scene_file_path==MAP,"reference":is_instance_valid(context) and context.owner==null}
	var before:=scene.get_node("BaseOeste").get_child_count()
	EditorInterface.get_selection().clear();EditorInterface.get_selection().add_node(scene.get_node("BaseOeste"))
	insert(4)
	var selected:=EditorInterface.get_selection().get_selected_nodes()
	checks.inserted=not selected.is_empty() and selected[0].owner==scene and scene.get_node("BaseOeste").get_child_count()==before+1
	var packed:=PackedScene.new();packed.pack(scene)
	ResourceSaver.save(packed,"res://work/editor190-serialized.tscn")
	var text:=FileAccess.get_file_as_string("res://work/editor190-serialized.tscn")
	checks.no_duplicate_world=not "WarTerrainVisualSector" in text and not "ContextoDoMapa" in text
	var history:=get_undo_redo();history.get_history_undo_redo(history.get_object_history_id(scene)).undo()
	checks.undo=scene.get_node("BaseOeste").get_child_count()==before
	refresh_terrain()
	var at:=Vector3(350,WarTerrain.height_at(350,350),350)
	var trench:=load(LIB+"trincheira_escavavel_6m.tscn").instantiate() as WarTrenchModule
	trench.position=at;scene.add_child(trench);trench.owner=scene;refresh_terrain()
	checks.trench_excavates=absf(WarTerrain.height_at(at.x,at.z)-(at.y-1.5))<.01
	trench.depth=2.;refresh_terrain()
	checks.trench_depth=absf(WarTerrain.height_at(at.x,at.z)-(at.y-2.))<.01 and is_equal_approx(trench.get_node("Revestimento").scale.y,2./1.5)
	trench.position.x+=20;refresh_terrain()
	checks.moving_restores_old_ground=absf(WarTerrain.height_at(at.x,at.z)-at.y)<.01
	checks.new_position_excavates=WarTerrain.height_at(trench.position.x,trench.position.z)<at.y-1.8
	scene.remove_child(trench);trench.free();refresh_terrain()
	checks.removal_restores_ground=absf(WarTerrain.height_at(at.x,at.z)-at.y)<.01
	checks.preview_unsaved=is_instance_valid(terrain_preview) and terrain_preview.owner==null
	var file:=FileAccess.open("res://tests/library190-editor-results.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks));file.close()
	print("EDITOR_LIBRARY_QA ",JSON.stringify(checks))
	if is_instance_valid(context): context.queue_free();context=null
	await get_tree().create_timer(2.).timeout
	WarTerrain.material=null
	await get_tree().process_frame
	get_tree().quit(0 if checks.values().all(func(value):return value) else 1)

func _run_afghan_qa() -> void:
	while EditorInterface.get_resource_filesystem().is_scanning(): await get_tree().process_frame
	await get_tree().process_frame
	_populate_palette(true)
	var checks: Dictionary={"afghan_palette":list.item_count==17,"afghan_paths":SCENES.all(func(path):return path.begins_with("res://modes/battle_royale/library/")),"afghan_scene_exists":ResourceLoader.exists(AFGHAN_MAP)}
	var unique: Dictionary={}
	var valid:=true
	for path in SCENES:
		unique[path]=true
		var resource:=load(path) as PackedScene
		if resource==null: valid=false;continue
		var instance:=resource.instantiate() as Node3D
		if instance==null: valid=false;continue
		valid=valid and instance.get_script()==null and instance.has_meta("library_id")
		instance.free()
	checks.prefabs_reusable=valid;checks.unique_paths=unique.size()==SCENES.size()
	_populate_palette(false)
	checks.war_palette_preserved=list.item_count==WarPrefabFactory.ITEMS.size() and SCENES.all(func(path):return path.begins_with(LIB))
	var file:=FileAccess.open("res://work/afghan-library-editor-validation.json",FileAccess.WRITE);file.store_string(JSON.stringify(checks,"\t"));file.close()
	print("AFGHAN_EDITOR_QA ",JSON.stringify(checks));get_tree().quit(0 if checks.values().all(func(value):return value) else 1)
