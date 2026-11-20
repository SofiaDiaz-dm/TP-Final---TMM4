class_name Pickup
extends Node3D
## Un remedio: se puede mirar, agarrar con la mano derecha y entregar.
##
## La forma sale de un modelo real importado de un GLB, con el pivote en la
## base: apoyarlo es dejarlo a la altura de la repisa, sin cuentas de mitades.
## El brillo de "esto lo podés agarrar" se pinta sobre los materiales del
## propio modelo, así el objeto se enciende con sus colores y no de blanco.

enum State { ROOM, HAND, DELIVERED }

## Transform local dentro de la pata de Kaiser cuando lo lleva.
const IN_HAND_POSITION := Vector3(0.1, -0.24, -0.5)
const IN_HAND_SCALE := 0.5
## La energía que pide el juego llega hasta 3; los materiales del modelo ya
## tienen textura, así que se multiplica por menos para no quemarlos.
const GLOW_GAIN := 0.3

var item_name := ""
var state := State.ROOM
## Dónde vive cuando no lo tiene nadie.
var home := Vector3.ZERO
var home_yaw := 0.0

var _glow: Array[BaseMaterial3D] = []
var _aabb := AABB()
var _light: OmniLight3D


## [param model] es la escena del objeto y [param size] cuánto se agranda: un
## frasco de tamaño real a metro y medio no se ve.
func setup(display_name: String, model: PackedScene, at: Vector3, yaw: float, size := 1.0) -> void:
	item_name = display_name
	home = at
	home_yaw = yaw
	position = at
	rotation_degrees.y = yaw

	var holder := Node3D.new()
	holder.scale = Vector3.ONE * size
	add_child(holder)
	holder.add_child(model.instantiate())
	_aabb = _model_aabb(holder)
	_prepare_glow(holder)

	_light = Shapes.add_light(self, Vector3(0, 0.45, 0.35), Color(1.0, 0.86, 0.62), 0.35, 2.2)


## Caja que ocupa el objeto, en coordenadas del remedio. La usa dev/probe_surface
## para comprobar que la base toca la repisa.
func model_aabb() -> AABB:
	return _aabb


func is_available() -> bool:
	return state == State.ROOM


## Brillo: bajo si está tirado, alto si lo estás mirando, máximo si lo podés agarrar.
func set_highlight(energy: float) -> void:
	var glow := energy * GLOW_GAIN
	for mat in _glow:
		mat.emission_energy_multiplier = glow
	if _light != null:
		_light.light_energy = 0.2 + glow * 0.6


func attach_to(hand: Node3D) -> void:
	state = State.HAND
	reparent(hand, false)
	position = IN_HAND_POSITION
	rotation = Vector3.ZERO
	scale = Vector3.ONE * IN_HAND_SCALE


func detach_to(parent: Node) -> void:
	state = State.ROOM
	reparent(parent, false)
	position = home
	rotation = Vector3(0.0, deg_to_rad(home_yaw), 0.0)
	scale = Vector3.ONE


func deliver() -> void:
	state = State.DELIVERED
	visible = false


## Caja de todo el modelo, medida en el espacio del remedio (sin su giro).
func _model_aabb(holder: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mesh: MeshInstance3D in _meshes(holder):
		if mesh.mesh == null:
			continue
		var to_pickup := global_transform.affine_inverse() * mesh.global_transform
		var part: AABB = to_pickup * mesh.mesh.get_aabb()
		box = part if first else box.merge(part)
		first = false
	return box


## Copia los materiales del modelo y les habilita la emisión con su propia
## textura: el brillo respeta los colores y las letras del frasco.
func _prepare_glow(holder: Node3D) -> void:
	for mesh: MeshInstance3D in _meshes(holder):
		if mesh.mesh == null:
			continue
		for i in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(i)
			if not original is BaseMaterial3D:
				continue
			var mat := (original as BaseMaterial3D).duplicate() as BaseMaterial3D
			mat.emission_enabled = true
			mat.emission = Color.WHITE
			if mat.albedo_texture != null:
				mat.emission_texture = mat.albedo_texture
			mat.emission_energy_multiplier = 0.0
			mesh.set_surface_override_material(i, mat)
			_glow.append(mat)


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in root.get_children():
		if child is MeshInstance3D:
			out.append(child)
		out.append_array(_meshes(child))
	return out
