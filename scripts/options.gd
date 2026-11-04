extends RefCounted
class_name GameOptions
const ACTIONS:={"move_forward":"Avançar","move_back":"Recuar","move_left":"Esquerda","move_right":"Direita","jump":"Pular / subir","crouch":"Agachar / descer","lean_left":"Inclinar à esquerda","lean_right":"Inclinar à direita"}
const PRESETS:={"Baixo":{"aa":0,"scale":.75,"shadows":false,"shadow_distance":100,"render_distance":250,"lod_quality":0,"war_vegetation":1},"Médio":{"aa":1,"scale":.85,"shadows":true,"shadow_distance":150,"render_distance":400,"lod_quality":1,"war_vegetation":2},"Alto":{"aa":2,"scale":1.,"shadows":true,"shadow_distance":220,"render_distance":650,"lod_quality":2,"war_vegetation":3},"Ultra":{"aa":3,"scale":1.,"shadows":true,"shadow_distance":300,"render_distance":900,"lod_quality":2,"war_vegetation":3}}
const SCENARIO=preload("res://scripts/scenario_rendering.gd")
const RENDERERS:=["gl_compatibility","forward_plus"]
static var values: Dictionary={}
static var path:=""
static var dirty:=false

static func vegetation_preview_available(game: Node) -> bool:
	if not is_instance_valid(game):return false
	var id:="afghan" if game.map_kind=="afghan" else ("ukraine" if game is WarGame else "desert")
	return load("res://scripts/maps/definition.gd").grass_enabled(id) or (OS.has_feature("editor") and bool(game.get_meta("nova_grama_preview",false)))

static func ensure() -> void:
	var current:=NavalStorage.settings_folder().path_join("game-options.json")
	if current==path: return
	path=current;values=NavalStorage.read_json(path);dirty=false
	for field in ["fov","fps","aa","scale","hud_opacity","war_vegetation","voice_volume","render_distance","lod_quality"]:
		if values.has(field) and (not (values[field] is float or values[field] is int) or not is_finite(float(values[field]))): values.erase(field)
	# Proximity range is now a shared gameplay constant, including old accounts.
	for field in ["voice_distance","voice_clear_distance"]:
		if values.has(field):values.erase(field);dirty=true
	# Numeric preference: the account API intentionally rejects string values.
	if values.has("war_vegetation"): values.war_vegetation=clampi(int(values.war_vegetation),0,3)
	if values.has("renderer") and str(values.renderer) not in RENDERERS: values.erase("renderer");dirty=true

static func number(id: String,fallback: float) -> float:
	ensure();return float(values.get(id,fallback))
static func flag(id: String,fallback:=true) -> bool:
	ensure();return bool(values.get(id,fallback))
static func scenario_distance() -> int:
	var wanted:=number("render_distance",400);var result:=400;var difference:=INF
	for metres: int in SCENARIO.DISTANCES:
		if absf(metres-wanted)<difference:result=metres;difference=absf(metres-wanted)
	return result
static func vegetation_level() -> int:
	var wanted:=clampi(int(number("war_vegetation",2)),0,3)
	return wanted if "--nova-grama-preview" in OS.get_cmdline_user_args() else (2 if wanted==0 else wanted)
static func set_value(id: String,value: Variant) -> void:
	ensure();values[id]=value;dirty=true;NavalStorage.mark_setting("game-options.json")
static func renderer_preference() -> String:
	ensure();var wanted:=str(values.get("renderer","gl_compatibility"))
	return wanted if wanted in RENDERERS else "gl_compatibility"
static func active_renderer() -> String:
	return RenderingServer.get_current_rendering_method()
static func renderer_label(method: String) -> String:
	return "Forward+ (experimental)" if method=="forward_plus" else "Compatibility"
static func launch_renderer(method: String) -> int:
	if method not in RENDERERS or DisplayServer.get_name()=="headless":return -1
	values.renderer_pending=method;dirty=true;flush()
	var arguments:=PackedStringArray(["--rendering-method",method,"--"])
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--renderer-relaunch="):arguments.append(argument)
	arguments.append("--renderer-relaunch="+method)
	var pid:=OS.create_process(OS.get_executable_path(),arguments,false)
	if pid<=0:
		values.erase("renderer_pending");values.renderer=active_renderer();values.renderer_error=method;dirty=true;flush()
	return pid
