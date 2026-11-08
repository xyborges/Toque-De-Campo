extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, description: String) -> void:
	print(("PASS " if ok else "FAIL ") + description)
	if not ok:
		failures.append(description)

func _run() -> void:
	var previous_operation: String = WarRules.CURRENT_OPERATION
	var previous_objectives: Dictionary = WarRules.OBJECTIVES.duplicate(true)
	var dash := GameMatchDashboard.new()
	root.add_child(dash)
	dash.size = Vector2(620, 142)
	WarRules.CURRENT_OPERATION = WarOperation.UKRAINE
	WarRules.OBJECTIVES = {
		"A": {"active": true, "name": "A"},
		"B": {"active": true, "name": "B"},
		"C": {"active": true, "name": "C"},
		"D": {"active": false, "name": "D"},
		"E": {"active": false, "name": "E"}
	}
	var common := {
		"A": {"owner": 0}, "B": {"owner": 1}, "C": {"owner": -1},
		"D": {"owner": 0}, "E": {"owner": 1}
	}
	dash.update_state(0, [260, 210], common, 1180)
	_check(dash.view == "conquest" and dash.visible_sector_ids() == ["A", "B", "C"], "guerra mostra apenas setores ativos")
	_check(dash._clock_text() == "19:40" and str(dash.model.left_value) == "260" and str(dash.model.right_value) == "210", "tickets e cronometro preservados")
	_check(str(dash.model.left_label) == WarRules.team_name(0).to_upper(), "nome do time vem da regra da operacao")
	WarRules.CURRENT_OPERATION = WarOperation.FAVELA
	WarRules.OBJECTIVES = {
		"A": {"active": true, "name": "Entrada"},
		"B": {"active": true, "name": "Beco"},
		"C": {"active": true, "name": "Laje central"},
		"D": {"active": true, "name": "Subida"},
		"E": {"active": true, "name": "Topo"}
	}
	dash.update_state(1, [250, 275], common, 400)
	_check(dash.visible_sector_ids() == ["A", "B", "C", "D", "E"], "favela exibe os cinco setores")
	_check(str(dash.model.focus) == "C" and int(dash.model.own_team) == 1, "alvo central e equipe local respeitados")
	var contested := common.duplicate(true)
	contested["C"]["contested"] = true
	contested["C"]["progress"] = .42
	contested["C"]["side"] = 0
	dash.update_state(0, [250, 270], contested, 388)
	var sectors: Array = dash.model.get("sectors", [])
	_check(bool(sectors[2].get("contested", false)) and is_equal_approx(float(sectors[2].get("progress", 0.0)), .42), "disputa e progresso refletidos pelo snapshot")
	_check(int(sectors[2].get("side", -1)) == 0, "lado capturando definido pelo estado de rede")
	dash.update_survival(17, 30, 4, 92, true, "active")
	_check(dash.view == "survival" and dash.model.state == "ZONA FECHANDO" and dash._clock_text() == "01:32", "BR ativo com fechamento de zona")
	dash.update_survival(30, 30, 0, 0, false, "waiting")
	_check(dash.model.state == "AGUARDANDO", "BR em fila sem estado de zona incorreto")
	dash.update_naval(8, "submarino")
	_check(dash.view == "naval" and dash.model.right_value == "SUBMARINO" and dash._clock_text() == "EM CURSO", "naval sem cronometro ficticio")
	dash.update_arena("PVP DESERTO", "POSTO MILITAR", 190, false, 6, 3)
	_check(dash.view == "arena" and dash.model.right_value == "3" and dash._clock_text() == "03:10", "arena e treino com dados compartilhados")
	await process_frame
	WarRules.CURRENT_OPERATION = previous_operation
	WarRules.OBJECTIVES = previous_objectives
	dash.queue_free()
	print("RESULT " + ("PASS" if failures.is_empty() else "FAIL") + " (" + str(failures.size()) + " falhas)")
	quit(0 if failures.is_empty() else 1)
