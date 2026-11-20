"""Pose de la cabeza y de los ojos a partir de landmarks de la cara.

Solo geometria: no importa MediaPipe ni OpenCV, asi que se puede probar sin
camara (ver test_pose.py).

Convencion de signos, en grados:
    yaw   positivo = la persona gira hacia SU izquierda.
    pitch positivo = la persona levanta el menton (mira hacia arriba).

La nariz es un punto que sobresale del plano de los ojos, asi que su corrimiento
respecto del centro de los ojos es la tangente del angulo. Despejar con atan()
da grados casi exactos cerca del centro, que es donde se juega.

La imagen se asume SIN espejar, o sea la izquierda de la persona cae del lado
derecho de la imagen. Por eso las esquinas de los ojos se ordenan por X en vez de
confiar en su indice: el indice cambia si se espeja antes de detectar, la
posicion en la imagen no miente.

Para el parpadeo no se usan los blendshapes de MediaPipe: estan entrenados con
caras occidentales y en ojos pequenos (asiaticos) dan valores altos incluso con
los ojos abiertos. En cambio se usa el Eye Aspect Ratio (EAR) de los landmarks,
que mide la apertura real del ojo y no depende de la forma.
"""

from __future__ import annotations

import math

# Esquinas externas de los ojos y punta de la nariz.
EYE_CORNER_A = 33
EYE_CORNER_B = 263
NOSE_TIP = 1

# Cuanto sobresale la nariz respecto del ancho entre esquinas oculares. El valor
# teorico es ~0.25, pero la prueba en vivo mostro que 0.30 exageraba el angulo
# (66 grados para un giro de ~50). 0.50 lo acerca a la realidad.
NOSE_DEPTH_RATIO = 0.50
# Cuanto cae la punta de la nariz por debajo de la linea de los ojos con la cara
# derecha. El cero real lo fija la calibracion del juego.
NOSE_HEIGHT_RATIO = 0.32
# Por encima de este angulo la lectura ya no es confiable: la nariz se escapa
# del triangulo de los ojos.
MAX_HEAD_DEGREES = 70.0

# Landmarks del ojo para el Eye Aspect Ratio.
# Orden: [esquina externa, parpado superior externo, parpado superior interno,
#         esquina interna, parpado inferior interno, parpado inferior externo]
RIGHT_EYE = [33, 160, 158, 133, 153, 144]
LEFT_EYE = [362, 385, 387, 263, 373, 380]

# EAR tipico: abierto ~0.25-0.30, cerrado ~0.05-0.15.
# Para ojos pequenos (asiaticos) el EAR abierto es mas bajo, asi que se baja
# el umbral para no leerlos como cerrados.
EAR_OPEN = 0.20
EAR_CLOSED = 0.12


def _dist(a, b) -> float:
    return math.hypot(a.x - b.x, a.y - b.y)


def eye_aspect_ratio(landmarks, eye_indices) -> float:
    """EAR del ojo. Mas alto = mas abierto."""
    p = [landmarks[i] for i in eye_indices]
    vertical = _dist(p[1], p[5]) + _dist(p[2], p[4])
    horizontal = 2.0 * _dist(p[0], p[3])
    if horizontal < 1e-6:
        return 0.0
    return vertical / horizontal


def ear_to_blink(ear: float) -> float:
    """Convierte EAR a 0 (abierto) .. 1 (cerrado)."""
    if ear >= EAR_OPEN:
        return 0.0
    if ear <= EAR_CLOSED:
        return 1.0
    return (EAR_OPEN - ear) / (EAR_OPEN - EAR_CLOSED)


def head_pose(landmarks, height: int, width: int) -> dict | None:
    """Devuelve {"head_yaw", "head_pitch"} en grados, o None si no se puede."""
    if width <= 0 or height <= 0:
        return None

    eye_a = landmarks[EYE_CORNER_A]
    eye_b = landmarks[EYE_CORNER_B]
    nose = landmarks[NOSE_TIP]

    left_x, right_x = sorted((eye_a.x, eye_b.x))
    eye_span = right_x - left_x
    if eye_span < 1e-4:
        return None

    # x viene normalizado por el ancho e y por el alto: para compararlos hay
    # que pasar todo a la misma unidad (anchos de imagen).
    yaw_ratio = (nose.x - left_x) / eye_span - 0.5
    yaw = math.degrees(math.atan(yaw_ratio / NOSE_DEPTH_RATIO))

    eye_mid_y = (eye_a.y + eye_b.y) * 0.5
    vertical = (nose.y - eye_mid_y) * (height / width) / eye_span
    pitch = math.degrees(math.atan((NOSE_HEIGHT_RATIO - vertical) / NOSE_DEPTH_RATIO))

    return {
        "head_yaw": max(-MAX_HEAD_DEGREES, min(MAX_HEAD_DEGREES, yaw)),
        "head_pitch": max(-MAX_HEAD_DEGREES, min(MAX_HEAD_DEGREES, pitch)),
    }
