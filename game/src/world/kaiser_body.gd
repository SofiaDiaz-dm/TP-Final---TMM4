class_name KaiserBody
extends Node3D
## Las patas de Kaiser, pegadas a la cámara como en un juego en primera persona.
##
## Es la única parte del cuerpo que se ve, así que el contagio se cuenta entero
## acá: dedos que se hinchan, pústulas que brotan y la pata derecha que se
## levanta cuando levantás la mano.

const REST_LEFT := Vector3(-0.24, -0.3, -0.55)
const REST_RIGHT := Vector3(0.24, -0.3, -0.55)
const RAISED_RIGHT := Vector3(0.12, -0.12, -0.42)
const FINGERS_PER_PAW := 3

var _paws: Array[Node3D] = []
var _fingers: Array[MeshInstance3D] = []
var _pustules: Array[MeshInstance3D] = []
var _skin: StandardMaterial3D
var _time := 0.0


func build() -> void:
	_skin = Shapes.material(Color(0.75, 0.55, 0.35))
	var pustule_skin := Shapes.material(Color(0.5, 0.75, 0.25), Color(0.4, 0.9, 0.2), 0.6)

	var side := -1.0
	for rest in [REST_LEFT, REST_RIGHT]:
		var paw := Node3D.new()
		paw.position = rest
		paw.rotation_degrees = Vector3(-10.0, -side * 12.0, 0.0)
		add_child(paw)

		var palm := Shapes.add_mesh(paw, Shapes.sphere(0.08), _skin)
		palm.scale = Vector3(1.0, 0.7, 1.5)

		for i in FINGERS_PER_PAW:
			_fingers.append(Shapes.add_mesh(paw, Shapes.sphere(0.035), _skin,
				Vector3((i - 1) * 0.06, 0.0, -0.13)))

		for i in FINGERS_PER_PAW:
			var pustule := Shapes.add_mesh(paw, Shapes.sphere(0.03), pustule_skin,
				Vector3((i - 1) * 0.05, 0.05, -0.02 - i * 0.04))
			pustule.visible = false
			_pustules.append(pustule)

		_paws.append(paw)
		side = 1.0


func apply(delta: float, contagion: float, hand_up: bool, fist: bool) -> void:
	_time += delta
	var sick := clampf(contagion, 0.0, 1.0)

	_skin.albedo_color = Color(0.75, 0.55, 0.35).lerp(Color(0.45, 0.7, 0.3), sick)

	var pulse := 1.0 + sin(_time * 4.0) * 0.08 * sick
	for i in _fingers.size():
		var growth := 1.0 + sick * (0.8 + 0.5 * float(i % 2))
		_fingers[i].scale = Vector3.ONE * growth * pulse

	for i in _pustules.size():
		var threshold := 0.12 + 0.13 * float(i)
		var amount := clampf((sick - threshold) * 5.0, 0.0, 1.0)
		_pustules[i].visible = amount > 0.02
		_pustules[i].scale = Vector3.ONE * maxf(amount * 1.6, 0.01)

	for i in _paws.size():
		_paws[i].rotation.z = sin(_time * 18.0 + float(i) * 2.0) * 0.04 * sick

	var right := _paws[1]
	var target := RAISED_RIGHT if hand_up else REST_RIGHT
	right.position = right.position.lerp(target, 10.0 * delta)
	right.scale = right.scale.lerp(Vector3.ONE * (0.85 if fist else 1.0), 15.0 * delta)
