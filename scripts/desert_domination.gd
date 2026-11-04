extends Node3D
class_name DesertDomination

const CENTER:=Vector3(0,0,-7)
const SUPPLY:=Vector3(-3.35,0,-7)
const CAPTURE_SECONDS:=6.0
const SCORE_TARGET:=120
const ROUND_SECONDS:=600.0
const BREAK_SECONDS:=12.0
const SUPPLY_COOLDOWN:=20.0
var game: Node
var phase:="waiting"
var owner_id:=0
var capturing_id:=0
var progress:=0.0
var scores: Dictionary={}
var supplies: Dictionary={}
var seconds:=0.0
var remaining:=ROUND_SECONDS
var break_left:=0.0
var winner_id:=0
var winner_name:=""
var contested:=false
var occupants: Array[int]=[]
var score_clock:=0.0
var sync_clock:=0.0
var marker: Label3D
var supply_requests: Dictionary={}
var supply_stock: Dictionary={}

func build(service: Node) -> void:
	game=service
	name="DesertDomination"
	# Capacity data has no assets and is immutable. Do not deep-copy weapon
	# presentation/ballistic dictionaries during an interaction.
	for id in GameWeapons.INFANTRY_IDS:
		if GameWeapons.ITEMS[id].kind=="firearm": supply_stock[id]=Vector2i(int(GameWeapons.ITEMS[id].mag),int(CombatRules.WEAPON_OPTIONS[id].reserve))
	if DisplayServer.get_name()!="headless" and not game.dedicated_pvp:
		marker=Label3D.new();marker.text="A · CASINHA";marker.font_size=30;marker.pixel_size=.012
		marker.billboard=BaseMaterial3D.BILLBOARD_ENABLED;marker.modulate=FieldTheme.ACCENT
		marker.position=CENTER+Vector3.UP*5.4;add_child(marker)

static func inside(point: Vector3) -> bool:
	# The roof does not count: feet must be on an interior floor, not on top
	# of the building or beneath its foundation.
	return absf(point.x)<7.25 and point.z>-12.15 and point.z< -1.85 and point.y>-.10 and point.y<2.1

func authority() -> bool: return not game.online or multiplayer.is_server()

func blocked() -> bool: return game.online and phase=="finished"

func _physics_process(delta: float) -> void:
	if not authority(): return
	seconds+=delta
	if game.online: step(delta)
	sync_clock+=delta
	if game.online and sync_clock>=.5:
		sync_clock=0;game._broadcast("remote_domination_state",[snapshot()]);game.update_hud()

func step(delta: float) -> void:
	var alive: Array[GamePlayer]=[]
	for id in scores.keys():
		if not game.players.has(id): scores.erase(id)
	for id in supplies.keys():
		if not game.players.has(id): supplies.erase(id)
	for id in supply_requests.keys():
		if not game.players.has(id): supply_requests.erase(id)
	for actor: GamePlayer in game.players.values():
		if actor.is_npc: continue
		if not scores.has(actor.peer_id): scores[actor.peer_id]=0
		if actor.hp>0: alive.append(actor)
	if not game.players.has(owner_id): owner_id=0
	if phase=="finished":
		break_left=maxf(0,break_left-delta)
		if break_left<=0: reset_round()
		return
	var participants:=0
	for actor: GamePlayer in game.players.values():
		if not actor.is_npc: participants+=1
	if participants<2:
		phase="waiting";occupants.clear();capturing_id=0;progress=0;contested=false;score_clock=0
		return
	phase="active";remaining=maxf(0,remaining-delta);occupants.clear()
	for actor in alive:
		if inside(actor.global_position): occupants.append(actor.peer_id)
	contested=occupants.size()>1
	if occupants.size()==1:
		var candidate:=occupants[0]
		if owner_id==candidate:
			capturing_id=0;progress=0;score_clock+=delta
			while score_clock>=1:
				score_clock-=1;scores[candidate]=int(scores.get(candidate,0))+1
				if int(scores[candidate])>=SCORE_TARGET: finish(candidate);break
		else:
			score_clock=0
			if capturing_id!=candidate: capturing_id=candidate;progress=0
			progress=minf(CAPTURE_SECONDS,progress+delta)
			if progress>=CAPTURE_SECONDS:
				if owner_id!=0: game.match_stats.award(candidate,75,"neutral:house:"+str(seconds),"objective")
				game.match_stats.award(candidate,150,"capture:house:"+str(seconds),"objective")
				owner_id=candidate;capturing_id=0;progress=0
	else:
		# Contested capture pauses. Leaving the house loses partial progress.
		score_clock=0
		if occupants.is_empty(): capturing_id=0;progress=0
	if remaining<=0 and phase!="finished":
		var high:=-1;var winner:=0;var tied:=false
		for id in scores:
			if int(scores[id])>high: high=int(scores[id]);winner=int(id);tied=false
			elif int(scores[id])==high: tied=true
		finish(0 if tied else winner)

func finish(id: int) -> void:
	phase="finished";winner_id=id;break_left=BREAK_SECONDS
	var actor:=game.players.get(id) as GamePlayer
	winner_name=player_name(id) if is_instance_valid(actor) else "EMPATE"
	for player: GamePlayer in game.players.values(): player.clear_aim();player.cancel_reload()
	if game.online: game._broadcast("remote_domination_state",[snapshot()])

