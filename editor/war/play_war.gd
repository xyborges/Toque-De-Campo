extends Node
func _ready() -> void:
	var game:=WarGame.new();game.offline_operation=true;add_child(game)
