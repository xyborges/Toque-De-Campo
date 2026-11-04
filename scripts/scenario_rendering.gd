extends Node

# One controller per visual world; all resources and instance pools already
# exist. Optical focus only changes paired HLOD thresholds, never physics.
const DISTANCES:=[250,400,650,900]
const PIXELS:=[4.,2.,1.]
const BUDGET:=24
var world: Node
var distance:=400.
var quality:=1
var pairs: Array[Dictionary]=[]
var cursor:=0
var stable_direction:=Vector3.ZERO
var stable_since:=0.
var focused_position:=Vector3.ZERO
var focus_active:=false
var focus_clock:=0.
var switches:=0

func configure(target: Node,metres: float,lod: int) -> void:
	world=target;distance=clampf(metres,250.,900.);quality=clampi(lod,0,2);pairs.clear();cursor=0
	for node: GeometryInstance3D in get_tree().get_nodes_in_group("scenario_rendering"):
		if not world.is_ancestor_of(node):continue
		if node.has_meta("scenario_near_nodes"):
			if bool(node.get_meta("scenario_optional",false)):node.visibility_range_end=distance
			var baseline:=minf(distance,float(node.get_meta("scenario_lod",85.))*[.7,1.,1.3][quality])
			var record: Dictionary={"low":weakref(node),"near":node.get_meta("scenario_near_nodes"),"base":baseline,"until":0.,"focused":false}
			pairs.append(record);_range(record,baseline)
		elif node.get_meta("scenario_optional",false):
			var original:=float(node.get_meta("scenario_end",400.))
			var limit:=minf(distance,original*distance/400.) if original>0 else distance
			node.visibility_range_end=limit
			pairs.append({"low":weakref(node),"near":[],"base":limit,"until":0.,"focused":false,"detail_only":true})
	set_process(not pairs.is_empty())

func _range(record: Dictionary,metres: float) -> void:
	var low: GeometryInstance3D=record.low.get_ref()
	if not is_instance_valid(low):return
	if bool(record.get("detail_only",false)):low.visibility_range_end=metres;return
	# Near and distant meshes use exactly the same bounds/distance centre.
	low.visibility_range_begin=metres
	for ref: WeakRef in record.near:
		var node: GeometryInstance3D=ref.get_ref()
		if is_instance_valid(node):node.visibility_range_end=metres

func _process(delta: float) -> void:
	if not is_instance_valid(world):set_process(false);return
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera):return
	var game:=world.get_parent();var actor: Variant=game.get("local_player") if game else null
	var optical:=camera.fov<42.
	if is_instance_valid(actor) and actor.get("weapon_optics")!=null:
		var optics: RefCounted=actor.weapon_optics
		if optics.active and is_instance_valid(optics.camera):camera=optics.camera;optical=true
	update_focus(camera,optical,delta)

func update_focus(camera: Camera3D,optical: bool,delta: float) -> void:
	focus_clock+=delta
	var direction: Vector3=-camera.global_basis.z
	if not optical or stable_direction.dot(direction)<.997:
		stable_direction=direction;stable_since=focus_clock
	focus_active=optical and focus_clock-stable_since>=.12
	focused_position=camera.global_position+direction*distance
	# A fixed amount of metadata/threshold work per frame. No ray queries,
	# resource loads, new meshes, node creation or scene-tree scans here.
	for step in mini(BUDGET,pairs.size()):
		var record: Dictionary=pairs[cursor%pairs.size()];cursor+=1
		var low: GeometryInstance3D=record.low.get_ref()
		if not is_instance_valid(low):continue
		var local_bounds: AABB=low.custom_aabb if low.custom_aabb.size!=Vector3.ZERO else low.get_aabb()
		var bounds: AABB=low.global_transform*local_bounds
		var offset:=bounds.get_center()-camera.global_position;var radius:=bounds.size.length()*.5
		var along:=offset.dot(direction);var lateral:=(offset-direction*along).length()
		var cone:=tan(deg_to_rad(minf(50.,camera.fov*.5+4.)))
		if focus_active and along+radius>0 and along-radius<=distance and lateral<=radius+along*cone:record.until=focus_clock+.55
		var focused:=optical and focus_clock<float(record.until)
		if focused!=bool(record.focused):record.focused=focused;_range(record,distance if focused else float(record.base));switches+=1

func diagnostics() -> Dictionary:
	return {"distance":distance,"lod":quality,"pairs":pairs.size(),"focus":focus_active,"switches":switches,"budget":BUDGET}
