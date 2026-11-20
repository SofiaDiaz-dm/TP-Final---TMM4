extends Node3D
## Toma del apagón: se queda sin energía con la puerta cerrada y graba lo que
## pasa cuando vuelve la luz. Usa una cámara propia en el spawn, así la imagen
## no depende de la cámara del juego, y acorta los tiempos para que el video
## entre en pocos segundos.
##
##     godot --path game res://dev/blackout_shot.tscn \
##         --fixed-fps 30 --quit-after 150 --write-movie shot.png

const EYE := Vector3(0.115139, 0.65, -1.574154)
const HEADING := 173.8


func _ready() -> void:
	var game: Game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	var shot := Camera3D.new()
	shot.fov = game.camera.fov
	add_child(shot)
	shot.global_position = EYE
	shot.rotation_degrees = Vector3(0.0, HEADING, 0.0)
	shot.current = true

	game.hud.hide_hint()
	game.blackout_duration = 1.0
	game.blackout_beat = 1.6
	game.door_closed = true
	game.energy = 0.0
	game.running = true
	print("[SHOT] apagón forzado, cámara en ", EYE)
