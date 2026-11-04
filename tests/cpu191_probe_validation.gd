extends SceneTree
const Probe=preload("res://scripts/performance_probe.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label)
func run() -> void:
	check(Probe.begin(&"before_start")==0,"initialization is outside sampling")
	var metadata: Dictionary={"case":{"value":1}}
	var armed:=Probe.start(metadata)
	metadata.case.value=2
	check(armed==("--performance-probe" in OS.get_cmdline_user_args()),"the diagnostic flag is required")
	if armed:
		for index in 650:
			var started:=Probe.begin(&"bounded")
			Probe.end(&"bounded",started)
		var result:=Probe.report()
		check(result.metadata.case.value==1,"metadata is copied at the sampling barrier")
		check(result.scopes.bounded.calls==650,"all calls contribute to totals")
		check(result.scopes.bounded.retained_calls==600,"retained series is bounded at 600")
		check(result.scopes.bounded.durations_usec.size()==600 and result.scopes.bounded.elapsed_usec.size()==600,"duration and elapsed rings have matching bounds")
		var ordered:=true
		for index in range(1,600):
			if result.scopes.bounded.elapsed_usec[index]<result.scopes.bounded.elapsed_usec[index-1]: ordered=false
		check(ordered,"wrapped samples are reported chronologically")
		var started:=Probe.begin(&"after_stop")
		Probe.stop();Probe.end(&"after_stop",started)
		check(Probe.begin(&"after_stop")==0 and not Probe.report().scopes.has("after_stop"),"teardown is outside sampling")
		Probe.start();Probe.stop()
		check(Probe.report().scopes.is_empty(),"a new sampling window resets the old run")
	else:
		Probe.end(&"disabled",Time.get_ticks_usec())
		check(Probe.begin(&"disabled")==0 and Probe.report().scopes.is_empty(),"ordinary runs do not collect diagnostic data")
	print("CPU191_PROBE_VALIDATION ",JSON.stringify({"checks":checks,"failures":failures,"enabled":armed}))
	quit(0 if failures.is_empty() else 1)
