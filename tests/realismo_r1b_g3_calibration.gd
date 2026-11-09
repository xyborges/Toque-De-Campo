extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
const OUT="res://work/realismo-r1b-g3"

var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func trace_strafe(direction: float) -> Array[Dictionary]:
	var probe:=WarLocomotion.new()
	probe.tactical_motion_pilot=true
	probe.presentation_lateral=0.
	var rows: Array[Dictionary]=[]
	var previous_speed:=0.
	for frame in 12:
		var current_speed:=direction*WarRules.WALK_SPEED
		probe._advance_lateral(previous_speed,current_speed,0.,1.0/60.0,WarRules.WALK_SPEED,0.)
		rows.append({
			"frame":frame,
			"time_ms":snappedf((frame+1)*1000.0/60.0,.01),
			"weight":probe.presentation_lateral,
			"travel_mm":probe.presentation_lateral*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL*1000.0
		})
		previous_speed=current_speed
	return rows

func trace_curve(direction: float) -> Array[Dictionary]:
	var probe:=WarLocomotion.new()
	probe.tactical_motion_pilot=true
	probe.presentation_lateral=0.
	var rows: Array[Dictionary]=[]
	var yaw_step:=deg_to_rad(90.)/60.0*direction
	for frame in 18:
		var yaw_delta:=yaw_step if frame<6 else 0.
		probe._advance_lateral(0.,0.,yaw_delta,1.0/60.0,WarRules.WALK_SPEED,WarRules.WALK_SPEED)
		rows.append({
			"frame":frame,
			"time_ms":snappedf((frame+1)*1000.0/60.0,.01),
			"weight":probe.presentation_lateral,
			"travel_mm":probe.presentation_lateral*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL*1000.0
		})
	return rows

func signed_peak(rows: Array[Dictionary]) -> float:
	var value:=0.
	for row in rows:
		if absf(float(row.weight))>absf(value): value=float(row.weight)
	return value

func settle_after_ms(rows: Array[Dictionary],release_frame: int,threshold_mm:=.5) -> float:
	var release_time:=float(rows[release_frame].time_ms)
	for row in rows:
		if int(row.frame)>release_frame and absf(float(row.travel_mm))<=threshold_mm:
			return float(row.time_ms)-release_time
	return -1.

