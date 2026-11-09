extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
const OUT="res://work/realismo-r1a-g3"

var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func response_trace(start_speed: float,end_speed: float,frames: int) -> Array[Dictionary]:
	var probe:=WarLocomotion.new()
	probe.tactical_motion_pilot=true
	probe.presentation_longitudinal=0.
	var rows: Array[Dictionary]=[]
	var previous_speed:=start_speed
	for frame in frames:
		var current_speed:=end_speed
		probe._advance_presentation(previous_speed,current_speed,1.0/60.0,WarRules.WALK_SPEED)
		rows.append({
			"frame":frame,
			"time_ms":snappedf((frame+1)*1000.0/60.0,.01),
			"speed":current_speed,
			"weight":probe.presentation_longitudinal,
			"travel_mm":probe.presentation_longitudinal*WarLocomotion.PRESENTATION_FPP_TRAVEL*1000.0
		})
		previous_speed=current_speed
	return rows

func peak_weight(rows: Array[Dictionary]) -> float:
	var value:=0.
	for row in rows:
		if absf(float(row.weight))>absf(value): value=float(row.weight)
	return value

func settle_ms(rows: Array[Dictionary],threshold_mm:=.5) -> float:
	for row in rows:
		if int(row.frame)>0 and absf(float(row.travel_mm))<=threshold_mm:
			return float(row.time_ms)
	return -1.

func capture(actor: WarPlayer,label: String,weight: float) -> Dictionary:
	actor.locomotion.tactical_motion_pilot=true
	actor.locomotion.presentation_longitudinal=weight
	actor.locomotion.moving=1.
	actor.locomotion.sprint=0.
	actor.locomotion.phase=0.
	actor.aiming=false
	actor.iron_sights=false
	actor.reload_left=0.
	actor.fire_cooldown=0.
	actor._update_view()
	actor._update_weapon_pose()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var pos:=actor.view_root.position
	var path:=OUT+"/"+label+".png"
	var saved:=root.get_texture().get_image().save_png(path)
	return {
		"label":label,
		"weight":weight,
		"view_position":str(pos),
		"view_z":pos.z,
		"world_z":actor.weapon_root.position.z,
		"saved":saved,
		"file":path
	}

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("R1A G3 calibration requires rendered mode")
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var accel:=response_trace(0.,WarRules.WALK_SPEED,18)
	var brake:=response_trace(WarRules.WALK_SPEED,0.,18)
	var accel_peak:=peak_weight(accel)
	var brake_peak:=peak_weight(brake)
	var accel_peak_mm:=accel_peak*WarLocomotion.PRESENTATION_FPP_TRAVEL*1000.
	var brake_peak_mm:=brake_peak*WarLocomotion.PRESENTATION_FPP_TRAVEL*1000.

	var game:=FIXTURE.new() as WarGame
	root.add_child(game)
	await process_frame
	var actor:=game.local_player as WarPlayer
	actor.weapon_id="g3"
	actor.owned=["g3","glock"]
	actor.loadout=actor.owned.duplicate()
	actor.set_meta("weapon_optics",{})
	actor._refresh_weapon()
	actor.set_process(false)
	actor.set_physics_process(false)
	game.third_person=false
	actor.camera.make_current()
	game.hud_layer.hide()
	game.menu_layer.hide()

	var captures: Array[Dictionary]=[]
	captures.append(await capture(actor,"neutral",0.))
	captures.append(await capture(actor,"accel",accel_peak))
	captures.append(await capture(actor,"brake",brake_peak))

	var neutral_view_z:=float(captures[0].view_z)
	var accel_visual_mm:=(float(captures[1].view_z)-neutral_view_z)*1000.
	var brake_visual_mm:=(float(captures[2].view_z)-neutral_view_z)*1000.
	var world_max:=maxf(float(captures[0].world_z),maxf(float(captures[1].world_z),float(captures[2].world_z)))
	var world_min:=minf(float(captures[0].world_z),minf(float(captures[1].world_z),float(captures[2].world_z)))
	var world_span_mm:=(world_max-world_min)*1000.

	check(accel_peak>0.,"0->walk produces positive visual inertia")
	check(brake_peak<0.,"walk->0 produces negative visual inertia")
	check(accel_peak_mm>=8. and accel_peak_mm<=14.,"acceleration peak stays in the calibrated 8-14 mm window")
	check(absf(brake_peak_mm)>=8. and absf(brake_peak_mm)<=14.,"braking peak stays in the calibrated 8-14 mm window")
	check(settle_ms(accel)>=100. and settle_ms(accel)<=180.,"acceleration settles in the calibrated 100-180 ms window")
	check(settle_ms(brake)>=100. and settle_ms(brake)<=180.,"braking settles in the calibrated 100-180 ms window")
	check(absf(accel_visual_mm-accel_peak_mm)<.15,"rendered G3 acceleration offset matches locomotion state")
	check(absf(brake_visual_mm-brake_peak_mm)<.15,"rendered G3 braking offset matches locomotion state")
	check(world_span_mm<.01,"calibration keeps authoritative G3 path untouched")

	var report:={
		"walk_speed_mps":WarRules.WALK_SPEED,
		"travel_limit_mm":WarLocomotion.PRESENTATION_FPP_TRAVEL*1000.,
		"accel_peak_weight":accel_peak,
		"accel_peak_mm":accel_peak_mm,
		"accel_settle_ms_0_5mm":settle_ms(accel),
		"brake_peak_weight":brake_peak,
		"brake_peak_mm":brake_peak_mm,
		"brake_settle_ms_0_5mm":settle_ms(brake),
		"world_weapon_span_mm":world_span_mm,
		"accel_trace":accel,
		"brake_trace":brake,
		"captures":captures,
		"failures":failures
	}
	var out:=FileAccess.open(OUT+"/calibration.json",FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(report,"\t"))
		out.close()
	print("REALISMO_R1A_G3 ",JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)