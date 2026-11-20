class_name Shapes
extends RefCounted
## Fábrica de geometría y luz.
##
## Todo el juego se construye por código, así que estas funciones evitan repetir
## el mismo setup de mallas, materiales y luces en cada actor de la escena.


static func material(color: Color, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	return mat


static func add_mesh(parent: Node, mesh: Mesh, mat: Material, at := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = mat
	instance.position = at
	parent.add_child(instance)
	return instance


static func add_light(parent: Node, at: Vector3, color: Color, energy: float, radius: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	parent.add_child(light)
	return light


static func sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	return mesh


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	return mesh


static func cylinder(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return mesh


## Posición a [param yaw_degrees] del jugador (+ izquierda, - derecha),
## a [param distance] metros y a [param height] de altura.
static func polar(yaw_degrees: float, distance: float, height: float) -> Vector3:
	var angle := deg_to_rad(yaw_degrees)
	return Vector3(-sin(angle) * distance, height, -cos(angle) * distance)


## Diferencia entre dos ángulos en grados, siempre entre 0 y 180.
static func angle_gap(a: float, b: float) -> float:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0)
