extends Node3D
## Mapa de la repisa del lavabo: recorre la superficie en una grilla y dice, por
## cada franja de profundidad (z), qué tramos de ancho (x) son mesada plana.
## Sirve para elegir dónde apoyar cosas sin que queden colgando sobre el bowl.
##
##     godot --headless --path game res://dev/probe_deck.tscn
##
## No forma parte del juego.

const SINK_NODE := "Sink_001_Bathtube_0"
const X_FROM := 0.40
const X_TO := 1.60
const Z_FROM := 0.0
const Z_TO := 0.90
const STEP := 0.02
## La mesada está a esta altura; se acepta un centímetro de tolerancia.
const DECK_Y := 0.345
const TOLERANCE := 0.01


func _ready() -> void:
	var game: Game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	var tris := _sink_triangles(game)
	if tris.is_empty():
		print("no encontré ", SINK_NODE)
		get_tree().quit()
		return

	var z := Z_FROM
	while z <= Z_TO:
		print("z=%+.2f  %s" % [z, _runs(tris, z)])
		z += STEP
	get_tree().quit()


## Tramos de x donde hay mesada a la altura DECK_Y en la franja z.
func _runs(tris: Array, z: float) -> String:
	var out := PackedStringArray()
	var start := -1.0
	var x := X_FROM
	while x <= X_TO:
		var flat := absf(_top_at(tris, x, z) - DECK_Y) <= TOLERANCE
		if flat and start < 0.0:
			start = x
		elif not flat and start >= 0.0:
			_add_run(out, start, x - STEP)
			start = -1.0
		x += STEP
	if start >= 0.0:
		_add_run(out, start, X_TO)
	return ", ".join(out) if not out.is_empty() else "—"


func _add_run(out: PackedStringArray, from: float, to: float) -> void:
	var width := (to - from) * 100.0
	if width < 3.0:
		return
	out.append("%.2f–%.2f (%2.0f cm)" % [from, to, width])


func _sink_triangles(game: Game) -> Array:
	var sink := _find(game, SINK_NODE) as MeshInstance3D
	if sink == null:
		return []
	var arrays := sink.mesh.surface_get_arrays(0)
	var verts := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var xf := sink.global_transform
	var out := []
	var i := 0
	while i + 2 < indices.size():
		var a := xf * verts[indices[i]]
		var b := xf * verts[indices[i + 1]]
		var c := xf * verts[indices[i + 2]]
		i += 3
		out.append({
			"box": AABB(a, Vector3.ZERO).expand(b).expand(c),
			"a": a, "b": b, "c": c,
		})
	return out


func _top_at(tris: Array, x: float, z: float) -> float:
	var best := -9.0
	var from := Vector3(x, 2.0, z)
	var down := Vector3(0, -1, 0)
	for tri in tris:
		var box: AABB = tri["box"]
		if x < box.position.x or x > box.end.x:
			continue
		if z < box.position.z or z > box.end.z:
			continue
		var hit: Variant = Geometry3D.ray_intersects_triangle(
			from, down, tri["a"], tri["b"], tri["c"])
		if hit != null:
			best = maxf(best, (hit as Vector3).y)
	return best


func _find(node: Node, wanted: StringName) -> Node:
	if node.name == wanted:
		return node
	for c in node.get_children():
		var hit := _find(c, wanted)
		if hit != null:
			return hit
	return null
