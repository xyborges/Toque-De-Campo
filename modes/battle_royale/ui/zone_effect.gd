extends Node3D
class_name BRZoneEffect

const REACH:=105.
const SEGMENTS:=48
var game: Node3D
var edge: MeshInstance3D
var clock:=0.
var material: ShaderMaterial

func _ready() -> void:
	name="ZoneBoundary"
	if DisplayServer.get_name()=="headless":set_process(false);return
	edge=MeshInstance3D.new();edge.name="NearbyEdge";edge.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material=ShaderMaterial.new();material.shader=preload("res://modes/battle_royale/ui/zone_edge.gdshader")
	edge.material_override=material;edge.layers=1;add_child(edge);edge.hide()

func _process(delta: float) -> void:
	if not is_instance_valid(game) or not is_instance_valid(edge):return
	clock+=delta
	if clock<.1:return
	clock=0.
	if game.phase!="active" or not is_instance_valid(game.local_player) or game.local_player.hp<=0:
		edge.hide();return
	var zone:=BRZone.sample_snapshot(game.zone_parameters,Time.get_ticks_msec()*.001+game.server_time_offset)
	var center: Vector2=zone.get("center",Vector2.ZERO);var radius:=float(zone.get("radius",1500.))
	var viewer: Vector3=game.local_player.global_position
	var radial:=Vector2(viewer.x,viewer.z)-center
	if radius<.1 or absf(radial.length()-radius)>REACH:edge.hide();return
	var mid:=atan2(radial.y,radial.x)
	var arc:=PI if radius<REACH*.5 else minf(PI,REACH/radius*1.3)
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in SEGMENTS:
		var a:=mid-arc+2.*arc*float(index)/SEGMENTS
		var b:=mid-arc+2.*arc*float(index+1)/SEGMENTS
		var start:=center+Vector2(cos(a),sin(a))*radius;var finish:=center+Vector2(cos(b),sin(b))*radius
		var low_a:=Vector3(start.x,BRAfghanMap.height_at(start.x,start.y)-.4,start.y)
		var low_b:=Vector3(finish.x,BRAfghanMap.height_at(finish.x,finish.y)-.4,finish.y)
		var high_a:=low_a+Vector3.UP*13.;var high_b:=low_b+Vector3.UP*13.
		for point in [[low_a,Vector2(0,0)],[high_a,Vector2(0,1)],[low_b,Vector2(1,0)],[low_b,Vector2(1,0)],[high_a,Vector2(0,1)],[high_b,Vector2(1,1)]]:
			surface.set_uv(point[1]);surface.add_vertex(point[0])
	edge.mesh=surface.commit();material.set_shader_parameter("viewer_position",viewer);edge.show()
