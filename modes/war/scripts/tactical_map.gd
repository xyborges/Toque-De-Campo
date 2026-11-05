extends Control
class_name WarTacticalMap

signal spawn_chosen(id: String)
var game: WarGame
var compact:=false
var selectable:=false
var team:=0
var selected_spawn:="base"
var clock:=0.0
var terrain_texture: Texture2D
var territory_texture: ImageTexture
var signature:=""
var owners: Dictionary={}
var region: Rect2
const RES:=144
# Each tactical map belongs to one operation; static global buffers kept
# showing Ukraine roads/coast and invalid ownership cells in Afghanistan.
var ground: Texture2D
var sectors:=PackedInt32Array()
var land:=PackedByteArray()
var keys: Array=[]
var territory_cache: Dictionary={}
var road_paths: Array=[]

func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_STOP if selectable else Control.MOUSE_FILTER_IGNORE
	clip_contents=true
	custom_minimum_size=Vector2(190,190) if compact else Vector2(420,370)
	_prepare()
	terrain_texture=ground
	refresh()

func _prepare() -> void:
	if ground!=null: return
	keys=WarRules.OBJECTIVES.keys()
	if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:
		for route: Dictionary in BRAfghanMap.LAND.roads():
			var line: Array=[]
			for location: Vector3 in route.points:line.append(Vector2(location.x,location.z))
			if line.size()>1:road_paths.append(line)
	elif WarRules.CURRENT_OPERATION==WarOperation.FAVELA:
		road_paths.append(WarFavelaMap.PRIMARY)
		for street_z in WarFavelaMap.CROSS_STREETS:
			road_paths.append([Vector2(-640,street_z),Vector2(640,street_z)])
		for street_x in WarFavelaMap.VERTICAL_STREETS:
			road_paths.append([Vector2(street_x,-550),Vector2(street_x,500)])
		road_paths.append_array(WarFavelaMap.MINI_STREETS)
	else:
		for route: Array in WarRoads.ROUTES: road_paths.append(WarRoads.rounded(route))
	var points: Array[Vector2]=[]
	for id in keys:
		var p: Vector3=WarRules.OBJECTIVES[id].position;points.append(Vector2(p.x,p.z))
	for p: Vector3 in WarRules.BASES: points.append(Vector2(p.x,p.z))
	var image:=Image.create(RES,RES,false,Image.FORMAT_RGBA8)
	sectors.resize(RES*RES);land.resize(RES*RES)
	for y in RES:
		for x in RES:
			var p:=(Vector2(x+.5,y+.5)/RES*2-Vector2.ONE)*WarTerrain.HALF
			var dry:=true if WarRules.CURRENT_OPERATION==WarOperation.FAVELA else (absf(p.x-BRAfghanMap.LAND.stream_center(p.y))>4. if WarRules.CURRENT_OPERATION==WarOperation.AFGHAN else WarCoast.inland(p.x,p.y)>2)
			land[y*RES+x]=1 if dry else 0
			var nearest:=-1;var best:=INF
			for i in points.size():
				var d:=p.distance_squared_to(points[i])
				if d<best: best=d;nearest=i
			sectors[y*RES+x]=nearest
			var c:=Color("172c32")
			if dry:
				if WarRules.CURRENT_OPERATION==WarOperation.FAVELA:
					var height:=WarFavelaMap.height_at(p.x,p.y)
					var distance:=WarFavelaMap.road_distance(p)
					if p.y< -570.0:c=Color("43674a").lightened(clampf((height-80.0)*.001,-.1,.10))
					elif p.y>505.0:c=Color("898477")
					elif distance<9.0:c=Color("52585a")
					else:c=Color("a48d80").lightened(clampf((height-50.0)*.0005,-.07,.07))
				elif WarRules.CURRENT_OPERATION==WarOperation.AFGHAN:
					var height:=BRAfghanMap.height_at(p.x,p.y)
					c=Color("85775c").lightened(clampf((height-10.)*.002,-.05,.1))
				else:
					var height:=WarTerrain._landform(p.x,p.y)
					c=Color("465047").lightened(clampf((height-18)*.003,-.06,.10))
			image.set_pixel(x,y,c)
	ground=load("res://scripts/maps/definition.gd").cartography(WarRules.map_content())
	if ground==null:ground=ImageTexture.create_from_image(image)

func refresh() -> void:
	if not is_instance_valid(game) or ground==null: return
	var next:="%d:"%team
	for id in keys:
		var state: Dictionary=game.objective_states.get(id,{})
		# Territory pixels depend on ownership/contestation, not the capture
		# percentage drawn by the marker. Avoid reallocating/uploading 20k
		# pixels for every 10% tick of an otherwise identical coloured region.
		var capturing:=int(state.get("side",-1))>=0 and float(state.get("progress",0))>0
		next+="%s/%s/%s;"%[state.get("owner",-1),state.get("contested",false),capturing]
	if next!=signature:
		signature=next
		if territory_cache.has(signature): territory_texture=territory_cache[signature];queue_redraw();return
		var image:=Image.create(RES,RES,false,Image.FORMAT_RGBA8)
		for y in RES:
			for x in RES:
				var index:=y*RES+x;var c:=Color.TRANSPARENT
				if land[index]:
					var sector:=sectors[index]
					var state: Dictionary=game.objective_states.get(keys[sector],{}) if sector<keys.size() else {"owner":sector-keys.size()}
					var owner:=int(state.get("owner",-1))
					if owner>=0: c=FieldTheme.ACCENT if owner==team else FieldTheme.BAD;c.a=.23
					if bool(state.get("contested",false)) or int(state.get("side",-1))>=0 and float(state.get("progress",0))>0: c=Color(.85,.64,.25,.33)
				image.set_pixel(x,y,c)
		territory_texture=ImageTexture.create_from_image(image)
		territory_cache[signature]=territory_texture
		if territory_cache.size()>8: territory_cache.erase(territory_cache.keys()[0])
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	clock+=delta
	if clock<.1: return
	clock=0
	if compact and is_instance_valid(game.local_player): team=game.local_player.war_team
	refresh()

