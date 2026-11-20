class_name Hud
extends CanvasLayer
## Toda la interfaz: viñeta de contagio, párpados, íconos de remedios pendientes,
## mensajes del centro, estado de la lectura y el panel de depuración (F1).
##
## No sabe nada del juego: solo recibe valores ya calculados.
##
## El orden del árbol es el orden de dibujo: viñeta abajo, después los
## párpados, y los textos arriba de todo. No hay trucos de move_to_front().

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.8));
	float v = smoothstep(0.2, 0.7, d);
	COLOR = vec4(0.04, 0.1, 0.02, v * fuerza);
}
"""

const LID_COLOR := Color(0.02, 0.02, 0.03)

## "off" = disponible (apagado), "on" = en la mano (prendido).
## Las claves tienen que coincidir con los nombres de REMEDIES en main.gd.
const REMEDY_ICONS := {
	"Botiquín": {
		"off": "res://assets/ui/remedios/botiquin_off.png",
		"on": "res://assets/ui/remedios/botiquin_on.png",
	},
	"Frasco": {
		"off": "res://assets/ui/remedios/frasco_off.png",
		"on": "res://assets/ui/remedios/frasco_on.png",
	},
	"Paño": {
		"off": "res://assets/ui/remedios/pano_off.png",
		"on": "res://assets/ui/remedios/pano_on.png",
	},
}
## Tamaño en pantalla de cada ícono y separación entre ellos.
const ICON_SIZE := Vector2(96, 96)
const ICON_SPACING := 8

## Brillo detrás de cada ícono.
const GLOW_COLOR := Color(1.0, 0.85, 0.5)
## Grosor del brillo, como fracción del ícono. Tiene que ser menor que
## (GLOW_PAD - 1) / 2, si no se corta en los bordes.
const GLOW_SIZE := 0.08
## Cuánto se agranda el rectángulo para que entre el brillo.
const GLOW_PAD := 1.3
## Intensidad: apagado (disponible) y prendido (en la mano). Con 0.0 no brilla.
const GLOW_OFF := 0.35
const GLOW_ON := 1.0

const GLOW_SHADER := """
shader_type canvas_item;
uniform vec4 glow_color : source_color = vec4(1.0, 0.85, 0.5, 1.0);
uniform float glow_size = 0.08;
uniform float glow_strength = 1.0;
uniform float pad_scale = 1.3;

float inside(vec2 p) {
	return step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
}

