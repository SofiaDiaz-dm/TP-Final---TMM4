# Todos los cambios respecto del repositorio original

Este documento describe **qué cambió** entre el repositorio original
([`SofiaDiaz-dm/TP-Final---TMM4`](https://github.com/SofiaDiaz-dm/TP-Final---TMM4),
commit `207f9dd` *"Primer commit"*) y este repositorio.

No es un resumen: está pensado para que alguien que nunca vio ninguno de los dos
proyectos pueda entender qué había, qué se rompió, qué se arregló y por qué.
Está separado en cambios **estructurales** (carpetas, módulos, entrada) y
**narrativos** (escenario, reglas, finales), y al final hay una tabla commit por
commit con las 41 modificaciones que siguen al primer commit.

Si algo de lo que cambió no te gusta, al final está la sección
[Versión de respaldo](#versión-de-respaldo-rama-legacy): una rama que conserva el
juego original con las mejoras de cámara de este trabajo.

---

## 1. Punto de partida: qué había en `207f9dd`

### 1.1 Estructura

```
Godot/                 proyecto Godot 4
  juego3d.gd           665 líneas: TODO el juego 3D en un solo archivo
  juego.gd             129 líneas: una segunda versión, en 2D
  chili_visual.gd      el bicho dibujado con polígonos
  pata_visual.gd       la pata del jugador
  figura.gd            una figura de prueba
  node_2d.gd/tscn      escena de prueba, sin contenido
  final_abandono.gd/tscn  una pantalla de final suelta
  eye_input.gd         autoload: lee el UDP y expone la entrada
Python/
  ojos.py              108 líneas con un salto de línea entre cada línea
  face_landmarker.task
  gesture_recognizer.task
  requirements.txt
```

### 1.2 Problemas concretos

Estos no son opiniones: se pueden comprobar en el código del commit `207f9dd`.

1. **El proyecto no abría el juego.** `project.godot` tenía
   `run/main_scene="uid://nsituhwu8uyu"`, que corresponde a `node_2d.tscn`: una
   escena de prueba vacía. Apretar F5 en el editor no arrancaba el juego. Había
   que abrir la escena correcta a mano.
2. **Tres versiones del mismo juego mezcladas.** `juego.gd` (2D),
   `juego3d.gd` (3D) y las escenas de prueba (`node_2d`, `figura`) convivían en
   la misma carpeta, sin marcar cuál era la buena.
3. **Un archivo de 665 líneas hacía todo**: construía la geometría, decidía las
   reglas, manejaba los estados, dibujaba el HUD y escribía los finales. Cambiar
   cualquier cosa obligaba a leer el archivo entero.
4. **`ojos.py` tenía un salto de línea entre cada línea de código** y todo el
   programa vivía en el ámbito global: no había funciones, ni configuración, ni
   forma de probarlo sin abrir la cámara.
5. **Los modelos de MediaPipe se buscaban por ruta relativa** al directorio de
   trabajo (`"face_landmarker.task"`), así que el tracker solo arrancaba si lo
   lanzabas desde `Python/`.
6. **La mirada salía de blendshapes** (`gaze_x`, `gaze_y` normalizados). Ese
   método confunde "miro de reojo" con "giro la cabeza" y el signo dependía de
   cómo estuviera espejada la imagen.
7. **`eyes_closed_time` subía también cuando no había cara**: quedarse sin
   cámara contaba como "ojos cerrados" y el juego lo penalizaba.
8. **El tracker no tenía ni un argumento de línea de comandos.** Para probar sin
   cámara había que editar constantes dentro del archivo (`MOSTRAR_VENTANA`,
   `INVERTIR_MANOS`, `HAND_CADA`).
9. **No había README, ni `.gitignore` útil, ni forma de abrir el juego** sin
   conocer de memoria la línea de comandos de Godot.
10. **Los finales tenían un caso muerto**: el `abandono` (irse por la puerta)
    convivía con el resto sin una salida clara, y el final de los tres remedios
    quedó inalcanzable después de los primeros arreglos.

---

## 2. Cambios estructurales

### 2.1 Carpetas y nombres

| Antes | Ahora | Por qué |
| --- | --- | --- |
| `Godot/` | `game/` | El nombre dice qué es: el proyecto jugable. |
| `Python/` | `tracker/` | El nombre dice qué hace: seguir la cara y las manos. |
| `ojos.py` | `tracker/tracker.py` | Programa principal, con clase y argumentos. |
| `Godot/juego3d.gd` | `game/src/game/main.gd` + 9 módulos | Una responsabilidad por archivo. |
| `Godot/eye_input.gd` | `game/src/input/eye_input.gd` | Queda igual como autoload `EyeInput`. |
| `*.task` en `Python/` | `tracker/models/*.task` | Los binarios de modelos, separados del código. |
| (no existía) | `game/assets/bathroom/` | El baño en GLB. |
| (no existía) | `game/assets/remedies/` | Los tres remedios en GLB. |
| (no existía) | `game/dev/` | Herramientas de verificación. |

### 2.2 Reparto en módulos

`juego3d.gd` se partió por responsabilidad. Ningún archivo nuevo hace dos cosas:

```
game/src/
  game/
    main.gd          Orquestador: reglas, estados, finales, HUD. Nada de geometría.
    gaze_camera.gd   La cabeza de Kaiser: giro 1:1, zona muerta, giro de 360°, zoom.
  input/
    eye_input.gd     Autoload. Única fuente de entrada: cabeza, manos y ojos.
    udp_tracker.gd   Abre el puerto 4242 y entrega paquetes.
  world/
    room.gd          El baño, las paredes, la puerta del GLB y las luces.
    chili.gd         CHILI: su deterioro, su respiración, su posición.
    door.gd          El estado de la puerta.
    pickup.gd        Un remedio: modelo, apoyo, brillo y entrega.
    kaiser_body.gd   Las patas del jugador y el contagio visual.
  core/
    shapes.gd        Fábrica de mallas, materiales y luces.
    cli.gd           Banderas de línea de comandos.
  ui/
    hud.gd           Viñeta, negro, párpados, lista de remedios, finales y depuración.
```

Consecuencias concretas:

- `main.gd` pasó de 665 líneas mezcladas a **617** que solo orquestan. Para
  tocar el baño se abre `room.gd`; para tocar la cámara, `gaze_camera.gd`.
- Los actores ya no se dibujan desde afuera: cada uno tiene su `build()`.
- Las luces y mallas repetidas salen de `shapes.gd`, no de copiar y pegar.

### 2.3 Escenas

- La escena principal ahora es **`game/main.tscn`**: F5 abre el juego.
- Se borraron `juego.tscn`, `juego3d.tscn`, `node_2d.tscn`, `final_abandono.tscn`
  y `figura.gd`: eran restos de las versiones de prueba.
- El HUD se construye por código (`hud.gd`), así que no hay una escena de UI que
  se pueda desincronizar del estado del juego.

### 2.4 Autoload y entrada

`EyeInput` sigue siendo el único autoload, pero cambió el contrato:

| Antes (`207f9dd`) | Ahora |
| --- | --- |
| `gaze: Vector2` normalizado (blendshapes) | `head: Vector2` en **grados** |
| `blink: float` promedio | `blink_l`, `blink_r` y `blink` por separado |
| `palma_lista` | `palm_ready` |
| señal `agarrar` | señal `grab` |
| leía y filtraba todo en el mismo `_process` | `_ingest()` recibe un paquete y `_update_grab()` decide el gesto |
| sin calibración | baseline de párpados y cero de cabeza calibrados en vivo |

El resto del juego **nunca** sabe de dónde viene el dato: lee `EyeInput.head`,
`EyeInput.hand`, `EyeInput.gesture` y escucha `EyeInput.grab`.

---

## 3. Cambios en el tracker de la cámara

### 3.1 De `ojos.py` a `tracker/tracker.py`

- **Reescritura completa con una clase `Tracker`**: estado y configuración con
  nombre, en lugar de variables globales.
- **Argumentos de línea de comandos**:
  - `--fake` datos sintéticos, sin cámara.
  - `--no-preview` sin la ventana de la webcam.
  - `--camera N` elegir cámara.
  - `--port N` cambiar el puerto UDP.
  - `--mirror-hands` invertir qué mano es cuál.
  - `--hand-every N` analizar las manos cada N cuadros.
  - `--help`.
- **Rutas absolutas a los modelos**: `tracker/models/*.task` se resuelven desde
  el archivo, no desde el directorio de trabajo. Se puede lanzar desde cualquier
  lado.
- **Un solo `print` de estado por fase**, no un volcado por cuadro.

### 3.2 Pose de la cabeza: de blendshapes a geometría

- La pose ahora sale de **landmarks**: la nariz contra las esquinas de los ojos,
  pasada a grados con `atan()`.
- Ventaja: "miro de reojo" y "giro la cabeza" dejan de confundirse, y el signo
  ya no depende del espejado de la imagen.
- Se fue `gaze_x` / `gaze_y`; llegan `head_yaw` y `head_pitch` en grados.
- `tracker/pose.py` es **geometría pura, sin MediaPipe**: se puede probar sin
  cámara y sin instalar nada.
- `tracker/test_pose.py` verifica el signo con caras sintéticas: girar a la
  izquierda da ángulo positivo y positivo mira a la izquierda en Godot.

### 3.3 Parpadeo: de blendshapes a EAR

- Los blendshapes de MediaPipe están entrenados con caras occidentales: los ojos
  pequeños se leían como cerrados y mirar hacia arriba cerraba las barras negras.
- Se reemplazaron por **Eye Aspect Ratio (EAR)** sobre los landmarks del ojo, que
  mide la apertura real: abierto ≈ 0.2–0.58, cerrado ≈ 0.05–0.07.
- El juego recibe `blink_l` y `blink_r` por separado. Un guiño entorna la
  pantalla a medias en vez de taparla entera.

### 3.4 Manos

- MediaPipe devolvía `"None"` para todos los gestos con manos reales.
- Se agregó un **fallback por geometría**: puntas de los dedos por encima de las
  articulaciones = palma abierta; todas por debajo = puño.
- La confianza del reconocedor bajó a `0.3`.
- **Derecha e izquierda se asignan por la posición en la imagen**, no por el
  `handedness` de MediaPipe, que se equivoca seguido.
- Cada mano tiene un trabajo fijo: **la derecha agarra** los remedios y **la
  izquierda abre y cierra la puerta**. Antes la izquierda era el zoom.

### 3.5 Protocolo UDP

El formato es el mismo que antes (JSON por paquete a `127.0.0.1:4242`), con
cambios de contenido:

```json
{
  "face": true,
  "head_yaw": 12.4,      // antes: gaze_x
  "head_pitch": -3.1,    // antes: gaze_y
  "blink_l": 0.02,
  "blink_r": 0.05,
  "hand": true,
  "gesture": "Closed_Fist",
  "left_hand": false,    // antes: zoom_hand
  "left_gesture": "None" // antes: zoom_gesture
}
```

- `head_yaw` / `head_pitch` están en **grados**, no normalizados.
- `gesture` es la mano derecha y `left_gesture` la izquierda. Los campos del zoom
  se renombraron porque el zoom se apagó y la izquierda pasó a manejar la puerta
  (ver 5.7). `hand_depth` se sigue mandando pero el juego lo ignora.
- `"sin cara"` (`face: false`) ya no significa "ojos cerrados": son dos estados
  distintos y el juego los trata distinto.

### 3.6 Herramientas del tracker

- `tracker/probe.py`: prueba en vivo con ventana guía. Guarda un JSON de
  lecturas y un PNG por fase. Sirve para saber si el problema es de detección
  (no hay cara) o de la cuenta (los ángulos no se mueven).
- `tracker/test_pose.py`: pruebas sin cámara de la geometría y del EAR.

---

## 4. Cambios en la cámara (el corazón de este trabajo)

### 4.1 Giro 1:1 con la cabeza

- La cámara copia la cabeza **casi uno a uno**: girar 20° la cabeza gira 20° la
  cámara. Antes había dos suavizados en cascada (tracker + juego) que daban unos
  200 ms de retraso y un factor que exageraba el ángulo (66° para un giro de 50°).
- Zona muerta configurable (0.3°) para que no tiemble quieto.
- Suavizado exponencial que **no depende del framerate**.

### 4.2 Giro de 360°

- Sostener la mirada contra el borde hace que la cabeza siga girando sola, así se
  puede dar la vuelta completa sin torcer el cuello.
- Parámetros separados: umbral (`edge_threshold`), espera (`edge_delay`),
  velocidad (`edge_speed`) y rampa (`edge_ramp`).

### 4.3 Compensación de la webcam

- `pitch_bias` sube el centro de la mirada: la webcam suele estar arriba del
  monitor y la mirada natural cae hacia abajo. Sin esto, la cámara nacía
  mirando al piso.
- Límites asimétricos: más recorrido hacia arriba (`max_pitch_up = 45`) que
  hacia abajo (`max_pitch_down = 25`), por la misma razón.

### 4.4 Calibración automática

- **Ya no hay tecla de calibrar.** Cuando la cámara ve una cara estable durante
  `AUTO_START_AFTER` (1.2 s), el juego fija el cero de la cabeza, calibra los
  párpados con los ojos abiertos y arranca solo.
- Si el jugador mira para otro lado o se tapa la cara, la lectura se pausa pero
  el juego no se traba esperando una confirmación.
- Mostrar la calibración: `tracker/probe.py` muestra `head_yaw`, `head_pitch`,
  EAR y manos por fase.

### 4.5 Qué se eliminó de la cámara

- El **free-look con mouse** que se había agregado para poder jugar sin cámara.
- El **fallback automático a mouse y teclado** cuando el tracker no manda datos.
- La cámara ya no acepta rotación externa: `follow()` es la única fuente de
  rotación, y por eso las tomas de verificación usan una `Camera3D` propia.

---

## 5. Cambios en el juego (reglas y objetos)

### 5.1 Interacción: todo por gestos

| Acción | Cómo |
| --- | --- |
| Mirar / girar | mover la cabeza |
| Elegir un remedio | palma derecha abierta, apuntándolo con la mirada |
| Agarrar | cerrar el puño después de la palma |
| Entregar | abrir la mano derecha mirando a CHILI con el remedio en la mano |
| Abrir / cerrar la puerta | con la mano izquierda: puño (cerrar) o palma (abrir), mirando la puerta |
| Zoom | apagado por ahora (ver 5.7) |
| Arrancar | ponerse frente a la cámara: calibra sola |

Se eliminó por completo: `E`, `WASD`, `P`, `C`, `Esc`, `Enter`, `F1`, `F2`, el
mouse y la bandera `--mouse`. **No queda ninguna tecla en el juego.**

### 5.2 Lock-on y feedback

- `remedy_angle` pasó de 9° a 15° y se agregó un **objetivo** dentro de 20°: el
  remedio más cercano al centro se marca aunque la cabeza no esté perfecta.
- El **brillo** del remedio dice si se puede agarrar: al máximo cuando la palma
  lleva abierta el tiempo suficiente, medio cuando está en la mira.
- Tiempos del gesto más cortos: palma 0.15 s, puño 0.05 s, enfriamiento 0.5 s.

### 5.3 Los remedios

- Pasaron de ser primitivas de color plano a **modelos GLB con textura**:
  - **Botiquín** — `first-aid-kit`, escala 0.55 (43×29×29 cm reales).
  - **Frasco** — `pill-bottle`, escala 1.8 (4,6×4,6×7,7 cm reales).
  - **Paño** — `bath-towel`, escala 0.55 (38×28×15 cm reales).
  - Los tres son **CC0** de [Grab3D](https://grab3d.com), con `LICENSE.txt` y
    `manifest.json` en cada carpeta.
- `Pickup.setup(name, model, at, yaw, size)` recibe una `PackedScene`, mide el
  modelo con su AABB y **lo apoya solo**: el pivote del GLB está en la base, así
  que la altura es literalmente `DECK_Y`.
- El brillo se pinta **sobre los materiales del modelo** (emisión con su propia
  textura), así se enciende con sus colores y no de blanco.
- Están **apoyados sobre la repisa del lavabo**, dentro del espacio jugable y a
  la vista desde el spawn. Antes flotaban en el aire.

### 5.4 La puerta

- Se usa la **puerta del propio GLB** (`Door_001`) en vez de una malla inventada.
- Cerrada queda alineada con la pared (`DOOR_CLOSED_YAW = 0`) y abierta gira 90°
  hacia el pasillo (`DOOR_OPEN_YAW = 90`).
- Abrirla o cerrarla cuesta energía: es la mecánica que lleva al apagón.
- La maneja **la mano izquierda**: puño para cerrar, palma para abrir, siempre
  mirándola. La derecha queda libre para los remedios.

### 5.5 CHILI

- Vive en el pasillo, del otro lado de la puerta, y **aparece** cada tanto.
- Se apoya en el piso real (`FLOOR_Y = -0.49`), no en la altura de los ojos.
- Se deteriora solo (`gravity`) y mejora con cada remedio entregado.
- Mirarlo contagia; con el zoom prendido contagiaba más (hoy el zoom está
  apagado, ver 5.7).

### 5.6 Los spawns

- Las posiciones del jugador y de CHILI viven en `user://positions.cfg`.
- Se eligieron en desarrollo caminando por el mapa; los valores por defecto
  quedaron fijos en `main.gd`.
- Al arrancar, el rumbo de la cabeza se calcula desde el spawn hacia la puerta,
  así no hay que torcer el cuello para encontrarla.

### 5.7 Reparto de manos y zoom apagado

Último cambio, después de probar con cámara real:

- **La mano derecha agarra y la izquierda abre y cierra la puerta.** Antes las
  dos cosas salían de la mano derecha (la izquierda era el zoom), así que uno
  podía cerrar la puerta sin querer mientras buscaba un remedio. Ahora cada mano
  tiene un solo trabajo.
- **El zoom quedó apagado**: la mano izquierda abierta cambiaba el campo visual y
  eso arrastraba bugs (el giro se sentía distinto según el zoom, la imagen se
  cerraba de más). El código sigue ahí (`GazeCamera.set_zoom`) pero `main.gd` lo
  llama con `held = false`, así que nunca se activa. `contagion_zoom_bonus`
  tampoco se aplica mientras tanto.
- Los campos del protocolo se renombraron: `zoom_hand` → `left_hand` y
  `zoom_gesture` → `left_gesture`. Se llama `left_*` y no `door_*` porque es la
  mano, no la acción: si mañana la izquierda vuelve a hacer otra cosa, el nombre
  sigue sirviendo.
- `hand_depth` sigue viajando en el paquete, pero el juego ya no lo usa: era el
  tamaño de la mano izquierda para el zoom.
- El HUD de la puerta ahora dice "palma izquierda" / "puño izquierdo", y el
  depuración muestra qué gesto ve en cada mano.
- `dev/smoke` prueba las dos cosas: la izquierda abre y cierra la puerta, y la
  derecha **no** la toca aunque mire la puerta.

Archivos: `tracker/tracker.py`, `game/src/input/eye_input.gd`,
`game/src/game/main.gd`, `game/dev/smoke.gd`.

---

## 6. Cambios narrativos y de escenario

### 6.1 Del cuarto abstracto al baño

| Antes | Ahora |
| --- | --- |
| Un cuarto de primitivas construido por código | Un **baño GLB real** con azulejos, bañera, lavabo, espejo y canilla |
| Los objetos estaban en posiciones fijas en el aire | Los remedios están **apoyados sobre la repisa** |
| La puerta era una malla propia | La **puerta del GLB**, que abre hacia el pasillo |
| No había pasillo | CHILI vive **del otro lado de la puerta** |
| Iluminación plana | Luces y ambiente del GLB, con apagón real |

Se probaron varios packs de assets antes de quedarse con el baño definitivo:
Tiny Treats (CC0, por piezas), un baño de Sketchfab (CC-BY 4.0) y finalmente el
GLB de itch.io que está en el repo. Los intentos quedaron como commits porque
muestran el camino, no porque estén en la versión final.

### 6.2 Los finales

Antes había cuatro, con un caso muerto. Ahora hay **cuatro, y solo uno es bueno**:

| Final | Cómo se llega | Texto |
| --- | --- | --- |
| **ayuda** | entregar los tres remedios | "CHILI respira. Tus patas ya no son las mismas." |
| **pérdida** | CHILI se apaga solo mientras mirás para otro lado | "Mientras mirabas para otro lado, CHILI dejó de moverse." |
| **contemplación** | el contagio llega al máximo de tanto mirarlo | "Te ves reflejado en la pantalla apagada. Ya no sos el que vino a cazar monstruos." |
| **oscuridad** | cerrar la puerta gasta la energía, se apaga la luz y CHILI entra | "Las luces volvieron. Ya estaba adentro. Ya es tarde." |

Cambios de fondo:

- **El final de los tres remedios volvió a existir.** Después del refactor había
  quedado un `escape` que nunca se disparaba, y entregar los tres remedios no
  cerraba la partida. Se restauró el `ayuda` del código pre-refactor.
- **Un solo final por partida**: `_ending_queued` evita que dos condiciones
  disparen dos carteles en el mismo frame.
- **El `abandono` ("Saliste") se fue**: irse por la puerta ya no es una salida
  limpia, es el apagón.

### 6.3 El apagón

- Con la puerta cerrada la energía baja; a cero se apaga la luz.
- Cuando vuelve, **CHILI aparece parado delante de la cámara**, mirándote, a un
  metro, y el contagio se va al máximo.
- El cartel se muestra después de `blackout_beat` (1.6 s) para que se vea el
  susto. Antes el juego terminaba en negro y no se veía nada.
- La posición de CHILI se calcula desde el rumbo actual de la cámara: no se
  puede quedar mirando para otro lado justo cuando vuelve la luz.

### 6.4 La interfaz

- La lista de la esquina dice **qué remedios faltan**, no un tutorial.
- El **párpado** es visual y por ojo; la mecánica de "ojos cerrados" exige los
  dos ojos más de medio segundo. Un parpadeo normal no penaliza.
- "Sin cámara" dejó de ser "ojos cerrados": si se pierde la cara, el HUD lo dice
  y la mecánica se apaga, no se castiga.
- El cartel de objetivo dice **el gesto**, no una tecla.

---

## 7. Herramientas de desarrollo y pruebas

Todas son escenas (no `--script`) porque necesitan el autoload `EyeInput`.

| Herramienta | Qué verifica |
| --- | --- |
| `dev/smoke.tscn` | Levanta la escena real y prueba gestos, entrega, puerta, apagón y arranque automático. |
| `dev/probe_surface.tscn` | Que los remedios no floten: avisa `FLOJA`, `HUNDIDA` o `PUENTE`. |
| `dev/probe_deck.tscn` | Mapa de la repisa: qué tramos son planos y dónde se puede apoyar algo. |
| `dev/remedy_shot.tscn` | Primer plano de los remedios, para revisarlos. |
| `dev/blackout_shot.tscn` | Cómo se ve el apagón, frame por frame. |
| `dev/door_shot.tscn` | Cómo abre la puerta. |
| `tracker/probe.py` | Detección en vivo: cara, ángulos, EAR y manos, con PNG por fase. |
| `tracker/test_pose.py` | Geometría y EAR, sin cámara. |

Antes **no había ninguna prueba**. Ahora hay una prueba de humo que corre sin
ventana y sin cámara:

```bash
godot --headless --path game res://dev/smoke.tscn
godot --headless --path game res://dev/probe_surface.tscn
python tracker/test_pose.py
```

`dev/smoke.gd` **inyecta paquetes a `EyeInput`** como si vinieran del tracker. No
llama a funciones internas para simular el juego: dispara los gestos reales
(palma, puño, mano abierta) y verifica que el juego reaccione.

---

## 8. Documentación y publicación

- **`README.md`**: qué es el juego, estructura, instalación, controles, protocolo
  UDP, finales, pruebas, créditos y licencias. Antes no existía.
- **Atajos de Windows**:
  - `run-game.bat` arranca el tracker y el juego, y avisa si falta Python,
    `mediapipe` o Godot en vez de cerrarse sin decir nada.
  - `open-editor.bat` abre el editor.
  - `_find-godot.bat` busca Godot en el PATH, en `LOCALAPPDATA` o en `tools/`.
- **`.gitattributes`** para no romper los `.bat` (CRLF) y marcar los binarios.
- **`.gitignore`** con `.godot/`, `.venv/`, `exports/`, logs y basura de sistema.
- **Licencias**: cada asset trae la suya. El baño es de itch.io (revisar antes de
  publicar), los remedios son CC0 de Grab3D y MediaPipe es Apache 2.0.

---

## 9. Todo lo que se eliminó

Para que no queden dudas de qué ya no existe:

- `Godot/juego.gd`, `Godot/juego.tscn` — la versión 2D.
- `Godot/chili_visual.gd`, `Godot/pata_visual.gd` — el dibujo por polígonos.
- `Godot/figura.gd`, `Godot/node_2d.gd`, `Godot/node_2d.tscn` — las escenas de
  prueba.
- `Godot/final_abandono.gd`, `Godot/final_abandono.tscn` — la pantalla suelta.
- `Python/ojos.py` — reemplazado por `tracker/tracker.py`.
- `game/src/input/mouse_input.gd` — el reemplazo con mouse y teclado.
- El free-look de `GazeCamera` (`set_free_look`, `look`, `mouse_sensitivity`).
- La tecla `E` (`_interact`), `WASD` (`_update_movement`), `P` y `C`
  (`_save_positions`), `Esc`, `Enter`, `F1` y `F2`.
- La bandera `--mouse` y el fallback automático a mouse.
- El final `abandono`.
- Las primitivas de los remedios.

---

## 10. Historial completo, commit por commit

50 commits después del original. Los mensajes están en español y en imperativo:
qué hace el commit, no qué "se estuvo trabajando".

| # | Commit | Qué cambió |
| --- | --- | --- |
| — | `207f9dd` | **Original.** Punto de partida de todo este documento. |
| 1 | `aa8b756` | Parte el juego en módulos y borra el código muerto: se va la versión 2D y las escenas de prueba; `main.tscn` pasa a ser la escena principal. |
| 2 | `b882c7e` | Reescribe el tracker: `Tracker` con clase, argumentos, `--fake`, modelos en `tracker/models/`. El protocolo no cambia. |
| 3 | `3b4ddb8` | Documenta el proyecto: README, `run-game.bat`, `open-editor.bat` y `.gitignore`. |
| 4 | `0bc1f5b` | Arregla los atajos: buscan `.venv` en el repo y en la carpeta padre, y avisan si falta `mediapipe`. |
| 5 | `7f60536` | Pose de cabeza por landmarks en grados; separa parpadeo de "ojos cerrados"; dos párpados en el HUD; `test_pose`. |
| 6 | `a5945bd` | Calibración automática, menos suavizado, gracia de seguimiento y `tracker/probe.py`. |
| 7 | `20901bf` | EAR en vez de blendshapes para ojos pequeños; fallback de manos por geometría; derecha/izquierda por posición. |
| 8 | `af64611` | Lock-on de remedios, brillo de objetivo y tiempos de gesto más cortos. |
| 9 | `703a66a` | Suaviza la cámara y aclara la entrega a CHILI. |
| 10 | `474d3df` | Calibra el parpadeo con los ojos abiertos del jugador; zoom con la mano izquierda. |
| 11 | `b0019d3` | Delimita el espacio tipo FNAF y compensa el pitch de la webcam. |
| 12 | `2c59be2` | Agranda el movimiento de cabeza y hace que CHILI se acerque estilo FNAF. |
| 13 | `95e1965` | Primer baño con assets CC0 de Tiny Treats. |
| 14 | `4701ee4` | Gira más y acerca los objetos del baño. |
| 15 | `2521b44` | Más rango de giro y texturas en el baño. |
| 16 | `10d4145` | Cambia al baño real de Sketchfab (CC-BY 4.0). |
| 17 | `e31cf33` | Escena de baño estilo FNAF con puerta y CHILI. |
| 18 | `a556aac` | Mete al jugador dentro del baño, deja la puerta interactuable y a CHILI afuera. |
| 19 | `b7aba6f` | Usa la puerta del GLB y corrige el layout. |
| 20 | `f2c1ff5` | Otra vuelta a la puerta del asset y a la posición del jugador. |
| 21 | `25579a3` | Rota el baño 180° y permite giro de 360°. |
| 22 | `b03553b` | Revierte la rotación del baño y arregla la puerta. |
| 23 | `950c531` | Giro libre de 360° y movimiento suave, sin el bloqueo tipo FNAF. |
| 24 | `4aea77c` | Puerta del asset cerrada y alineada con la pared. |
| 25 | `a22e2d8` | CHILI visible al inicio; medicarlo o cerrar los ojos lo espanta. |
| 26 | `1e49670` | Jugador dentro del baño y la puerta abre hacia el pasillo. |
| 27 | `049e895` | CHILI al pasillo y la puerta abre hacia afuera. |
| 28 | `9f94ed7` | Movimiento `WASD` y `P` para depurar la posición (temporal). |
| 29 | `32beea8` | Quita el movimiento con las manos, retrocede la cámara y la puerta abre al pasillo. |
| 30 | `ed79122` | Retrocede el spawn y ajusta la apertura de la puerta. |
| 31 | `f26fd6d` | Quita el debug de posición `P`. |
| 32 | `33306cf` | Teclas `P` y `C` para guardar los spawns del jugador y de CHILI. |
| 33 | `095c74a` | Guarda los spawns, alinea la puerta con la pared y hace nacer la cámara mirando a la puerta. |
| 34 | `520afc5` | Agrega el modo mouse con `E` y apoya los remedios sobre la repisa (`DECK_Y` medido con raycasts). |
| 35 | `1e87f51` | Restaura el final de los tres remedios y el apagón con luz; un solo final por partida. |
| 36 | `311fc2b` | Remedios con modelos GLB reales CC0, `probe_deck` y `probe_surface` por perímetro. |
| 37 | `a407f45` | Deja el repo listo para publicar: `.gitattributes`, `.gitignore` y licencias en el README. |
| 38 | `d77dba0` | **Saca todo el teclado y el mouse**: el juego se juega solo con la cámara. |
| 39 | `e528ef5` | Escribe este documento (`CAMBIOS.md`) y lo enlaza desde el README. |
| 40 | `fea7a0d` | Saca un acento roto del mensaje de `_find-godot.bat` (cmd.exe lo mostraba como símbolo raro). |
| 41 | `a411992` | Pasa a enlaces absolutos los enlaces a la rama legacy, que se rompían con la barra en el nombre. |
| 42 | `0f2e440` | Suma al historial los commits de documentación. |
| 43 | `2099227` | Evita que Git convierta los `.import` a CRLF. |
| 44 | `27100ae` | Explica en el README cómo abrir el juego sin los atajos de Windows. |
| 45 | `3aa4319` | Ajustes del README hechos directo desde GitHub. |
| 46 | `5c80658` | Reescribe el README como guía de trabajo del equipo. |
| 47 | `faca32b` | Aclara el consumo de energía de la puerta y saca un acento del `.bat`. |
| 48 | `794bc00` | Saca la nota de licencia de los créditos del README. |
| 49 | `2987097` | Recorta la lista de pendientes del README. |
| 50 | `6e5f6a5` | La mano izquierda maneja la puerta, la derecha agarra y el zoom queda apagado (ver 5.7). |

Los commits 28 a 34 fueron de exploración con las teclas: sirvieron para elegir
la posición del jugador, la de CHILI y la de los remedios. En el commit 38 se
quitaron las teclas, pero **los valores que se eligieron con ellas quedaron**.

---

## 11. Versión de respaldo (rama legacy)

Si preferís el juego más parecido al original, está la rama
**`legacy/original-camara`**.

Qué conserva y qué no:

- **Conserva el juego original completo**: `Godot/juego3d.gd` con su cuarto de
  primitivas, su HUD y sus cuatro finales, tal como estaban en `207f9dd`.
- **Conserva las mejoras de cámara de este trabajo**:
  - el tracker nuevo (`tracker/`) con pose por landmarks en grados,
  - parpadeo por EAR,
  - fallback de manos por geometría,
  - argumentos de línea de comandos (`--fake`, `--no-preview`, etc.),
  - y un adaptador en `Godot/eye_input.gd` para que el juego viejo entienda el
    protocolo nuevo.
- **No tiene** el baño GLB, ni los remedios con modelos reales, ni el apagón
  nuevo, ni el lock-on, ni el refactor en módulos.

Cómo verla:

```bash
git fetch origin
git switch legacy/original-camara
```

El README de esa rama explica lo mismo en dos líneas: es el original con la
cámara arreglada.

---

## 12. Cómo verificar el estado de este repo

```bash
# 1. Compila y trae los assets.
godot --headless --path game --import

# 2. Prueba de humo: gestos, entrega, puerta, apagón y arranque automático.
godot --headless --path game res://dev/smoke.tscn

# 3. Los remedios están apoyados, no flotando.
godot --headless --path game res://dev/probe_surface.tscn

# 4. Geometría y EAR sin cámara.
python tracker/test_pose.py

# 5. Jugar.
python tracker/tracker.py
godot --path game
```

Los tres primeros tienen que terminar en `SMOKE: OK` y `REMEDIOS: OK`. Si no,
algo se rompió y el mensaje dice qué.

---

## 13. Créditos y licencias

- **El baño** (`game/assets/bathroom`) es un GLB descargado de itch.io. El repo
  no incluye la licencia original: revisala antes de publicar el juego.
- **Los tres remedios** (`game/assets/remedies`) son de
  [Grab3D](https://grab3d.com), **CC0 1.0** (dominio público, sin atribución).
  Cada carpeta trae su `LICENSE.txt` y su `manifest.json` con el origen.
- **MediaPipe** y sus modelos (`tracker/models`) son de Google, Apache 2.0.
- **El código del juego** no tiene licencia todavía. Si el repo va a ser público,
  conviene agregar un `LICENSE`.
