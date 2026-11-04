extends VBoxContainer
class_name GameGlobalRanking

const KINDS:=["kills","kd","deaths","coins"]
const TITLES:=["TOP 10 ELIMINAÇÕES","TOP 10 K/D","TOP 10 MORTES","TOP 10 DINHEIRO"]
var accounts: NavalAccounts
var category:=0
var heading: Label
var updated: Label
var explanation: Label
var entries: Array[HBoxContainer]=[]
var data: Dictionary={}
var busy:=false
var retry_at:=0.0
var stale:=false

func cache_path() -> String:
	return NavalStorage.folder().path_join("global-ranking-"+accounts.api_url.sha256_text().left(12)+".json")

func _ready() -> void:
	name="GlobalRanking";add_theme_constant_override("separation",12)
	data=NavalStorage.read_json(cache_path())
	if not valid_payload(data): data={}
	var navigation:=HBoxContainer.new();add_child(navigation)
	GameUI.button(navigation,"‹",cycle.bind(-1)).custom_minimum_size=Vector2(56,42)
	heading=GameUI.label(navigation,"",24,FieldTheme.ACCENT)
	heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	GameUI.button(navigation,"›",cycle.bind(1)).custom_minimum_size=Vector2(56,42)
	var panel:=GameUI.panel(self);var table:=VBoxContainer.new();panel.add_child(table)
	var header:=HBoxContainer.new();table.add_child(header)
	GameUI.label(header,"POS.",12,FieldTheme.MUTED).custom_minimum_size.x=64
	GameUI.label(header,"JOGADOR",12,FieldTheme.MUTED).size_flags_horizontal=Control.SIZE_EXPAND_FILL
	GameUI.label(header,"ESTATÍSTICA",12,FieldTheme.MUTED).custom_minimum_size.x=130
	for i in 10:
		var row:=HBoxContainer.new();row.custom_minimum_size.y=30;table.add_child(row)
		GameUI.label(row,"",16,FieldTheme.ACCENT if i<3 else FieldTheme.MUTED).custom_minimum_size.x=64
		var player_name:=GameUI.label(row,"",17);player_name.size_flags_horizontal=Control.SIZE_EXPAND_FILL
		player_name.autowrap_mode=TextServer.AUTOWRAP_OFF;player_name.clip_text=true
		var value:=GameUI.label(row,"",17,FieldTheme.ACCENT if i<3 else FieldTheme.INK)
		value.custom_minimum_size.x=130;value.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
		entries.append(row)
	explanation=GameUI.label(self,"",13,FieldTheme.MUTED)
	updated=GameUI.label(self,"",12,FieldTheme.MUTED)
	visibility_changed.connect(func():
		if is_visible_in_tree(): refresh_remote()
	)
	render()

func cycle(direction: int) -> void:
	category=posmod(category+direction,KINDS.size());render()

func render() -> void:
	heading.text=TITLES[category]
	var list: Array=data.get("lists",{}).get(KINDS[category],[])
	for i in entries.size():
		var row:=entries[i]
		row.get_child(0).text=str(i+1)
		row.get_child(1).text=str(list[i].get("name","")) if i<list.size() else "—"
		row.get_child(1).tooltip_text=row.get_child(1).text
		var value: Variant=list[i].get(KINDS[category],0) if i<list.size() else null
		row.get_child(2).text=(str(int(value))+" moedas" if category==3 else ("%.2f"%float(value) if category==1 else str(int(value)))) if value!=null else "—"
	explanation.text="K/D disponível após %d eliminações e mortes somadas."%int(data.get("kd_min_participation",20)) if category==1 else "Estatísticas das contas no servidor central · atualização a cada 60 minutos."
	if data.is_empty(): updated.text="Carregando ranking…" if busy else "Ranking ainda indisponível. Entre na conta e tente novamente."
	else:
		var stamp:=Time.get_datetime_dict_from_unix_time(int(data.get("generated_at",0)))
		updated.text="Última atualização: %02d/%02d · %02d:%02d UTC%s"%[stamp.day,stamp.month,stamp.hour,stamp.minute," · DADOS EM CACHE / CONEXÃO INDISPONÍVEL" if stale else ""]

func refresh_remote() -> void:
	var now:=Time.get_unix_time_from_system()
	if busy or now<retry_at: return
	if not data.is_empty() and now<float(data.get("expires_at",0)): render();return
	busy=true;stale=not data.is_empty();render()
	var result:=await accounts.call_api("rankings")
	if not is_inside_tree(): return
	busy=false;retry_at=now+30
	if result.get("ok",false) and valid_payload(result.get("rankings",{})):
		data=result.rankings.duplicate(true);stale=false
		NavalStorage.write_json(cache_path(),data)
	else: stale=not data.is_empty()
	render()

static func valid_payload(value: Variant) -> bool:
	if not value is Dictionary or not value.get("lists") is Dictionary: return false
	if not _valid_number(value.get("generated_at")) or not _valid_number(value.get("expires_at")): return false
	if float(value.generated_at)<=0 or float(value.expires_at)<float(value.generated_at): return false
	if value.has("kd_min_participation") and not _valid_number(value.kd_min_participation): return false
	for kind in KINDS:
		var list: Variant=value.lists.get(kind)
		if not list is Array or list.size()>10: return false
		for entry in list:
			if not entry is Dictionary or not entry.get("name") is String: return false
			for field in ["kills","deaths","coins","kd"]:
				if not _valid_number(entry.get(field)): return false
	return true

static func _valid_number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value)>=0 and float(value)<=1.0e12
