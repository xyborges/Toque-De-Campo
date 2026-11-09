extends RefCounted
class_name GameBotPopulation

# Temporary gameplay population limit, not a physics/pose optimization.
# BR has no teams, so it uses the same 22-bot total as a free-for-all cap.
const BOTS_PER_TEAM := 11
const TOTAL_BOTS := BOTS_PER_TEAM * 2

# Isolated stress fixtures deliberately retain their old 28-bot population.
# Only authorized game instances with BOTH test metadata flags use this.
const QA_BOTS_PER_TEAM := 14

static func war_online_targets(humans: Array, qa_28_bot_fixture := false) -> Array:
	if humans.size() < 2 or int(humans[0]) + int(humans[1]) < 1:
		return [0, 0]
	var difference := int(humans[0]) - int(humans[1])
	if not qa_28_bot_fixture:
		# Add bots on each side up to 11, then subtract the human imbalance
		# from the human-heavy side. This balances total players without
		# ever creating a twelfth bot on the human-light side.
		return [
			clampi(BOTS_PER_TEAM - maxi(difference, 0), 0, BOTS_PER_TEAM),
			clampi(BOTS_PER_TEAM + mini(difference, 0), 0, BOTS_PER_TEAM)
		]
	# Keep the original fixed-28 population and even-split balancing logic
	# for explicit 28-bot performance fixtures; never enable in real rooms.
	var targets := [QA_BOTS_PER_TEAM, QA_BOTS_PER_TEAM]
	var transfer := floori(absf(float(difference)) * 0.5)
	if difference > 1:
		targets[0] -= transfer
		targets[1] += transfer
	elif difference < -1:
		targets[1] -= transfer
		targets[0] += transfer
	return targets
