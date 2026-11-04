extends CharacterBody3D
class_name NavalShip

var kind := "light"
var peer := 0
var identity := ""
var display_name := "Jogador"
var ship_id := ""
var life := 1
var spec: Dictionary = {}
var hp := 100.0
var heading := 0.0
var speed := 0.0
var turn_speed := 0.0
var throttle := 0.0
var steering := 0.0
var aim := Vector3(0,0,-300)
var firing := false
var selected := "lightMG"
var ammo: Dictionary = {}
var waits: Dictionary = {}
var reload_left := 0.0
var reload_weapon := ""
var turrets: Dictionary = {}
var dead := false
var death_time := 0.0
var last_damage_at := -1000.0
var last_change_at := -1000.0
var respawn_at := 0.0
var target_state: Dictionary = {}
var motion:=GameSnapshotMotion.new()
var initialized := false
var latest_input := 0.0
var components := {"engine":100.0,"steering":100.0,"turrets":100.0}

func build(ship_kind: String, owner: int, account: String, nickname: String) -> void:
	kind = ship_kind
	peer = owner
	identity = account
	display_name = nickname
	spec = NavalCatalog.SHIPS[kind]
	ship_id = NavalCatalog.uid()
	name = "Ship_"+str(peer)
	collision_layer = 2
	collision_mask = 3
	NavalGeometry.ship_details(self,kind)
	_navigation_lights()
	var mounts := NavalCatalog.mounts(kind)
	for weapon: String in spec.weapons:
		var turret := NavalTurret.new()
		add_child(turret)
		turret.position = mounts[weapon]
		turret.build(weapon)
		turrets[weapon] = turret
		ammo[weapon] = int(NavalCatalog.WEAPONS[weapon].ammo)
		waits[weapon] = 0.0
	hp = float(spec.hp)
	initialized = true

func _navigation_lights() -> void:
	if DisplayServer.get_name()=="headless": return
	var deck := 1.7 if kind=="submarine" else float(spec.height)*.55
	for marker: Dictionary in [
		{"id":"PortNavigation","point":Vector3(-float(spec.width)*.43,deck+.65,0),"color":Color("dc4b3f")},
		{"id":"StarboardNavigation","point":Vector3(float(spec.width)*.43,deck+.65,0),"color":Color("6ed38b")},
		{"id":"SternNavigation","point":Vector3(0,deck+.65,float(spec.length)*.44),"color":Color("e1e1cc")}]:
		var node := MeshInstance3D.new()
		node.name = marker.id
		var shape := SphereMesh.new()
		shape.radius = .07
		shape.height = .14
		shape.radial_segments = 8
		shape.rings = 4
		node.mesh = shape
		node.position = marker.point
		var material := StandardMaterial3D.new()
		material.albedo_color = marker.color
		material.emission_enabled = true
		material.emission = marker.color
		material.emission_energy_multiplier = 2.3
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)

