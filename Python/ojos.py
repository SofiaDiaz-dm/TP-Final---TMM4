import cv2, json, socket, time

import mediapipe as mp

from mediapipe.tasks import python as mp_python

from mediapipe.tasks.python import vision



GODOT = ("127.0.0.1", 4242)

MOSTRAR_VENTANA = True    # False si no querés ver la cámara

HAND_CADA = 1             # analizar las manos cada N cuadros (subilo a 2 si va lento)

CARA_GRACIA = 1.5         # segundos que se sostiene la última mirada si una mano tapa la cara

INVERTIR_MANOS = False    # ponelo en True si el juego toma tu mano derecha como izquierda



# --- modelos (tienen que estar en la misma carpeta que este archivo) ---

cara_detector = vision.FaceLandmarker.create_from_options(

    vision.FaceLandmarkerOptions(

        base_options=mp_python.BaseOptions(model_asset_path="face_landmarker.task"),

        running_mode=vision.RunningMode.VIDEO,

        output_face_blendshapes=True,

        num_faces=1,

    )

)

mano_detector = vision.GestureRecognizer.create_from_options(

    vision.GestureRecognizerOptions(

        base_options=mp_python.BaseOptions(model_asset_path="gesture_recognizer.task"),

        running_mode=vision.RunningMode.VIDEO,

        num_hands=2,

    )

)



sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

cap = cv2.VideoCapture(0)



t0 = time.time()

ultimo_ts = -1

cuadro = 0

der, gesto_der = False, "None"      # mano derecha: agarrar y entregar

izq, gesto_izq = False, "None"      # mano izquierda: zoom

ultima_cara = None                  # últimos datos de la cara

ultima_cara_t = 0.0



while True:

    ok, frame = cap.read()

    if not ok:

        break



    ts = int((time.time() - t0) * 1000)

    if ts <= ultimo_ts:

        ts = ultimo_ts + 1

    ultimo_ts = ts



    ahora = time.time()



    # --- cara ---

    rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)

    img = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb)

    res = cara_detector.detect_for_video(img, ts)

    cara = None

    if res.face_blendshapes:

        b = {c.category_name: c.score for c in res.face_blendshapes[0]}

        cara = {

            "blink_l": b["eyeBlinkLeft"],

            "blink_r": b["eyeBlinkRight"],

            # positivo = mira hacia su izquierda

            "gaze_x": ((b["eyeLookOutLeft"] + b["eyeLookInRight"])

                       - (b["eyeLookInLeft"] + b["eyeLookOutRight"])) / 2,

            "gaze_y": ((b["eyeLookUpLeft"] + b["eyeLookUpRight"])

                       - (b["eyeLookDownLeft"] + b["eyeLookDownRight"])) / 2,

        }

        ultima_cara = cara

        ultima_cara_t = ahora



    # --- manos (la imagen se espeja para que "derecha" e "izquierda" sean las tuyas) ---

    if cuadro % HAND_CADA == 0:

        espejo = cv2.cvtColor(cv2.flip(frame, 1), cv2.COLOR_BGR2RGB)

        img_manos = mp.Image(image_format=mp.ImageFormat.SRGB, data=espejo)

        rm = mano_detector.recognize_for_video(img_manos, ts)

        der, gesto_der = False, "None"

        izq, gesto_izq = False, "None"

        for i in range(len(rm.hand_landmarks)):

            lado = "Right"

            if i < len(rm.handedness) and rm.handedness[i]:

                lado = rm.handedness[i][0].category_name

            gesto = "None"

            if i < len(rm.gestures) and rm.gestures[i]:

                gesto = rm.gestures[i][0].category_name

            es_derecha = (lado == "Right")

            if INVERTIR_MANOS:

                es_derecha = not es_derecha

            if es_derecha:

                der, gesto_der = True, gesto

            else:

                izq, gesto_izq = True, gesto

    cuadro += 1



    # si una mano tapa la cara, sostenemos la última mirada un momento

    if cara is None and (der or izq) and ultima_cara is not None and ahora - ultima_cara_t < CARA_GRACIA:

        cara = ultima_cara



    data = {

        "face": cara is not None,

        "hand": der, "gesture": gesto_der if der else "None",

        "zoom_hand": izq, "zoom_gesture": gesto_izq if izq else "None",

    }

    if cara is not None:

        data.update(cara)

    sock.sendto(json.dumps(data).encode(), GODOT)



    if MOSTRAR_VENTANA:

        vista = cv2.flip(frame, 1)   # espejo, para que sea natural levantar la mano

        if cara is not None:

            texto = f"gaze x {cara['gaze_x']:.2f} y {cara['gaze_y']:.2f} | blink {cara['blink_l']:.2f}"

        else:

            texto = "sin cara"

        cv2.putText(vista, texto, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)

        cv2.putText(vista, f"derecha: {gesto_der if der else '-'}    izquierda: {gesto_izq if izq else '-'}",

                    (10, 65), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 200, 255), 2)

        cv2.imshow("camara", vista)

        if cv2.waitKey(1) & 0xFF == ord("q"):

            break



cap.release()

cv2.destroyAllWindows() 