extends Node3D
class_name GameDamageNumbers

const LIMIT:=48
var active: Array[Dictionary]=[]
var available: Array[Label3D]=[]
var seen: Dictionary={}

func show_damage(event_id: String,point: Vector3,amount: float,critical:=false,naval:=false) -> void:
	if not GameOptions.flag("damage_text"): return
	if not point.is_finite() or not is_finite(amount) or amount<=0 or seen.has(event_id): return
	seen[event_id]=true
	if seen.size()>256: seen.erase(seen.keys()[0])
	var label: Label3D
	if not available.is_empty(): label=available.pop_back()
	elif active.size()<LIMIT:
		label=Label3D.new()
		label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		label.font_size=18
		label.outline_size=4
		label.fixed_size=false
		label.pixel_size=.01
		label.no_depth_test=false
		label.shaded=false
		add_child(label)
	else:
		var old: Dictionary=active.pop_front()
		label=old.label
	label.text=str(maxi(1,roundi(amount)))+("!" if critical else "")
	label.modulate=Color("ef4141")
	label.outline_modulate=Color(.02,.04,.04,.9)
	label.global_position=point+Vector3.UP*(2 if naval else .24)
	label.show()
	var camera:=get_viewport().get_camera_3d()
	if is_instance_valid(camera): _scale_label(label,camera,maxf(1,get_viewport().get_visible_rect().size.y),absf(camera.get_camera_projection().y.y))
	active.append({"label":label,"origin":label.global_position,"left":.95,"naval":naval,"amount":amount})

func _process(delta: float) -> void:
	var camera:=get_viewport().get_camera_3d()
	var projection_y:=absf(camera.get_camera_projection().y.y) if is_instance_valid(camera) else 1.0
	var viewport_height:=maxf(1,get_viewport().get_visible_rect().size.y)
	for i in range(active.size()-1,-1,-1):
		var item: Dictionary=active[i]
		item.left-=delta
		if item.left<=0:
			item.label.hide();available.append(item.label);active.remove_at(i)
		else:
			item.label.global_position=item.origin+Vector3.UP*(1-item.left/.95)*(.6 if not item.naval else 2.5)
			item.label.modulate.a=minf(1,item.left/.25)
			if is_instance_valid(camera):
				_scale_label(item.label,camera,viewport_height,projection_y)

func _scale_label(label: Label3D,camera: Camera3D,height: float,projection_y: float) -> void:
	var depth:=camera.global_basis.z.dot(camera.global_position-label.global_position)
	label.visible=depth>camera.near
	label.scale=Vector3.ONE*maxf(.001,2*maxf(.01,depth)/(height*maxf(.01,projection_y)*label.pixel_size))
