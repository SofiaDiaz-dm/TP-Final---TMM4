extends Node3D
## Herramienta de diagnóstico: comprueba que los remedios estén apoyados sobre
## la repisa del lavabo y no colgando sobre el bowl.
##
##     godot --headless --path game res://dev/probe_surface.tscn
##
## Levanta la escena real (así los valores son los que ve el jugador) y, para
## cada remedio, castea rayos hacia abajo en todo su perímetro. No forma parte
## del juego.

const SINK_NODE := "Sink_001_Bathtube_0"
const TOLERANCE := 0.02
## Cuánto puede sobresalir el piso por debajo de la base antes de considerar
## que el objeto quedó colgando sobre un hueco.
const OVERHANG := 0.03


func _ready() -> void:
	var game: Game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	var tris := _sink_triangles(game)
	if tris.is_empty():
		print("no encontré ", SINK_NODE)
		get_tree().quit()
		return

	var failures := 0
	for remedy: Pickup in game.remedies:
		var box: AABB = remedy.global_transform * remedy.model_aabb()
		var base := box.position.y
		var lowest := 9.0
		var highest := -9.0
		for sample in _perimeter(box):
			var surface := _top_at(tris, sample.x, sample.z)
			lowest = minf(lowest, surface)
			highest = maxf(highest, surface)
		var gap := base - highest
		var state := "OK"
		if absf(gap) > TOLERANCE:
			state = "FLOJA" if gap > 0.0 else "HUNDIDA"
			failures += 1
		elif lowest < base - OVERHANG:
			state = "PUENTE"
			failures += 1
		print("%-9s base y=%.3f  repisa y=%.3f a %.3f  %s   alto %.2f m" % [
			remedy.item_name, base, highest, lowest, state, box.size.y])
	print("REMEDIOS: %s" % ("OK" if failures == 0 else "%d mal ubicados" % failures))
	get_tree().quit()


## Centro y esquinas de la base: alcanza para saber si apoya en los cuatro
## lados o si se está cayendo en el bowl.
func _perimeter(box: AABB) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var center := box.get_center()
	out.append(Vector3(center.x, 0.0, center.z))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			out.append(Vector3(
				center.x + sx * box.size.x * 0.45,
				0.0,
				center.z + sz * box.size.z * 0.45))
	return out


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


## Y de la cara más alta del lavabo justo arriba/abajo del punto (x, z).
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