func reset_round() -> void:
	game.match_stats.clear()
	phase="waiting";owner_id=0;capturing_id=0;progress=0;remaining=ROUND_SECONDS
	winner_id=0;winner_name="";score_clock=0;contested=false;scores.clear()
	for actor: GamePlayer in game.players.values():
		if actor.is_npc: continue
		actor.hp=0;game._reset_server_player(actor)

func snapshot() -> Dictionary:
	var supply_left: Dictionary={}
	for id in supplies: supply_left[id]=maxf(0,float(supplies[id])-seconds)
	return {"phase":phase,"owner":owner_id,"capturing":capturing_id,"progress":progress,"scores":scores.duplicate(),"remaining":remaining,"winner":winner_id,"winner_name":winner_name,"break_left":break_left,"contested":contested,"occupants":occupants.duplicate(),"supply_left":supply_left}

func receive(state: Dictionary) -> void:
	phase=str(state.phase);owner_id=int(state.owner);capturing_id=int(state.capturing);progress=float(state.progress)
	scores=state.scores.duplicate();remaining=float(state.remaining);winner_id=int(state.winner)
	winner_name=str(state.winner_name);break_left=float(state.break_left);contested=bool(state.contested)
	occupants.assign(state.occupants)
	for id in state.supply_left: supplies[id]=Time.get_ticks_msec()*.001+float(state.supply_left[id])
	if blocked() and is_instance_valid(game.local_player): game.local_player.clear_aim()
	game.update_hud()

func supply_wait(id: int) -> float:
	var clock:=seconds if authority() else Time.get_ticks_msec()*.001
	return maxf(0,float(supplies.get(id,0))-clock)

func replenish(actor: GamePlayer,life: int) -> String:
	if not authority() or not is_instance_valid(actor) or actor.is_npc or actor.hp<=0 or actor.life_id!=life: return ""
	if game.waiting_for_pvp() or blocked(): return "Aguarde a partida."
	if not inside(actor.global_position) or actor.global_position.distance_to(SUPPLY)>2.6: return "Aproxime-se da caixa dentro da casa."
	if not actor.grenade_held_id.is_empty() or actor.grenade_prime_pending or actor.grenade_throw_left>0: return "Guarde a granada antes de reabastecer."
	if supply_wait(actor.peer_id)>0:
		# One prompt for a key/RPC burst, without allocating one HUD timer for
		# every duplicate. Valid interactions and the 20 s cooldown are unchanged.
		if seconds<float(supply_requests.get(actor.peer_id,-1.0)): return ""
		supply_requests[actor.peer_id]=seconds+.25
		return "Reposição disponível em %d s."%ceili(supply_wait(actor.peer_id))
	var ray:=PhysicsRayQueryParameters3D.create(actor.camera_pivot.global_position,SUPPLY+Vector3.UP*1.15,1)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return "A caixa está atrás de um obstáculo."
	actor.cancel_reload();actor.trigger_held=false
	for weapon in actor.ammo:
		if not supply_stock.has(weapon): continue
		var stock: Vector2i=supply_stock[weapon]
		actor.ammo[weapon]=stock.x;actor.reserves[weapon]=stock.y
	actor.grenades=2 if actor.grenades_enabled else 0
	supplies[actor.peer_id]=seconds+SUPPLY_COOLDOWN
	if game.online and multiplayer.is_server() and game._network_peer_ready(actor.peer_id):
		# Ammunition is private state. The other participants do not need this
		# packet, and a refill does not change the loadout or rebuild equipment.
		rpc_id(actor.peer_id,"supply_inventory",game._inventory_packet(actor),actor.grenades)
	else: game.update_hud()
	return "Reabastecido."

@rpc("authority","call_remote","reliable")
func supply_inventory(packet: Array,grenades: int) -> void:
	if packet.size()!=10: return
	var actor:=game.local_player as GamePlayer
	if not is_instance_valid(actor) or actor.hp<=0 or int(packet[0])!=actor.peer_id or int(packet[8])!=actor.life_id or int(packet[9])<actor.authoritative_reload_revision: return
	actor.grenades=clampi(grenades,0,2) if actor.grenades_enabled else 0
	game.callv("remote_inventory",packet)

func player_name(id: int) -> String:
	var actor:=game.players.get(id) as GamePlayer
	return str(game.profile.nickname if actor.is_local else actor.name) if is_instance_valid(actor) else "Ninguém"

func headline(id: int) -> String:
	if phase=="finished": return "%s · NOVA RODADA EM %d s"%[winner_name.to_upper(),ceili(break_left)]
	if phase=="waiting": return "DOMINAÇÃO · AGUARDANDO 2 JOGADORES"
	return "DOMINAÇÃO · CASINHA   |   %d / %d   ·   %02d:%02d"%[int(scores.get(id,0)),SCORE_TARGET,int(remaining)/60,int(remaining)%60]

func detail() -> String:
	if phase=="finished": return "EMPATE" if winner_id==0 else "VENCEU A RODADA"
	if contested: return "CONTESTADA · nenhum jogador pontua"
	if capturing_id!=0: return "%s capturando · %d%%"%[player_name(capturing_id).left(18),roundi(progress/CAPTURE_SECONDS*100)]
	if owner_id!=0: return "%s controla · 1 ponto/s somente dentro da casa"%player_name(owner_id).left(18)
	return "Fique sozinho dentro da casa por 6 s para capturar"
