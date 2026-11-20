"""Puente entre la camara y el juego.

Lee la cara y las manos con MediaPipe y manda por UDP un JSON por cuadro con la
pose de la cabeza, el parpadeo y los gestos de cada mano. El juego escucha en el
puerto 4242 (ver game/src/input/eye_input.gd).

Cada mano tiene un trabajo: la derecha agarra y entrega los remedios, la
izquierda abre y cierra la puerta. El zoom con la mano izquierda esta apagado
por ahora (bugueaba), asi que `hand_depth` se sigue mandando pero el juego lo
ignora.

La camara manda la POSE DE LA CABEZA, no la direccion de los ojos: los
blendshapes de mirada son muy ruidosos y no distinguen "miro de reojo" de "giro
la cabeza". Con landmarks, girar la cabeza mueve la nariz respecto de las
esquinas de los ojos, y de ahi sale un angulo en grados (la cuenta vive en
pose.py).

    python tracker.py                 # con ventana de la camara
    python tracker.py --no-preview    # solo manda datos
    python tracker.py --fake          # sin camara, datos sinteticos

Los modelos .task tienen que estar en models/ (al lado de este archivo).
"""

from __future__ import annotations

import argparse
import json
import math
import socket
import time
from dataclasses import dataclass
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np
from mediapipe.tasks import python as mp_python
from mediapipe.tasks.python import vision

from pose import (EYE_CORNER_A, EYE_CORNER_B, LEFT_EYE, NOSE_TIP,
                  RIGHT_EYE, ear_to_blink, eye_aspect_ratio, head_pose)

MODELS = Path(__file__).parent / "models"

# Frame de la cara que se analiza siempre.
FACE_MODEL = MODELS / "face_landmarker.task"
HAND_MODEL = MODELS / "gesture_recognizer.task"

# Si una mano tapa la cara, se sostiene la ultima pose este tiempo.
FACE_GRACE = 1.5


@dataclass
class Config:
    host: str = "127.0.0.1"
    port: int = 4242
    camera: int = 0
    preview: bool = True
    mirror_hands: bool = False
    hand_every: int = 1
    fake: bool = False


