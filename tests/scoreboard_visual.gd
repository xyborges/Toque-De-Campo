extends SceneTree
var game: Node3D
var checks:=0
var failures: Array[String]=[]
var captures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1;print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)
func fill(count: int,teams:=false) -> void:
	game.match_stats.clear()
	for i in count:
		game.match_stats.register(i+1,"Jogador "+str(i+1),i%2 if teams else -1)
		var row: Dictionary=game.match_stats.rows[i+1]
		row.points=(count-i)*125;row.kills=count-i;row.deaths=i;row.assists=i%4;row.damage=245.7*(count-i);row.objective=75*(i%3);row.ping=-1 if i==0 else 12+i*7
	game.context_override={"mode":"GUERRA · CONQUISTA" if teams else "DESERTO · TODOS CONTRA TODOS","map":"LINHA DE FRENTE" if teams else "POSTO MILITAR","seconds":657,"time_label":"RESTANTE","network":true,"teams":teams,"tickets":"EQUIPE 1 · 300 TICKETS     |     EQUIPE 2 · 240 TICKETS" if teams else "","objectives":"A · EQUIPE 1     B · NEUTRO     C · EQUIPE 2" if teams else "A · CASINHA · Jogador 1 controla"}
	game.scoreboard._update_context();game.scoreboard.refresh()
func shot(label: String) -> void:
	await create_timer(.12).timeout;RenderingServer.force_draw(false)
	var path:="res://work/scoreboard-"+label+".png";root.get_texture().get_image().save_png(path);captures.append(path)
