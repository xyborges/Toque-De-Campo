extends RefCounted

# Infantry-only state. Selection is persistent; durability belongs to one life.
# BR keeps its own inventory and never enables this component.
const HP:=[0.,60.,100.,150.]
const RATIO:=[0.,.30,.40,.55]
const NAMES:=["Sem proteção","Leve","Padrão","Pesado"]
const WEIGHT:={"vest":[0.,3.,6.,10.],"helmet":[0.,1.,1.5,2.5]}
var enabled:=false
var life:=-1
var revision:=0
var gear: Dictionary={"vest":{"level":0,"durability":0.},"helmet":{"level":0,"durability":0.}}

static func level(id: String) -> int:
	return clampi(int(id.get_slice("_",1)),0,3)

func deploy(actor: GamePlayer) -> void:
	if actor.game and (actor.game.get_meta("battle_royale",false) or actor.game is NavalMode):return
	if not actor.has_meta("approved_loadout"):return
	if enabled and life==actor.life_id:return
	enabled=true;life=actor.life_id;revision=1
	var slots: Dictionary=actor.get_meta("approved_loadout",{})
	for kind in ["vest","helmet"]:
		var tier:=level(str(slots.get(kind,"")))
		gear[kind]={"level":tier,"durability":HP[tier]}
	refresh_visuals(actor)

func snapshot() -> Dictionary:
	return {"revision":revision,"gear":gear.duplicate(true)} if enabled else {}

func receive(actor: GamePlayer,packet_life: int,packet: Dictionary,broken: String="") -> bool:
	if packet_life!=actor.life_id or packet.is_empty():return false
	var incoming:=int(packet.get("revision",-1))
	if incoming<1 or (life==packet_life and incoming<=revision):return false
	var clean: Dictionary={}
	var raw: Variant=packet.get("gear",{})
	if not raw is Dictionary:return false
	for kind in ["vest","helmet"]:
		var item: Variant=raw.get(kind,{})
		if not item is Dictionary:return false
		var tier:=clampi(int(item.get("level",0)),0,3)
		var durability:=float(item.get("durability",0.))
		if not is_finite(durability) or durability<0. or durability>HP[tier]:return false
		clean[kind]={"level":tier if durability>0 else 0,"durability":durability if tier>0 else 0.}
	enabled=true;life=packet_life;revision=incoming;gear=clean
	refresh_visuals(actor)
	if broken in ["vest","helmet"]:play_break(actor,broken)
	return true

func multiplier() -> float:
	if not enabled:return 1.
	var kilograms:=0.
	for kind in ["vest","helmet"]:kilograms+=float(WEIGHT[kind][int(gear[kind].level)])
	return maxf(.80,1.-kilograms*.012)

func damage(actor: GamePlayer,amount: float,region: String,normal_damage: float) -> float:
	if not enabled or life!=actor.life_id:return normal_damage
	var kind:="helmet" if region=="head" else ("vest" if region in ["torso","chest","abdomen","abdomenPelvis"] else "")
	if kind.is_empty() or int(gear[kind].level)==0:return normal_damage
	var weapon:=GameWeapons.canonical(actor.last_impact_weapon)
	if GameWeapons.is_launcher(weapon) or weapon in ["tank","autocannon","missile","torpedo","tv","drone","water"]:return normal_damage
	var base:=amount*float(CombatRules.DAMAGE.get(region,1.))
	var item: Dictionary=gear[kind]
	var absorbed:=minf(float(item.durability),base*RATIO[int(item.level)])
	if absorbed<=0:return normal_damage
	item.durability=maxf(0.,float(item.durability)-absorbed);revision+=1
	var broken:=""
	if float(item.durability)<=0.:
		item.level=0;broken=kind;refresh_visuals(actor);play_break(actor,kind)
	if actor.game and actor.game.has_method("_protection_changed"):actor.game._protection_changed(actor,broken)
	return base-absorbed

func refresh_visuals(actor: GamePlayer) -> void:
	if not enabled or not is_instance_valid(actor.body_root):return
	if actor is WarPlayer or actor.has_meta("war_team"):
		for node in actor.body_root.find_children("*","MeshInstance3D",true,false):
			var kind:=str(node.get_meta("protection_slot",""))
			if kind in ["vest","helmet"]:node.visible=int(gear[kind].level)>0
	else:
		for kind in ["vest","helmet"]:
			var anchor: Node3D=actor.avatar_parts.get("head" if kind=="helmet" else "torso")
			if not anchor:continue
			var previous:=anchor.get_node_or_null("InfantryProtection"+kind)
			var tier:=int(gear[kind].level)
			if previous and int(previous.get_meta("level",-1))==tier:continue
			if previous:anchor.remove_child(previous);previous.queue_free()
			if tier>0:
				var piece:=load("res://modes/battle_royale/ui/equipment/"+kind+"_%d.tscn"%tier).instantiate() as Node3D
				piece.name="InfantryProtection"+kind;piece.set_meta("level",tier);anchor.add_child(piece)

func play_break(actor: GamePlayer,kind: String) -> void:
	if DisplayServer.get_name()=="headless" or not actor.is_inside_tree():return
	var sound:=AudioStreamPlayer3D.new();sound.name="ProtectionBreak";sound.bus="Armas";sound.max_distance=35.;sound.volume_db=-3.
	sound.stream=load("res://audio/ballistics/metal.wav");sound.pitch_scale=.70 if kind=="vest" else 1.18
	actor.add_child(sound);sound.position=Vector3(0,1.65 if kind=="helmet" else 1.15,0)
	sound.finished.connect(sound.queue_free);sound.play()
