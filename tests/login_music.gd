extends SceneTree
var failures: Array[String] = []
var checks := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func run() -> void:
	var before := AudioServer.bus_count
	var music := GameMenuMusic.new()
	root.add_child(music)
	for path: String in GameMenuMusic.PLAYLIST:
		var track := load(path) as AudioStreamMP3
		check(track!=null and track.get_length()>1 and track.data.size()>1000,"MP3 imported "+path.get_file())
	var last := ""
	music.queue.clear()
	var complete := true
	var distinct := true
	for cycle in range(20):
		var batch: Array[String] = []
		for i in range(6):
			var chosen := music.next_login_track()
			distinct = distinct and chosen!=last
			batch.append(chosen)
			last = chosen
		complete = complete and batch.size()==6 and batch.all(func(path: String): return batch.count(path)==1)
	check(complete,"twenty shuffled cycles play all six tracks once each")
	check(distinct,"no adjacent repeat across cycle boundaries")
	music.set_login_active(true)
	await create_timer(0.8).timeout
	check(music.playing and music.get_playback_position()>0.1 and music.current_login_track in GameMenuMusic.PLAYLIST,"login track actually advances")
	check(not (music.stream as AudioStreamMP3).loop,"individual login tracks do not loop forever")
	var previous := music.current_login_track
	music.finished.emit()
	check(music.playing and music.current_login_track!=previous,"finished signal advances to a different song")
	var keep := music.stream
	var position := music.get_playback_position()
	music.set_login_active(false)
	await create_timer(0.2).timeout
	check(music.stream==keep and music.get_playback_position()>position,"login success preserves the current track without restart")
	keep = music.stream
	position = music.get_playback_position()
	music.set_login_active(true)
	await create_timer(0.9).timeout
	check(music.stream==keep and music.get_playback_position()>position,"logout preserves current song and playback position")
	music.stream = music.original
	music.play()
	music.set_login_active(false)
	music.set_login_active(true)
	await create_timer(0.8).timeout
	check(music.stream==music.original and music.get_playback_position()>0.5,"original menu song also survives logout without a forced transition")
	music.finished.emit()
	check(music.playing and music.current_login_track in GameMenuMusic.PLAYLIST and not music.stream.loop,"natural finish advances shuffled playlist even while logged out")
	music.queue_free()
	await process_frame
	check(AudioServer.bus_count==before,"private music bus is released")
	var report := {"checks":checks,"failures":failures,"tracks":6,"shuffle_selections":120}
	FileAccess.open("res://tests/login-music-results.json",FileAccess.WRITE).store_string(JSON.stringify(report))
	print(JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
