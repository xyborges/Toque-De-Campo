extends MeshInstance3D
class_name WarShipGuide
var manager: WarVehicles
var clock:=0.0
var geometry:=ImmediateMesh.new()
var launch: Dictionary={}
var predicted_end:=Vector3.ZERO
func _ready() -> void:
	mesh=geometry;cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat:=StandardMaterial3D.new();mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.albedo_color=Color("d6b966");material_override=mat
func _process(delta: float) -> void:
	var ship:=manager.find_target(manager._own_id()) as WarShip
	visible=is_instance_valid(ship) and manager._local_is_operator() and not manager.game.ui_focus.blocked()
	if not visible: return
	clock+=delta
	if clock<1./15: return
	clock=0;update_path(ship)
func update_path(ship: WarShip) -> void:
	material_override.albedo_color=Color("bf6a54") if ship.protected_lane() else Color("d6b966")
	var data: Dictionary=NavalCatalog.WEAPONS[ship.naval_weapon]
	var point:=ship.muzzle.global_position;var velocity: Vector3=-ship.muzzle.global_basis.z.normalized()*float(data.speed)+Vector3(ship.velocity.x,0,ship.velocity.z)
	launch={"origin":point,"velocity":velocity,"weapon":ship.naval_weapon}
	var age:=0.;var travelled:=0.;var duration:=NavalBallistics.duration(velocity.length(),float(data.range),float(data.life),ship.naval_weapon);var step:=duration/128.
	geometry.clear_surfaces();geometry.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	geometry.surface_add_vertex(point)
	for index in 128:
		var next: Vector3=GameBulletPhysics.advance(point,velocity,float(data.gravity),NavalBallistics.drag_for(ship.naval_weapon),step).position
		var next_velocity: Vector3=GameBulletPhysics.advance(point,velocity,float(data.gravity),NavalBallistics.drag_for(ship.naval_weapon),step).velocity
		if ship.naval_weapon=="torpedo": next.y=WarCoast.wave(next,manager.game.war_clock+age+step)-.15
		var query:=PhysicsRayQueryParameters3D.create(point,next,CombatRules.SHOT_MASK,manager.owner_excludes(ship.driver));query.collide_with_areas=true
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		var stopped:=not hit.is_empty()
		if stopped: next=hit.position
		elif ship.naval_weapon!="torpedo" and next.y<=WarCoast.wave(next,manager.game.war_clock+age+step) and WarCoast.wet(next.x,next.z):
			var fraction:=clampf((point.y-WarCoast.wave(point,manager.game.war_clock+age))/maxf(.001,point.y-next.y),0,1);next=point.lerp(next,fraction);stopped=true
		geometry.surface_add_vertex(next);travelled+=point.distance_to(next);point=next;velocity=next_velocity;age+=step
		if stopped or travelled>=float(data.range): break
	geometry.surface_end();predicted_end=point
