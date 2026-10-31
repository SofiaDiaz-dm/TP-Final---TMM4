extends Node2D

var contagio := 0.0   # lo asigna el script del juego
var t := 0.0

func _process(delta):
	t += delta
	queue_redraw()

func _draw():
	var col := Color(0.75, 0.55, 0.35).lerp(Color(0.45, 0.7, 0.3), contagio)
	draw_circle(Vector2.ZERO, 30, col)   # almohadilla

	for i in 4:   # dedos que se hinchan y laten
		var ang := deg_to_rad(-60.0 + i * 40.0)
		var pos := Vector2(sin(ang), -cos(ang)) * 38.0
		var pulso := 0.5 + 0.5 * sin(t * 3.0 + i)
		draw_circle(pos, 10.0 + contagio * 10.0 * pulso, col.darkened(0.1))

	if contagio > 0.3:
		draw_circle(Vector2(20, 18), 8.0 + contagio * 20.0, col.darkened(0.25))
	if contagio > 0.6:
		draw_circle(Vector2(-25, 15), 6.0 + contagio * 15.0, Color(0.4, 0.2, 0.5))