void fragment() {
	// El rectángulo es más grande que la imagen: se remapea el UV para que la
	// imagen quede en el centro y sobre margen para el brillo.
	vec2 uv = (UV - vec2(0.5)) * pad_scale + vec2(0.5);
	vec4 base = texture(TEXTURE, uv) * inside(uv);

	float g = 0.0;
	for (int i = 0; i < 16; i++) {
		float ang = float(i) * 0.3926991;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 p1 = uv + dir * glow_size;
		vec2 p2 = uv + dir * glow_size * 0.5;
		g += inside(p1) * texture(TEXTURE, p1).a;
		g += inside(p2) * texture(TEXTURE, p2).a;
	}
	g = clamp(g / 16.0, 0.0, 1.0) * glow_strength * glow_color.a;

	float a = base.a + g * (1.0 - base.a);
	vec3 rgb = (base.rgb * base.a + glow_color.rgb * g * (1.0 - base.a)) / max(a, 0.0001);
	COLOR = vec4(rgb, a);
}
"""

var debug_visible := false

var _vignette: ShaderMaterial
var _lid_top: ColorRect
var _lid_bottom: ColorRect
var _ending_background: ColorRect
var _center: Label
var _status: Label
var _target: Label
var _debug: Label
var _pending: VBoxContainer
var _icons := {}
var _icon_textures := {}


func build() -> void:
	_vignette = _add_vignette()

	_lid_top = _add_rect(LID_COLOR)
	_lid_bottom = _add_rect(LID_COLOR)
	set_eyelids(0.0)

	_ending_background = _add_rect(Color.BLACK)
	_ending_background.visible = false

	_center = Label.new()
	add_child(_center)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_center.add_theme_font_size_override("font_size", 28)

	_status = Label.new()
	add_child(_status)
	_status.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.offset_top = 26.0
	_status.add_theme_font_size_override("font_size", 20)
	_status.add_theme_color_override("font_color", Color(1, 0.85, 0.6, 0.9))
	_status.add_theme_constant_override("outline_size", 6)
	_status.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_status.visible = false

	_target = Label.new()
	add_child(_target)
	_target.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_target.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target.offset_bottom = -24.0
	_target.add_theme_font_size_override("font_size", 22)
	_target.add_theme_color_override("font_color", Color(0.7, 1, 0.7, 0.95))
	_target.add_theme_constant_override("outline_size", 6)
	_target.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_target.visible = false

	_debug = Label.new()
	_debug.position = Vector2(12, 8)
	_debug.add_theme_font_size_override("font_size", 15)
	_debug.visible = debug_visible
	add_child(_debug)

	_pending = VBoxContainer.new()
	add_child(_pending)
	_pending.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_pending.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_pending.offset_right = -16.0
	_pending.offset_top = 10.0
	_pending.add_theme_constant_override("separation", ICON_SPACING)
	_pending.visible = false
	_build_remedy_icons()


func show_hint(text: String) -> void:
	_center.text = text
	_center.visible = true


func hide_hint() -> void:
	_center.visible = false
	_center.text = ""


func show_ending(text: String) -> void:
	_ending_background.visible = true
	_center.text = text
	_center.visible = true
	_status.visible = false
	_pending.visible = false
	set_eyelids(0.0)


## 0 = nada, 1 = verde cerrado por todos lados.
func set_vignette(amount: float) -> void:
	_vignette.set_shader_parameter("fuerza", clampf(amount, 0.0, 1.0))


## 0 = ojos abiertos, 1 = párpados cerrados. Los párpados tienen que seguir al
## parpadeo, no a la mecánica de "ojos cerrados": son cosas distintas.
func set_eyelids(amount: float) -> void:
	var closed := clampf(amount, 0.0, 1.0)
	var height := get_viewport().get_visible_rect().size.y
	var opening := height * (1.0 - closed)
	_lid_top.offset_bottom = -opening
	_lid_bottom.offset_top = opening
	_lid_top.visible = closed > 0.001
	_lid_bottom.visible = closed > 0.001


## Aviso corto arriba del centro: "sin cámara", "ojos cerrados". Vacío = oculto.
func set_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()


## Muestra el nombre del remedio que está en la mira y si se puede agarrar.
func set_target(text: String) -> void:
	_target.text = text
	_target.visible = not text.is_empty()


## names = remedios que todavía no se entregaron. carried_name = el que está en
## la mano (imagen prendida); los demás usan la apagada. Los entregados se ocultan.
## names = remedios que todavía no se entregaron. carried_name = el que está en
## la mano (imagen prendida); los demás usan la apagada. Los entregados se ocultan.
func set_pending(names: PackedStringArray, visible: bool, carried_name := "") -> void:
	_pending.visible = visible and not names.is_empty()
	for item_name in _icons:
		var icon: TextureRect = _icons[item_name]
		icon.visible = names.has(item_name)
		var carried: bool = item_name == carried_name
		icon.texture = _icon_textures[item_name].get("on" if carried else "off")
		var mat := icon.material as ShaderMaterial
		mat.set_shader_parameter("glow_strength", GLOW_ON if carried else GLOW_OFF)

func set_debug(text: String) -> void:
	_debug.text = text


func set_debug_visible(value: bool) -> void:
	debug_visible = value
	_debug.visible = value


func toggle_debug() -> void:
	set_debug_visible(not debug_visible)

func _build_remedy_icons() -> void:
	var shader := Shader.new()
	shader.code = GLOW_SHADER
	for item_name in REMEDY_ICONS:
		var paths: Dictionary = REMEDY_ICONS[item_name]
		var textures := {}
		for state in ["off", "on"]:
			if ResourceLoader.exists(paths[state]):
				textures[state] = load(paths[state])
		_icon_textures[item_name] = textures

		var icon := TextureRect.new()
		icon.custom_minimum_size = ICON_SIZE * GLOW_PAD
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		# La imagen llena todo el rectángulo: el shader se encarga del margen.
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.texture = textures.get("off")

		# Un material por ícono, para que cada uno tenga su propia intensidad.
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("glow_color", GLOW_COLOR)
		mat.set_shader_parameter("glow_size", GLOW_SIZE)
		mat.set_shader_parameter("pad_scale", GLOW_PAD)
		mat.set_shader_parameter("glow_strength", GLOW_OFF)
		icon.material = mat

		_pending.add_child(icon)
		_icons[item_name] = icon


func _add_rect(color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return rect


func _add_vignette() -> ShaderMaterial:
	var rect := ColorRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	rect.material = mat
	add_child(rect)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return mat
