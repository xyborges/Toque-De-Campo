extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var panel := GameMatchResultPanel.new()
	root.add_child(panel)
	await process_frame
	panel.present("victory","GUERRA","EUA triunfam","Operacao resolvida por tickets",[["EQUIPE","82"],["INIMIGO","0"],["TEMPO","14:32"]])
	if panel.headline.text != "VITÓRIA" or panel.stat_values[0].text != "82":
		push_error("FAIL victory and stats")
		quit(1)
		return
	panel.show()
	panel.intro()
	panel.set_countdown("PRÓXIMA PARTIDA EM 00:12")
	if not panel.timer.visible or panel.stat_panels[2].visible==false:
		push_error("FAIL countdown and summary cards")
		quit(1)
		return
	await create_timer(0.55).timeout
	if panel.headline.modulate.a < 0.99:
		push_error("FAIL title animation")
		quit(1)
		return
	panel.present("defeat","GUERRA","Rodada perdida","",[["EQUIPE","0"],["INIMIGO","82"]])
	if panel.headline.text != "DERROTA" or panel.stat_panels[2].visible:
		push_error("FAIL defeat and two-card layout")
		quit(1)
		return
	panel.present("draw","PVP DESERTO","Sem vencedor","",[])
	if panel.headline.text != "EMPATE" or panel.stat_panels[0].visible:
		push_error("FAIL draw and empty layout")
		quit(1)
		return
	panel.present("neutral","GUERRA","Sem equipe local","Resultado conhecido",[["TICKETS","23"]])
	if panel.headline.text != "RESULTADO" or panel.stat_values[0].text != "23":
		push_error("FAIL spectator neutral result")
		quit(1)
		return
	var win_sound := panel._ceremony_tone(true)
	var loss_sound := panel._ceremony_tone(false)
	if win_sound.data.size()<16000 or loss_sound.data.size()<12000 or win_sound.data==loss_sound.data:
		push_error("FAIL original victory and defeat sound cues")
		quit(1)
		return
	print("PASS match result: victory/defeat/draw/neutral, stats, timer, animation, original cues")
	quit(0)
