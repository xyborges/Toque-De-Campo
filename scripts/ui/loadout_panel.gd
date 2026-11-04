extends VBoxContainer
class_name GameLoadoutPanel
var game: Node
var checks: Dictionary={}
var grenade_option: CheckBox

func _ready() -> void:
	GameUI.label(self,"EQUIPAMENTO DA PRÓXIMA PARTIDA",14,FieldTheme.ACCENT)
	var grid:=GridContainer.new();grid.columns=3;add_child(grid)
	for id in GameWeapons.INFANTRY_IDS:
		var check:=CheckBox.new();check.text=GameWeapons.ITEMS[id].name
		check.disabled=id not in game.profile.owned
		check.button_pressed=id in game.profile.get("loadout",game.profile.owned)
		grid.add_child(check);checks[id]=check
		check.toggled.connect(func(_value): save())
	grenade_option=CheckBox.new();grenade_option.text="Granadas · 2 por vida"
	grenade_option.button_pressed=bool(game.profile.get("grenades",true))
	add_child(grenade_option);grenade_option.toggled.connect(func(_value): save())
	GameUI.label(self,"G ou 3 equipa. Segure clique para armar; solte para lançar. Pavio: 5 s.",12,FieldTheme.MUTED)

func save() -> void:
	var selected: Array=[]
	for id in checks:
		if checks[id].button_pressed and id in game.profile.owned: selected.append(id)
	if selected.is_empty():
		var first: String=str(game.profile.owned[0]);selected.append(first);checks[first].set_pressed_no_signal(true)
	game.profile["loadout"]=selected
	game.profile["grenades"]=grenade_option.button_pressed
	if game.profile.get("equipped","ak") not in selected: game.profile["equipped"]=selected[0]
	game._save_profile()