func run() -> void:
	game=load("res://tests/scoreboard_context_fixture.gd").new();game.set_meta("test_mode",true);root.add_child(game)
	game.mode="training";game.map_kind="sandbox";game._enter_match_world();game.set_physics_process(false)
	var actor: GamePlayer=game._spawn_player(1,true,false,Vector3.ZERO);actor.set_physics_process(false)
	game.mode="pvp"
	var board: GameScoreboard=game.scoreboard
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var key:=InputEventKey.new();key.keycode=KEY_TAB;key.pressed=true
	for dimensions in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,768)]:
		root.size=dimensions;await process_frame;await process_frame
		for count in [1,3,6,12]:
			fill(count,count==12);board._input(key)
			await shot("%dx%d-%d"%[dimensions.x,dimensions.y,count])
			var rect:=board.panel.get_global_rect();var viewport:=root.get_visible_rect()
			check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=viewport.size.x+2 and rect.end.y<=viewport.size.y+2,"panel stays inside viewport: %s / %d players"%[str(dimensions),count])
			check(rect.size.y<viewport.size.y*.9,"panel leaves proportional margins: %s / %d players"%[str(dimensions),count])
			if count==1: check(rect.size.y<viewport.size.y*.55,"one player has a compact balanced panel")
	check(board.groups[0].rows.get_child_count()==6 and board.groups[1].rows.get_child_count()==6,"twelve players are split into two six-player teams")
	check(board.tickets.text.contains("300") and board.tickets.text.contains("240") and board.objective.text.contains("NEUTRO"),"tickets and objectives are displayed from mode state")
	check(absf(board.groups[0].headers.points.global_position.x-board.row_pool[0].cells.points.global_position.x)<1,"column headings align with reusable player cells")
	check(board.row_pool[0].cells.kd.text=="12.00" and board.row_pool[0].cells.kills.text=="12" and board.row_pool[0].cells.damage.text=="2948","zero deaths and fractional damage use readable safe formatting")
	var before:=board.refresh_count;var nodes:=get_node_count()
	for i in 100: board.refresh()
	check(board.refresh_count==before and nodes==get_node_count(),"unchanged frames do not rebuild or refresh table components")
	game.match_stats.award(12,2000,"ui:leader");board.refresh()
	check(int(board.row_pool[0].id)==12 and board.lines[0].text=="2125","score change reorders rows without leading zeros")
	game.match_stats.remove(12);board.refresh()
	check(board.row_pool[11].node.visible==false,"disconnect removes a row without rebuilding the table")
	game.match_stats.register(44,"Entrou agora",1);board.refresh()
	check(board.row_pool[11].cells.ping.text=="—","unmeasured latency is never displayed as zero milliseconds")
	check(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and not paused,"TAB does not pause gameplay or release camera controls")
	game.context_override.seconds=301;game.context_override.tickets="EQUIPE 1 · 100 TICKETS     |     EQUIPE 2 · 90 TICKETS";board._update_context()
	check(board.timer.text.ends_with("5:01") and board.tickets.text.contains("100"),"timer and tickets update while the scoreboard is open")
	game.context_override.network=false;board._update_context();board.refresh()
	check(not board.groups[0].headers.ping.visible and not board.row_pool[0].cells.ping.visible,"offline hides network-only columns")
	game.context_override.teams=false;board._update_context();board.refresh()
	check(board.groups[0].node.visible and not board.groups[1].node.visible and not board.groups[2].node.visible,"changing mode regroups cached rows without a fabricated stats update")
	key.pressed=false;board._input(key);check(not board.visible,"releasing TAB closes the scoreboard")
	var prior_focus:=root.gui_get_focus_owner()
	key.pressed=true;Input.parse_input_event(key);await process_frame
	check(board.visible and root.gui_get_focus_owner()==prior_focus,"real TAB dispatch does not move GUI focus away from combat")
	key.pressed=false;Input.parse_input_event(key);await process_frame
	check(not board.visible and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED,"real TAB release restores the unobstructed gameplay view")
	game.context_override={"mode":"GUERRA · CONQUISTA · OFFLINE","map":"LINHA DE FRENTE","seconds":420,"time_label":"RESTANTE","network":false,"teams":true,"tickets":"EQUIPE 1 · 300 TICKETS     |     EQUIPE 2 · 280 TICKETS","objectives":"A · EQUIPE 1     B · NEUTRO     C · NEUTRO"}
	board.show()
	check(board.heading.text.contains("OFFLINE") and board.map_label.text=="LINHA DE FRENTE" and board.timer.text.ends_with("7:00"),"programmatic opening initializes mode, map and timer immediately")
	check(board.groups[0].node.visible and board.groups[1].node.visible and not board.groups[0].headers.ping.visible and not board.row_pool[0].cells.ping.visible,"programmatic offline opening immediately groups teams and hides latency")
	var opened_refresh:=board.refresh_count;board.refresh();board._visibility_changed()
	check(board.refresh_count==opened_refresh,"repeated opening callbacks do not rebuild unchanged player rows")
	await shot("programmatic-offline")
	board.hide()
	game.show_menu();root.size=Vector2i(1280,800);await process_frame
	var widget: GameGlobalRanking=game.main_menu.ranking_widget
	var accounts=load("res://tests/ranking_accounts_fixture.gd").new();root.add_child(accounts);widget.accounts=accounts
	var values: Array=[]
	for i in 10: values.append({"name":"Jogador "+str(i+1),"kills":100-i*7,"deaths":30-i,"coins":2500-i*100,"kd":float(100-i*7)/float(30-i)})
	var data: Dictionary={"generated_at":int(Time.get_unix_time_from_system()),"expires_at":int(Time.get_unix_time_from_system())+3600,"kd_min_participation":20,"lists":{"kills":values,"kd":values,"deaths":values,"coins":values}}
	accounts.response={"ok":true,"rankings":data}
	widget.data={};widget.retry_at=0;game.main_menu.ranking_overlay.show();await create_timer(.15).timeout
	check(widget.data==data and accounts.calls==1,"ranking fetch is asynchronous and uses the existing account service")
	await widget.refresh_remote();check(accounts.calls==1,"opening a fresh cached ranking does not query again")
	for i in 4: widget.cycle(1)
	check(widget.category==0 and widget.heading.text=="TOP 10 ELIMINAÇÕES","ranking arrows cycle through all four classifications")
	await shot("ranking-dropdown")
	var right: Rect2=game.main_menu.ranking_panel.get_global_rect()
	check(right.get_center().x>root.get_visible_rect().size.x*.6 and game.main_menu.pages.play.visible,"ranking is a separate right-side dropdown over the main menu")
	widget.data.expires_at=0;widget.retry_at=0;accounts.response={"ok":false}
	await widget.refresh_remote();check(widget.stale and not widget.data.is_empty() and widget.updated.text.contains("CACHE"),"connection failure keeps and labels the last valid ranking")
	check(not GameGlobalRanking.valid_payload({"lists":{}}),"invalid cached payload cannot break the menu")
	var broken:=data.duplicate(true);broken.generated_at=[]
	check(not GameGlobalRanking.valid_payload(broken),"invalid ranking timestamps are rejected before rendering")
	broken=data.duplicate(true);broken.lists.kills[0].coins=INF
	check(not GameGlobalRanking.valid_payload(broken),"non-finite ranking values are rejected before formatting")
	check(widget.entries[0].get_child(0).text=="1","global ranking positions also avoid leading zeros")
	game.queue_free();accounts.queue_free();await process_frame;await process_frame
	var report: Dictionary={"checks":checks,"failures":failures,"captures":captures,"note":"UI population uses controlled fixture statistics; this is not a twelve-player FPS benchmark"}
	NavalStorage.write_json("res://tests/scoreboard-visual-results.json",report);print(JSON.stringify(report));quit(0 if failures.is_empty() else 1)
