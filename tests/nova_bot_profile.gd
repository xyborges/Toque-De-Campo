extends WarBotDirector

# Profiling wrapper only. The original movement, decisions and tick frequency
# are unchanged; scope timings are inclusive and must not be added together.
func _physics_process(delta: float) -> void:
	var t:=GamePerformanceProbe.begin(&"bot.tick")
	super._physics_process(delta)
	if t: GamePerformanceProbe.end(&"bot.tick",t)

func _move(actor: WarPlayer,record: Dictionary,delta: float) -> void:
	var t:=GamePerformanceProbe.begin(&"bot.move")
	super._move(actor,record,delta)
	if t: GamePerformanceProbe.end(&"bot.move",t)

func _think(id: int) -> void:
	var t:=GamePerformanceProbe.begin(&"bot.think")
	super._think(id)
	if t: GamePerformanceProbe.end(&"bot.think",t)

func _drive(actor: WarPlayer,record: Dictionary,delta: float) -> void:
	var t:=GamePerformanceProbe.begin(&"bot.drive")
	super._drive(actor,record,delta)
	if t: GamePerformanceProbe.end(&"bot.drive",t)
