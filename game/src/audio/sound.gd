extends Node
## Sound (autoload): todo el sonido del juego.
## Corre aunque el árbol esté en pausa (inicio y cinemática).

const AUDIO_DIR := "res://assets/audio/"
const EXTENSIONS := ["ogg", "mp3", "wav"]

## Por cada sonido: archivo (sin extensión), volumen en dB (0 = máximo, más
## negativo = más bajo) y si se repite en loop.
## En "ambient", poné el volumen que ya tenías.
const SOUNDS := {
	"ambient": {"file": "ambiente", "volume": -16.0, "loop": true},
	"growl": {"file": "chili-grunidos", "volume": +6.0, "loop": true},
	"behind": {"file": "chili-atras", "volume": -2.0, "loop": false},
	"hurt": {"file": "herido", "volume": -2.0, "loop": false},
	"lights": {"file": "luces", "volume": -4.0, "loop": false},
	"door": {"file": "puerta", "volume": -2.0, "loop": false},
	"door_open": {"file": "abrir", "volume": -2.0, "loop": false},
	"pickup": {"file": "remedio", "volume": -2.0, "loop": false},
}
## Segundos que tarda en subir el ambiente al empezar.
const FADE_IN := 2.0
## Segundos de fundido al empezar y cortar los gruñidos.
const GROWL_FADE := 0.4
const SILENT_DB := -60.0

## Volumen del ambiente mientras se juega (dB). El de inicio y finales es el
## "volume" de "ambient" en SOUNDS.
const AMBIENT_GAME_DB := -26.0
## Segundos que tarda en pasar de un volumen al otro.
const AMBIENT_MODE_FADE := 1.5

var _players := {}
var _ambient_tween: Tween
var _growl_tween: Tween
var _growl_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SOUNDS:
		var player := AudioStreamPlayer.new()
		player.stream = _load_stream(SOUNDS[key]["file"], SOUNDS[key]["loop"])
		add_child(player)
		_players[key] = player


# ---------- Ambiente ----------

## Empieza el ambiente con un fundido. Si ya está sonando, no lo reinicia.
func start_ambient() -> void:
	var player := _players["ambient"] as AudioStreamPlayer
	if player.stream == null:
		return
	if _ambient_tween:
		_ambient_tween.kill()
	if not player.playing:
		player.volume_db = SILENT_DB
		player.play()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(player, "volume_db", _volume("ambient"), FADE_IN)


## Baja el volumen en [param fade] segundos y corta el ambiente.
func stop_ambient(fade := 3.0) -> void:
	var player := _players["ambient"] as AudioStreamPlayer
	if not player.playing:
		return
	if _ambient_tween:
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(player, "volume_db", SILENT_DB, fade)
	_ambient_tween.tween_callback(player.stop)


## En juego el ambiente baja para dejar oír los efectos. En el inicio, la
## cinemática y los finales vuelve al volumen normal.
func set_ambient_mode(in_game: bool) -> void:
	var player := _players["ambient"] as AudioStreamPlayer
	if not player.playing:
		return
	var target := AMBIENT_GAME_DB if in_game else _volume("ambient")
	if _ambient_tween:
		_ambient_tween.kill()
	_ambient_tween = create_tween()
	_ambient_tween.tween_property(player, "volume_db", target, AMBIENT_MODE_FADE)

# ---------- CHILI ----------

## Gruñidos en loop: se llama cada cuadro con true mientras CHILI es monstruo y
## se ve, y con false el resto del tiempo.
func set_chili_growl(on: bool) -> void:
	if on == _growl_on:
		return
	_growl_on = on
	var player := _players["growl"] as AudioStreamPlayer
	if player.stream == null:
		return
	if _growl_tween:
		_growl_tween.kill()
	_growl_tween = create_tween()
	if on:
		if not player.playing:
			player.volume_db = SILENT_DB
			player.play()
		_growl_tween.tween_property(player, "volume_db", _volume("growl"), GROWL_FADE)
	else:
		_growl_tween.tween_property(player, "volume_db", SILENT_DB, GROWL_FADE)
		_growl_tween.tween_callback(player.stop)


## CHILI aparece cuando vuelve la luz.
func play_chili_behind() -> void:
	_play_once("behind")


# ---------- Efectos sueltos ----------

func play_hurt() -> void:
	_play_once("hurt")


func play_lights() -> void:
	_play_once("lights")


func stop_lights() -> void:
	(_players["lights"] as AudioStreamPlayer).stop()


func play_door() -> void:
	_play_once("door")


func play_door_open() -> void:
	_play_once("door_open")


func play_pickup() -> void:
	_play_once("pickup")

# ---------- Internos ----------

func _play_once(key: String) -> void:
	var player := _players[key] as AudioStreamPlayer
	if player.stream == null:
		return
	player.volume_db = _volume(key)
	player.play()


func _volume(key: String) -> float:
	return SOUNDS[key]["volume"]


func _load_stream(file: String, loop: bool) -> AudioStream:
	for extension in EXTENSIONS:
		var path := "%s%s.%s" % [AUDIO_DIR, file, extension]
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			# ogg y mp3 tienen "loop"; con wav hay que activarlo en Import.
			if loop and "loop" in stream:
				stream.set("loop", true)
			return stream
	push_warning("Sound: no encontré %s%s (.ogg/.mp3/.wav)" % [AUDIO_DIR, file])
	return null
	