func simulate(delta: float, time: float) -> void:
	if dead: return
	for weapon in waits: waits[weapon] = maxf(0.0,float(waits[weapon])-delta)
	if reload_left > 0.0:
		reload_left = maxf(0.0,reload_left-delta)
		if reload_left == 0.0:
			ammo[reload_weapon] = int(NavalCatalog.WEAPONS[reload_weapon].ammo)
			reload_weapon = ""
	if time-latest_input > 0.40:
		throttle = 0.0
		steering = 0.0
		firing = false
	var acceleration := float(spec.accel)
	var desired_speed := float(spec.speed)*throttle*(0.30 if throttle < 0.0 else 1.0)
	if throttle == 0.0: acceleration = 0.85+absf(speed)*0.035
	elif speed*throttle < 0.0: acceleration *= 2.1
	speed = move_toward(speed,desired_speed,delta*acceleration)
	var steering_factor := 0.12+0.88*clampf(absf(speed)/maxf(float(spec.speed)*0.55,1.0),0.0,1.0)
	var desired_turn := steering*float(spec.turn)*steering_factor*(1.0 if speed >= 0.0 else -1.0)
	turn_speed = move_toward(turn_speed,desired_turn,delta*float(spec.turn)*1.4)
	heading = wrapf(heading+turn_speed*delta,-PI,PI)
	var forward := Basis(Vector3.UP,heading)*Vector3.FORWARD
	velocity = velocity.lerp(forward*speed,1.0-exp(-delta*1.7))
	velocity.y = 0.0
	var collision := move_and_collide(velocity*delta,false,0.04,true)
	if collision:
		velocity = velocity.slide(collision.get_normal())*0.35
		speed *= 0.35
		turn_speed *= 0.6
	global_position.x = clampf(global_position.x,-NavalCatalog.MAP_LIMIT,NavalCatalog.MAP_LIMIT)
	global_position.z = clampf(global_position.z,-NavalCatalog.MAP_LIMIT,NavalCatalog.MAP_LIMIT)
	global_position.y = NavalCatalog.wave(global_position,time)
	var slope_x := cos(global_position.x*0.025+time*0.85)*0.0055
	var slope_z := cos(global_position.z*0.037-time*0.65)*0.00407
	basis = Basis(Vector3.UP,heading)*Basis.from_euler(Vector3(-slope_z,0,slope_x))
	for turret in turrets.values(): turret.step(aim,velocity,delta)

func start_reload() -> bool:
	if dead or reload_left > 0.0 or int(ammo[selected]) >= int(NavalCatalog.WEAPONS[selected].ammo): return false
	firing = false
	reload_weapon = selected
	reload_left = float(NavalCatalog.WEAPONS[selected].reload)
	return true

func snapshot() -> Dictionary:
	var guns: Dictionary = {}
	for weapon in turrets:
		var turret: NavalTurret = turrets[weapon]
		guns[weapon] = {"yaw":turret.yaw,"pitch":turret.elevation,"valid":turret.reachable,"blocked":turret.blocked}
	return {"peer":peer,"identity":identity,"name":display_name,"id":ship_id,"kind":kind,"life":life,"position":global_position,"rotation":rotation,"heading":heading,"velocity":velocity,"speed":speed,"hp":hp,"ammo":ammo.duplicate(),"selected":selected,"waits":waits.duplicate(),"reload_left":reload_left,"reload_weapon":reload_weapon,"turrets":guns,"dead":dead,"death_time":death_time,"respawn_at":respawn_at,"last_damage_at":last_damage_at,"last_change_at":last_change_at}

func receive(state: Dictionary) -> void:
	var fresh := target_state.is_empty() or str(state.id) != ship_id or int(state.life) != life
	target_state = state
	ship_id = str(state.id)
	life = int(state.life)
	hp = float(state.hp)
	dead = bool(state.dead)
	last_damage_at = float(state.get("last_damage_at",-1000.0))
	last_change_at = float(state.get("last_change_at",-1000.0))
	death_time = float(state.death_time)
	respawn_at = float(state.respawn_at)
	speed = float(state.speed)
	velocity = state.velocity
	ammo = state.ammo.duplicate()
	selected = str(state.selected)
	waits = state.get("waits",{}).duplicate()
	reload_left = float(state.reload_left)
	reload_weapon = str(state.reload_weapon)
	if fresh: motion.clear()
	motion.push(state.position,state.velocity,state.rotation,float(state.get("clock",0)))
	if fresh:
		global_position = state.position
		rotation = state.rotation

func interpolate(delta: float, clock: float) -> void:
	if target_state.is_empty(): return
	global_transform=motion.sample(clock)
	for weapon in turrets:
		if target_state.turrets.has(weapon): turrets[weapon].apply_snapshot(target_state.turrets[weapon],delta)
	if dead:
		var age := maxf(0.0,clock-death_time)
		global_position.y = float(target_state.position.y)-age*0.65
		rotation.z += minf(age*0.025,0.25)
		visible = age < 5.0
	else: visible = true
