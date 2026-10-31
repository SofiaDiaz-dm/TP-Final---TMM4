extends Control

func _ready():
	await get_tree().create_timer(6.0).timeout
	get_tree().change_scene_to_file("res://juego.tscn")  # vuelve al inicio
