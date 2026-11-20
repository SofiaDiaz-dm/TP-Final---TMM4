class_name Cli
extends RefCounted
## Banderas de línea de comandos.
##
## Godot separa los argumentos propios de los del juego con `--`, así que hay
## que mirar en las dos listas para encontrar una bandera sin importar cómo se
## haya invocado.

static func has_flag(flag: String) -> bool:
	return flag in OS.get_cmdline_user_args() or flag in OS.get_cmdline_args()
