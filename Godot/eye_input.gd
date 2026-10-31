extends Node
# Autoload "EyeInput": recibe por UDP lo que manda ojos.py (cara y manos).
#  - mano DERECHA: agarrar (palma abierta y después puño) y abrir la mano para entregar.
#  - mano IZQUIERDA: zoom (palma abierta).

signal agarrar

@export var palma_min := 0.3   # segundos de palma abierta antes de poder agarrar
@export var puno_min := 0.1    # segundos de puño cerrado para confirmar
@export var enfriar := 0.8     # espera después de agarrar

var udp := PacketPeerUDP.new()
var face := false
var gaze := Vector2.ZERO
var blink := 0.0
var eyes_closed_time := 0.0
var hand := false              # mano derecha a la vista
var gesture := "None"          # gesto de la mano derecha
var zoom_hand := false         # mano izquierda a la vista
var zoom_gesture := "None"     # gesto de la mano izquierda
var palma_lista := false       # true cuando la palma derecha lleva abierta el tiempo suficiente

var _sin_datos := 0.0
var _palma_t := 0.0
var _sin_palma := 0.0
var _puno_t := 0.0
var _espera := 0.0


func _ready():
	udp.bind(4242, "127.0.0.1")


func _process(delta):
	# --- datos que llegan de Python ---
	while udp.get_available_packet_count() > 0:
		var d = JSON.parse_string(udp.get_packet().get_string_from_utf8())
		if typeof(d) != TYPE_DICTIONARY:
			continue
		_sin_datos = 0.0
		face = d.get("face", false)
		hand = d.get("hand", false)
		gesture = d.get("gesture", "None")
		zoom_hand = d.get("zoom_hand", false)
		zoom_gesture = d.get("zoom_gesture", "None")
		if face:
			gaze = gaze.lerp(Vector2(d.get("gaze_x", 0.0), d.get("gaze_y", 0.0)), 0.3)
			blink = (d.get("blink_l", 0.0) + d.get("blink_r", 0.0)) / 2.0

	# si Python se cierra, no nos quedamos con el último valor
	_sin_datos += delta
	if _sin_datos > 1.0:
		face = false
		hand = false
		zoom_hand = false

	# --- ojos cerrados (o cara fuera de cámara) ---
	if not face or blink > 0.6:
		eyes_closed_time += delta
	else:
		eyes_closed_time = 0.0

	# --- gesto de agarrar (mano derecha): palma abierta y después puño ---
	if hand and gesture == "Open_Palm":
		_palma_t += delta
		_sin_palma = 0.0
	else:
		_sin_palma += delta
		if _sin_palma > 1.0:
			_palma_t = 0.0   # pasó mucho tiempo: hay que volver a abrir la mano

	if hand and gesture == "Closed_Fist":
		_puno_t += delta
	else:
		_puno_t = 0.0

	_espera = maxf(_espera - delta, 0.0)
	palma_lista = hand and _palma_t >= palma_min

	if _puno_t >= puno_min and _palma_t >= palma_min and _espera <= 0.0:
		_palma_t = 0.0
		_puno_t = 0.0
		_espera = enfriar
		agarrar.emit()
