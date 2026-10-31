extends Node3D
# Juego en primera persona controlado con la mirada y las manos.
# Todo se construye por código: solo hace falta un Node3D con este script.
#
# Mirada: apunta y gira la cabeza de Kaiser (llevándola hacia un borde, la cabeza
#         sigue girando: recorrido de 360°).
# Mano derecha: agarra (palma abierta y después puño) y entrega (abrir la mano
#         mirando a CHILI).
# Mano izquierda: palma abierta = zoom, para acercarse.

enum Foco { CHILI, OBJETO, PUERTA, OTRO, CERRADOS }

# --- ajustes (se tocan desde el Inspector) ---
@export var giro_x := 90.0            # grados de giro de cabeza por unidad de mirada
@export var giro_y := 60.0
@export var max_yaw := 38.0           # cuánto gira la cabeza solo con mover los ojos
@export var max_pitch := 22.0         # cuánto puede subir / bajar
@export var borde_mirada := 0.45      # valor de "mirada" (texto de depuración) a partir del cual la cabeza sigue girando
@export var seg_borde := 0.5          # segundos que hay que sostener la mirada en el borde para que empiece a girar
@export var vel_giro := 90.0          # grados por segundo como máximo al girar así
@export var invertir_x := false       # tildalo si la cabeza gira para el lado contrario
@export var invertir_y := false
@export var fov_zoom := 38.0          # campo visual con el zoom al máximo (sin zoom es 75)
@export var vel_zoom := 2.5
@export var contagio_zoom := 0.6      # cuánto más contagia mirar a CHILI con zoom (0 = nada)
@export var radio_mirada := 15.0      # grados: qué tan cerca del centro cuenta como "mirar" a CHILI o la puerta
@export var radio_objeto := 9.0       # grados: lo mismo para los objetos a buscar
@export var gracia_objeto := 1.5      # segundos que se recuerda el último objeto mirado
@export var gracia_chili := 1.2       # segundos: si estabas mirando a CHILI hace menos que esto, cuenta como que lo mirás
@export var seg_ojos_cerrados := 0.5  # cuánto tiempo con los ojos cerrados cuenta como "cerrados"
@export var ritmo_contagio := 0.012   # por segundo, mirando a CHILI
@export var ritmo_gravedad := 0.004   # por segundo, CHILI empeora solo
@export var mejora_por_entrega := 0.25
@export var seg_puerta := 4.0         # segundos mirando la puerta para irse
@export var mostrar_lista := true     # lista de objetos a buscar (arriba a la derecha)

# Posiciones, vistas desde Kaiser: (ángulo, distancia en metros).
# 0 = al frente, + = hacia la izquierda, - = hacia la derecha, 180 = justo atrás.
const POS_CHILI := Vector2(0.0, 2.6)
const POS_VENDA := Vector2(72.0, 5.5)
const POS_FRASCO := Vector2(-72.0, 5.5)
const POS_PANO := Vector2(-144.0, 5.5)
const POS_PUERTA := Vector2(144.0, 9.0)

# --- estado del juego ---
var foco := Foco.OTRO
var iniciado := false
var terminado := false
var offset := Vector2.ZERO            # calibración de la mirada
var gravedad := 0.35                  # CHILI: 0 sano, 1 crítico
var contagio := 0.0                   # KAISER: 0 normal, 1 transformado
var fasc := 0.0                       # fascinación 0..1 (mirar de cerca)
var zoom := 0.0                       # 0 sin zoom, 1 zoom al máximo
var sigue := 0.0                      # cuánto te sigue CHILI hacia la puerta (0..1)
var entregados := 0
var en_mano := -1                     # índice del objeto que lleva Kaiser (-1 = ninguno)
var mirado := -1                      # objeto que está mirando ahora
var ultimo_mirado := -1
var t_ultimo_mirado := -100.0
var t_ultimo_chili := -100.0          # la última vez que estabas mirando a CHILI
var t_agarre := -10.0                 # cuándo agarraste el último objeto
var t_puerta := 0.0
var bait := 0.0                       # "tentación": CHILI llama la atención
var bait_t := 2.0
var flash := 0.0
var t := 0.0
var giro_base := 0.0                  # hacia dónde está girada la cabeza (360°)
var borde_t := 0.0                    # cuánto llevás mirando hacia un borde
var yaw := 0.0
var pitch := 0.0
var yaw_obj := 0.0
var pitch_obj := 0.0
var negro_a := 0.0

