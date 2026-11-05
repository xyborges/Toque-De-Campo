extends SceneTree

const Effects := preload("res://modes/war/scripts/effects.gd")

var passed := 0

func verify(ok: bool, description: String) -> void:
    if not ok:
        push_error("FAIL: " + description)
        quit(1)
        return
    passed += 1

func _init() -> void:
    call_deferred("_run_tests")

func _run_tests() -> void:
    verify(Effects.WRECK_PLUME_LIMIT * Effects.WRECK_PLUME_CARDS == 24, "fixed mesh budget")
    verify(Effects.wreck_plume_profile(100.0, 2400.0, 15.0).is_empty(), "no near full-screen cards")
    verify(Effects.wreck_plume_profile(7000.0, 2400.0, 15.0).is_empty(), "far distance ceiling")
    verify(Effects.wreck_plume_profile(3500.0, 2400.0, 76.0).is_empty(), "plume expires")
    verify(Effects.wreck_plume_profile(3500.0, 2400.0, 0.0).is_empty(), "initial flash has no premature smoke")
    for distance: float in [450.0, 900.0, 1600.0, 2400.0, 3500.0, 4900.0, 5750.0]:
        var profile: Dictionary = Effects.wreck_plume_profile(distance, 2400.0, 20.0)
        verify(not profile.is_empty(), "smoke present at " + str(distance))
        if profile.is_empty(): continue
        verify(float(profile.mapped_distance) <= 2400.0 * .72 + .001, "camera far clipping at " + str(distance))
        verify(is_equal_approx(float(profile.scale), float(profile.mapped_distance) / distance), "projection scale " + str(distance))
        verify(is_equal_approx(float(profile.height) * float(profile.scale) / float(profile.mapped_distance), float(profile.height) / distance), "angular size " + str(distance))
        verify(float(profile.opacity) > 0.0 and float(profile.opacity) <= 1.0, "opacity " + str(distance))
    var fx: WarEffects = Effects.new()
    fx.wreck_plume_pool = MultiMesh.new()
    for index in 18:
        fx._register_wreck_plume(Vector3(index, 0, index), index)
    verify(fx.wreck_plumes.size() == Effects.WRECK_PLUME_LIMIT, "maximum 8 concurrent wrecks")
    verify(int(fx.wreck_plumes[0].seed) == 10, "oldest smoke is evicted")
    # Exercise the real MultiMesh update path without loading a battlefield.
    var pool := MultiMesh.new()
    pool.transform_format = MultiMesh.TRANSFORM_3D
    pool.use_colors = true
    pool.use_custom_data = true
    pool.mesh = QuadMesh.new()
    pool.instance_count = Effects.WRECK_PLUME_LIMIT * Effects.WRECK_PLUME_CARDS
    fx.wreck_plume_pool = pool
    fx.wreck_plumes.clear()
    var camera := Camera3D.new()
    root.add_child(camera)
    camera.far = 2400.0
    camera.position = Vector3(0.0, 8.0, 0.0)
    for index in Effects.WRECK_PLUME_LIMIT:
        fx._register_wreck_plume(Vector3(float(index) * 6.0, 0.0, -3500.0), index)
        fx.wreck_plumes[index].age = 20.0
    fx._wreck_plume_step(0.016, camera)
    verify(pool.visible_instance_count == 24, "24 far smoke cards rendered at 3.5 km")
    var sampled := pool.get_instance_transform(0).origin
    verify(sampled.distance_to(camera.global_position) < camera.far, "rendered smoke stays within far plane")
    var shader: Shader = load("res://modes/war/shaders/wreck_smoke_far.gdshader")
    verify(shader != null, "distant smoke shader loads")
    var material := ShaderMaterial.new()
    material.shader = shader
    var visible_mesh := MultiMeshInstance3D.new()
    visible_mesh.multimesh = pool
    visible_mesh.material_override = material
    visible_mesh.custom_aabb = AABB(Vector3(-8000,-400,-8000),Vector3(16000,1200,16000))
    root.add_child(visible_mesh)
    camera.make_current()
    # On a real GL renderer this executes at least two frames with the actual shader.
    if DisplayServer.get_name() != "headless":
        await process_frame
        await process_frame
    var start_usec := Time.get_ticks_usec()
    for tick in 240:
        fx._wreck_plume_step(1.0 / 60.0, camera)
    var elapsed_ms := float(Time.get_ticks_usec() - start_usec) / 1000.0
    verify(pool.visible_instance_count == 24, "pool remains at 24 after 240 frames")
    fx._wreck_plume_step(75.0, camera)
    verify(pool.visible_instance_count == 0 and fx.wreck_plumes.is_empty(), "plumes expire cleanly")
    print("PASS war_tank_smoke_distance: ", passed, " checks; 240-frame CPU loop ", snappedf(elapsed_ms, .01), " ms")
    quit()
