extends SceneTree
## Frontline state machine, non-Favela regressions and physical rim.
## godot --headless --path . --script res://tests/favela_frontline_qa.gd

var failures: Array[String] = []
var checks := 0

func ensure(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func _take(states: Dictionary, team: int) -> Dictionary:
	var focus: String = WarFavelaFrontline.active_id(states)
	ensure(not focus.is_empty(), "Front disappeared unexpectedly")
	if focus.is_empty(): return {"winner": -1, "active": "", "changed": false}
	var counts := [0, 0]
	counts[team] = 1
	states[focus] = WarRules.capture(states[focus], counts, WarRules.CAPTURE_SECONDS + 0.3)
	ensure(int(states[focus].owner) == team, "Capture refused " + focus)
	return WarFavelaFrontline.advance(states, focus, team)

func _run() -> void:
	WarRules.configure(WarOperation.FAVELA)
	WarTerrain.configure(WarOperation.FAVELA)
	var states: Dictionary = WarRules.fresh_objectives()
	ensure(WarFavelaFrontline.enabled(WarRules.CURRENT_OPERATION), "Favela must use frontline")
	ensure(WarFavelaFrontline.active_id(states) == "C", "Initial focus must be C")
	for key in ["A", "B"]:
		ensure(int(states[key].owner) == 0, key + " not protected by Police")
	for key in ["D", "E"]:
		ensure(int(states[key].owner) == 1, key + " not protected by Bandits")
	ensure(WarFavelaFrontline.can_capture(states, "C"), "C is not capturable")
	ensure(not WarFavelaFrontline.can_capture(states, "A"), "Locked A capturable")
	ensure(WarFavelaFrontline.spawn_allowed(states, 0, "B"), "Police cannot spawn adjacent")
	ensure(WarFavelaFrontline.spawn_allowed(states, 1, "D"), "Bandit cannot spawn adjacent")
	ensure(not WarFavelaFrontline.spawn_allowed(states, 0, "A"), "Police can spawn behind")
	ensure(not WarFavelaFrontline.spawn_allowed(states, 1, "B"), "Bandit can spawn on Police")
	ensure(WarFavelaFrontline.winner_at_limit(states, [80, 80]) == -1, "Central tie must draw")
	ensure(WarFavelaFrontline.winner_at_limit(states, [80, 60]) == 0, "Central tickets tiebreaker")
	var move: Dictionary = _take(states, 0)
	ensure(str(move.active) == "D" and int(move.winner) == -1, "Police C must advance to D")
	ensure(WarFavelaFrontline.winner_at_limit(states, [15, 200]) == 0,
		"Territory must outrank tickets at time limit")
	ensure(WarFavelaFrontline.spawn_allowed(states, 0, "C"), "Police C rally missing")
	ensure(WarFavelaFrontline.spawn_allowed(states, 1, "E"), "Bandit E rally missing")
	move = _take(states, 1)
	ensure(str(move.active) == "C", "Bandit counterattack must return to C")
	move = _take(states, 1)
	ensure(str(move.active) == "B", "Bandit advance to B failed")
	ensure(WarFavelaFrontline.winner_at_limit(states, [230, 1]) == 1,
		"Bandits closer to Police base must win timeout")
	move = _take(states, 1)
	ensure(str(move.active) == "A", "Bandit advance to A failed")
	move = _take(states, 1)
	ensure(int(move.winner) == 1 and str(move.active).is_empty(),
		"Bandit terminal victory not detected")
	var police: Dictionary = WarRules.fresh_objectives()
	for expected in ["D", "E", ""]:
		move = _take(police, 0)
		ensure(str(move.active) == expected, "Police reverse victory step " + expected)
	ensure(int(move.winner) == 0, "Police terminal victory not detected")
	ensure(WarOperation.objectives(WarOperation.FAVELA)["E"].position.x == 430.0,
		"Football field sector E shifted")
	ensure(WarFavelaMap.OBJECTIVES_2D[4] == WarFavelaMap.BAILE_CENTER,
		"Football field not aligned to sector E")
	ensure(WarFavelaRim.height_offset(0.0, 0.0) == 0.0,
		"City center must not be lifted")
	ensure(WarFavelaRim.height_offset(730.0, 0.0) > 30.0,
		"East ring hill not high enough")
	ensure(WarFavelaRim.height_offset(0.0, -730.0) > 30.0,
		"South ring hill not high enough")
	for p in WarFavelaMap.OBJECTIVES_2D:
		ensure(WarFavelaRim.height_offset(p.x, p.y) == 0.0,
			"Objective buried under perimeter ridge: " + str(p))
	for p in WarFavelaMap.BASES_2D:
		ensure(WarFavelaRim.height_offset(p.x, p.y) == 0.0,
			"Base buried under ridge: " + str(p))
	ensure(WarFavelaMap.accessible(WarRules.OBJECTIVES["E"].position),
		"Football point has inaccessible grade")
	var street_ridge := WarFavelaRim.height_offset(640.0, 340.0)
	ensure(is_zero_approx(street_ridge), "Ridge damages the last cross street")
	WarRules.configure(WarOperation.UKRAINE)
	ensure(not WarFavelaFrontline.enabled(WarRules.CURRENT_OPERATION),
		"Other War maps forced into Frontlines")
	var classic: Dictionary = WarRules.fresh_objectives()
	for key in classic:
		ensure(int(classic[key].owner) == -1, "Legacy mode pre-captured " + key)
	print("FAVELA_FRONTLINE_QA ", JSON.stringify({
		"checks": checks, "failures": failures,
		"field": str(WarFavelaMap.BAILE_CENTER),
		"police_win": 0, "bandit_win": 1
	}))
	if failures.is_empty():
		print("FAVELA_FRONTLINE_QA PASS")
		quit(0)
	else:
		for issue in failures: printerr("FAVELA_FRONTLINE_QA FAIL " + issue)
		quit(1)
