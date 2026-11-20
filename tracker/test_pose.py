"""Prueba de la geometria de la cabeza. No necesita camara ni MediaPipe.

    python tracker/test_pose.py
"""

import sys
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).parent))
import pose  # noqa: E402

WIDTH, HEIGHT = 640, 480

_failures = 0


def landmark(x: float, y: float) -> SimpleNamespace:
    return SimpleNamespace(x=x, y=y)


def face(nose_x: float = 0.50, nose_y: float | None = None, mirrored: bool = False):
    """Cara de frente: la nariz cae NOSE_HEIGHT_RATIO bajo la linea de los ojos."""
    span = 0.20
    eye_left, eye_right = 0.40, 0.60
    if nose_y is None:
        nose_y = 0.40 + pose.NOSE_HEIGHT_RATIO * span * (WIDTH / HEIGHT)

    landmarks = [landmark(0.0, 0.0)] * 300
    landmarks[pose.EYE_CORNER_A] = landmark(eye_right if mirrored else eye_left, 0.40)
    landmarks[pose.EYE_CORNER_B] = landmark(eye_left if mirrored else eye_right, 0.40)
    landmarks[pose.NOSE_TIP] = landmark(nose_x, nose_y)
    return landmarks


def expect(condition: bool, description: str, value: object = "") -> None:
    global _failures
    if not condition:
        _failures += 1
        print(f"MAL  {description}: {value}")


def main() -> int:
    front = pose.head_pose(face(), HEIGHT, WIDTH)
    expect(abs(front["head_yaw"]) < 1.0, "cara de frente, yaw ~0", front["head_yaw"])
    expect(abs(front["head_pitch"]) < 1.0, "cara de frente, pitch ~0", front["head_pitch"])

    # Girar a SU izquierda: la nariz se corre al lado derecho de la imagen.
    left = pose.head_pose(face(nose_x=0.53), HEIGHT, WIDTH)
    expect(left["head_yaw"] > 1.0, "giro a su izquierda da yaw positivo", left["head_yaw"])

    right = pose.head_pose(face(nose_x=0.47), HEIGHT, WIDTH)
    expect(right["head_yaw"] < -1.0, "giro a su derecha da yaw negativo", right["head_yaw"])

    # Menton arriba: la nariz sube respecto de la linea de los ojos.
    span = 0.20
    neutral_y = 0.40 + pose.NOSE_HEIGHT_RATIO * span * (WIDTH / HEIGHT)
    up = pose.head_pose(face(nose_y=neutral_y - 0.03), HEIGHT, WIDTH)
    expect(up["head_pitch"] > 1.0, "menton arriba da pitch positivo", up["head_pitch"])

    down = pose.head_pose(face(nose_y=neutral_y + 0.03), HEIGHT, WIDTH)
    expect(down["head_pitch"] < -1.0, "menton abajo da pitch negativo", down["head_pitch"])

    # Espejar la imagen no puede cambiar el signo: las esquinas se ordenan por X.
    mirrored = pose.head_pose(face(nose_x=0.53, mirrored=True), HEIGHT, WIDTH)
    expect(abs(mirrored["head_yaw"] - left["head_yaw"]) < 0.01,
           "espejar no cambia el resultado", mirrored["head_yaw"])

    # Parpadeo por Eye Aspect Ratio: valores bajos de EAR son ojo cerrado.
    open_eye = [landmark(0.1, 0.5), landmark(0.2, 0.4), landmark(0.3, 0.4),
                landmark(0.4, 0.5), landmark(0.3, 0.6), landmark(0.2, 0.6)]
    closed_eye = [landmark(0.1, 0.5), landmark(0.2, 0.5), landmark(0.3, 0.5),
                  landmark(0.4, 0.5), landmark(0.3, 0.5), landmark(0.2, 0.5)]
    ear_open = pose.eye_aspect_ratio(open_eye, list(range(6)))
    ear_closed = pose.eye_aspect_ratio(closed_eye, list(range(6)))
    expect(ear_open > ear_closed, "EAR abierto > EAR cerrado", f"{ear_open:.3f} vs {ear_closed:.3f}")
    expect(pose.ear_to_blink(ear_open) < 0.2, "EAR abierto da blink ~0", pose.ear_to_blink(ear_open))
    expect(pose.ear_to_blink(ear_closed) > 0.8, "EAR cerrado da blink ~1", pose.ear_to_blink(ear_closed))

    if _failures == 0:
        print("POSE: OK")
    return 0 if _failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