func view_bounds() -> Rect2:
	if compact and is_instance_valid(game.local_player):
		var p: Vector3=game.local_player.global_position
		return Rect2(Vector2(p.x,p.z)-Vector2.ONE*330,Vector2.ONE*660)
	return Rect2(-Vector2.ONE*WarTerrain.HALF,Vector2.ONE*WarTerrain.HALF*2)

func map_rect() -> Rect2:
	var extent:=minf(size.x-16,size.y-16)
	return Rect2((size-Vector2.ONE*extent)*.5,Vector2.ONE*extent)

func project(point: Vector3) -> Vector2:
	return region.position+(Vector2(point.x,point.z)-view_bounds().position)/view_bounds().size*region.size

func valid_spawn(id: String) -> bool:
	return id=="base" or game._valid_deployment_spawn(team,id)

func _gui_input(event: InputEvent) -> void:
	if not selectable or not event is InputEventMouseButton or not event.pressed or event.button_index!=MOUSE_BUTTON_LEFT: return
	var best:=24.;var chosen:=""
	for id in ["base"]+keys:
		if not valid_spawn(id): continue
		var p: Vector3=WarRules.BASES[clampi(team,0,1)] if id=="base" else WarRules.OBJECTIVES[id].position
		var d: float=event.position.distance_to(project(p))
		if d<best: best=d;chosen=id
	if not chosen.is_empty(): selected_spawn=chosen;spawn_chosen.emit(chosen);queue_redraw();accept_event()

func _draw() -> void:
	if ground==null or not is_instance_valid(game): return
	region=map_rect()
	draw_style_box(FieldTheme.box(FieldTheme.BASE,FieldTheme.BORDER,8),Rect2(Vector2.ZERO,size))
	var bounds:=view_bounds()
	# Prepared cartography and territory overlay have different resolutions.
	# Sampling both with RES cropped most of the 1024px authored map and
	# displaced the capture markers relative to the ground image.
	var normalized_origin: Vector2=(bounds.position+Vector2.ONE*WarTerrain.HALF)/(WarTerrain.HALF*2)
	var normalized_size: Vector2=bounds.size/(WarTerrain.HALF*2)
	var ground_size: Vector2=ground.get_size()
	draw_texture_rect_region(ground,region,Rect2(normalized_origin*ground_size,normalized_size*ground_size))
	if territory_texture: draw_texture_rect_region(territory_texture,region,Rect2(normalized_origin*Vector2.ONE*RES,normalized_size*Vector2.ONE*RES))
	var font:=get_theme_default_font()
	for route: Array in road_paths:
		for i in route.size()-1:
			var a:=project(Vector3(route[i].x,0,route[i].y));var b:=project(Vector3(route[i+1].x,0,route[i+1].y))
			if region.intersects(Rect2(a,Vector2.ONE).expand(b)): draw_line(a,b,Color(.70,.70,.59,.36),1,true)
	for id in keys:
		var p:=project(WarRules.OBJECTIVES[id].position)
		if not region.grow(-12).has_point(p): continue
		var state: Dictionary=game.objective_states.get(id,{})
		var owner:=int(state.get("owner",-1))
		var color:=FieldTheme.ACCENT if owner==team else (FieldTheme.BAD if owner>=0 else FieldTheme.INK)
		draw_circle(p,10,Color("101b1d"));draw_arc(p,10,0,TAU,20,color,1.5,true)
		draw_string(font,p+Vector2(-4,5),id,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
		if selectable and id==selected_spawn: draw_arc(p,15,0,TAU,24,FieldTheme.INK,2,true)
	for side in 2:
		var p:=project(WarRules.BASES[side])
		if region.grow(-12).has_point(p):
			var color:=FieldTheme.ACCENT if side==team else FieldTheme.BAD
			draw_rect(Rect2(p-Vector2.ONE*7,Vector2.ONE*14),color,false,2)
			if selectable and side==team and selected_spawn=="base": draw_arc(p,14,0,TAU,24,FieldTheme.INK,2,true)
	for id in game.members:
		var actor:=game.players.get(id) as WarPlayer
		if not is_instance_valid(actor) or actor.hp<=0 or not actor.deployed or actor.war_team!=team: continue
		var p:=project(actor.global_position)
		if not region.grow(-8).has_point(p): continue
		var color:=FieldTheme.INK if actor==game.local_player else FieldTheme.ACCENT
		var forward:=Vector2(-sin(actor.yaw),-cos(actor.yaw));var side:=Vector2(-forward.y,forward.x)
		draw_colored_polygon(PackedVector2Array([p+forward*8,p-forward*5+side*4,p-forward*5-side*4]),color)
	draw_string(font,region.position+Vector2(7,17),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,12,FieldTheme.INK)
