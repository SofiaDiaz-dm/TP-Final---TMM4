class_name Room
extends Node3D
## El baño donde está Kaiser: un modelo completo importado de Sketchfab
## ("The Bathroom" de Evan, CC-BY 4.0).
##
## Los remedios se colocan cerca del lavabo, donde tiene sentido encontrarlos.

const HALF_SIZE := 12.0
const WALL_HEIGHT := 5.0
const CLUTTER_COUNT := 0
const SEED := 7

## La puerta del GLB gira sobre su bisagra (el origen del nodo `Door_001`), así
## que el único eje que hay que tocar es el vertical. El asset trae la puerta
## entreabierta a -42,7°: 0° es cerrada (alineada con la pared) y 90° es abierta
## hacia el pasillo, que es el lado +Z del baño.
const DOOR_CLOSED_YAW := 0.0
const DOOR_OPEN_YAW := 90.0

var _clear_zones: Array[Vector3] = []
var glb_door: Node3D = null
var _door_original_rotation: Vector3 = Vector3.ZERO
var _door_closed := false


func set_door_closed(closed: bool) -> void:
	if glb_door == null:
		return
	_door_closed = closed
	# Se conserva la inclinación original del asset (X y Z) y solo se cambia el
	# giro vertical: así la puerta gira como una puerta y no como una tapa.
	glb_door.rotation_degrees = Vector3(
		_door_original_rotation.x,
		DOOR_CLOSED_YAW if closed else DOOR_OPEN_YAW,
		_door_original_rotation.z)


func build(clear_zones: Array[Vector3]) -> void:
	_clear_zones = clear_zones
	_build_environment()
	_build_bathroom()
	_build_clutter()
	# Buscar la puerta del asset importado.
	_find_glb_door()


func _find_glb_door() -> void:
	var all_doors: Array[Node3D] = []
	_collect_doors(self, all_doors)
	var best_door: Node3D = null
	var best_dist := 9999.0
	for d in all_doors:
		var dist := d.global_position.distance_to(Vector3.ZERO)
		if dist < best_dist:
			best_dist = dist
			best_door = d
	if best_door != null:
		glb_door = best_door
		_door_original_rotation = best_door.rotation_degrees
	else:
		print("GLB door NOT found")


func _collect_doors(node: Node, result: Array[Node3D]) -> void:
	var node_name := node.name
	# Solo nodos "Door" o "Door_001", "Door_002", etc. (no hinges ni meshes).
	if node_name == "Door" or (node_name.begins_with("Door_") and not "Hinges" in node_name and not "windows" in node_name):
		if node is Node3D:
			result.append(node as Node3D)
	for c in node.get_children():
		_collect_doors(c, result)


func _find_node_by_name(node: Node, search: String) -> Node:
	if node.name == search:
		return node
	for c in node.get_children():
		var r := _find_node_by_name(c, search)
		if r != null:
			return r
	return null


## Coloca un nodo vacío donde van los remedios (cerca del lavabo).
func medicine_cabinet_position() -> Vector3:
	return Vector3(-2.0, 1.2, -1.5)


## Repisa para el frasco. Vive acá porque es mueble, no un objeto agarrable.
func add_shelf(at: Vector3, yaw_degrees: float) -> void:
	var shelf := Node3D.new()
	shelf.position = at
	shelf.rotation_degrees.y = yaw_degrees
	add_child(shelf)
	var wood := Shapes.material(Color(0.35, 0.25, 0.15))
	Shapes.add_mesh(shelf, Shapes.box(Vector3(1.6, 0.08, 0.55)), wood, Vector3(0, 1.0, 0))
	Shapes.add_mesh(shelf, Shapes.box(Vector3(0.07, 1.0, 0.07)), wood, Vector3(-0.7, 0.5, 0))
	Shapes.add_mesh(shelf, Shapes.box(Vector3(0.07, 1.0, 0.07)), wood, Vector3(0.7, 0.5, 0))


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.15, 0.18, 0.22)
	env.ambient_light_energy = 0.4
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.08)
	env.fog_density = 0.06
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)


func _build_bathroom() -> void:
	var scene := load("res://assets/bathroom/the_bathroom_free.glb") as PackedScene
	if scene == null:
		push_warning("Room: no pude cargar el baño")
		return
	var bathroom := scene.instantiate()
	# El jugador está adentro del baño.
	bathroom.scale = Vector3.ONE * 1.0
	bathroom.position = Vector3(0, -0.5, 0)
	add_child(bathroom)
	# Luces tenues para ambiente de terror.
	Shapes.add_light(self, Vector3(0, 3.0, 0), Color(0.8, 0.75, 0.6), 1.5, 12.0)
	Shapes.add_light(self, Vector3(-2.0, 2.0, -1.5), Color(0.6, 0.5, 0.4), 0.8, 5.0)


func _build_clutter() -> void:
	# El baño ya tiene todo su desorden. No agregar más.
	pass


func _is_clear(yaw: float, distance: float) -> bool:
	return true
