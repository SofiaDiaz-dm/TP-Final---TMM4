extends Node2D

@export var sensibilidad := Vector2(800.0, 800.0)  # píxeles por unidad de mirada
@export var invertir_x := false
@export var umbral_pestañeo := 0.5
@export var radio := 40.0

var pos := Vector2.ZERO
var color := Color.WHITE

func _ready():
	pos = get_viewport_rect().size / 2.0

func _process(delta):
	var tamaño = get_viewport_rect().size
	var centro = tamaño / 2.0
	var g = EyeInput.gaze

	# x: positivo = mirás hacia tu izquierda, por eso se invierte para que la figura vaya al mismo lado
	var dir_x = 1.0 if invertir_x else -1.0
	var objetivo = centro + Vector2(dir_x * g.x * sensibilidad.x, -g.y * sensibilidad.y)
	objetivo = objetivo.clamp(Vector2(radio, radio), tamaño - Vector2(radio, radio))

	pos = pos.lerp(objetivo, 10.0 * delta)

	var cerrado = EyeInput.blink > umbral_pestañeo
	color = color.lerp(Color.RED if cerrado else Color.WHITE, 15.0 * delta)

	queue_redraw()

func _draw():
	draw_circle(pos, radio, color)
