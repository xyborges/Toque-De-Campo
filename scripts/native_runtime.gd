extends RefCounted
class_name GameNativeRuntime

## Centralized policy for native Godot C++ GDExtension features.
## Native is preferred on supported platforms. Each feature is independently
## reversible using command-line flags; missing binaries fall back to GDScript.
const ALL_LEGACY: String="--war-native-legacy"
const POSE_LEGACY: String="--pose-gde-legacy"
const SEPARATION_LEGACY: String="--war-bot-separation-legacy"

static func enabled_from_args(feature: String,args: PackedStringArray,available: bool) -> bool:
	if not available or args.has(ALL_LEGACY):return false
	match feature:
		"pose":
			return not (args.has(POSE_LEGACY) or args.has("--pose-gd-legacy"))
		"separation":
			return not args.has(SEPARATION_LEGACY)
	return false

static func enabled(feature: String) -> bool:
	# A stale / partial native binary must never enable a missing gameplay
	# entrypoint. This also permits Windows/Linux fallback after a bad export.
	var available:=ClassDB.class_exists("WarNativePoseMath")
	if available:
		match feature:
			"pose":
				available=ClassDB.class_has_method("WarNativePoseMath","apply_arms_direct")
			"separation":
				available=ClassDB.class_has_method("WarNativePoseMath","separation_batch")
			_:
				available=false
	return enabled_from_args(feature,OS.get_cmdline_user_args(),available)
