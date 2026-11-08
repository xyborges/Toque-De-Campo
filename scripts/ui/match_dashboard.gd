extends Control
class_name GameMatchDashboard

# One compact, non-interactive information hierarchy for every battle mode.
# All displayed values come from the existing mode/authority snapshots.
const WIDTH := 620.0
const HEIGHT := 142.0
const SECTORS := ["A", "B", "C", "D", "E"]

var view := ""
var model: Dictionary = {}

func _ready() -> void:
	name = "MatchDashboard"
	theme = GameUI.THEME
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(WIDTH, HEIGHT)

func _present(kind: String, values: Dictionary) -> void:
	if kind == view and values == model:
		return
	view = kind
	model = values.duplicate(true)
	queue_redraw()

func update_state(team: int, scores: Array, objectives: Dictionary, time_left: int) -> void:
	# Fixed team order prevents the score columns changing sides on respawn.
	var frontline := WarFavelaFrontline.enabled(WarRules.CURRENT_OPERATION)
	var visible: Array[Dictionary] = []
	for id in SECTORS:
		var definition: Dictionary = WarRules.OBJECTIVES.get(id, {})
		if not bool(definition.get("active", false)):
			continue
		var record: Dictionary = objectives.get(id, {})
		visible.append({
			"id": id, "owner": int(record.get("owner", -1)),
			"contested": bool(record.get("contested", false)),
			"progress": clampf(float(record.get("progress", 0.0)), 0.0, 1.0),
			"side": int(record.get("side", -1)),
			"active": frontline and WarFavelaFrontline.can_capture(objectives, id),
			"name": str(definition.get("name", id))
		})
	var focus := WarFavelaFrontline.active_id(objectives) if frontline else ""
	var left := maxi(0, int(scores[0])) if scores.size() > 0 else 0
	var right := maxi(0, int(scores[1])) if scores.size() > 1 else 0
	_present("conquest", {
		"mode": "LINHA DE FRENTE" if frontline else "CONQUISTA",
		"map": WarRules.map_name().to_upper(),
		"left_label": WarRules.team_name(0).to_upper(),
		"right_label": WarRules.team_name(1).to_upper(),
		"left_value": str(left), "right_value": str(right),
		"seconds": maxi(0, time_left), "clock_label": "RESTANTE",
		"max_tickets": WarRules.START_TICKETS, "left_tickets": left,
		"right_tickets": right, "own_team": team,
		"sectors": visible, "focus": focus
	})

func update_survival(alive: int, total: int, kills: int, seconds: int, closing: bool, phase: String) -> void:
	var state := "AGUARDANDO" if phase == "waiting" else ("ENCERRADA" if phase == "finished" else ("ZONA FECHANDO" if closing else "PRÓXIMA ZONA"))
	_present("survival", {
		"mode": "BATTLE ROYALE", "map": "DESERTO AFEGÃO",
		"left_label": "SOBREVIVENTES", "right_label": "ABATES",
		"left_value": "%d/%d" % [maxi(0, alive), maxi(0, total)],
		"right_value": str(maxi(0, kills)),
		"seconds": maxi(0, seconds), "clock_label": "ZONA",
		"state": state, "phase": phase
	})

func update_naval(commanders: int, vessel: String) -> void:
	_present("naval", {
		"mode": "PVP NAVAL", "map": "BATALHA MARÍTIMA",
		"left_label": "COMANDANTES", "right_label": "VEÍCULO",
		"left_value": str(maxi(0, commanders)),
		"right_value": vessel.to_upper(),
		"clock_label": "PARTIDA", "clock_value": "EM CURSO",
		"state": "COMBATE NAVAL"
	})

func update_arena(mode_label: String, map_label: String, seconds: int, remaining: bool, players: int, kills: int, detail: String = "") -> void:
	_present("arena", {
		"mode": mode_label.to_upper(), "map": map_label.to_upper(),
		"left_label": "JOGADORES", "right_label": "ABATES",
		"left_value": str(maxi(0, players)), "right_value": str(maxi(0, kills)),
		"seconds": maxi(0, seconds),
		"clock_label": "RESTANTE" if remaining else "DECORRIDO",
		"state": detail.to_upper().left(64) if not detail.is_empty() else "COMBATE EM ANDAMENTO"
	})

