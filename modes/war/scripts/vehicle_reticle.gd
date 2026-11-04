extends Control
var manager: WarVehicles
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void: queue_redraw()
func _draw() -> void:
	if not is_instance_valid(manager) or not manager._local_is_operator() or manager.game.ui_focus.blocked(): return
	var vehicle:=manager.find_target(manager._own_id()) as WarVehicle
	if not is_instance_valid(vehicle): return
	if manager._transport(vehicle): return
	if vehicle is WarShip:
		# The infantry dot is under a hidden infantry HUD while aboard.
		draw_circle(size*.5,2,Color("f0f3df"))
		return
	var view:=manager.vehicle_view
	var color:=FieldTheme.ACCENT
	var centre:=size*.5
	var guided:=manager.tv.viewing()
	if not guided and not manager.camera.is_position_behind(view.intent_point):
		var intended:=manager.camera.unproject_position(view.intent_point).clamp(Vector2(22,80),size-Vector2(22,80))
		# Immediate mouse intent, distinct from the physical gun ring.
		draw_polyline(PackedVector2Array([intended+Vector2(0,-10),intended+Vector2(10,0),intended+Vector2(0,10),intended+Vector2(-10,0),intended+Vector2(0,-10)]),Color("edf1de"),1.3,true)
	if guided or not view.external:
		var font:=ThemeDB.fallback_font
		var edge:=Color(.015,.025,.025,.70)
		var margin:=maxf(20,size.x*.024)
		draw_rect(Rect2(0,0,margin,size.y),edge);draw_rect(Rect2(size.x-margin,0,margin,size.y),edge)
		draw_rect(Rect2(margin,0,size.x-margin*2,12),edge);draw_rect(Rect2(margin,size.y-18,size.x-margin*2,18),edge)
		var inset:=Vector2(margin+10,94);var extent:=size-Vector2(margin+10,54)
		for corner in [inset,Vector2(extent.x,inset.y),Vector2(inset.x,extent.y),extent]:
			var xdir:=1 if corner.x<size.x*.5 else -1
			var ydir:=1 if corner.y<size.y*.5 else -1
			draw_line(corner,corner+Vector2(28*xdir,0),color,2,true);draw_line(corner,corner+Vector2(0,23*ydir),color,2,true)
		var label_text: String="TV / LINK ATIVO" if guided else "SENSOR / "+str(vehicle.spec.name).to_upper()
		draw_string(font,inset+Vector2(40,17),label_text,HORIZONTAL_ALIGNMENT_LEFT,-1,16,color)
		var mode_text:="FLIR" if manager.thermal else "EO / DIA"
		if guided:
			var round: Dictionary=manager.game.war_fx.find_round(manager.tv.view_id)
			mode_text="LINK %.1f s / %.0f m"%[float(round.life),float(round.distance)]
		draw_string(font,Vector2(inset.x+40,extent.y-10),mode_text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
		if not guided:
			draw_string(font,Vector2(size.x*.5-65,extent.y-10),"AZ %03d / EL %+.0f°"%[posmod(int(rad_to_deg(vehicle.heading+vehicle.turret_yaw)),360),rad_to_deg(vehicle.gun_pitch)],HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
		else:
			var cue:=manager.camera.global_position+manager.tv.direction()*80
			if not manager.camera.is_position_behind(cue):
				var pointer:=manager.camera.unproject_position(cue).clamp(Vector2(margin+50,110),size-Vector2(margin+50,100))
				draw_arc(pointer,13,0,TAU,28,color,1.5,true)
			draw_string(font,Vector2(size.x*.5-95,extent.y-10),"C / VOLTAR À TORRE",HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	if not guided:
		if manager.camera.is_position_behind(view.barrel_point): return
		var point:=manager.camera.unproject_position(view.barrel_point)
		if Rect2(Vector2.ZERO,size).has_point(point):
			draw_arc(point,6,0,TAU,20,color,1.5,true)
			draw_circle(point,1.5,color)
	if guided or not view.external:
		for axis in [Vector2.RIGHT,Vector2.UP]:
			draw_line(centre+axis*7,centre+axis*44,color,1,true)
			draw_line(centre-axis*7,centre-axis*44,color,1,true)
		for step in range(1,5):
			var p:=centre+Vector2(0,step*18)
			draw_line(p-Vector2(4,0),p+Vector2(4,0),color,1,true)
		draw_circle(centre,1.2,color)
		var font:=ThemeDB.fallback_font
		if not guided: draw_string(font,centre+Vector2(55,24),"%d m"%int(view.barrel_range),HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	if view.damage_pulse>0: draw_rect(Rect2(Vector2.ONE*3,size-Vector2.ONE*6),Color(.9,.16,.10,view.damage_pulse*.65),false,4)
