class_name Chili
extends Node3D
## CHILI: el bicho que se muere en el piso, como imagen 2D.
##
## Son 12 cuadros de su transformación: el 1 es sano y el 12 es la muerte. El
## cuadro sale de [member gravity] (0 = sano, 1 = crítico), que escribe el juego.
## Cuando la gravedad cambia, la imagen no salta: pasa por los cuadros
## intermedios, como un gif (también hacia atrás cuando lo medicás).

const FRAME_PATH := "res://assets/chili/chilli%d.png"
const FRAME_COUNT := 12
## Alto de la imagen en el mundo, en metros. El ancho sale de la proporción.
const DISPLAY_HEIGHT := 1.5
## Cuadros por segundo cuando pasa de un cuadro a otro.
const FRAME_FPS := 6.0
## true si los PNG tienen fondo negro sólido en vez de transparente.
const BLACK_BACKGROUND := false

## Qué tan enfermo está (0 = sano, 1 = crítico). Lo escribe el juego.
var gravity := 0.35

var base_position := Vector3.ZERO

var _frames: Array[Texture2D] = []
var _quad: MeshInstance3D
var _mesh: QuadMesh
var _material: StandardMaterial3D
var _light: OmniLight3D
var _shown := 0.0
var _last_index := -1
var _time := 0.0


func build() -> void:
	base_position = position

	for i in range(1, FRAME_COUNT + 1):
		var path := FRAME_PATH % i
		if ResourceLoader.exists(path):
			_frames.append(load(path) as Texture2D)
		else:
			push_warning("Chili: falta %s" % path)
			_frames.append(null)

	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Siempre de frente a la cámara, pero parado.
	_material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	_material.billboard_keep_scale = true
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if BLACK_BACKGROUND:
		_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD

	_mesh = QuadMesh.new()
	_quad = MeshInstance3D.new()
	_quad.mesh = _mesh
	_quad.material_override = _material
	_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# El origen de CHILI es el piso: la imagen se apoya ahí.
	_quad.position = Vector3(0, DISPLAY_HEIGHT * 0.5, 0)
	add_child(_quad)

	_shown = float(_target_frame())
	_show_frame(roundi(_shown))

	_light = Shapes.add_light(self, Vector3(0, 1.2, 0.6), Color(0.75, 0.9, 0.85), 0.8, 3.5)


## [param bait] = destello de tentación, [param flash] = fogonazo de la entrega.
func apply(delta: float, bait: float, flash: float) -> void:
	_time += delta
	var sick := clampf(gravity, 0.0, 1.0)

	# Avanza (o retrocede) de a un cuadro por vez hacia el que le toca.
	_shown = move_toward(_shown, float(_target_frame()), FRAME_FPS * delta)
	var index := clampi(roundi(_shown), 0, FRAME_COUNT - 1)
	if index != _last_index:
		_show_frame(index)

	# La tentación y la entrega iluminan la imagen.
	var glow := 1.0 + bait * 0.4 + flash * 1.5
	_material.albedo_color = Color(glow, glow, glow, 1.0)
	# Temblor: más fuerte mientras más enfermo.
	_quad.position.x = sin(_time * 28.0) * 0.01 * sick * (1.0 + bait * 2.0)
	_light.light_energy = 0.8 + bait * 2.5 + flash * 4.0


## Se arrastra hacia [param target] una fracción [param amount] del camino.
func pull_towards(target: Vector3, amount: float, delta: float) -> void:
	position = base_position.lerp(target, amount * 0.85)


## Gravedad 0 = cuadro 1 (sano), gravedad 1 = cuadro 12 (la muerte).
func _target_frame() -> int:
	return clampi(roundi(clampf(gravity, 0.0, 1.0) * (FRAME_COUNT - 1)), 0, FRAME_COUNT - 1)


func _show_frame(index: int) -> void:
	_last_index = index
	var texture := _frames[index]
	_material.albedo_texture = texture
	_quad.visible = texture != null
	if texture != null:
		var aspect := float(texture.get_width()) / float(texture.get_height())
		_mesh.size = Vector2(DISPLAY_HEIGHT * aspect, DISPLAY_HEIGHT)

## Número del cuadro (1 a 12) que se está mostrando ahora.
func frame_number() -> int:
	return _last_index + 1
