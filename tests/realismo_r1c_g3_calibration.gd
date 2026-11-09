extends SceneTree

const FIXTURE=preload("res://tests/war_optics_fixture.gd")
const OUT="res://work/realismo-r1c-g3"

var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool,label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func recovery_trace(weight: float) -> Array[Dictionary]:
	var rows: Array[Dictionary]=[]
	var current:=weight
	for frame in 30:
		current=move_toward(current,0.,(1.0/60.0)*WarLocomotion.PRESENTATION_LANDING_RECOVERY)
		rows.append({
			"frame":frame,
			"time_ms":snappedf((frame+1)*1000.0/60.0,.01),
			"weight":current,
			"travel_mm":current*WarLocomotion.PRESENTATION_LANDING_FPP_TRAVEL*1000.
		})
	return rows

func settle_ms(rows: Array[Dictionary],threshold_mm:=.5) -> float:
	for row in rows:
		if absf(float(row.travel_mm))<=threshold_mm:
			return float(row.time_ms)
	return -1.

func capture(actor: WarPlayer,label: String,weight: float) -> Dictionary:
	actor.locomotion.tactical_motion_pilot=true
	actor.locomotion.presentation_longitudinal=0.
	actor.locomotion.presentation_lateral=0.
	actor.locomotion.presentation_landing=weight
	actor.locomotion.moving=0.
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
		"world_y":actor.weapon_root.position.y,
		"world_z":actor.weapon_root.position.z,
		"saved":saved,
		"file":path
	}

func run() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("R1C G3 calibration requires rendered mode")
		quit(2)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	root.content_scale_size=Vector2i(1280,720)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))

	var normal_weight:=WarLocomotion.landing_target(4.4)
	var hard_weight:=WarLocomotion.landing_target(6.0)
	var normal_mm:=normal_weight*WarLocomotion.PRESENTATION_LANDING_FPP_TRAVEL*1000.
	var hard_mm:=hard_weight*WarLocomotion.PRESENTATION_LANDING_FPP_TRAVEL*1000.
	var normal_trace:=recovery_trace(normal_weight)
	var hard_trace:=recovery_trace(hard_weight)
	var normal_settle:=settle_ms(normal_trace)
	var hard_settle:=settle_ms(hard_trace)

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
	captures.append(await capture(actor,"normal-landing",normal_weight))
	captures.append(await capture(actor,"hard-landing",hard_weight))

	var neutral:=captures[0]
	var normal:=captures[1]
	var hard:=captures[2]
	var normal_visual_mm:=(float(neutral.view_y)-float(normal.view_y))*1000.
	var hard_visual_mm:=(float(neutral.view_y)-float(hard.view_y))*1000.
	var world_span_mm:=0.
	var world_origin:=Vector3(float(neutral.world_x),float(neutral.world_y),float(neutral.world_z))
	var xz_drift_mm:=0.
	for item in captures:
		var world:=Vector3(float(item.world_x),float(item.world_y),float(item.world_z))
		world_span_mm=maxf(world_span_mm,world.distance_to(world_origin)*1000.)
		xz_drift_mm=maxf(xz_drift_mm,absf(float(item.view_x)-float(neutral.view_x))*1000.)
		xz_drift_mm=maxf(xz_drift_mm,absf(float(item.view_z)-float(neutral.view_z))*1000.)

	check(normal_mm>=18. and normal_mm<=22.,"normal landing target stays in the 18-22 mm window")
	check(hard_mm>=34.9 and hard_mm<=35.1,"hard landing target reaches but does not exceed the 35 mm ceiling")
	check(normal_settle>=100. and normal_settle<=160.,"normal landing recovers below 0.5 mm within 100-160 ms")
	check(hard_settle>=200. and hard_settle<=250.,"hard landing recovers below 0.5 mm within 200-250 ms")
	check(absf(normal_visual_mm-normal_mm)<.15,"rendered G3 normal landing matches locomotion state")
	check(absf(hard_visual_mm-hard_mm)<.15,"rendered G3 hard landing matches locomotion state")
	check(world_span_mm<.01,"R1C keeps authoritative G3 local transform unchanged")
	check(xz_drift_mm<.01,"R1C adds no lateral or longitudinal drift")
	check(actor.camera.get_parent()!=actor.shoulder_arm,"R1C calibration is actually captured in FPP")
	check(actor.camera.transform.is_equal_approx(camera_rest),"R1C leaves camera transform unchanged")

	actor.view_root.transform=Transform3D.IDENTITY
	actor.locomotion.presentation_landing=hard_weight
	actor.aiming=true
	actor.iron_sights=true
	actor._update_weapon_pose()
	check(actor.view_root.position.is_equal_approx(actor._weapon_offset()),"ADS remains exactly aligned during a landing")

	var report:={
		"normal_weight":normal_weight,
		"normal_target_mm":normal_mm,
		"normal_visual_mm":normal_visual_mm,
		"normal_settle_ms":normal_settle,
		"hard_weight":hard_weight,
		"hard_target_mm":hard_mm,
		"hard_visual_mm":hard_visual_mm,
		"hard_settle_ms":hard_settle,
		"world_weapon_span_mm":world_span_mm,
		"xz_drift_mm":xz_drift_mm,
		"normal_trace":normal_trace,
		"hard_trace":hard_trace,
		"captures":captures,
		"failures":failures
	}
	var out:=FileAccess.open(OUT+"/calibration.json",FileAccess.WRITE)
	if out:
		out.store_string(JSON.stringify(report,"\t"))
		out.close()
	print("REALISMO_R1C_G3 "+JSON.stringify(report))
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