func visible_sector_ids() -> Array[String]:
	var ids: Array[String] = []
	for item in model.get("sectors", []):
		ids.append(str(item.get("id", "")))
	return ids

func _clock_text() -> String:
	if model.has("clock_value"):
		return str(model.clock_value)
	var seconds := int(model.get("seconds", 0))
	return "%02d:%02d" % [seconds / 60, seconds % 60]

func _letter(font: Font, value: String, x: float, y: float, pixels: int, color: Color, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	# Right-aligned draw_string expects the left edge of its alignment box.
	var origin := x - width if alignment == HORIZONTAL_ALIGNMENT_RIGHT and width > 0.0 else x
	draw_string(font, Vector2(origin, y), value, alignment, width, pixels, color)

func _panel(rect: Rect2, fill: Color, edge: Color = FieldTheme.BORDER) -> void:
	draw_rect(rect, fill, true)
	draw_rect(rect, edge, false, 1.0)

func _team_meter(x: float, width: float, tickets: int, color: Color) -> void:
	# Game rules are authoritative; bars only visualize already synced tickets.
	draw_rect(Rect2(x, 75, width, 3), FieldTheme.BORDER, true)
	var remaining := clampf(float(tickets) / maxf(1.0, float(model.get("max_tickets", 1))), 0.0, 1.0)
	draw_rect(Rect2(x, 75, width * remaining, 3), color, true)

func _draw_conquest_footer(font: Font) -> void:
	var sectors: Array = model.get("sectors", [])
	if sectors.is_empty():
		_letter(font, "SEM OBJETIVOS ATIVOS", 14, 125, 12, FieldTheme.MUTED)
		return
	var count := sectors.size()
	var step := minf(69.0, 510.0 / float(count))
	var item_width := minf(56.0, step - 9.0)
	var start := (WIDTH - count * step + step - item_width) * 0.5
	var focus := str(model.get("focus", ""))
	var friendly := 0
	var enemy := 0
	var disputed := ""
	var capturing := ""
	var capture_side := -1
	var capture_progress := 0.0
	for i in count:
		var item: Dictionary = sectors[i]
		var owner := int(item.get("owner", -1))
		if owner == 0: friendly += 1
		if owner == 1: enemy += 1
		if bool(item.get("contested", false)): disputed = str(item.get("id", ""))
		if float(item.get("progress", 0.0)) > capture_progress and int(item.get("side", -1)) in [0, 1]:
			capturing = str(item.get("id", ""))
			capture_side = int(item.get("side", -1))
			capture_progress = float(item.get("progress", 0.0))
		var at := start + i * step
		var selected := bool(item.get("active", false))
		var tint := FieldTheme.ACCENT if owner == 0 else (FieldTheme.BAD if owner == 1 else FieldTheme.MUTED)
		var fill := FieldTheme.HOVER if selected else FieldTheme.FIELD
		_panel(Rect2(at, 88, item_width, 26), fill, FieldTheme.ACCENT if selected else tint.darkened(0.40))
		draw_rect(Rect2(at + 1, 88, item_width - 2, 3), tint, true)
		if selected:
			draw_rect(Rect2(at - 3, 85, item_width + 6, 32), FieldTheme.ACCENT, false, 1.2)
		if bool(item.get("contested", false)):
			draw_rect(Rect2(at + 3, 108, item_width - 6, 3), FieldTheme.BAD, true)
		elif float(item.get("progress", 0.0)) > 0:
			var side := int(item.get("side", -1))
			var capture_color := FieldTheme.ACCENT if side == 0 else (FieldTheme.BAD if side == 1 else FieldTheme.MUTED)
			draw_rect(Rect2(at + 3, 109, (item_width - 6) * clampf(float(item.get("progress", 0.0)), 0.0, 1.0), 2), capture_color, true)
		_letter(font, str(item.get("id", "")), at, 107, 16, FieldTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, item_width)
		if i < count - 1:
			draw_line(Vector2(at + item_width + 2, 101), Vector2(at + step - 2, 101), FieldTheme.BORDER, 1.5)
	var foot := ""
	if not disputed.is_empty():
		foot = "SETOR %s EM DISPUTA" % disputed
	elif not capturing.is_empty():
		var own := int(model.get("own_team", -1))
		var action := "CAPTURANDO" if capture_side == own else "AVANÇO INIMIGO"
		if own not in [0, 1]: action = "CAPTURA EM ANDAMENTO"
		foot = "%s %s  ·  %d%%" % [action, capturing, roundi(capture_progress * 100.0)]
	elif not focus.is_empty():
		var focus_name := focus
		for sector in sectors:
			if str(sector.get("id", "")) == focus:
				focus_name = str(sector.get("name", focus)).to_upper()
				break
		foot = "ALVO %s  ·  %s" % [focus, focus_name]
	else:
		foot = "CONTROLE  %d  /  %d  /  %d NEUTROS" % [friendly, enemy, count - friendly - enemy]
	_letter(font, foot.left(66), 14, 133, 12, FieldTheme.ACCENT if not focus.is_empty() or not capturing.is_empty() else FieldTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, WIDTH - 28)

func _draw() -> void:
	if view.is_empty():
		return
	var scale := minf(1.0, size.x / WIDTH)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale, scale))
	var font := get_theme_default_font()
	_panel(Rect2(0, 0, WIDTH, HEIGHT), FieldTheme.PANEL)
	draw_rect(Rect2(0, 0, WIDTH, 3), FieldTheme.ACCENT, true)
	_letter(font, str(model.get("map", "")), 16, 22, 12, FieldTheme.MUTED)
	_letter(font, str(model.get("mode", "")), WIDTH - 16, 22, 12, FieldTheme.ACCENT, HORIZONTAL_ALIGNMENT_RIGHT, 260)
	draw_line(Vector2(16, 29), Vector2(WIDTH - 16, 29), FieldTheme.BORDER, 1.0)
	var left_label := str(model.get("left_label", ""))
	var right_label := str(model.get("right_label", ""))
	var left_color := FieldTheme.ACCENT
	var right_color := FieldTheme.BAD if view == "conquest" else FieldTheme.ACCENT
	_letter(font, left_label.left(22), 16, 48, 12, left_color)
	_letter(font, right_label.left(22), WIDTH - 16, 48, 12, right_color, HORIZONTAL_ALIGNMENT_RIGHT, 204)
	_letter(font, str(model.get("left_value", "")), 16, 71, 25, FieldTheme.INK)
	_letter(font, str(model.get("right_value", "")), WIDTH - 16, 71, 25, FieldTheme.INK, HORIZONTAL_ALIGNMENT_RIGHT, 205)
	_panel(Rect2(235, 35, 150, 44), FieldTheme.FIELD, FieldTheme.BORDER)
	_letter(font, str(model.get("clock_label", "")), 235, 49, 11, FieldTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER, 150)
	_letter(font, _clock_text(), 235, 72, 23 if view != "naval" else 17, FieldTheme.INK, HORIZONTAL_ALIGNMENT_CENTER, 150)
	if view == "conquest":
		_team_meter(16, 195, int(model.get("left_tickets", 0)), left_color)
		_team_meter(WIDTH - 211, 195, int(model.get("right_tickets", 0)), right_color)
		var team := int(model.get("own_team", -1))
		if team == 0: draw_circle(Vector2(7, 43), 3.5, FieldTheme.ACCENT)
		if team == 1: draw_circle(Vector2(WIDTH - 7, 43), 3.5, FieldTheme.ACCENT)
		_draw_conquest_footer(font)
	else:
		var state := str(model.get("state", ""))
		_panel(Rect2(138, 93, WIDTH - 276, 27), FieldTheme.FIELD, FieldTheme.BORDER)
		var state_color := FieldTheme.BAD if state == "ZONA FECHANDO" else FieldTheme.ACCENT
		_letter(font, state, 138, 112, 14, state_color, HORIZONTAL_ALIGNMENT_CENTER, WIDTH - 276)
		_letter(font, "DADOS DA PARTIDA", 16, 135, 10, FieldTheme.MUTED)
		_letter(font, str(model.get("mode", "")), WIDTH - 16, 135, 10, FieldTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT, 175)
