extends Node
## Prueba de humo, sin ventana.
##
## Levanta la escena real y ejercita el ciclo de un remedio: agarrar, dejar,
## agarrar y entregar. Todo por gesto, porque el juego ya no tiene teclado ni
## mouse: se le inyectan paquetes a EyeInput como si vinieran del tracker.
##
##     godot --headless res://dev/smoke.tscn

var _failures := 0


func _ready() -> void:
	_check_input()

	var game: Game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame

	game.running = true
	var remedy: Pickup = game.remedies[0]

	_expect(game.remedies.size() == 3, "hay 3 remedios")
	_expect(remedy.state == Pickup.State.ROOM, "el remedio arranca en el cuarto")

	# Agarrar mirándolo: palma abierta y puño, el gesto real.
	game.looked_remedy = remedy
	_grab_gesture(game)
	_expect(game.carried == remedy, "el gesto agarró el remedio mirado")
	_expect(remedy.state == Pickup.State.HAND, "el remedio está en la mano")
	_expect(remedy.get_parent() == game.camera, "el remedio cuelga de la cámara")

	# No se puede llevar dos cosas.
	_grab_gesture(game)
	_expect(game.carried == remedy, "no agarra un segundo remedio")

	# Soltarlo lo devuelve a su lugar.
	game.call("_drop")
	_expect(game.carried == null, "soltar vacía la mano")
	_expect(remedy.state == Pickup.State.ROOM, "el remedio volvió al cuarto")
	_expect(remedy.position.is_equal_approx(remedy.home), "volvió a su posición")

	# Entregarlo lo saca del mundo y cura: mano abierta mirando a CHILI.
	var gravity_before: float = game.gravity
	game.looked_remedy = remedy
	_grab_gesture(game)
	_deliver_gesture(game)
	_expect(game.delivered == 1, "cuenta la entrega")
	_expect(remedy.state == Pickup.State.DELIVERED, "el remedio quedó entregado")
	_expect(not remedy.visible, "el remedio entregado no se ve")
	_expect(game.gravity < gravity_before, "entregar baja la gravedad")

	# El HUD tiene que enseñar el gesto, no una tecla.
	_expect("llevás" not in game.call("_target_text"), "sin nada en la mano no habla de llevás")
	var third: Pickup = game.remedies[2]
	game.looked_remedy = third
	_expect("palma" in game.call("_target_text"), "el HUD enseña el gesto de agarrar")
	_expect(third.item_name in game.call("_target_text"), "el HUD nombra el remedio")
	game.looked_remedy = null
	game.targeted_remedy = null
	_expect("puerta" in game.call("_target_text"), "el HUD avisa de la puerta")

	# La puerta se abre y se cierra con la mano izquierda, mirándola.
	game.carried = null
	game.looked_remedy = null
	game.targeted_remedy = null
	var was_closed: bool = game.door_closed
	_door_gesture(game, was_closed)
	_expect(game.door_closed != was_closed, "el gesto abre o cierra la puerta")

	# La mano derecha es para los remedios: mirando la puerta no la toca.
	var closed_now: bool = game.door_closed
	var gesture := "Open_Palm" if closed_now else "Closed_Fist"
	EyeInput._ingest({"hand": true, "gesture": gesture}, 1.0 / 60.0)
	game._door_toggle_cooldown = 0.0
	game.call("_update_door_toggle", 0.016)
	EyeInput._ingest({"hand": false, "gesture": "None"}, 1.0 / 60.0)
	_expect(game.door_closed == closed_now, "la mano derecha no abre ni cierra la puerta")

	# Un solo juego escuchando la entrada: si quedan dos, los gestos se
	# duplican y las pruebas siguientes mienten.
	game.queue_free()
	await get_tree().process_frame

	await _check_autostart()
	await _check_win_ending()
	await _check_blackout_ending()

	print("SMOKE: %s" % ("OK" if _failures == 0 else "%d fallas" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)


# ============================================================
#  GESTOS
# ============================================================

## Palma abierta el tiempo suficiente y después puño: es lo que detecta
## EyeInput y lo que dispara el agarre en el juego.
func _grab_gesture(game: Game) -> void:
	EyeInput._ingest({"hand": true, "gesture": "Open_Palm"}, 1.0 / 60.0)
	# 0.6 s de palma: pasa el tiempo de espera del gesto y también el enfriamiento
	# entre agarres, que en la vida real transcurre solo.
	EyeInput._update_grab(0.6)
	EyeInput._ingest({"hand": true, "gesture": "Closed_Fist"}, 1.0 / 60.0)
	EyeInput._update_grab(0.06)


## Mano abierta mirando a CHILI con algo en la mano: el juego cura en la regla
## 2b de `_update_rules`.
func _deliver_gesture(game: Game) -> void:
	game.focus = Game.Focus.CHILI
	game._time_without_chili = 0.0
	game._grabbed_at = -10.0
	EyeInput._ingest({"hand": true, "gesture": "Open_Palm"}, 1.0 / 60.0)
	EyeInput._update_grab(0.6)
	game.call("_update_rules", 0.016)
	EyeInput._ingest({"hand": false, "gesture": "None"}, 1.0 / 60.0)
	EyeInput._update_grab(0.016)


## Mira la puerta y hace el gesto que falta con la mano izquierda: puño si está
## abierta, palma si está cerrada.
func _door_gesture(game: Game, door_is_closed: bool) -> void:
	var door := game.room.glb_door
	var aim := door.global_position + Vector3(0.0, 1.0, 0.0)
	game.camera.look_at(aim, Vector3.UP)
	var gesture := "Open_Palm" if door_is_closed else "Closed_Fist"
	EyeInput._ingest({"left_hand": true, "left_gesture": gesture}, 1.0 / 60.0)
	game._door_toggle_cooldown = 0.0
	game.call("_update_door_toggle", 0.016)
	EyeInput._ingest({"left_hand": false, "left_gesture": "None"}, 1.0 / 60.0)


# ============================================================
#  FINALES
# ============================================================

## Sin tecla de inicio: cuando hay cara un rato, el juego arranca solo.
func _check_autostart() -> void:
	var game: Game = await _fresh_game(false)
	_expect(not game.running, "el juego no arranca sin ver una cara")
	EyeInput._ingest(_face_frame(0.0, 0.0), 1.0 / 60.0)
	game.call("_process", Game.AUTO_START_AFTER + 0.1)
	_expect(game.running, "con la cara a la vista el juego arranca solo")
	game.queue_free()
	await get_tree().process_frame


## Entregar los tres remedios cierra la partida, como antes del refactor.
## Se entregan por el gesto real, no tocando el contador a mano.
func _check_win_ending() -> void:
	var game: Game = await _fresh_game()
	for remedy: Pickup in game.remedies:
		game.looked_remedy = remedy
		_grab_gesture(game)
		_expect(game.carried == remedy, "el gesto agarra el %s" % remedy.item_name)
		_deliver_gesture(game)
	_expect(game.delivered == game.remedies.size(), "se entregaron los tres")
	game.call("_update_rules", 0.016)
	_expect(game.finished, "entregar los tres remedios termina la partida")
	_expect(game.ending == &"ayuda", "el final de los tres remedios es 'ayuda'")
	game.queue_free()
	await get_tree().process_frame


## El apagón no termina en negro: vuelve la luz, CHILI aparece delante del
## jugador y el contagio se va al máximo.
func _check_blackout_ending() -> void:
	var game: Game = await _fresh_game()
	game.blackout_beat = 0.0
	game.door_closed = true
	game.energy = 0.0
	game.call("_update_rules", 0.016)
	_expect(not game.lights_on, "la energía en cero apaga las luces")

	game._blackout_timer = 0.0
	game.call("_update_rules", 0.016)
	_expect(game.lights_on, "después del apagón vuelve la luz")
	_expect(game.chili.visible, "CHILI está a la vista con la luz prendida")
	_expect(game.contagion >= 1.0, "el contagio queda al máximo")

	var toward := game.chili.global_position - game.camera.global_position
	toward.y = 0.0
	var forward := -game.camera.global_transform.basis.z
	forward.y = 0.0
	_expect(forward.normalized().dot(toward.normalized()) > 0.9,
		"CHILI aparece delante de la cámara")

	# El final cae después del respiro, no en el mismo frame.
	await get_tree().process_frame
	await get_tree().process_frame
	_expect(game.ending == &"oscuridad", "el apagón termina en 'oscuridad'")
	game.queue_free()
	await get_tree().process_frame


func _fresh_game(start := true) -> Game:
	var game: Game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	game.running = start
	return game


func _expect(condition: bool, description: String) -> void:
	if not condition:
		_failures += 1
		printerr("  FALLA: ", description)


## Parpadeo, "ojos cerrados" y el gesto de agarre. Se alimenta EyeInput a mano
## para no depender de una cámara.
func _check_input() -> void:
	var step := 1.0 / 60.0

	# Un parpadeo: los párpados se cierran, la mecánica no se activa.
	EyeInput._ingest(_face_frame(1.0, 1.0), step)
	_expect(EyeInput.blink > 0.3, "el párpado se cierra en un parpadeo")
	_expect(EyeInput.eyes_closed_time == 0.0, "un parpadeo no acumula ojos cerrados")

	# Sostener los dos ojos cerrados sí es el estado "ojos cerrados".
	for i in 120:
		EyeInput._ingest(_face_frame(1.0, 1.0), step)
	_expect(EyeInput.eyes_closed_time > 1.0, "cerrar los dos ojos acumula tiempo")

	# Un guiño (un ojo solo) no cuenta.
	for i in 120:
		EyeInput._ingest(_face_frame(1.0, 0.0), step)
	_expect(EyeInput.eyes_closed_time == 0.0, "un guiño no es ojos cerrados")

	# Sin cara no es "ojos cerrados" ni debe arrastrar el estado.
	for i in 120:
		EyeInput._ingest(_face_frame(1.0, 1.0), step)
	# La gracia de seguimiento es 0.4 s: hay que superarla para que se pierda.
	for i in 30:
		EyeInput._ingest({"face": false}, step)
	_expect(not EyeInput.tracking, "sin cara se pierde el seguimiento")
	_expect(EyeInput.eyes_closed_time == 0.0, "sin cara no es ojos cerrados")

	# La pose llega con signo positivo cuando la cabeza gira a la izquierda.
	EyeInput._ingest(_face_frame(0.0, 0.0, 20.0), step)
	_expect(EyeInput.head.x > 0.0, "girar a la izquierda da ángulo positivo")
	EyeInput._ingest(_face_frame(0.0, 0.0, -20.0), step * 30.0)
	_expect(EyeInput.head.x < 0.0, "girar a la derecha da ángulo negativo")

	# El gesto de agarre: palma sostenida y después puño, una sola vez.
	EyeInput._ingest({"hand": true, "gesture": "Open_Palm"}, step)
	EyeInput._update_grab(0.2)
	_expect(EyeInput.palm_ready, "la palma sostenida queda lista")
	var grabs := [0]
	var counter := func() -> void: grabs[0] += 1
	EyeInput.grab.connect(counter)
	EyeInput._ingest({"hand": true, "gesture": "Closed_Fist"}, step)
	EyeInput._update_grab(0.06)
	_expect(grabs[0] == 1, "palma y puño disparan el agarre")
	# Con el puño sostenido no vuelve a disparar.
	EyeInput._update_grab(1.0)
	_expect(grabs[0] == 1, "un puño sostenido no repite el agarre")
	EyeInput.grab.disconnect(counter)

	# Se deja la entrada limpia para el resto de las pruebas.
	EyeInput._ingest({"face": false, "hand": false, "gesture": "None"}, 1.0)


func _face_frame(left: float, right: float, yaw := 0.0) -> Dictionary:
	return {
		"face": true,
		"head_yaw": yaw,
		"head_pitch": 0.0,
		"blink_l": left,
		"blink_r": right,
	}
