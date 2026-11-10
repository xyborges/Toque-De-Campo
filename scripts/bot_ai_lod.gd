extends RefCounted
class_name WarBotAiLod

## Tactical decision LOD only. Never throttles physics, hitboxes, damage,
## movement integration, shots, network replication, or authority corrections.
const COMBAT_RANGE_SQ:=200.0*200.0
const CAUTION_RANGE_SQ:=350.0*350.0
const OBJECTIVE_RANGE_SQ:=80.0*80.0
const COMBAT_INTERVAL:=0.25
const CAUTION_INTERVAL:=0.55
const DISTANT_INTERVAL:=1.0

static func enabled_from_args(args: PackedStringArray) -> bool:
	return not args.has("--war-bot-ai-lod-legacy")

static func interval(enemy_distance_squared: float,urgent: bool,objective_near: bool) -> float:
	if urgent or objective_near or enemy_distance_squared<=COMBAT_RANGE_SQ:
		return COMBAT_INTERVAL
	if enemy_distance_squared<=CAUTION_RANGE_SQ:
		return CAUTION_INTERVAL
	return DISTANT_INTERVAL
