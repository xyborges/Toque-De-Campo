extends SceneTree
const Cadence = preload("res://scripts/network_cadence.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func run() -> void:
	var counts: Array = []
	for fps in [30,60,120]:
		for period in [.05,.1,.2,.5,2.]:
			var elapsed := 0.
			var sends := 0
			for _frame in fps*6:
				elapsed+=1./fps
				if Cadence.due(elapsed,period):
					elapsed=Cadence.consume(elapsed,period)
					sends+=1
					if _frame==fps*6-1: check(not Cadence.due(elapsed,period),"one update consumes every expired slot at "+str(fps)+"Hz / "+str(period)+"s")
			counts.append({"fps":fps,"period":period,"updates":sends,"remainder":elapsed})
			check(sends==roundi(6./period),"nominal RPC rate stays exact over six seconds at "+str(fps)+"Hz / "+str(period)+"s")
	var clock := .19999999999999
	check(Cadence.due(clock,.2) and is_zero_approx(Cadence.consume(clock,.2)),"floating-point boundary does not postpone a 200ms snapshot to tick thirteen")
	for period in [.05,.1,.2]:
		clock=period*.2+period*7.
		var emitted := 0
		if Cadence.due(clock,period):
			emitted+=1;clock=Cadence.consume(clock,period)
		# Two immediate updates after the stall must not drain a backlog.
		for _update in 2:
			if Cadence.due(clock,period):
				emitted+=1;clock=Cadence.consume(clock,period)
		check(emitted==1 and is_equal_approx(clock,period*.2),"a seven-period stutter sends once and retains only the fractional phase for "+str(period)+"s")
	clock=.213
	var sends := 0
	for delta in [0.,1./120.,1./120.]:
		clock+=delta
		if Cadence.due(clock,.05): sends+=1;clock=Cadence.consume(clock,.05)
	check(sends==1,"two short updates after a 213ms stall do not produce catch-up packets")
	check(not Cadence.due(2.,0.) and Cadence.consume(2.,0.)==0.,"invalid periods cannot cause division or scheduling errors")
	var result := {"checks":checks,"failures":failures,"cases":counts,"no_network_clients":true}
	NavalStorage.write_json("res://tests/latency191-cadence-results.json",result);print(JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)
