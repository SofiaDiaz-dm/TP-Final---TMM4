# CHILI — TP Final TMM4

Documentación de trabajo del proyecto. Está escrita para el equipo: qué se
cambió respecto del repositorio original, cómo está armado el código y qué queda
pendiente. El detalle exhaustivo, commit por commit, está en
[CAMBIOS.md](CAMBIOS.md).

Repo original: [`SofiaDiaz-dm/TP-Final---TMM4`](https://github.com/SofiaDiaz-dm/TP-Final---TMM4),
commit `207f9dd`.

---

## 1. El juego y su enfoque

Kaiser está paralizado en el baño y solo puede mover la cabeza. CHILI, el bicho,
se está muriendo del otro lado de la puerta: hay que mirarlo de cerca, juntar
tres remedios y entregárselos. Pero mirarlo fascina, y fascinarse contagia.

El juego es un terror en primera persona sin movimiento: **la cámara es el
cuerpo del jugador**. De ahí salen las cuatro decisiones de diseño que explican
todo el código:

1. **Un solo canal de entrada.** Todo se hace con la cabeza, las manos y los
   ojos. No hay teclado ni mouse, ni siquiera como respaldo: si el tracker no
   manda datos, no hay juego. Cada mano tiene un trabajo: la derecha agarra los
   remedios, la izquierda abre y cierra la puerta.
2. **Mirar es información y es costo.** Mirar a CHILI permite ver su estado y
   habilitar la entrega, pero sube el contagio. Cerrar los ojos lo espanta y
   acelera la infección. Nunca hay una acción gratis.
3. **La salida fácil es la trampa.** Cerrar la puerta corta el contagio, pero
   consume energía; cuando se agota, se apaga la luz y CHILI entra. La única
   salida buena es curarlo, no encerrarse.
4. **Sin tutorial.** El HUD no explica: la lista de la esquina son los remedios
   que faltan y el brillo de cada objeto dice si ya se puede agarrar.

El resultado son cuatro finales, y solo uno es bueno: `ayuda` (los tres
remedios), `pérdida` (CHILI se apaga solo), `contemplación` (contagio al máximo)
y `oscuridad` (apagón).

---

## 2. Qué cambió respecto del repo original

El repo original tenía el juego repartido en tres versiones mezcladas y varios
problemas que impedían usarlo. Esto es lo que se resolvió, en orden de impacto:

| Problema en `207f9dd` | Qué se hizo |
| --- | --- |
| `project.godot` apuntaba a `node_2d.tscn`, una escena de prueba vacía: F5 no abría el juego | La escena principal es `game/main.tscn` |
| Tres versiones del mismo juego (`juego.gd` 2D, `juego3d.gd` 3D, escenas de prueba) | Se conserva solo el 3D; se borran la versión 2D y las escenas sueltas |
| `juego3d.gd` de 665 líneas hacía geometría, reglas, estados y HUD | Se partió por responsabilidad en `game/src/` (ver sección 3) |
| `ojos.py` tenía un salto de línea entre cada línea y todo en el ámbito global | `tracker/tracker.py` con clase y argumentos de línea de comandos |
| La mirada salía de blendshapes: confundía "mirar de reojo" con "girar la cabeza" | Pose por landmarks en grados, con signo independiente del espejado |
| Los ojos pequeños se leían como cerrados | Parpadeo por EAR (apertura real del ojo) en vez de blendshapes |
| MediaPipe devolvía `"None"` en todos los gestos de mano | Fallback por geometría de los dedos y derecha/izquierda por posición en la imagen |
| "Sin cara" contaba como "ojos cerrados" y penalizaba | Son estados distintos; la mecánica se apaga cuando no hay lectura |
| No había calibración: la cámara nacía mirando al piso | Cero de cabeza y baseline de párpados calibrados solos |
| El cuarto era de primitivas y los remedios flotaban en el aire | Baño GLB y remedios GLB apoyados sobre la repisa |
| El final de los tres remedios quedó inalcanzable tras los primeros arreglos | Restaurado, y un solo final por partida |
| El apagón terminaba en negro sin mostrar nada | Vuelve la luz, CHILI aparece adelante y recién después cae el cartel |
| No había README, ni pruebas, ni forma de abrir el juego | README, prueba de humo y sondas de desarrollo |

En el medio del desarrollo se agregó un modo con mouse y tecla `E` para poder
probar sin cámara. **Ese modo ya no existe**: se sacó entero (mouse_input,
free-look, `E`, `WASD`, `P`, `C`, `Esc`, `F1`, `F2`, `Enter`, `--mouse`). Los
valores que se eligieron con esas teclas (spawns, altura de la repisa) quedaron
fijos en el código.

---

## 3. Cómo está organizado el código

```
game/                  Proyecto Godot 4.6 (esta es la carpeta que se abre)
  main.tscn            Escena de entrada
  src/
    input/
      eye_input.gd     Autoload. Única fuente de entrada del juego
      udp_tracker.gd   Abre el puerto 4242 y entrega paquetes
    game/
      main.gd          Orquestador: reglas, estados, finales y HUD
      gaze_camera.gd   La cabeza de Kaiser: mirada y giro de 360°
    world/
      room.gd          El baño, la puerta del GLB, las luces
      chili.gd         CHILI: deterioro, respiración, posición
      door.gd          Estado de la puerta
      pickup.gd        Un remedio: modelo, apoyo, brillo, entrega
      kaiser_body.gd   Las patas y el contagio visual
    core/
      shapes.gd        Fábrica de mallas, materiales y luces
      cli.gd           Banderas de línea de comandos
    ui/
      hud.gd           Viñeta, párpados, lista, objetivo, finales
  assets/
    bathroom/          El baño (GLB de itch.io, licencia sin confirmar)
    remedies/          Botiquín, frasco y paño (GLB CC0 de Grab3D)
  dev/                 Herramientas de verificación (sección 7)
tracker/
  tracker.py           Cámara -> UDP: cabeza, parpadeo y gestos
  pose.py              Geometría pura: landmarks -> grados. Sin MediaPipe
  test_pose.py         Pruebas de esa geometría, sin cámara
  probe.py             Prueba en vivo con ventana guía
  models/              Modelos .task de MediaPipe
```

**Regla de dependencia:** `main.gd` decide, los actores dibujan o leen. Ningún
nodo del mundo consulta el estado del juego ni a `EyeInput`; recibe valores ya
calculados en su `apply()`. Si un actor necesita saber algo, se le pasa por
parámetro: no se agrega un singleton.

Un archivo nuevo tiene que caer en una de esas carpetas. Si hace dos cosas, son
dos archivos.

---

## 4. Contratos entre módulos

Estos son los puntos donde se toca el código de otro. Cambiarlos rompe cosas.

### `EyeInput` (autoload)

```gdscript
var tracking: bool          # hay cara confiable
var head: Vector2           # pose en grados: X = giro (+ izquierda), Y = cabeceo (+ arriba)
var blink_l: float          # 0 = abierto, 1 = cerrado
var blink_r: float
var blink: float            # promedio, solo efecto visual
var eyes_closed_time: float # segundos con los dos ojos cerrados (mecánica)
var hand: bool              # mano derecha a la vista (agarra)
var gesture: String         # "None", "Open_Palm", "Closed_Fist", ...
var left_hand: bool         # mano izquierda a la vista (puerta)
var left_gesture: String
var hand_depth: float       # tamaño de la mano izquierda; hoy no se usa (era para el zoom)
var palm_ready: bool        # la palma lleva abierta el tiempo mínimo

signal grab                 # palma -> puño
func hand_obstructs() -> bool
func calibrate_blink() -> void
```

`_ingest(frame, delta)` y `_update_grab(delta)` son internos, pero son la puerta
de entrada de las pruebas: `dev/smoke` los usa para inyectar paquetes sin cámara.

### `GazeCamera`

```gdscript
func follow(head: Vector2, can_look: bool, can_turn: bool, delta: float) -> void
func set_zoom(held: bool, fascination: float, delta: float) -> void   # held siempre false: zoom apagado
func recenter(to_heading := 0.0) -> void
func heading_degrees() -> int
```

`follow()` es la **única** fuente de rotación de la cámara: pisa
`rotation_degrees` en cada frame. Para una toma fija hay que usar una `Camera3D`
aparte, como hacen las escenas de `dev/`.

### `Pickup`

```gdscript
func setup(display_name: String, model: PackedScene, at: Vector3, yaw: float, size := 1.0)
func is_available() -> bool
func set_highlight(energy: float)          # brillo de "esto se puede agarrar"
func attach_to(hand: Node3D)
func detach_to(parent: Node)
func deliver()
```

`setup()` mide el modelo con su AABB y lo apoya solo: los GLB tienen el pivote en
la base, así que `at.y` es la altura de la superficie. El brillo se pinta sobre
los materiales del propio modelo.

### `Room`, `Chili`, `KaiserBody`, `Hud`

```gdscript
room.build(clear_zones)          # construye el baño y busca la puerta del GLB
room.set_door_closed(closed)
chili.apply(delta, bait, flash)
kaiser.apply(delta, contagion, hand_up, fist)
hud.set_pending(names, visible); hud.set_target(text); hud.set_status(text)
```

---

## 5. Dónde se toca cada cosa

| Quiero cambiar... | Archivo |
| --- | --- |
| Qué remedios hay, dónde y de qué tamaño | `game/src/game/main.gd` (`REMEDIES`, `DECK_Y`) |
| Posición inicial del jugador o de CHILI | `DEFAULT_PLAYER_POS` / `DEFAULT_CHILI_POS` en `main.gd` |
| Velocidad del contagio, curación, apagón | exports de `main.gd` (`contagion_rate`, `cure_per_delivery`, `door_energy_drain`, `blackout_*`) |
| Cómo se siente el giro de la cabeza | exports de `gaze_camera.gd` (`gain`, `dead_zone`, `pitch_bias`, `edge_*`) |
| Qué cuenta como "estar mirando" | `focus_angle`, `remedy_angle` y el cono de lock-on en `main.gd` |
| El texto de los finales | `ENDINGS` en `main.gd` |
| La geometría o la decoración del baño | `room.gd` |
| El HUD (colores, posición, viñeta) | `hud.gd` |
| Qué hace un gesto | `eye_input.gd` (detección) y `main.gd` (consecuencia) |
| Ángulos de la cabeza, EAR, manos | `tracker/pose.py` y `tracker/tracker.py` |

---

## 6. Correr el proyecto

Requisitos:

1. **Godot 4.6** (versión estándar, no hace falta la de C#).
2. **Python 3.10–3.12** con las dependencias del tracker:

```bash
python -m venv .venv
.venv\Scripts\pip install -r tracker/requirements.txt
```

En Linux o macOS: `python3 -m venv .venv` y `.venv/bin/pip install -r ...`.

El juego necesita el tracker para tener entrada, y el orden importa:

```bash
python tracker/tracker.py     # primero el tracker
godot --path game             # después el juego
```

En Windows, `run-game.bat` hace las dos cosas y avisa si falta Python,
`mediapipe` o Godot. `open-editor.bat` abre solo el editor.

Sin los atajos, el proyecto se abre desde el gestor de Godot con **Import** →
`game/project.godot`, o con `godot --path game`. El doble click sobre
`project.godot` funciona solo si Godot se instaló con el instalador.

### Banderas

```bash
godot --path game -- --auto                 # arranca sin esperar la calibración
python tracker/tracker.py --no-preview      # sin ventana de cámara
python tracker/tracker.py --fake            # datos sintéticos, sin cámara
python tracker/tracker.py --help
```

`--fake` es la forma de trabajar en el código sin webcam: manda datos sintéticos
por el mismo protocolo, así el juego se comporta igual que con cámara.

---

## 7. El protocolo tracker ↔ juego

Un JSON por paquete UDP a `127.0.0.1:4242`:

```json
{
  "face": true,
  "head_yaw": 12.4,
  "head_pitch": -3.1,
  "blink_l": 0.02,
  "blink_r": 0.05,
  "hand": true,
  "gesture": "Closed_Fist",
  "left_hand": false,
  "left_gesture": "None"
}
```

- `head_yaw` / `head_pitch` en **grados**. Positivo = izquierda del jugador /
  mentón arriba. Los saca `pose.py` de la geometría de la cara.
- `blink_l` / `blink_r`: 0 = abierto, 1 = cerrado, por ojo (EAR).
- `gesture` / `left_gesture`: `"None"`, `"Open_Palm"`, `"Closed_Fist"`, etc.
  `gesture` es la mano derecha (agarra) y `left_gesture` la izquierda (puerta).
- `hand_depth`: tamaño de la mano izquierda en la imagen. Se sigue mandando pero
  el juego no lo usa: era para el zoom, que está apagado mientras se arregla el
  bug.
- `face: false` significa "sin lectura", no "ojos cerrados". Los campos de la
  cara no vienen en ese caso.

**Si se agrega un campo hay que tocar los dos lados**: `tracker/tracker.py` para
mandarlo y `eye_input.gd` para leerlo. El payload es el contrato; el juego no
sabe nada de Python.

---

## 8. Pruebas y herramientas

Todo corre sin ventana y sin cámara.

```bash
godot --headless --path game res://dev/smoke.tscn        # SMOKE: OK
godot --headless --path game res://dev/probe_surface.tscn # REMEDIOS: OK
python tracker/test_pose.py                               # POSE: OK
```

- **`dev/smoke.tscn`** levanta la escena real e inyecta paquetes en `EyeInput`.
  Prueba los gestos de verdad: palma + puño agarra, un puño sostenido no repite,
  soltar devuelve el remedio, mano abierta mirando a CHILI entrega, el HUD
  enseña el gesto, la puerta abre y cierra con la mano izquierda (y la derecha,
  mirando la puerta, no la toca), el arranque automático, el final de los tres
  remedios y el apagón.
- **`dev/probe_surface.tscn`** mide la repisa con raycasts y avisa si un remedio
  quedó `FLOJA`, `HUNDIDA` o haciendo `PUENTE` sobre el hueco del lavabo.
- **`dev/probe_deck.tscn`** mapea la mesada: qué tramos son planos. Se usó para
  elegir los tres lugares.
- **`dev/remedy_shot.tscn`**, **`blackout_shot.tscn`**, **`door_shot.tscn`**
  renderizan una toma fija de cada cosa para revisarla sin jugar.
- **`tracker/probe.py`** prueba la detección en vivo: abre la cámara, guía por
  seis posiciones y guarda un JSON con lecturas y un PNG por fase. Sirve para
  separar "no detecta la cara" de "los ángulos no se mueven".
- **`tracker/test_pose.py`** verifica el signo de los ángulos y el EAR con caras
  sintéticas, sin MediaPipe.

Antes de abrir el editor después de tocar código conviene correr las tres
primeras: son las que avisan si se rompió una regla.

---

## 9. Ramas

| Rama | Qué tiene |
| --- | --- |
| `main` | El juego actual: solo cámara, baño GLB, remedios con modelos, refactor en módulos. |
| `legacy/original-camara` | El juego original de `207f9dd` tal cual, con el tracker nuevo y un adaptador en `Godot/eye_input.gd`. Sirve para comparar. |
| `original` | `207f9dd` intacto, sin tocar. |

`upstream` apunta al repo de Sofia. `origin` es este repo.

---

## 10. Estado y pendientes

Lo que funciona hoy está verificado con las pruebas de la sección 8 y con el
tracker `--fake` de punta a punta.

Lo que falta o está flojo, ordenado por prioridad:

- **El zoom está apagado.** La mano izquierda ahora abre y cierra la puerta;
  `GazeCamera.set_zoom()` queda en el código pero se llama con `held = false`.
  Hay que arreglar el bug que tenía antes de volver a atarlo a un gesto.
- **El desorden procedural está apagado** (`CLUTTER_COUNT = 0` en `room.gd`): el
  baño quedó limpio. Si se quiere más caos, hay que revisar que no tape los
  remedios ni la puerta.
- **No hay tests de UI ni de la escena completa**: `smoke` cubre las reglas, no
  el dibujo.
- **La sensibilidad del gesto está calibrada a ojo.** `PALM_HOLD`, `FIST_HOLD` y
  `GRAB_COOLDOWN` en `eye_input.gd` pueden necesitar ajuste con otras cámaras.
- **Los spawns están fijos.** Se eligen editando `main.gd` o
  `user://positions.cfg`.