# --- nodos creados por código ---
var camara: Camera3D
var chili: Node3D
var chili_base := Vector3.ZERO
var puerta: Node3D
var chili_luz: OmniLight3D
var bulto: MeshInstance3D
var mat_chili: StandardMaterial3D
var mat_mancha: StandardMaterial3D
var mat_pata: StandardMaterial3D
var mat_puerta: StandardMaterial3D
var orejas: Array[MeshInstance3D] = []
var manchas: Array[MeshInstance3D] = []
var dedos: Array[MeshInstance3D] = []
var pustulas: Array[MeshInstance3D] = []
var patas: Array[Node3D] = []
var pata_reposo: Array[Vector3] = []
var items: Array[Node3D] = []
var items_nombre: Array[String] = []
var items_estado: Array[int] = []     # 0 en el cuarto, 1 en la mano, 2 entregado
var items_mat: Array[StandardMaterial3D] = []
var items_pos: Array[Vector3] = []    # dónde está cada objeto en el cuarto
var items_rot: Array[float] = []
var vineta_mat: ShaderMaterial
var negro: ColorRect
var fondo_final: ColorRect
var centro: Label
var hud: Label
var lista: Label


func _ready():
	_crear_ambiente()
	_crear_sala()
	_crear_chili()
	_crear_puerta()
	_crear_items()
	_crear_desorden()
	_crear_camara_y_patas()
	_crear_interfaz()
	EyeInput.agarrar.connect(_on_agarrar)


# ============================================================
#  ENTRADA
# ============================================================

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("ui_accept"):
		# mirá al centro de la pantalla y apretá Enter para calibrar

		offset = EyeInput.gaze
		giro_base = 0.0      # la cabeza vuelve a mirar al frente (a CHILI)
		yaw = 0.0
		yaw_obj = 0.0
		borde_t = 0.0
		if not iniciado:
			
			iniciado = true
			centro.text = ""
		print("Calibrado: ", offset)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		hud.visible = not hud.visible


# el gesto de agarrar (palma abierta + puño con la mano derecha) lo detecta EyeInput
func _on_agarrar():
	if not iniciado or terminado:
		return
	if en_mano >= 0:
		_aviso("Ya tenés algo en la mano")
		return
	var idx := mirado
	if idx < 0 and ultimo_mirado >= 0 and items_estado[ultimo_mirado] == 0 and (t - t_ultimo_mirado) < gracia_objeto:
		idx = ultimo_mirado
	if idx < 0:
		_aviso("No estás mirando ningún objeto")
		return
	items_estado[idx] = 1
	en_mano = idx
	var it := items[idx]
	it.reparent(camara, false)
	it.position = Vector3(0.1, -0.24, -0.5)
	it.rotation = Vector3.ZERO
	it.scale = Vector3.ONE * 0.5
	t_agarre = t


# no se muestra nada en el juego: esto solo escribe en la consola de Godot, para depurar
func _aviso(texto: String):
	print(texto)


# ============================================================
#  BUCLE PRINCIPAL
# ============================================================

func _process(delta):
	t += delta
	_actualizar_camara(delta)
	if iniciado and not terminado:
		_actualizar_juego(delta)
	_actualizar_visuales(delta)
	_actualizar_textos()