static func startup_renderer_guard() -> bool:
	if DisplayServer.get_name()=="headless" or OS.has_feature("editor") or "--renderer-test" in OS.get_cmdline_user_args():return false
	ensure()
	var wanted:=renderer_preference();var active:=active_renderer()
	var marker:=""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--renderer-relaunch="):marker=argument.trim_prefix("--renderer-relaunch=");break
	if wanted==active:
		var changed:=values.has("renderer_pending") or values.has("renderer_error")
		values.erase("renderer_pending");values.erase("renderer_error")
		if changed:dirty=true;flush()
		return false
	if marker==wanted:
		values.erase("renderer_pending");values.renderer=active;values.renderer_error=wanted;dirty=true;flush()
		return false
	if str(values.get("renderer_pending",""))==wanted:
		values.erase("renderer_pending");values.renderer=active;values.renderer_error=wanted;dirty=true;flush()
		return false
	return launch_renderer(wanted)>0
static func flush() -> void:
	if dirty and NavalStorage.write_json(path,values): dirty=false

static func apply(viewport: Viewport,world: Node=null) -> void:
	ensure()
	if DisplayServer.get_name()=="headless": return
	if values.has("fps"): Engine.max_fps=clampi(int(values.fps),0,240)
	if values.has("vsync"): DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	viewport.msaa_3d=clampi(int(values.get("aa",0)),0,3)
	viewport.mesh_lod_threshold=SCENARIO.PIXELS[clampi(int(number("lod_quality",1)),0,2)]
	if values.has("scale"): viewport.scaling_3d_scale=clampf(float(values.scale),.5,1)
	if is_instance_valid(world) and values.has("shadows"):
		for light: DirectionalLight3D in world.find_children("*","DirectionalLight3D",true,false):
			light.shadow_enabled=bool(values.shadows);light.directional_shadow_max_distance=clampf(number("shadow_distance",180),60,400)
	if is_instance_valid(world) and world.is_inside_tree():
		var scenario_controller:=world.get_node_or_null("ScenarioRendering")
		if not is_instance_valid(scenario_controller):scenario_controller=SCENARIO.new();scenario_controller.name="ScenarioRendering";world.add_child(scenario_controller)
		scenario_controller.configure(world,scenario_distance(),clampi(int(number("lod_quality",1)),0,2))
		var vegetation_level:=vegetation_level()
		for controller in world.get_tree().get_nodes_in_group("war_vegetation_visuals"):
			if (controller==world or world.is_ancestor_of(controller)) and controller.has_method("apply_level"):
				controller.call("apply_level",vegetation_level)
	for hud in viewport.get_tree().get_nodes_in_group("game_hud"):
		if hud is Control: hud.modulate.a=clampf(number("hud_opacity",1),.65,1)

static func startup(viewport: Viewport) -> void:
	ensure()
	if DisplayServer.get_name()=="headless": return
	if values.has("window_mode"):
		var size: Variant=values.get("window_size",[1280,800])
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if size is Array and size.size()==2: DisplayServer.window_set_size(Vector2i(clampi(int(size[0]),800,3840),clampi(int(size[1]),600,2160)))
		if int(values.window_mode)==1: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	apply(viewport)

static func apply_controls() -> void:
	ensure()
	var saved: Variant=values.get("keys",{})
	if not saved is Dictionary: return
	for action in ACTIONS:
		if not InputMap.has_action(action) or not saved.has(action): continue
		var code:=int(saved[action])
		if code<=0 or code>KEY_SPECIAL+100: continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey: InputMap.action_erase_event(action,event)
		var event:=InputEventKey.new();event.physical_keycode=code;InputMap.action_add_event(action,event)

static func bind(action: String,code: int) -> String:
	if not ACTIONS.has(action) or code<=0: return "Tecla inválida."
	if code in [KEY_ESCAPE,KEY_TAB,KEY_ENTER,KEY_G,KEY_V,KEY_R,KEY_C,KEY_F,KEY_X,KEY_B,KEY_H,KEY_M,KEY_T] or (code>=KEY_0 and code<=KEY_9): return "Tecla em uso."
	for other in ACTIONS:
		if other==action: continue
		for event in InputMap.action_get_events(other):
			if event is InputEventKey and code in [event.keycode,event.physical_keycode]: return "Tecla em uso."
	var keys: Dictionary=values.get("keys",{});keys[action]=code;set_value("keys",keys);apply_controls();flush();return ""

static func key_name(action: String) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey: return OS.get_keycode_string(event.physical_keycode if event.physical_keycode>0 else event.keycode)
	return "—"
