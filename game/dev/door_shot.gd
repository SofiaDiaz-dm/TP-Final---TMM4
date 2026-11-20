extends Node3D
## Toma de referencia para revisar la puerta sin abrir el juego: arma el baño y
## deja la cámara en tres tomas fijas. Se usa junto con `--write-movie`.

var room: Room
var cam: Camera3D
var door_pos := Vector3.ZERO

func _ready() -> void:
	room = Room.new()
	add_child(room)
	room.build([])
	cam = Camera3D.new()
	add_child(cam)
	cam.current = true
	door_pos = room.glb_door.global_position
	_set_shot(0)


func _process(_delta: float) -> void:
	var frame := Engine.get_process_frames()
	var shot := 0
	if frame >= 60:
		shot = 2
	elif frame >= 30:
		shot = 1
	if shot != _last_shot:
		_set_shot(shot)


var _last_shot := -1

func _set_shot(shot: int) -> void:
	_last_shot = shot
	match shot:
		0:
			# Vista del jugador, puerta cerrada.
			room.set_door_closed(true)
			_aim(Vector3(0.115139, 0.65, -1.574154), door_pos + Vector3(0, 1.0, 0))
		1:
			# Vista del jugador, puerta abierta hacia el pasillo.
			room.set_door_closed(false)
			_aim(Vector3(0.115139, 0.65, -1.574154), door_pos + Vector3(0, 1.0, 0))
		2:
			# Desde el pasillo: se ve la cara de afuera de la puerta.
			room.set_door_closed(true)
			_aim(Vector3(-0.65, 0.65, 3.4), door_pos + Vector3(0, 1.0, 0))


func _aim(from: Vector3, to: Vector3) -> void:
	cam.position = from
	cam.look_at(to, Vector3.UP)