func _actualizar_camara(delta):
	# la mirada gira la cabeza de Kaiser (que está quieto, paralizado).
	# Con la mano derecha a la vista la cabeza se queda quieta (para que no se mueva al
	# levantarla), salvo cuando ya llevás un objeto: ahí tenés que poder mirar a CHILI.
	var g: Vector2 = EyeInput.gaze - offset
	var palma_arriba: bool = EyeInput.hand and EyeInput.gesture == "Open_Palm" and en_mano >= 0
	var mirando_bien: bool = EyeInput.face and EyeInput.blink < 0.5 and not (EyeInput.hand and en_mano < 0) and not palma_arriba
	# con zoom la cabeza gira más fino
	var escala := lerpf(1.0, fov_zoom / 75.0, zoom)
	var gx := 0.0
	var pide_borde := false
	if mirando_bien:
		var sx := -1.0 if invertir_x else 1.0
		var sy := -1.0 if invertir_y else 1.0
		gx = g.x * sx
		yaw_obj = clampf(gx * giro_x * escala, -max_yaw, max_yaw)
		pitch_obj = clampf(g.y * giro_y * sy * escala, -max_pitch, max_pitch)
		# el recorrido de 360°: la cabeza solo sigue girando si sostenés la mirada en un borde,
		# sin zoom y sin una mano abierta tapando la cara (da lecturas falsas).
		# Con el puño cerrado (llevando un objeto) sí puede girar.
		var mano_tapa: bool = (EyeInput.hand and EyeInput.gesture != "Closed_Fist") or EyeInput.zoom_hand
		pide_borde = not mano_tapa and zoom < 0.2 and EyeInput.blink < 0.3 and absf(gx) > borde_mirada
	if pide_borde:
		borde_t += delta
		if borde_t > seg_borde:
			var exceso := minf(absf(gx) - borde_mirada, 0.3) / 0.3
			giro_base += signf(gx) * exceso * vel_giro * delta
	else:
		borde_t = maxf(borde_t - 2.0 * delta, 0.0)
	yaw = lerpf(yaw, yaw_obj, 5.0 * delta)
	pitch = lerpf(pitch, pitch_obj, 5.0 * delta)
	camara.rotation_degrees = Vector3(pitch, giro_base + yaw, 0.0)


func _angulo(obj: Node3D, desfase: Vector3) -> float:
	var adelante: Vector3 = -camara.global_transform.basis.z
	var hacia: Vector3 = (obj.global_position + desfase - camara.global_position).normalized()
	return rad_to_deg(adelante.angle_to(hacia))


func _actualizar_juego(delta):
	var cerrados: bool = EyeInput.eyes_closed_time > seg_ojos_cerrados and not EyeInput.hand

	# 1. ¿qué objeto estás mirando? Con la palma abierta la elección queda fija,
	#    así no se pierde mientras levantás la mano.
	var fija: bool = EyeInput.hand and EyeInput.palma_lista and en_mano < 0
	if cerrados or en_mano >= 0:
		mirado = -1
	elif fija:
		mirado = ultimo_mirado if (ultimo_mirado >= 0 and items_estado[ultimo_mirado] == 0) else -1
	else:
		mirado = -1
		var mejor := radio_objeto
		for i in items.size():
			if items_estado[i] == 0:
				var a := _angulo(items[i], Vector3.ZERO)
				if a < mejor:
					mejor = a
					mirado = i
		if mirado >= 0:
			ultimo_mirado = mirado
			t_ultimo_mirado = t

	# 2. ¿a qué estás mirando en general?
	var nuevo := Foco.OTRO
	if cerrados:
		nuevo = Foco.CERRADOS
	elif mirado >= 0:
		nuevo = Foco.OBJETO
	elif _angulo(puerta, Vector3(0, 1.8, 0)) < radio_mirada:
		nuevo = Foco.PUERTA
	elif _angulo(chili, Vector3(0, 0.4, 0)) < radio_mirada:
		nuevo = Foco.CHILI
	if nuevo != foco:
		foco = nuevo
		print("Foco: ", Foco.keys()[foco])
	if foco == Foco.CHILI:
		t_ultimo_chili = t

	# 3. el mundo no espera: CHILI empeora solo (el doble si cerrás los ojos)
	var empeora := ritmo_gravedad
	if foco == Foco.CERRADOS:
		empeora *= 2.0
	gravedad += empeora * delta

	# 4. mirar a CHILI fascina... y contagia (más si te acercás con el zoom).
	#    Apartar la vista frena el contagio.
	if foco == Foco.CHILI:
		fasc = move_toward(fasc, 1.0, 0.35 * delta)
		contagio += ritmo_contagio * (0.3 + 0.7 * fasc) * (1.0 + zoom * contagio_zoom) * delta
	else:
		fasc = move_toward(fasc, 0.0, 0.8 * delta)

	# 5. abrir la mano con un objeto: si estabas mirando a CHILI (ahora o hace un instante)
	#    se lo entregás; si no, lo dejás en su lugar
	if en_mano >= 0 and EyeInput.hand and EyeInput.palma_lista and (t - t_agarre) > 0.7:
		print("Abriste la mano: foco=", Foco.keys()[foco], "  última vez mirando a CHILI hace ", snappedf(t - t_ultimo_chili, 0.1), " s")
		if foco == Foco.CHILI or (t - t_ultimo_chili) < gracia_chili:
			_entregar()
		else:
			_devolver()

	# 6. irse: sostener la mirada en la puerta. CHILI te sigue.
	if foco == Foco.PUERTA:
		t_puerta += delta
		sigue = move_toward(sigue, 1.0, delta / seg_puerta)
	else:
		t_puerta = maxf(t_puerta - 2.0 * delta, 0.0)
		sigue = move_toward(sigue, 0.0, 0.1 * delta)

	# 7. tentación: CHILI llama la atención con destellos (cada vez más seguido)
	bait_t -= delta
	if bait_t <= 0.0:
		bait = 1.0
		bait_t = randf_range(1.0, 2.5) * (1.4 - clampf(gravedad, 0.0, 1.0) * 0.6)
	bait = move_toward(bait, 0.0, 3.0 * delta)
	flash = move_toward(flash, 0.0, 1.5 * delta)

	# 8. finales
	if contagio >= 1.0:
		_final("contemplacion")
	elif gravedad >= 1.0:
		_final("perdida")
	elif entregados >= items.size():
		_final("ayuda")
	elif t_puerta >= seg_puerta:
		_final("abandono")


