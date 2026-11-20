class_name UdpTracker
extends RefCounted
## Recibe por UDP los paquetes JSON que manda tracker.py.

const BIND_ADDRESS := "127.0.0.1"

var _socket := PacketPeerUDP.new()


func open(listen_port: int) -> Error:
	return _socket.bind(listen_port, BIND_ADDRESS)


## Último paquete válido de la cola, o un diccionario vacío si no llegó nada.
## Si se acumularon varios, se descartan los viejos: solo importa el presente.
func poll() -> Dictionary:
	var latest := {}
	while _socket.get_available_packet_count() > 0:
		var parsed: Variant = JSON.parse_string(_socket.get_packet().get_string_from_utf8())
		if typeof(parsed) == TYPE_DICTIONARY:
			latest = parsed
	return latest
