extends Node
## GameFlow (autoload): INICIO -> CINEMATICA -> JUEGO
## Pausa el juego hasta el estado JUEGO y dibuja sus pantallas encima.

enum State { INICIO, CINEMATICA, JUEGO }

signal state_changed(new_state: State)

const TITLE_PATH := "res://assets/ui/inicio.png"
const HAND_FRAMES_DIR := "res://assets/ui/mano/"
const HAND_FPS := 6.0
## Posición de la mano como proporción de la pantalla (0-1) y escala.
const HAND_POSITION := Vector2(0.5, 0.75)
const HAND_SCALE := Vector2(0.6, 0.6)

## Si el archivo existe se reproduce; si no, pantalla negra de 5 segundos.
const CINEMATIC_PATH := "res://assets/video/intro.ogv"
const CINEMATIC_FALLBACK_SECONDS := 5.0
## Atajo de prueba sin cámara (Enter en el inicio).
const DEBUG_SKIP_WITH_ENTER := true

var state: State = State.INICIO

var _layer: CanvasLayer
var _bg: ColorRect
var _title: TextureRect
var _hand: AnimatedSprite2D
var _label: Label
var _video: VideoStreamPlayer
var _cinematic_time := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# El tracker tiene que seguir llegando con el árbol en pausa.
	EyeInput.process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	EyeInput.grab.connect(_on_grab)
	_set_state(State.INICIO)


func _process(delta: float) -> void:
	match state:
		State.INICIO:
			if DEBUG_SKIP_WITH_ENTER and Input.is_action_just_pressed("ui_accept"):
				_set_state(State.CINEMATICA)
		State.CINEMATICA:
			# Sin video: pantalla negra de 5 segundos.
			if not _video.visible:
				_cinematic_time += delta
				if _cinematic_time >= CINEMATIC_FALLBACK_SECONDS:
					_set_state(State.JUEGO)


## Vuelve a la pantalla de inicio. La llama main.gd antes de recargar la escena.
func show_start() -> void:
	_set_state(State.INICIO)


func _set_state(new_state: State) -> void:
	state = new_state
	match state:
		State.INICIO:
			_layer.visible = true
			_bg.color = Color.BLACK
			_video.stop()
			_video.visible = false
			_label.visible = false
			_title.visible = true
			_show_hand(true)
			get_tree().paused = true
			Sound.start_ambient()
		State.CINEMATICA:
			_title.visible = false
			_show_hand(false)
			_start_cinematic()
		State.JUEGO:
			_video.stop()
			_layer.visible = false
			_show_hand(false)
			get_tree().paused = false
			Sound.set_ambient_mode(true)
	state_changed.emit(state)


## EyeInput emite grab con "palma abierta y después puño" de la mano derecha.
func _on_grab() -> void:
	if state == State.INICIO:
		_set_state(State.CINEMATICA)


func _start_cinematic() -> void:
	_cinematic_time = 0.0
	_bg.color = Color.BLACK
	if ResourceLoader.exists(CINEMATIC_PATH):
		_video.stream = load(CINEMATIC_PATH)
		_video.visible = true
		_video.play()
		_label.visible = false
	else:
		_video.visible = false
		# Placeholder: el cartel se va cuando llegue el video real.
		_label.text = "cinemática"
		_label.visible = true


func _on_video_finished() -> void:
	if state == State.CINEMATICA:
		_set_state(State.JUEGO)


func _show_hand(on: bool) -> void:
	_hand.visible = on
	if on and _hand.sprite_frames != null:
		_hand.play("default")
	else:
		_hand.stop()


# ---------- UI ----------

func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	add_child(_layer)

	_bg = ColorRect.new()
	_layer.add_child(_bg)
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Imagen del título, cubriendo toda la pantalla.
	_title = TextureRect.new()
	_title.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_title.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(TITLE_PATH):
		_title.texture = load(TITLE_PATH)
	_layer.add_child(_title)
	_title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Mano animada (cuadros PNG en HAND_FRAMES_DIR).
	_hand = AnimatedSprite2D.new()
	_hand.sprite_frames = _load_hand_frames()
	_hand.scale = HAND_SCALE
	_layer.add_child(_hand)
	_layout_hand()
	get_viewport().size_changed.connect(_layout_hand)

	_video = VideoStreamPlayer.new()
	_video.expand = true
	_video.visible = false
	_video.finished.connect(_on_video_finished)
	_layer.add_child(_video)
	_video.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 32)
	_layer.add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _layout_hand() -> void:
	_hand.position = get_viewport().get_visible_rect().size * HAND_POSITION


## Arma la animación con todos los PNG de la carpeta, en orden alfabético.
func _load_hand_frames() -> SpriteFrames:
	var names: Array[String] = []
	for file in DirAccess.get_files_at(HAND_FRAMES_DIR):
		# En un juego exportado solo quedan los .import: se normaliza el nombre.
		var clean := file.trim_suffix(".import")
		if clean.ends_with(".png") and not names.has(clean):
			names.append(clean)
	names.sort()
	if names.is_empty():
		return null

	var frames := SpriteFrames.new()
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("default", HAND_FPS)
	for file_name in names:
		frames.add_frame("default", load(HAND_FRAMES_DIR + file_name))
	return frames