func _entregar():
	var it := items[en_mano]
	items_estado[en_mano] = 2
	it.visible = false
	_aviso("Le diste: " + items_nombre[en_mano])
	en_mano = -1
	entregados += 1
	gravedad = maxf(gravedad - mejora_por_entrega, 0.0)
	flash = 1.0


func _devolver():
	var i := en_mano
	var it := items[i]
	it.reparent(self, false)
	it.position = items_pos[i]
	it.rotation = Vector3(0.0, deg_to_rad(items_rot[i]), 0.0)
	it.scale = Vector3.ONE
	items_estado[i] = 0
	en_mano = -1
	_aviso("Dejaste: " + items_nombre[i])


func _final(tipo: String):
	terminado = true
	var textos := {
		"contemplacion": "Te ves reflejado en la pantalla apagada.\n\nYa no sos el que vino a cazar monstruos.",
		"abandono": "Saliste.\n\nCHILI te sigue, arrastrándose.",
		"perdida": "Mientras mirabas para otro lado,\nCHILI dejó de moverse.",
		"ayuda": "CHILI respira.\n\nTus patas ya no son las mismas.",
	}
	fondo_final.color = Color.BLACK
	centro.text = textos[tipo]
	print("FINAL: ", tipo)
	await get_tree().create_timer(10.0).timeout
	get_tree().reload_current_scene()


# ============================================================
#  VISUALES (todo el estado se ve en el cuerpo)
# ============================================================

