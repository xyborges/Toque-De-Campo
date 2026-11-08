extends Control
class_name GameNavalHUD
var mode: NavalMode
var hp_bar: ProgressBar
var telemetry: Label
var rank: Label
var weapon_row: HBoxContainer
var aim_label: Label
var notification: Label
var reticle: ColorRect
var ammo: Label
var turret_state: Label
var reload: ProgressBar
var match_dashboard: GameMatchDashboard
func _ready() -> void:
	add_to_group("game_hud")
	name = "NavalHUD"
	theme = GameUI.THEME
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hull := GameUI.panel(self)
	GameUI.rect(hull,22,-203,265,-100,Vector2(0,1))
	var data := VBoxContainer.new()
	hull.add_child(data)
	telemetry = GameUI.label(data,"",15)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size.y = 6
	data.add_child(hp_bar)
	var weapon := GameUI.panel(self)
	GameUI.rect(weapon,-320,-205,-22,-100,Vector2.ONE)
	var armament := VBoxContainer.new()
	weapon.add_child(armament)
	ammo = GameUI.label(armament,"",24,FieldTheme.ACCENT)
	reload = ProgressBar.new()
	reload.custom_minimum_size.y = 4
	reload.show_percentage = false
	armament.add_child(reload)
	var board := GameUI.panel(self)
	GameUI.rect(board,-285,70,-22,215,Vector2(1,0))
	rank = GameUI.label(board,"",12)
	rank.tab_stops = PackedFloat32Array([140,175])
	rank.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	rank.autowrap_mode = TextServer.AUTOWRAP_OFF
	weapon_row = HBoxContainer.new()
	weapon_row.anchor_left = 0.0
	weapon_row.anchor_right = 1.0
	weapon_row.anchor_top = 1
	weapon_row.anchor_bottom = 1
	weapon_row.offset_left = 22
	weapon_row.offset_right = -22
	weapon_row.offset_top = -84
	weapon_row.offset_bottom = -22
	weapon_row.add_theme_constant_override("separation",8)
	add_child(weapon_row)
	reticle = ColorRect.new()
	reticle.color = FieldTheme.INK
	GameUI.rect(reticle,-2,-2,2,2,Vector2(0.5,0.5))
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(reticle)
	aim_label = GameUI.label(self,"",12)
	GameUI.rect(aim_label,-230,20,230,48,Vector2(0.5,0.5))
	aim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turret_state = GameUI.label(self,"",11,FieldTheme.MUTED)
	GameUI.rect(turret_state,-230,44,230,90,Vector2(0.5,0.5))
	turret_state.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification = GameUI.label(self,"",19,FieldTheme.ACCENT)
	notification.anchor_left = 0.20
	notification.anchor_right = 0.80
	notification.offset_top = 110
	notification.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_dashboard = GameMatchDashboard.new()
	add_child(match_dashboard)
	GameUI.rect(match_dashboard,-310,16,310,158,Vector2(.5,0))
	GameUI.hud_menu_button(self,func(): mode._open("pause"))
func refresh(ship: NavalShip) -> void:
	telemetry.text = "%s · %d / %d\n%.1f m/s · INTEGRIDADE" % [ship.spec.name.to_upper(),ship.hp,ship.spec.hp,absf(ship.speed)]
	var data: Dictionary = NavalCatalog.WEAPONS[mode.selected]
	ammo.text = "%s\n%03d / %d%s" % [data.name.to_upper(),int(ship.ammo[mode.selected]),int(data.ammo)," · %.1f s" % ship.reload_left if ship.reload_left>0 else ""]
	var cooldown := float(ship.waits.get(mode.selected,0.0))
	if ship.reload_left<=0:
		if int(ship.ammo[mode.selected])<=0: ammo.text += " · R: RECARREGAR"
		elif cooldown>0.15: ammo.text += " · PRONTA EM %.1f s" % cooldown
	reload.visible = ship.reload_left>0
	reload.value = 100.0*(1.0-ship.reload_left/maxf(float(data.reload),0.001))
	var states: Array[String] = []
	for id in ship.turrets:
		var turret: NavalTurret = ship.turrets[id]
		states.append("%s %s" % [{"lightMG":"L","heavyMG":"P","missile":"M","torpedo":"T"}[id],"BLOQUEADA" if turret.blocked else ("PRONTA" if turret.reachable else "LIMITE")])
	turret_state.text = " · ".join(states)
	match_dashboard.update_naval(mode.ships.size(),"SUBMARINO" if ship.kind=="submarine" else "SUPERFÍCIE")
