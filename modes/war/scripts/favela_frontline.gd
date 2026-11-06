extends RefCounted
class_name WarFavelaFrontline

## A single contested sector advances toward the opposing base. Keeping
## ownership in the existing objective_state payload avoids a second source
## of truth for offline simulation, multiplayer and reconnect snapshots.
const ORDER := ["A", "B", "C", "D", "E"]
const START_INDEX := 2

static func enabled(operation: String) -> bool:
	return operation == WarOperation.FAVELA

static func initial(states: Dictionary) -> Dictionary:
	for i in ORDER.size():
		var key: String = ORDER[i]
		if not states.has(key):
			continue
		var record: Dictionary = states[key]
		record.owner = 0 if i < START_INDEX else (1 if i > START_INDEX else -1)
		record.side = -1
		record.progress = 0.0
		record.idle = 0.0
		record.contested = false
		record.count = [0, 0]
		states[key] = record
	return states

static func active_id(states: Dictionary) -> String:
	# Exactly one neutral objective during play, and none after terminal
	# conquest. No additional RPC/serialized state required.
	for key: String in ORDER:
		if states.has(key) and int(states[key].get("owner", -2)) == -1:
			return key
	return ""

static func active_index(states: Dictionary) -> int:
	return ORDER.find(active_id(states))

static func can_capture(states: Dictionary, key: String) -> bool:
	return key == active_id(states) and not key.is_empty()

static func spawn_allowed(states: Dictionary, team: int, key: String) -> bool:
	if team not in [0, 1] or not states.has(key):
		return false
	var front := active_index(states)
	if front < 0:
		return false
	var own_index := front - 1 if team == 0 else front + 1
	return own_index >= 0 and own_index < ORDER.size() and ORDER[own_index] == key \
		and int(states[key].get("owner", -1)) == team

static func advance(states: Dictionary, key: String, capturing_team: int) -> Dictionary:
	# Called by the authority only when the currently neutral flag completes
	# its full capture. A counterattack captures the next neutral enemy-side
	# sector and moves the line back toward the center.
	var index := ORDER.find(key)
	if index < 0 or capturing_team not in [0, 1]:
		return {"changed": false, "active": active_id(states), "winner": -1}
	if not states.has(key) or int(states[key].get("owner", -1)) != capturing_team:
		return {"changed": false, "active": active_id(states), "winner": -1}
	var next_index := index + (1 if capturing_team == 0 else -1)
	if next_index < 0 or next_index >= ORDER.size():
		return {"changed": true, "active": "", "winner": capturing_team}
	var next_key: String = ORDER[next_index]
	states[next_key] = {
		"owner": -1, "side": -1, "progress": 0.0,
		"idle": 0.0, "contested": false, "count": [0, 0]
	}
	return {"changed": true, "active": next_key, "winner": -1}

static func winner_at_limit(states: Dictionary, remaining_tickets: Array) -> int:
	# The team closest to the enemy base wins if the match expires. Tickets
	# only break a stalemate at the neutral central sector.
	var index := active_index(states)
	if index < 0:
		return -1
	if index < START_INDEX:
		return 1
	if index > START_INDEX:
		return 0
	if remaining_tickets.size() < 2 or int(remaining_tickets[0]) == int(remaining_tickets[1]):
		return -1
	return 0 if int(remaining_tickets[0]) > int(remaining_tickets[1]) else 1
