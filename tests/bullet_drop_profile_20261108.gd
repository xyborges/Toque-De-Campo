extends SceneTree
const Bullet = preload("res://scripts/bullet_physics.gd")
# Benchmarks CPU operations only. No multiplayer, graphical FPS, or gameplay edits.
const PASSES := 11
const MATH_CALLS := 25000
const RAY_CALLS := 25000
const GRAVITY := 16.0
const DRAG := 0.035
const DT := 1.0 / 60.0
const MODES := [
    "straight", "drag_only", "drag_and_drop", "advance_dictionary",
    "coefficients_hit", "coefficients_miss",
    "ray_setup", "ray_cast", "projectile_drag_only", "projectile_drag_and_drop"
]
var sink := 0.0
var ray: PhysicsRayQueryParameters3D
var collisions := 0

func _initialize() -> void:
    _run.call_deferred()

func _run() -> void:
    var arena := Node3D.new()
    root.add_child(arena)
    # A small static scene avoids a misleading empty-space-only ray benchmark.
    for x in 12:
        for z in 4:
            var body := StaticBody3D.new()
            body.position = Vector3(18.0 + float(x) * 15.0, 130.0, -16.0 + float(z) * 10.0)
            var collision := CollisionShape3D.new()
            var shape := BoxShape3D.new()
            shape.size = Vector3(2.0, 26.0, 2.0)
            collision.shape = shape
            body.add_child(collision)
            arena.add_child(body)
    ray = PhysicsRayQueryParameters3D.create(Vector3.ZERO, Vector3(1, 0, 0), 1)
    await physics_frame
    await physics_frame
    var space := root.get_world_3d().direct_space_state
    # Warm both the script VM and cached ballistic coefficients.
    for mode in MODES:
        _bench(mode, 1200, space)
    var results := {}
    for mode in MODES:
        results[mode] = []
    for pass_index in PASSES:
        var order := MODES.duplicate()
        if pass_index % 2 == 1:
            order.reverse()
        for mode in order:
            var calls: int = RAY_CALLS if mode in ["ray_setup", "ray_cast", "projectile_drag_only", "projectile_drag_and_drop"] else MATH_CALLS
            var begun := Time.get_ticks_usec()
            _bench(mode, calls, space)
            var milliseconds := float(Time.get_ticks_usec() - begun) / 1000.0
            (results[mode] as Array).append(1000.0 * milliseconds / float(calls))
    var stats := {}
    for mode in MODES:
        var samples: Array = results[mode].duplicate()
        samples.sort()
        stats[mode] = {
            "ms_per_1000_median": samples[int(samples.size() / 2)],
            "ms_per_1000_min": samples.front(),
            "ms_per_1000_max": samples.back(),
            "ms_per_1000_p95": samples[int(ceil(0.95 * float(samples.size()))) - 1],
            "samples": results[mode]
        }
    var predicted := Bullet.advance(Vector3(0, 150, 0), Vector3(560, 0, -25), GRAVITY, DRAG, 1.0)
    var flat := Bullet.advance(Vector3(0, 150, 0), Vector3(560, 0, -25), 0.0, DRAG, 1.0)
    var difference := (flat.position as Vector3).y - (predicted.position as Vector3).y
    var report := {
        "origin_main": "4e41854",
        "godot": str(Engine.get_version_info().get("string", "")),
        "os": OS.get_name(),
        "display": DisplayServer.get_name(),
        "renderer": "headless",
        "method": "Godot GDScript CPU microbenchmark, fixed 60 Hz; 11 alternating A/B passes after warmup, 48 static collision bodies; ms per 1000 calls, not frame FPS",
        "math_calls_per_pass": MATH_CALLS,
        "ray_calls_per_pass": RAY_CALLS,
        "passes": PASSES,
        "stats": stats,
        "ray_hits": collisions,
        "gravity_test": {"one_second_drop_m": difference, "pass": difference > 0.0},
        "checksum": sink
    }
    var out := FileAccess.open("res://docs/benchmark-results/bullet-drop-20261108.json", FileAccess.WRITE)
    if out == null:
        push_error("Unable to create benchmark JSON")
        quit(2)
        return
    out.store_string(JSON.stringify(report, "\t") + "\n")
    out.close()
    print("BULLET_DROP_PROFILE ", JSON.stringify(report))
    arena.queue_free()
    quit(0 if difference > 0.0 else 1)

func _bench(mode: String, calls: int, space: PhysicsDirectSpaceState3D) -> void:
    var pos := Vector3(0, 145, 0)
    var vel := Vector3(560, 0, -25)
    var gravity_vector := Vector3.DOWN * GRAVITY
    for i in calls:
        if mode == "straight":
            var destination := pos + vel * DT
            sink += destination.x * 0.0000001
        elif mode == "drag_only":
            var w := Bullet.coefficients(DRAG, DT)
            var next := pos + vel * w.y
            var velocity := vel * w.x
            sink += (next.x + velocity.x) * 0.0000001
        elif mode == "drag_and_drop":
            var w := Bullet.coefficients(DRAG, DT)
            var next := pos + vel * w.y + gravity_vector * w.z
            var velocity := vel * w.x + gravity_vector * w.y
            sink += (next.y + velocity.y) * 0.0000001
        elif mode == "advance_dictionary":
            var state := Bullet.advance(pos, vel, GRAVITY, DRAG, DT)
            sink += (state.position as Vector3).y * 0.0000001
        elif mode == "coefficients_hit":
            var w := Bullet.coefficients(DRAG, DT)
            sink += w.x * 0.0000001
        elif mode == "coefficients_miss":
            var custom_dt := DT + 0.0000008 * float(i % 3072)
            var w := Bullet.coefficients(DRAG, custom_dt)
            sink += w.y * 0.0000001
        else:
            var origin := Vector3(0, 145.0 + float(i % 3), -13.0 + float(i % 7) * 3.0)
            var displacement := Vector3(190.0 + float(i % 21), -10.0, 0.0)
            var destination := origin + displacement
            if mode == "projectile_drag_only" or mode == "projectile_drag_and_drop":
                var w := Bullet.coefficients(DRAG, DT)
                var shot_velocity := displacement / DT
                destination = origin + shot_velocity * w.y
                if mode == "projectile_drag_and_drop":
                    destination += gravity_vector * w.z
            ray.from = origin
            ray.to = destination
            if mode != "ray_setup":
                var hit := space.intersect_ray(ray)
                if not hit.is_empty():
                    collisions += 1
                sink += float(hit.size()) * 0.0000001
            else:
                sink += destination.x * 0.0000001
