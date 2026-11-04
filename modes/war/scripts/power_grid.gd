extends Node3D
class_name WarPowerGrid
const MAX_LIGHTS:=10
var game: WarGame
var poles: Dictionary={}
var circuits: Array[Dictionary]=[]
var wires: Array[Dictionary]=[]
var falling: Array[String]=[]
var wire_material:=StandardMaterial3D.new()
var clock:=0.0
var scan_clock:=0.0
func _ready() -> void:
	name="PowerGrid";wire_material.albedo_color=Color("171e1b")
	for index in WarRoads.ROUTES.size():
		var route: Array=WarRoads.rounded(WarRoads.ROUTES[index]);var ids: Array[String]=[]
		for part in route.size()-1:
			var a: Vector2=route[part];var b: Vector2=route[part+1];var direction: Vector2=(b-a).normalized();var side:=Vector2(-direction.y,direction.x)*8
			var count:=maxi(1,int(a.distance_to(b)/72))
			for i in count:
				var point:=WarRoads.roadside(a.lerp(b,(i+.25)/count)+side,12.)
				if WarTerrain.height_at(point.x,point.y)<2: continue
				var close:=false
				for pole: WarPowerPole in poles.values():
					if Vector2(pole.position.x,pole.position.z).distance_to(point)<24: close=true;break
				if close: continue
				ids.append(add_pole("road_%d_%d_%d"%[index,part,i],WarTerrain.point(point.x,point.y),i%8!=5))
		circuits.append({"ids":ids,"powered":index!=3})
		connect_wires(ids)
	for team in 2:
		var ids: Array[String]=[]
		for i in 5:
			var at: Vector3=WarCoast.PORTS[team]+Vector3(-30,0,-92+i*44)
			var verge:=WarRoads.roadside(Vector2(at.x,at.z),12.)
			ids.append(add_pole("port_%d_%d"%[team,i],WarTerrain.point(verge.x,verge.y),i!=2))
		circuits.append({"ids":ids,"powered":true});connect_wires(ids)
	recompute()
func add_pole(id: String,point: Vector3,functional: bool) -> String:
	var pole:=WarPowerPole.new();pole.name=id;pole.pole_id=id;pole.position=point;pole.functional=functional;add_child(pole);poles[id]=pole;return id
func connect_wires(ids: Array[String]) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in ids.size()-1:
		var line:=MeshInstance3D.new();line.mesh=ImmediateMesh.new();line.material_override=wire_material;line.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;line.visibility_range_end=280;add_child(line)
		var wire: Dictionary={"a":ids[i],"b":ids[i+1],"node":line};wires.append(wire);update_wire(wire)
func update_wire(wire: Dictionary) -> void:
	var a: WarPowerPole=poles[wire.a];var b: WarPowerPole=poles[wire.b]
	var from:=a.attachment();var to:=b.attachment()
	var mesh:=wire.node.mesh as ImmediateMesh;mesh.clear_surfaces();mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for i in 17:
		var t:=i/16.0;var p:=from.lerp(to,t);p.y-=sin(t*PI)*(3.0 if a.broken or b.broken else 1.4)
		var floor_y:=WarTerrain.height_at(p.x,p.z)+.12
		for port: Vector3 in WarCoast.PORTS:
			if absf(p.x-port.x)<41 and absf(p.z-port.z)<115: floor_y=maxf(floor_y,port.y+.08)
		p.y=maxf(p.y,floor_y);mesh.surface_add_vertex(p)
	mesh.surface_end()
func recompute() -> void:
	for circuit in circuits:
		var connected: bool=circuit.powered
		for id: String in circuit.ids:
			var pole: WarPowerPole=poles[id]
			connected=connected and not pole.broken;pole.energized=connected
			if not connected: pole.set_lit(false)
func hit(collider: Object,amount: float,direction: Vector3) -> bool:
	if not is_instance_valid(collider) or not collider.has_meta("war_pole"): return false
	if not game.multiplayer.is_server(): return true
	var pole:=poles.get(str(collider.get_meta("war_pole"))) as WarPowerPole
	if pole and pole.damage(amount,direction,game.war_clock): broken(pole)
	return true
func blast(point: Vector3,amount: float,radius: float) -> void:
	if not game.multiplayer.is_server(): return
	for pole: WarPowerPole in poles.values():
		if pole.broken: continue
		var target:=pole.global_position+Vector3.UP*3
		var d:=point.distance_to(target)
		if d>=radius: continue
		var ray:=PhysicsRayQueryParameters3D.create(point+Vector3.UP*.15,target,1,[pole.get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		if pole.damage(amount*(1-d/radius),target-point,game.war_clock): broken(pole)
func broken(pole: WarPowerPole) -> void:
	falling.append(pole.pole_id);recompute()
	if game.online: game._broadcast("war_pole_broken",[pole.pole_id,pole.broken_at,pole.fall_yaw])
func receive(id: String,at: float,yaw: float) -> void:
	var pole:=poles.get(id) as WarPowerPole
	if not pole or pole.broken: return
	pole.apply_break(at,yaw);pole.animate(game.war_clock);falling.append(id);recompute()
func snapshot() -> Array:
	var result: Array=[]
	for pole: WarPowerPole in poles.values():
		if pole.broken: result.append([pole.pole_id,pole.broken_at,pole.fall_yaw])
	return result
func _process(delta: float) -> void:
	if not is_instance_valid(game): return
	clock=game.war_clock
	if not falling.is_empty():
		var changed:=falling.duplicate()
		for id: String in changed:
			if not poles[id].animate(clock): falling.erase(id)
		for wire in wires:
			if wire.a in changed or wire.b in changed: update_wire(wire)
	if DisplayServer.get_name()=="headless": return
	scan_clock+=delta
	if scan_clock<.25: return
	scan_clock=0
	var camera:=get_viewport().get_camera_3d()
	if not is_instance_valid(camera): return
	var night: bool=float(GameDayNight.sample(clock).daylight)<.3
	var nearby: Array[WarPowerPole]=[]
	for pole: WarPowerPole in poles.values():
		if night and pole.energized and pole.functional and not pole.broken and pole.global_position.distance_squared_to(camera.global_position)<10000: nearby.append(pole)
	nearby.sort_custom(func(a,b):return a.global_position.distance_squared_to(camera.global_position)<b.global_position.distance_squared_to(camera.global_position))
	var selected: Dictionary={}
	for i in mini(MAX_LIGHTS,nearby.size()): selected[nearby[i].pole_id]=true
	for pole: WarPowerPole in poles.values(): pole.set_lit(selected.has(pole.pole_id))