func _actualizar_visuales(delta):
	# --- CHILI según su gravedad ---
	var grav := clampf(gravedad, 0.0, 1.0)
	mat_chili.albedo_color = Color(0.9, 0.88, 0.85).lerp(Color(0.45, 0.3, 0.4), grav)
	bulto.scale = Vector3.ONE * (0.5 + grav * 1.8)
	for o in orejas:
		o.rotation.z = -signf(o.position.x) * deg_to_rad(grav * 60.0)
	var n := int(grav * manchas.size() + 0.5)
	for i in manchas.size():
		manchas[i].visible = i < n
	mat_mancha.emission_energy_multiplier = 0.4 + bait * 2.0
	chili_luz.light_energy = 0.8 + bait * 2.5 + flash * 4.0
	chili.rotation.z = sin(t * 28.0) * 0.03 * grav * (1.0 + bait * 2.0)

	# --- CHILI sigue a Kaiser hacia la puerta cuando quiere irse ---
	var destino := puerta.position
	chili.position = chili_base.lerp(destino, sigue * 0.85)
	var dir := destino - chili_base
	var giro_objetivo := atan2(dir.x, dir.z) if sigue > 0.02 else 0.0
	chili.rotation.y = lerp_angle(chili.rotation.y, giro_objetivo, 4.0 * delta)

	# --- zoom (mano izquierda abierta) y fascinación (se cierra el campo visual) ---
	var zoom_obj := 1.0 if (EyeInput.zoom_hand and EyeInput.zoom_gesture == "Open_Palm") else 0.0
	zoom = move_toward(zoom, zoom_obj, vel_zoom * delta)
	camara.fov = lerpf(75.0, fov_zoom, zoom) * lerpf(1.0, 0.7, fasc)
	vineta_mat.set_shader_parameter("fuerza", clampf(fasc * 0.4 + contagio * 0.9, 0.0, 1.0))

	# --- ojos cerrados: pantalla negra ---
	var cerrados: bool = iniciado and not terminado and EyeInput.eyes_closed_time > seg_ojos_cerrados and not EyeInput.hand
	negro_a = move_toward(negro_a, 1.0 if cerrados else 0.0, 4.0 * delta)
	negro.color = Color(0, 0, 0, negro_a)

	# --- las patas de Kaiser se deforman con el contagio ---
	mat_pata.albedo_color = Color(0.75, 0.55, 0.35).lerp(Color(0.45, 0.7, 0.3), contagio)
	var pulso := 1.0 + sin(t * 4.0) * 0.08 * contagio
	for i in dedos.size():
		var crecimiento := 1.0 + contagio * (0.8 + 0.5 * float(i % 2))
		dedos[i].scale = Vector3.ONE * crecimiento * pulso
	for i in pustulas.size():
		var umbral := 0.12 + 0.13 * float(i)
		var s := clampf((contagio - umbral) * 5.0, 0.0, 1.0)
		pustulas[i].visible = s > 0.02
		pustulas[i].scale = Vector3.ONE * maxf(s * 1.6, 0.01)
	for k in patas.size():
		patas[k].rotation.z = sin(t * 18.0 + float(k) * 2.0) * 0.04 * contagio

	# --- la pata derecha se levanta cuando levantás la mano derecha ---
	var alzada: bool = EyeInput.hand
	var obj_der: Vector3 = Vector3(0.12, -0.12, -0.42) if alzada else pata_reposo[1]
	patas[1].position = patas[1].position.lerp(obj_der, 10.0 * delta)
	var cerrada: bool = alzada and EyeInput.gesture == "Closed_Fist"
	patas[1].scale = patas[1].scale.lerp(Vector3.ONE * (0.85 if cerrada else 1.0), 15.0 * delta)

	# --- los objetos brillan cuando los mirás (más si ya estás por agarrarlos) ---
	var fija: bool = EyeInput.hand and EyeInput.palma_lista and en_mano < 0
	for i in items.size():
		var e := 0.25
		if items_estado[i] == 1:
			e = 0.8
		elif i == mirado:
			e = 3.0 if fija else 1.6
		items_mat[i].emission_energy_multiplier = e

	mat_puerta.emission_energy_multiplier = 0.6 + (t_puerta / seg_puerta) * 2.0


func _actualizar_textos():
	var g: Vector2 = EyeInput.gaze - offset
	var mano_txt: String = EyeInput.gesture if EyeInput.hand else "ninguna"
	var lista_txt: String = " (lista)" if EyeInput.palma_lista else ""
	var izq_txt: String = EyeInput.zoom_gesture if EyeInput.zoom_hand else "ninguna"
	var en_mano_txt: String = items_nombre[en_mano] if en_mano >= 0 else "-"
	var rumbo := int(fposmod(giro_base + yaw, 360.0))
	hud.text = "mirada: (%.2f, %.2f)   ojos cerrados: %.1fs\nmano der: %s%s   mano izq: %s   zoom: %.2f\nfoco: %s   rumbo: %d°\nfascinación: %.2f   contagio: %.2f\ngravedad CHILI: %.2f   entregados: %d/%d   en la mano: %s\n[Enter] recalibrar    [F1] ocultar esto" % [
		g.x, g.y, EyeInput.eyes_closed_time, mano_txt, lista_txt, izq_txt, zoom,
		Foco.keys()[foco], rumbo, fasc, contagio,
		gravedad, entregados, items.size(), en_mano_txt]

	# lista de objetos pendientes (sin instrucciones)
	var s := ""
	for i in items.size():
		if items_estado[i] != 2:
			s += items_nombre[i] + "\n"
	lista.text = s
	lista.visible = mostrar_lista and iniciado and not terminado


# ============================================================
#  CONSTRUCCIÓN DE LA ESCENA (formas simples en lugar de arte)
# ============================================================

