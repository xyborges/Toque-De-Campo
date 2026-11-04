extends CanvasLayer
class_name WarThermal
var game: WarGame
var enabled := false
var overlay: ColorRect
var registered: Dictionary = {}
var heat_materials: Dictionary = {}
var scan_clock := 0.0

func _ready() -> void:
	name="Thermal"
	layer=1
	overlay=ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; uniform sampler2D scene:hint_screen_texture,repeat_disable,filter_linear; void fragment(){vec3 rgb=texture(scene,SCREEN_UV).rgb;float luminance=dot(rgb,vec3(.2126,.7152,.0722));float contrast=smoothstep(.12,.98,luminance);COLOR=vec4(vec3(.025+contrast*.85),1.0);}"
	var material:=ShaderMaterial.new();material.shader=shader
	overlay.material=material
	add_child(overlay)
	overlay.hide()

func set_enabled(value: bool) -> void:
	if enabled==value: return
	enabled=value
	overlay.visible=value
	if value: _scan()
	else: _restore_materials()

func _restore_materials() -> void:
	for entry: Dictionary in registered.values():
		var node: MeshInstance3D=entry.ref.get_ref()
		# Preserve material changes made by damage/customization while active.
		if is_instance_valid(node) and node.material_override==entry.material:
			node.material_override=entry.original
		if is_instance_valid(node): node.remove_meta("thermal_source")
	registered.clear()

func _exit_tree() -> void:
	_restore_materials()

func _process(delta: float) -> void:
	if not enabled: return
	scan_clock+=delta
	if scan_clock>.3: scan_clock=0;_scan()

func _scan() -> void:
	for id in registered.keys():
		if not is_instance_valid(registered[id].ref.get_ref()): registered.erase(id)
	for actor: GamePlayer in game.players.values(): _register(actor.body_root,.86)
	if not game.vehicle_system: return
	for vehicle: WarVehicle in game.vehicle_system.vehicles.values():
		for mesh: MeshInstance3D in vehicle.find_children("*","MeshInstance3D",true,false):
			var name_text:=str(mesh.name)
			var heat:=.62 if vehicle.driver>0 and not vehicle.destroyed else .26
			if name_text.begins_with("Engine") or mesh.get_meta("thermal_region","")=="engine": heat=.92 if vehicle.driver>0 else .52
			elif name_text.begins_with("Gun") or mesh.get_meta("thermal_region","")=="gun": heat=.77 if vehicle.fire_wait>0 else .4
			_register_mesh(mesh,heat)
	for drone: WarDrone in game.vehicle_system.drones.values(): _register(drone,.9)

func _register(root: Node3D,heat: float) -> void:
	if not is_instance_valid(root): return
	for mesh: MeshInstance3D in root.find_children("*","MeshInstance3D",true,false): _register_mesh(mesh,heat)

func _register_mesh(mesh: MeshInstance3D,heat: float) -> void:
	if not enabled or mesh.has_meta("wreck_source"): return
	var key:=int(heat*100)
	if not heat_materials.has(key):
		var material:=ShaderMaterial.new()
		material.shader=preload("res://modes/war/shaders/heat.gdshader")
		material.set_shader_parameter("active",true)
		material.set_shader_parameter("heat",heat)
		heat_materials[key]=material
	var desired: Material=heat_materials[key]
	var id:=mesh.get_instance_id()
	# Most scans see exactly the same appearance and heat. Avoid replacing
	# metadata/dictionaries (and notifying the renderer) for every mesh again.
	if registered.has(id):
		var previous: Dictionary=registered[id]
		if previous.material==desired and mesh.material_override==desired: return
	if not registered.has(id):
		registered[id]={"ref":weakref(mesh),"material":desired,"original":mesh.material_override}
	else:
		var entry: Dictionary=registered[id]
		if mesh.material_override!=entry.material: entry.original=mesh.material_override
		entry.material=desired
	mesh.set_meta("thermal_source",{"material":registered[id].original})
	# Thermal is an opaque replacement pass, with the same geometry/depth.
	# An overlay rendered the textured/lit model AND its heat silhouette.
	if mesh.material_override!=desired: mesh.material_override=desired
