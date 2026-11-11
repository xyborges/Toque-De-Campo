extends SceneTree
## Native is preferred automatically when the extension is present; every
## feature remains independently reversible and must fall back when absent.
var checks:=0
var failures: Array[String]=[]

func verify(ok: bool,reason: String) -> void:
	checks+=1
	if not ok:failures.append(reason)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var empty:=PackedStringArray()
	var global_legacy:=PackedStringArray(["--war-native-legacy"])
	var pose_legacy:=PackedStringArray(["--pose-gde-legacy"])
	var separation_legacy:=PackedStringArray(["--war-bot-separation-legacy"])
	for feature in ["pose","separation"]:
		verify(GameNativeRuntime.enabled_from_args(feature,empty,true),"native default on: "+feature)
		verify(not GameNativeRuntime.enabled_from_args(feature,empty,false),"missing DLL fallback: "+feature)
		verify(not GameNativeRuntime.enabled_from_args(feature,global_legacy,true),"global legacy: "+feature)
	verify(not GameNativeRuntime.enabled_from_args("pose",pose_legacy,true),"pose legacy")
	verify(GameNativeRuntime.enabled_from_args("separation",pose_legacy,true),"pose flag should not stop bot C++")
	verify(not GameNativeRuntime.enabled_from_args("separation",separation_legacy,true),"separation legacy")
	verify(GameNativeRuntime.enabled_from_args("pose",separation_legacy,true),"separation flag should not stop poses")
	verify(not GameNativeRuntime.enabled_from_args("unknown",empty,true),"unknown feature fallback")
	var loaded:=ClassDB.class_exists("WarNativePoseMath")
	verify(GameInfantryPose.native_pose_enabled==GameNativeRuntime.enabled("pose"),"pose default matches central policy")
	var director:=WarBotDirector.new()
	verify(director.native_separation_enabled==GameNativeRuntime.enabled("separation"),"director matches central policy")
	director.free()
	var args:=OS.get_cmdline_user_args()
	verify(GameInfantryPose.native_pose_enabled==GameNativeRuntime.enabled_from_args("pose",args,loaded),"real pose command-line policy")
	print("GDE_NATIVE_DEFAULTS_QA ",JSON.stringify({"checks":checks,"failures":failures,"native_class_available":loaded,"pose_default":GameInfantryPose.native_pose_enabled,"command_line_flags":Array(args)}))
	quit(0 if failures.is_empty() else 1)