func _mat(color: Color, emision := Color.BLACK, energia := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	if energia > 0.0:
		m.emission_enabled = true
		m.emission = emision
		m.emission_energy_multiplier = energia
	return m


func _esfera(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _caja(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b


func _capsula(r: float, alto: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = alto
	return c


func _cilindro(r: float, alto: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = alto
	return c


func _forma(mesh: Mesh, mat: Material, pos: Vector3, padre: Node) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = pos
	padre.add_child(m)
	return m


func _luz(pos: Vector3, color: Color, energia: float, rango: float, padre: Node) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energia
	l.omni_range = rango
	padre.add_child(l)
	return l


# posición a cierto ángulo (+ = izquierda, - = derecha) y distancia de Kaiser
func _polar(yaw_deg: float, dist: float, y: float) -> Vector3:
	var a := deg_to_rad(yaw_deg)
	return Vector3(-sin(a) * dist, y, -cos(a) * dist)


# diferencia entre dos ángulos, siempre entre 0 y 180
func _dif_ang(a: float, b: float) -> float:
	return absf(fposmod(a - b + 180.0, 360.0) - 180.0)


func _crear_ambiente():
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.25, 0.3, 0.35)
	env.ambient_light_energy = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.16, 0.18)
	env.fog_density = 0.04
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _crear_sala():
	# un cuarto cuadrado y cerrado alrededor de Kaiser
	var m_suelo := _mat(Color(0.18, 0.15, 0.13))
	var m_pared := _mat(Color(0.22, 0.24, 0.24))
	_forma(_caja(Vector3(24, 0.2, 24)), m_suelo, Vector3(0, -0.1, 0), self)
	_forma(_caja(Vector3(24, 5, 0.3)), m_pared, Vector3(0, 2.5, -11), self)
	_forma(_caja(Vector3(24, 5, 0.3)), m_pared, Vector3(0, 2.5, 11), self)
	_forma(_caja(Vector3(0.3, 5, 24)), m_pared, Vector3(-11, 2.5, 0), self)
	_forma(_caja(Vector3(0.3, 5, 24)), m_pared, Vector3(11, 2.5, 0), self)


func _crear_chili():
	chili = Node3D.new()
	chili.position = _polar(POS_CHILI.x, POS_CHILI.y, 0.0)
	chili_base = chili.position
	add_child(chili)
	mat_chili = _mat(Color(0.9, 0.88, 0.85))
	_forma(_esfera(0.28), mat_chili, Vector3(0, 0.28, 0), chili)        # cuerpo
	_forma(_esfera(0.17), mat_chili, Vector3(0, 0.58, 0.1), chili)      # cabeza
	var negro_ojo := _mat(Color.BLACK)
	_forma(_esfera(0.025), negro_ojo, Vector3(-0.065, 0.62, 0.25), chili)
	_forma(_esfera(0.025), negro_ojo, Vector3(0.065, 0.62, 0.25), chili)
	for lado in [-1.0, 1.0]:
		var l: float = lado
		var o := _forma(_capsula(0.045, 0.4), mat_chili, Vector3(l * 0.07, 0.85, 0.08), chili)
		orejas.append(o)
	# bulto: la deformación que crece
	bulto = _forma(_esfera(0.1), _mat(Color(0.35, 0.25, 0.3)), Vector3(0.22, 0.25, 0.15), chili)
	# manchas de infección
	mat_mancha = _mat(Color(0.3, 0.7, 0.2), Color(0.3, 0.9, 0.2), 0.5)
	var puntos := [Vector3(-0.1, 0.35, 0.24), Vector3(0.08, 0.2, 0.26), Vector3(0.0, 0.42, 0.24),
		Vector3(-0.18, 0.2, 0.2), Vector3(0.15, 0.4, 0.2), Vector3(0.0, 0.14, 0.24)]
	for p in puntos:
		var mancha := _forma(_esfera(0.035), mat_mancha, p, chili)
		mancha.visible = false
		manchas.append(mancha)
	chili_luz = _luz(Vector3(0, 1.2, 0.6), Color(0.75, 0.9, 0.85), 0.8, 3.5, chili)


func _crear_puerta():
	# la puerta está lejos, atrás a la izquierda
	puerta = Node3D.new()
	puerta.position = _polar(POS_PUERTA.x, POS_PUERTA.y, 0.0)
	puerta.rotation_degrees.y = POS_PUERTA.x
	puerta.scale = Vector3.ONE * 1.6
	add_child(puerta)
	var m_marco := _mat(Color(0.12, 0.1, 0.09))
	_forma(_caja(Vector3(0.15, 2.3, 0.2)), m_marco, Vector3(-0.7, 1.15, 0), puerta)
	_forma(_caja(Vector3(0.15, 2.3, 0.2)), m_marco, Vector3(0.7, 1.15, 0), puerta)
	_forma(_caja(Vector3(1.55, 0.15, 0.2)), m_marco, Vector3(0, 2.3, 0), puerta)
	mat_puerta = _mat(Color(0.2, 0.17, 0.12), Color(1.0, 0.8, 0.5), 0.6)
	_forma(_caja(Vector3(1.25, 2.2, 0.05)), mat_puerta, Vector3(0, 1.1, -0.05), puerta)
	_luz(Vector3(0, 1.1, 0.8), Color(1.0, 0.8, 0.5), 1.5, 5.0, puerta)


func _crear_item(nombre: String, mesh: Mesh, color: Color, pos: Vector3, rot_y: float):
	var it := Node3D.new()
	it.position = pos
	it.rotation_degrees.y = rot_y
	add_child(it)
	var m := _mat(color, color, 0.25)
	_forma(mesh, m, Vector3.ZERO, it)
	_luz(Vector3(0, 0.6, 0.5), color, 0.5, 2.2, it)   # un brillo suave para poder encontrarlo
	items.append(it)
	items_nombre.append(nombre)
	items_estado.append(0)
	items_mat.append(m)
	items_pos.append(pos)
	items_rot.append(rot_y)


func _crear_items():
	# repisa para el frasco
	var repisa := Node3D.new()
	repisa.position = _polar(POS_FRASCO.x, POS_FRASCO.y, 0.0)
	repisa.rotation_degrees.y = POS_FRASCO.x
	add_child(repisa)
	var m_madera := _mat(Color(0.2, 0.15, 0.1))
	_forma(_caja(Vector3(1.6, 0.08, 0.55)), m_madera, Vector3(0, 1.0, 0), repisa)
	_forma(_caja(Vector3(0.07, 1.0, 0.07)), m_madera, Vector3(-0.7, 0.5, 0), repisa)
	_forma(_caja(Vector3(0.07, 1.0, 0.07)), m_madera, Vector3(0.7, 0.5, 0), repisa)

	# los tres objetos a buscar, repartidos por el cuarto
	_crear_item("Venda", _cilindro(0.16, 0.2), Color(0.9, 0.9, 0.85),
		_polar(POS_VENDA.x, POS_VENDA.y, 0.1), POS_VENDA.x)
	_crear_item("Frasco", _capsula(0.1, 0.4), Color(0.9, 0.55, 0.1),
		_polar(POS_FRASCO.x, POS_FRASCO.y, 1.24), POS_FRASCO.x)
	_crear_item("Paño", _caja(Vector3(0.5, 0.08, 0.36)), Color(0.3, 0.6, 0.7),
		_polar(POS_PANO.x, POS_PANO.y, 0.04), POS_PANO.x)


func _crear_desorden():
	# cajas, barriles y muebles repartidos por todo el cuarto, sin tapar los objetos,
	# a CHILI ni a la puerta. La semilla fija hace que siempre sea el mismo cuarto.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var mats := [_mat(Color(0.2, 0.17, 0.14)), _mat(Color(0.16, 0.18, 0.18)), _mat(Color(0.24, 0.2, 0.16))]
	# zonas despejadas: (ángulo, distancia, margen en grados)
	var zonas := [
		Vector3(POS_VENDA.x, POS_VENDA.y, 8.0),
		Vector3(POS_FRASCO.x, POS_FRASCO.y, 10.0),
		Vector3(POS_PANO.x, POS_PANO.y, 8.0),
		Vector3(POS_CHILI.x, 99.0, 12.0),     # CHILI
		Vector3(POS_PUERTA.x, 99.0, 12.0),    # puerta
	]
	var puestos := 0
	var intentos := 0
	while puestos < 48 and intentos < 800:
		intentos += 1
		var yaw_d := rng.randf_range(-180.0, 180.0)
		var dist := rng.randf_range(3.0, 9.5)
		var libre := true
		for z in zonas:
			var zz: Vector3 = z
			if _dif_ang(yaw_d, zz.x) < zz.z and dist < zz.y + 0.8:
				libre = false
		if not libre:
			continue
		var tipo := rng.randi() % 3
		var mat: Material = mats[rng.randi() % mats.size()]
		var alto := 0.0
		var pieza: MeshInstance3D
		if tipo == 0:
			var tam := Vector3(rng.randf_range(0.4, 1.0), rng.randf_range(0.4, 0.9), rng.randf_range(0.4, 0.9))
			alto = tam.y
			pieza = _forma(_caja(tam), mat, _polar(yaw_d, dist, alto / 2.0), self)
		elif tipo == 1:
			alto = rng.randf_range(0.7, 1.0)
			pieza = _forma(_cilindro(rng.randf_range(0.28, 0.42), alto), mat, _polar(yaw_d, dist, alto / 2.0), self)
		else:
			alto = rng.randf_range(1.4, 2.2)
			pieza = _forma(_caja(Vector3(0.5, alto, 0.5)), mat, _polar(yaw_d, dist, alto / 2.0), self)
		pieza.rotation_degrees.y = rng.randf_range(0.0, 90.0)
		puestos += 1


func _crear_camara_y_patas():
	camara = Camera3D.new()
	camara.position = Vector3(0, 0.65, 0)
	camara.fov = 75.0
	add_child(camara)
	camara.current = true

	# las patas de Kaiser, pegadas a la cámara (como las manos en primera persona)
	mat_pata = _mat(Color(0.75, 0.55, 0.35))
	var mat_pustula := _mat(Color(0.5, 0.75, 0.25), Color(0.4, 0.9, 0.2), 0.6)
	for lado in [-1.0, 1.0]:
		var l: float = lado
		var pata := Node3D.new()
		pata.position = Vector3(l * 0.24, -0.3, -0.55)
		pata.rotation_degrees = Vector3(-10.0, -l * 12.0, 0.0)
		camara.add_child(pata)
		var palma := _forma(_esfera(0.08), mat_pata, Vector3.ZERO, pata)
		palma.scale = Vector3(1.0, 0.7, 1.5)
		for i in 3:
			dedos.append(_forma(_esfera(0.035), mat_pata, Vector3((i - 1) * 0.06, 0.0, -0.13), pata))
		for i in 3:
			var p := _forma(_esfera(0.03), mat_pustula, Vector3((i - 1) * 0.05, 0.05, -0.02 - i * 0.04), pata)
			p.visible = false
			pustulas.append(p)
		patas.append(pata)
		pata_reposo.append(pata.position)


func _crear_interfaz():
	# viñeta (se oscurece y se tiñe de verde con la fascinación y el contagio)
	var capa_v := CanvasLayer.new()
	capa_v.layer = 1
	add_child(capa_v)
	var vineta := ColorRect.new()
	capa_v.add_child(vineta)
	vineta.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vineta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float fuerza : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 uv = UV - vec2(0.5);
	float d = length(uv * vec2(1.0, 0.8));
	float v = smoothstep(0.2, 0.7, d);
	COLOR = vec4(0.04, 0.1, 0.02, v * fuerza);
}
"""
	vineta_mat = ShaderMaterial.new()
	vineta_mat.shader = sh
	vineta.material = vineta_mat

	# ojos cerrados: negro
	var capa_n := CanvasLayer.new()
	capa_n.layer = 2
	add_child(capa_n)
	negro = ColorRect.new()
	negro.color = Color(0, 0, 0, 0)
	capa_n.add_child(negro)
	negro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	negro.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# textos: depuración (F1 para ocultar) y lista de objetos
	var capa_h := CanvasLayer.new()
	capa_h.layer = 3
	add_child(capa_h)
	hud = Label.new()
	hud.position = Vector2(12, 8)
	hud.add_theme_font_size_override("font_size", 15)
	capa_h.add_child(hud)

	lista = Label.new()
	capa_h.add_child(lista)
	lista.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	lista.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	lista.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lista.offset_right = -16.0
	lista.offset_top = 10.0
	lista.add_theme_font_size_override("font_size", 18)

	# mensajes centrales y pantalla de final
	var capa_c := CanvasLayer.new()
	capa_c.layer = 4
	add_child(capa_c)
	fondo_final = ColorRect.new()
	fondo_final.color = Color(0, 0, 0, 0)
	capa_c.add_child(fondo_final)
	fondo_final.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo_final.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centro = Label.new()
	capa_c.add_child(centro)
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	centro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centro.add_theme_font_size_override("font_size", 28)
	centro.text = "Mirá al centro de la pantalla\ny apretá ENTER para empezar"
	
