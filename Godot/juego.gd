extends Node2D

enum Estado { OBSERVANDO, MIRANDO, TOCANDO, ALEJANDOSE, FINAL_ABANDONO }
var estado := Estado.OBSERVANDO

@onready var chili = $Chili
@onready var puerta: Node2D = $Puerta
@onready var punto: Node2D = $Punto
@onready var pata = $Pata

# --- ajustes (se tocan desde el Inspector) ---
@export var sensibilidad := Vector2(800.0, 800.0)
@export var invertir_x := false
@export var radio_chili := 110.0
@export var radio_puerta := 90.0
@export var radio_toque := 100.0
@export var umbral_detalle := 0.5
@export var seg_por_toque := 2.0
@export var seg_ojos_cerrados := 0.8

# --- mundo ---
var gravedad := 0.5     # CHILI: 0 sano, 1 crítico
var contagio := 0.0     # KAISER: 0 normal, 1 deformada
var pendiente := 0.0    # mejora sin fijar
var mirada := 0.0       # 0..1, mirar de cerca

# --- ojos ---
var offset := Vector2.ZERO
var g_pos := Vector2.ZERO

# --- tocar / alejarse ---
var toque := 0.0
var punto_t := 0.0
var t_puerta := 0.0

# --- pata defectuosa ---
var deriva_t := 0.0
var trabada := 0.0
var pata_obj := Vector2.ZERO


func _ready():
	g_pos = get_viewport_rect().size / 2.0
	pata_obj = g_pos


func _input(event):
	# mirá al centro de la pantalla y apretá Enter para calibrar
	if event.is_action_pressed("ui_accept"):
		offset = EyeInput.gaze
		print("Calibrado: ", offset)


func _process(delta):
	if estado == Estado.FINAL_ABANDONO:
		return

	# 1. mirada -> posición en pantalla
	var tam := get_viewport_rect().size
	var g := EyeInput.gaze - offset
	var dir_x := 1.0 if invertir_x else -1.0
	var crudo := tam / 2.0 + Vector2(dir_x * g.x * sensibilidad.x, -g.y * sensibilidad.y)
	var fuera := not get_viewport_rect().grow(60.0).has_point(crudo)
	g_pos = g_pos.lerp(crudo.clamp(Vector2.ZERO, tam), 8.0 * delta)

	# 2. ¿estás mirando de verdad? (ojos cerrados, sin cara o mirando fuera = no)
	var mirando_pantalla := EyeInput.eyes_closed_time < seg_ojos_cerrados and not fuera

	# 3. punto guía que se mueve lento sobre la herida
	punto_t += delta
	punto.global_position = chili.global_position + Vector2(sin(punto_t * 0.7) * 110.0, sin(punto_t * 1.4) * 30.0)
	punto.visible = mirada >= umbral_detalle

	var sobre_chili := g_pos.distance_to(chili.global_position) < radio_chili
	var sobre_puerta := g_pos.distance_to(puerta.global_position) < radio_puerta
	var siguiendo: bool = pata.global_position.distance_to(punto.global_position) < radio_toque
	# 4. transiciones
	var nuevo := Estado.OBSERVANDO
	if mirando_pantalla:
		if sobre_puerta:
			nuevo = Estado.ALEJANDOSE
		elif sobre_chili:
			if mirada >= umbral_detalle and siguiendo:
				nuevo = Estado.TOCANDO
			else:
				nuevo = Estado.MIRANDO
	if nuevo != estado:
		_cambiar_estado(nuevo)

	# 5. qué pasa en cada estado
	match estado:
		Estado.OBSERVANDO:
			mirada = move_toward(mirada, 0.0, 1.5 * delta)
			toque = maxf(toque - delta, 0.0)
			_empeorar(delta)
		Estado.MIRANDO:
			mirada = move_toward(mirada, 1.0, 0.5 * delta)
			toque = maxf(toque - delta, 0.0)
			_fijar(delta)
		Estado.TOCANDO:
			mirada = move_toward(mirada, 1.0, 0.5 * delta)
			_tocar(delta)
		Estado.ALEJANDOSE:
			mirada = move_toward(mirada, 0.0, 1.5 * delta)
			toque = maxf(toque - delta, 0.0)
			_empeorar(delta)
			t_puerta += delta
			if t_puerta > 1.5:
				_cambiar_estado(Estado.FINAL_ABANDONO)

	_mover_pata(delta)
	_actualizar_visuales()


func _cambiar_estado(nuevo):
	estado = nuevo
	t_puerta = 0.0
	print("Estado: ", Estado.keys()[estado])
	if estado == Estado.FINAL_ABANDONO:
		get_tree().change_scene_to_file("res://final_abandono.tscn")


func _empeorar(delta):
	pendiente = move_toward(pendiente, 0.0, 0.02 * delta)
	gravedad = minf(gravedad + 0.01 * delta, 1.0)


func _fijar(delta):
	# mirar de cerca convierte la mejora pendiente en mejora real
	var cant := minf(pendiente, 0.05 * delta * mirada)
	pendiente -= cant
	gravedad = maxf(gravedad - cant, 0.0)


func _tocar(delta):
	if trabada <= 0.0:
		toque += delta / seg_por_toque
	if toque >= 1.0:
		toque = 0.0
		pendiente += 0.08                        # CHILI mejora (si después lo mirás)
		contagio = minf(contagio + 0.08, 1.0)    # la pata de KAISER se deforma


func _mover_pata(delta):
	deriva_t += delta
	if trabada > 0.0:
		trabada -= delta   # se queda quieta
	else:
		if estado == Estado.TOCANDO and randf() < contagio * 0.5 * delta:
			trabada = randf_range(0.3, 0.9)
		var temblor := Vector2(randf_range(-1, 1), randf_range(-1, 1)) * contagio * 8.0
		var deriva := Vector2(sin(deriva_t * 0.9), cos(deriva_t * 0.7)) * contagio * 70.0
		pata_obj = g_pos + temblor + deriva
	pata.global_position = pata.global_position.lerp(pata_obj, 18.0 * delta)


func _actualizar_visuales():
	chili.gravedad = gravedad
	chili.mirada = mirada
	pata.contagio = contagio
