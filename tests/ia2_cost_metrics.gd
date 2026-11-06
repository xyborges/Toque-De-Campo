extends RefCounted
class_name IA2CostMetrics

# Test-only, active only when the QA launcher requests --ia2-profile-bots.
# Uses process-frame buckets: multiple physics ticks during a slow frame
# are charged to that *rendered* frame rather than reported per physics tick.
static var enabled: bool = "--ia2-profile-bots" in OS.get_cmdline_user_args()
static var measuring := false
static var frames: Dictionary = {}
static var counts: Dictionary = {}
static var first_usec := 0

static func start() -> void:
	frames.clear()
	counts.clear()
	first_usec = Time.get_ticks_usec()
	measuring = enabled

static func begin() -> int:
	return Time.get_ticks_usec() if enabled and measuring else 0

static func end(scope: StringName, started: int, units: int = 1) -> void:
	if started <= 0 or not measuring: return
	var elapsed: float = maxf(0.0, float(Time.get_ticks_usec() - started)) * 0.001
	var frame := Engine.get_process_frames()
	if not frames.has(frame): frames[frame] = {}
	var row: Dictionary = frames[frame]
	var key := str(scope)
	row[key] = float(row.get(key, 0.0)) + elapsed
	counts[key] = int(counts.get(key, 0)) + units

static func touch_frame() -> void:
	if not measuring: return
	var frame := Engine.get_process_frames()
	if not frames.has(frame): frames[frame] = {}

static func stop() -> void:
	measuring = false

static func _distribution(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {}
	var ordered := values.duplicate()
	ordered.sort()
	var n := ordered.size()
	var total := 0.0
	for value in ordered: total += value
	return {
		"mean_ms_per_frame": total / n,
		"p50_ms_per_frame": ordered[mini(n-1, ceili(n*.50)-1)],
		"p95_ms_per_frame": ordered[mini(n-1, ceili(n*.95)-1)],
		"p99_ms_per_frame": ordered[mini(n-1, ceili(n*.99)-1)],
		"max_ms_per_frame": ordered[-1]
	}

static func report() -> Dictionary:
	var keys: Array[String] = []
	for key in counts: keys.append(str(key))
	keys.sort()
	var out: Dictionary = {"enabled":enabled, "render_frames":frames.size(), "scopes":{},
		"note":"Inclusive times; nested scopes overlap. Per-frame buckets use Engine.get_process_frames(). Timing overhead is included."}
	var ordered_frames := frames.keys()
	ordered_frames.sort()
	for key in keys:
		var values: Array[float] = []
		for frame in ordered_frames:
			var row: Dictionary = frames[frame]
			values.append(float(row.get(key,0.0)))
		var item := _distribution(values)
		item["calls"] = int(counts[key])
		item["calls_per_frame"] = float(counts[key]) / maxf(1.0, float(frames.size()))
		out.scopes[key] = item
	return out
