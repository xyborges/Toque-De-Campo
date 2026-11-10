extends RefCounted
## Experimental visual policy for Favela V2 only. No physics or spawn changes.
## Ported conservatively from the 32m candidate of 05296b8.
const CELL_METERS:=32.0
const OCCLUDER_INSET:=0.24
const DETAIL_LOD_METERS:=130.0
const WINDOW_LOD_METERS:=120.0
const SMALL_PROP_LOD_METERS:=180.0

static func enabled_by_command_line()->bool:
	return OS.get_cmdline_user_args().has("--favela-v2-occlusion-pilot")

static func _houses(root: Node3D)->Array[Node3D]:
	var homes:Array[Node3D]=[]
	for container_path in ["CasasAoLongoDaSubida",
		"FavelaV2MorroEsquerdo/ResidenciasEscalonadas"]:
		var container:=root.get_node_or_null(container_path)
		if container==null:continue
		for child:Node in container.get_children():
			if child is Node3D:
				homes.append(child as Node3D)
	return homes

static func _lod(house: Node3D)->int:
	var count:=0
	# House body and roof are real line-of-sight cover; retain both up to
	# the original mesh's far range. Only the details are aggressively LODed.
	for name in ["Janela","CaixaAgua"]:
		var part:=house.get_node_or_null(name)
		if part is GeometryInstance3D:
			(part as GeometryInstance3D).visibility_range_end=WINDOW_LOD_METERS if name=="Janela" else SMALL_PROP_LOD_METERS
			count+=1
	for node:Node in house.get_children():
		if not node.name.begins_with("Reuso_"):continue
		for visual:Node in node.find_children("*","GeometryInstance3D",true,false):
			var geo:=visual as GeometryInstance3D
			geo.visibility_range_end=minf(float(geo.visibility_range_end),DETAIL_LOD_METERS) if geo.visibility_range_end>0 else DETAIL_LOD_METERS
			geo.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			count+=1
	return count

static func _occluder(house: Node3D)->OccluderInstance3D:
	var structure:=house.get_node_or_null("Body") as StaticBody3D
	if structure==null or structure.collision_layer & 1==0:return null
	var shape:=structure.get_node_or_null("Collision") as CollisionShape3D
	if shape==null or not shape.shape is BoxShape3D:return null
	var block:=shape.shape as BoxShape3D
	if block.size.y<2.0 or minf(block.size.x,block.size.z)<3.0:return null
	var occluder:=OccluderInstance3D.new()
	occluder.name="FavelaV2OclusaoCasas32m"
	var box:=BoxOccluder3D.new()
	box.size=block.size-Vector3.ONE*OCCLUDER_INSET
	occluder.occluder=box
	occluder.transform=shape.transform
	occluder.set_meta("source_collider","FavelaV2CasaSolida")
	occluder.set_meta("experimental_cell_m",CELL_METERS)
	# Children inherit the original building's scale/rotation/position.
	# No extra StaticBody3D, no duplicate collisions or navigation changes.
	house.add_child(occluder)
	return occluder

static func apply(map_root: Node3D,visuals: bool,enable_occlusion: bool)->Dictionary:
	var outcome:Dictionary={"houses":0,"lod_details":0,"occluders":0,
		"enabled":visuals and enable_occlusion,"cell_m":CELL_METERS}
	if not visuals:return outcome
	var cells:Dictionary={}
	for house:Node3D in _houses(map_root):
		outcome.houses=int(outcome.houses)+1
		outcome.lod_details=int(outcome.lod_details)+_lod(house)
		if not enable_occlusion:continue
		var global_at:Vector3=house.global_position
		var cell:=Vector2i(floori(global_at.x/CELL_METERS),floori(global_at.z/CELL_METERS))
		if cells.has(cell):continue
		var occluder:=_occluder(house)
		if occluder==null:continue
		cells[cell]=true
		outcome.occluders=int(outcome.occluders)+1
	return outcome
