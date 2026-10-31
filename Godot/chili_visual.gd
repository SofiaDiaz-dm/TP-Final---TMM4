extends Node2D

var gravedad := 0.5   # los asigna el script del juego
var mirada := 0.0
var t := 0.0

# posiciones fijas de las manchas de infección
const MANCHAS := [Vector2(-25, 10), Vector2(20, 25), Vector2(-5, -5), Vector2(30, -10),
				  Vector2(-35, 35), Vector2(5, 45), Vector2(-15, 25), Vector2(35, 40)]

func _process(delta):
	t += delta
	queue_redraw()

func _draw():
	var col := Color(0.95, 0.92, 0.9).lerp(Color(0.5, 0.3, 0.4), gravedad)
	var zoom := 1.0 + mirada * 0.25   # mirar de cerca = acercarse
	var temblor := Vector2(sin(t * 25.0), cos(t * 31.0)) * gravedad * 3.0
	draw_set_transform(temblor, 0.0, Vector2(zoom, zoom))

	# orejas: se van cayendo con la gravedad
	var caida := gravedad * 25.0
	draw_colored_polygon(PackedVector2Array([Vector2(-35, -55), Vector2(-40 - caida, -120 + caida * 2.0), Vector2(-15, -60)]), col)
	draw_colored_polygon(PackedVector2Array([Vector2(35, -55), Vector2(40 + caida, -120 + caida * 2.0), Vector2(15, -60)]), col)

	# cuerpo y cabeza
	draw_circle(Vector2(0, 20), 60, col)
	draw_circle(Vector2(0, -35), 38, col)
	draw_circle(Vector2(-12, -40), 5, Color.BLACK)
	draw_circle(Vector2(12, -40), 5, Color.BLACK)

	# bulto que crece: la deformación
	draw_circle(Vector2(35, 30), 15.0 + gravedad * 25.0, col.darkened(0.2))

	# manchas de infección: más cuanto más grave
	var n := int(gravedad * MANCHAS.size() + 0.5)
	for i in n:
		draw_circle(MANCHAS[i], 6.0 + gravedad * 6.0, Color(0.45, 0.8, 0.3))
		if mirada > 0.5:   # al mirar de cerca se revela el detalle
			draw_circle(MANCHAS[i], 2.5, Color(0.2, 0.1, 0.2))
