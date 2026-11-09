extends RefCounted
class_name BotCostProbe

# Instrumentacao experimental da IA 1; NUNCA habilitada em gameplay normal.
# Os acumuladores sao drenados a cada quadro renderizado pelo runner.
const SCOPES: Array[String] = ["move_slide", "step_test", "perception", "line_of_sight", "navigation", "pose", "think_total", "bot_move_total", "bot_separation"]
static var enabled: bool = "--ia1-physics-probe" in OS.get_cmdline_user_args()
static var usec: Dictionary = {}
static var calls: Dictionary = {}

static func record(scope: String, elapsed_usec: int, quantity: int = 1) -> void:
	if not enabled: return
	usec[scope] = float(usec.get(scope, 0.0)) + maxi(0, elapsed_usec)
	calls[scope] = int(calls.get(scope, 0)) + quantity

static func clear() -> void:
	usec.clear()
	calls.clear()

static func take() -> Dictionary:
	var result: Dictionary = {}
	for scope: String in SCOPES:
		result[scope] = {"usec": float(usec.get(scope, 0.0)), "calls": int(calls.get(scope, 0))}
	clear()
	return result
