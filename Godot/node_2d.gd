extends Node2D

func _process(_delta):
	print(EyeInput.gaze, " blink: ", EyeInput.blink, " cerrados: ", EyeInput.eyes_closed_time)