class Tracker:
    """Una lectura de camara, un diccionario con todo lo que el juego necesita."""

    def __init__(self, config: Config) -> None:
        self.config = config
        self._started = time.time()
        self._last_timestamp = -1
        self._frame_index = 0

        self._face = vision.FaceLandmarker.create_from_options(
            vision.FaceLandmarkerOptions(
                base_options=mp_python.BaseOptions(model_asset_path=str(FACE_MODEL)),
                running_mode=vision.RunningMode.VIDEO,
                num_faces=1,
            )
        )
        self._hands = vision.GestureRecognizer.create_from_options(
            vision.GestureRecognizerOptions(
                base_options=mp_python.BaseOptions(model_asset_path=str(HAND_MODEL)),
                running_mode=vision.RunningMode.VIDEO,
                num_hands=2,
                min_hand_detection_confidence=0.3,
                min_hand_presence_confidence=0.3,
                min_tracking_confidence=0.3,
            )
        )

        self._last_face: dict | None = None
        self._last_face_at = 0.0
        self._last_hands = {"hand": False, "gesture": "None",
                            "left_hand": False, "left_gesture": "None",
                            "hand_depth": 0.0}

    def read(self, frame) -> dict:
        """Analiza un cuadro y devuelve el estado listo para mandar."""
        timestamp = self._timestamp()
        face = self._read_face(frame, timestamp)
        hands = self._read_hands(frame, timestamp)

        # Si una mano tapa la cara, MediaPipe pierde la cara un instante:
        # se sostiene la ultima pose para que la cabeza no pegue saltos.
        if face is None and hands["hand"] and self._last_face is not None:
            if time.time() - self._last_face_at < FACE_GRACE:
                face = self._last_face

        payload = {
            "face": face is not None,
            "hand": hands["hand"],
            "gesture": hands["gesture"],
            "left_hand": hands["left_hand"],
            "left_gesture": hands["left_gesture"],
        }
        if face is not None:
            payload.update(face)

        self._frame_index += 1
        return payload

    def overlay(self, frame, payload: dict) -> None:
        """Dibuja el estado sobre el cuadro de la ventana de depuracion."""
        if payload["face"]:
            text = (f"cabeza  yaw {payload['head_yaw']:+5.1f} deg   "
                    f"pitch {payload['head_pitch']:+5.1f} deg   "
                    f"parpadeo {payload['blink_l']:.2f}/{payload['blink_r']:.2f}")
        else:
            text = "sin cara"
        hands = f"derecha: {payload['gesture']}    izquierda: {payload['left_gesture']}"
        cv2.putText(frame, text, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
        cv2.putText(frame, hands, (10, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 200, 255), 2)

    def close(self) -> None:
        self._face.close()
        self._hands.close()

    def _timestamp(self) -> int:
        # MediaPipe exige tiempos estrictamente crecientes.
        now = int((time.time() - self._started) * 1000)
        if now <= self._last_timestamp:
            now = self._last_timestamp + 1
        self._last_timestamp = now
        return now

    def _read_face(self, frame, timestamp: int) -> dict | None:
        image = mp.Image(image_format=mp.ImageFormat.SRGB,
                         data=cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
        result = self._face.detect_for_video(image, timestamp)
        if not result.face_landmarks:
            return None

        landmarks = result.face_landmarks[0]
        height, width = frame.shape[:2]
        angles = head_pose(landmarks, height, width)
        if angles is None:
            return None

        # Parpadeo por Eye Aspect Ratio: no depende de la forma del ojo, asi
        # que funciona con ojos pequenos (asiaticos) que los blendshapes leen
        # como cerrados.
        blink_l = ear_to_blink(eye_aspect_ratio(landmarks, LEFT_EYE))
        blink_r = ear_to_blink(eye_aspect_ratio(landmarks, RIGHT_EYE))

        face = {
            "blink_l": blink_l,
            "blink_r": blink_r,
            **angles,
        }
        self._last_face = face
        self._last_face_at = time.time()
        return face

    def _read_hands(self, frame, timestamp: int) -> dict:
        state = {"hand": False, "gesture": "None", "left_hand": False, "left_gesture": "None", "hand_depth": 0.0}
        if self._frame_index % max(self.config.hand_every, 1) != 0:
            # Se reutiliza la ultima lectura de manos para ahorrar cuadros.
            return self._last_hands

        # El cuadro se espeja para que "derecha" e "izquierda" sean las del
        # jugador y no las de la imagen.
        mirrored = cv2.cvtColor(cv2.flip(frame, 1), cv2.COLOR_BGR2RGB)
        image = mp.Image(image_format=mp.ImageFormat.SRGB, data=mirrored)
        result = self._hands.recognize_for_video(image, timestamp)

        for i, landmarks in enumerate(result.hand_landmarks):
            gesture = "None"
            if i < len(result.gestures) and result.gestures[i]:
                gesture = result.gestures[i][0].category_name

            # Si el reconocedor no clasifica, se intenta por la geometria de los
            # dedos: puntas arriba de las articulaciones = palma abierta.
            if gesture == "None":
                gesture = _classify_hand(landmarks)

            # MediaPipe adivina la mano, y se equivoca seguido. La posicion en la
            # imagen es mas confiable: despues de espejar, la mano derecha del
            # jugador queda a la derecha del cuadro.
            center_x = sum(lm.x for lm in landmarks) / len(landmarks)
            is_right = center_x > 0.5
            if self.config.mirror_hands:
                is_right = not is_right

            # Tamano de la mano en la imagen: proxy de distancia a la camara.
            # Mano grande = cerca, mano pequena = lejos. Era para el zoom, que
            # esta apagado: se sigue mandando por si vuelve.
            xs = [lm.x for lm in landmarks]
            ys = [lm.y for lm in landmarks]
            box_area = (max(xs) - min(xs)) * (max(ys) - min(ys))

            if is_right:
                state["hand"] = True
                state["gesture"] = gesture
            else:
                state["left_hand"] = True
                state["left_gesture"] = gesture
                state["hand_depth"] = box_area

        self._last_hands = state
        return state


def _classify_hand(landmarks) -> str:
    """Clasifica la mano por la geometria de los dedos cuando MediaPipe no la reconoce.

    Cuenta cuantos dedos estan estirados (punta por encima de la articulacion).
    4 o mas = palma abierta, 0 o 1 = puno cerrado.
    """
    # Indices: (punta, articulacion PIP) para indice, medio, anular, menique.
    fingers = [(8, 6), (12, 10), (16, 14), (20, 18)]
    extended = 0
    for tip_idx, pip_idx in fingers:
        if landmarks[tip_idx].y < landmarks[pip_idx].y:
            extended += 1
    # Pulgar: se estira hacia el lado, no hacia arriba.
    if abs(landmarks[4].x - landmarks[3].x) > 0.04:
        extended += 1
    if extended >= 4:
        return "Open_Palm"
    if extended <= 1:
        return "Closed_Fist"
    return "None"


class FakeSource:
    """Datos sinteticos: sirve para probar el juego sin camara ni modelos."""

    def __init__(self) -> None:
        self._started = time.time()

    def read(self, frame=None) -> dict:
        t = time.time() - self._started
        return {
            "face": True,
            # Barrido lento a los costados y un cabeceo mas rapido.
            "head_yaw": 28.0 * math.sin(t * 0.6),
            "head_pitch": 12.0 * math.sin(t * 0.9),
            "blink_l": 0.0,
            "blink_r": 0.0,
            "hand": False,
            "gesture": "None",
            "left_hand": False,
            "left_gesture": "None",
            "hand_depth": 0.0,
        }

    def overlay(self, frame, payload: dict) -> None:
        cv2.putText(frame, "modo fake", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

    def close(self) -> None:
        pass


def parse_args() -> Config:
    parser = argparse.ArgumentParser(description="Tracker de mirada y manos para CHILI.")
    parser.add_argument("--host", default="127.0.0.1", help="destino UDP (default 127.0.0.1)")
    parser.add_argument("--port", type=int, default=4242, help="puerto UDP (default 4242)")
    parser.add_argument("--camera", type=int, default=0, help="indice de camara (default 0)")
    parser.add_argument("--no-preview", action="store_true", help="no abrir la ventana de la camara")
    parser.add_argument("--mirror-hands", action="store_true",
                        help="invertir manos si el juego toma derecha por izquierda")
    parser.add_argument("--hand-every", type=int, default=1,
                        help="analizar las manos cada N cuadros (subilo si va lento)")
    parser.add_argument("--fake", action="store_true", help="datos sinteticos, sin camara")
    args = parser.parse_args()
    return Config(
        host=args.host,
        port=args.port,
        camera=args.camera,
        preview=not args.no_preview,
        mirror_hands=args.mirror_hands,
        hand_every=args.hand_every,
        fake=args.fake,
    )


def main() -> int:
    config = parse_args()
    sender = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    destination = (config.host, config.port)

    capture = None
    if config.fake:
        source = FakeSource()
        print("Modo fake: mandando datos sinteticos.")
    else:
        source = Tracker(config)
        capture = cv2.VideoCapture(config.camera)
        if not capture.isOpened():
            print(f"No pude abrir la camara {config.camera}.")
            return 1
        print(f"Camara {config.camera} abierta. Mandando a {config.host}:{config.port}.")
    print("q en la ventana para salir, Ctrl+C en la consola para cortar.")

    try:
        while True:
            frame = None
            if capture is not None:
                ok, frame = capture.read()
                if not ok:
                    print("Se corto la imagen de la camara.")
                    return 1

            payload = source.read(frame)
            sender.sendto(json.dumps(payload).encode(), destination)

            if config.preview:
                if frame is None:
                    frame = np.zeros((480, 640, 3), dtype=np.uint8)
                view = cv2.flip(frame, 1)
                source.overlay(view, payload)
                cv2.imshow("CHILI - tracker", view)
                if cv2.waitKey(1) & 0xFF == ord("q"):
                    break
    except KeyboardInterrupt:
        pass
    finally:
        source.close()
        if capture is not None:
            capture.release()
        cv2.destroyAllWindows()
        sender.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