func capture(actor: WarPlayer,label: String,weight: float) -> Dictionary:
	actor.locomotion.tactical_motion_pilot=true
	actor.locomotion.presentation_longitudinal=0.
	actor.locomotion.presentation_lateral=weight
	actor.locomotion.moving=1.
	actor.locomotion.sprint=0.
	actor.locomotion.phase=0.
	actor.aiming=false
	actor.iron_sights=false
	actor.reload_left=0.
	actor.fire_cooldown=0.
	actor._update_weapon_pose()
	for i in 4: await process_frame
	await RenderingServer.frame_post_draw
	var pos:=actor.view_root.position
	var path:=OUT+"/"+label+".png"
	var saved:=root.get_texture().get_image().save_png(path)
	return {
		"label":label,
		"weight":weight,
		"view_x":pos.x,
		"view_y":pos.y,
		"view_z":pos.z,
		"world_x":actor.weapon_root.position.x,
		"saved":saved,
		"file":path
	}

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("R1B G3 calibration requires rendered mode")
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var strafe_left:=trace_strafe(-1.)
	var strafe_right:=trace_strafe(1.)
	var curve_left:=trace_curve(1.)
	var curve_right:=trace_curve(-1.)
	var sl_peak:=signed_peak(strafe_left)
	var sr_peak:=signed_peak(strafe_right)
	var cl_peak:=signed_peak(curve_left)
	var cr_peak:=signed_peak(curve_right)
	var sl_mm:=sl_peak*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL*1000.
	var sr_mm:=sr_peak*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL*1000.
	var cl_mm:=cl_peak*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL*1000.
	var cr_mm:=cr_peak*WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL*1000.
	var strafe_settle:=settle_after_ms(strafe_right,0)
	var curve_settle:=settle_after_ms(curve_right,5)

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
	actor.aiming=false
	actor.iron_sights=false
	actor._update_view()
	actor.camera.make_current()
	game.hud_layer.hide()
	game.menu_layer.hide()
	var camera_rest:=actor.camera.transform

	var captures: Array[Dictionary]=[]
	captures.append(await capture(actor,"neutral",0.))
	captures.append(await capture(actor,"strafe-left",sl_peak))
	captures.append(await capture(actor,"strafe-right",sr_peak))
	captures.append(await capture(actor,"curve-left",cl_peak))
	captures.append(await capture(actor,"curve-right",cr_peak))

	var neutral_x:=float(captures[0].view_x)
	var neutral_y:=float(captures[0].view_y)
	var neutral_z:=float(captures[0].view_z)
	var world_min:=float(captures[0].world_x)
	var world_max:=world_min
	var yz_drift_mm:=0.
	for item in captures:
		world_min=minf(world_min,float(item.world_x))
		world_max=maxf(world_max,float(item.world_x))
		yz_drift_mm=maxf(yz_drift_mm,absf(float(item.view_y)-neutral_y)*1000.)
		yz_drift_mm=maxf(yz_drift_mm,absf(float(item.view_z)-neutral_z)*1000.)
	var world_span_mm:=(world_max-world_min)*1000.

	check(sl_peak>0. and sr_peak<0.,"strafe directions lag opposite to movement")
	check(cl_peak>0. and cr_peak<0.,"curve directions lag opposite to yaw")
	check(absf(absf(sl_mm)-absf(sr_mm))<.05,"strafe response is symmetric")
	check(absf(absf(cl_mm)-absf(cr_mm))<.05,"curve response is symmetric")
	check(absf(sr_mm)>=6. and absf(sr_mm)<=9.5,"strafe peak stays in the 6-9.5 mm window")
	check(absf(cr_mm)>=7. and absf(cr_mm)<=10.,"curve peak stays in the 7-10 mm window")
	check(strafe_settle>=70. and strafe_settle<=140.,"strafe returns below 0.5 mm within 70-140 ms")
	check(curve_settle>=80. and curve_settle<=160.,"curve returns below 0.5 mm within 80-160 ms")
	check(absf((float(captures[1].view_x)-neutral_x)*1000.-sl_mm)<.15,"rendered G3 left strafe matches locomotion state")
	check(absf((float(captures[2].view_x)-neutral_x)*1000.-sr_mm)<.15,"rendered G3 right strafe matches locomotion state")
	check(absf((float(captures[3].view_x)-neutral_x)*1000.-cl_mm)<.15,"rendered G3 left curve matches locomotion state")
	check(absf((float(captures[4].view_x)-neutral_x)*1000.-cr_mm)<.15,"rendered G3 right curve matches locomotion state")
	check(world_span_mm<.01,"R1B keeps authoritative G3 world position unchanged")
	check(yz_drift_mm<.01,"R1B adds no vertical or longitudinal drift")
	check(actor.camera.get_parent()!=actor.shoulder_arm,"R1B visual calibration is actually captured in FPP")
	check(actor.camera.transform.is_equal_approx(camera_rest),"R1B leaves the camera transform unchanged")

	var report:={
		"walk_speed_mps":WarRules.WALK_SPEED,
		"turn_rate_deg_s":90.,
		"lateral_travel_limit_mm":WarLocomotion.PRESENTATION_LATERAL_FPP_TRAVEL*1000.,
		"strafe_left_peak_mm":sl_mm,
		"strafe_right_peak_mm":sr_mm,
		"strafe_settle_after_impulse_ms":strafe_settle,
		"curve_left_peak_mm":cl_mm,
		"curve_right_peak_mm":cr_mm,
		"curve_settle_after_release_ms":curve_settle,
		"world_weapon_span_mm":world_span_mm,
		"yz_drift_mm":yz_drift_mm,
		"strafe_left_trace":strafe_left,
		"strafe_right_trace":strafe_right,
		"curve_left_trace":curve_left,
		"curve_right_trace":curve_right,
		"captures":captures,
		"failures":failures
	}
	var out:=FileAccess.open(OUT+"/calibration.json",FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(report,"\t"))
		out.close()
	print("REALISMO_R1B_G3 "+JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
