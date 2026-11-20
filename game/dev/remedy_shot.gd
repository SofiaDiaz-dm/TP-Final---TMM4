extends Node3D
## Primer plano de la repisa del lavabo, para revisar los modelos de cerca.
##
##     godot --path game res://dev/remedy_shot.tscn \
##         --fixed-fps 30 --quit-after 8 --write-movie shot.png

func _ready() -> void:
	var game: Game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.hud.visible = false

	var shot := Camera3D.new()
	shot.fov = 55.0
	add_child(shot)
	shot.global_position = Vector3(0.95, 0.82, -0.55)
	shot.look_at(Vector3(1.08, 0.40, 0.36), Vector3.UP)
	shot.current = true
	print("[SHOT] cámara en ", shot.global_position)
