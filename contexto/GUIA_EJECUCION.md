# GUIA_EJECUCION.md — Plan por etapas para Claude Code

> Cómo usar esto: copiá y pegá **una etapa por vez** como mensaje a Claude Code.
> Esperá a que termine, revisá lo que hizo, probá, y recién ahí pasás a la siguiente.
> No le tires todo junto: el obligatorio es largo y conviene cerrar parte por parte.
> Antes de la Etapa 0, asegurate de que `CLAUDE.md` esté en la raíz del repo.

---

## ETAPA 0 — Preparar el terreno

```
Leé CLAUDE.md entero antes de hacer nada. Después creá la estructura de carpetas que
describe (parte1-bash, parte2-c, parte3-ada, parte4-docker, informe) con un .gitkeep en
cada una. Creá un README.md en la raíz con un índice de las 4 partes y cómo se corre cada
una (dejá los detalles en TODO por ahora). No escribas código de las partes todavía.
Confirmame qué creaste.
```

---

## ETAPA 1 — Bash (Parte 1, 5 pts)

### 1A — Diagnóstico

```
Trabajamos en /parte1-bash. Tengo el script original paddock_manager.sh (te lo paso o
está en la letra del obligatorio en el proyecto). Hay dos bugs reportados:

- Ticket #104: buscar "Gorra Edicion Especial Monza" da error de que el archivo "Edicion"
  no existe.
- Ticket #105: ejecutar "descatalogar" sin nombre de escudería borró TODOS los manifiestos
  de /mercaderia/.

Escribí informe/defensa-parte1.md con el "Informe de Autopsia": explicá técnicamente cada
incidente, identificando la línea exacta del fallo, usando los conceptos de word splitting,
globbing y expansión de variables tal como se explican en CLAUDE.md. Que lo entienda alguien
que no fue a clase. Todavía no toques el script.
```

### 1B — El parche

```
Ahora escribí parte1-bash/paddock_manager_fixed.sh: el mismo script pero arreglado con
buenas prácticas (quoting con comillas dobles, validar variables vacías con [ -z ], manejo
seguro de rutas). No reescribas el sistema de cero: mantené la misma estructura y solo
corregí lo necesario. Comentá cada cambio explicando qué problema evita.

Después creá un set de datos de prueba (inventario_f1.csv de ejemplo y una carpeta
mercaderia/ con manifiestos) y probá los dos casos que fallaban para demostrar que ahora
andan bien. Mostrame la salida.
```

---

## ETAPA 2 — C: productor/consumidor (Parte 2 Ej.1, parte de 7 pts)

```
Trabajamos en /parte2-c. Implementá en C el ejercicio del restaurante con hilos POSIX
(pthread) y semáforos POSIX, siguiendo los patrones de CLAUDE.md.

Requerimientos exactos de la letra:
- 5 cocineros, 10 mozos.
- Barra de platos listos con capacidad 8.
- Cada cocinero: prepara un plato (random hasta 3 seg), lo deja en la barra.
- Cada mozo: retira un plato, lo entrega (random hasta 2 seg).
- La barra es estrecha: entra UN SOLO MOZO A LA VEZ (mutua exclusión extra solo para
  mozos al retirar).
- Termina cuando se prepararon Y entregaron 50 platos en total.
- Salida estilo: "Cocinero 2 dejó un plato en la barra (platos en barra: 5)".

Pautas:
- Mapeá P↔sem_wait y V↔sem_post con comentarios, porque en la defensa se habla de P y V.
- Identificá explícitamente en comentarios: procesos, recursos, y qué arbitra cada
  semáforo (lleno, vacío, exclusión).
- Tené cuidado con la condición de fin (50 platos) para que no queden hilos colgados
  esperando para siempre. Explicá en comentario cómo evitás ese deadlock de cierre.
- Makefile simple para compilar (gcc con -lpthread).

Compilá, corré, y mostrame una porción de la salida. Después generá
informe/defensa-parte2-ej1.md con las notas de defensa.
```

---

## ETAPA 3 — C: grafo de precedencias (Parte 2 Ej.2, resto de 7 pts)

> Este ejercicio es teórico (grafo + explicación), pero conviene también dejarlo
> implementado para tener algo concreto que mostrar.

```
Sigue en /parte2-c, subcarpeta ej2. Las tareas y dependencias son:
- IS (inicializar sistema): sin previas.
- BD (config base de datos): requiere IS.
- SV (config servidor): requiere IS.
- PR (ejecutar pruebas): requiere BD y SV.
- DF (deploy final): requiere PR.

Hacé tres cosas:
1. informe/defensa-parte2-ej2.md con: (a) el grafo de precedencias en ASCII, (b) la
   inicialización de semáforos (todos en 0, uno por dependencia, cada tarea hace P de sus
   precedentes y V para habilitar a las siguientes), (c) la justificación de por qué es
   correcta. Seguí el patrón de grafo de precedencias de CLAUDE.md.
2. Una implementación en C (pthread + semáforos) que respete ese grafo, con prints que
   demuestren el orden correcto (IS siempre antes que BD/SV, PR después de ambas, etc.).
3. Compilá, corré varias veces y mostrame que el orden siempre se respeta.
```

---

## ETAPA 4 — ADA: base del juego (Parte 3, 16 pts — la más grande)

> Esta parte vale casi la mitad. Hacela en sub-etapas y NO avances si algo no compila.

### 4A — Esqueleto y render

```
Trabajamos en /parte3-ada. Vamos a hacer el Space Invaders simplificado en ADA, pero por
partes. Primero solo el esqueleto, sin concurrencia todavía:

- Pantalla de 80x24 en consola de texto.
- Una estructura para el estado de la pantalla (matriz de caracteres) y un procedimiento
  que la dibuja (borra pantalla y reimprime).
- El cañón en la fila de abajo, controlado por teclado: D derecha, A izquierda, W dispara.
  Por ahora solo que se mueva, sin balas ni naves.
- Loop principal que en cada iteración lee input y redibuja.

Usá solo construcciones de las de CLAUDE.md (Text_IO, tipos básicos, loops). Comentá todo.
Compilá con gnatmake y mostrame que corre. Si necesitás algo de E/S no visto en clase
(ej. lectura de tecla sin enter), marcalo con el comentario de "no visto en clase" y
explicámelo aparte.
```

### 4B — Naves como tasks

```
Ahora agregá las naves. Según la letra y CLAUDE.md, CADA NAVE ES UNA TASK. Usá task type
para no repetir código (como el ejemplo de task type del material). Requisitos:
- Naves de 4 "píxeles" (caracteres), en al menos 2 filas, alternadas.
- Se mueven lento hacia la derecha primero, después hacia la izquierda (rebote).
- Cada nave actualiza su posición en el estado compartido.

Cuidado con el acceso concurrente al estado de la pantalla: coordiná con citas/rendezvous
como se vio en clase, no con trucos externos. Explicá en comentarios cómo evitás que dos
tasks pisen la pantalla a la vez. Compilá y mostrame las naves moviéndose.
```

### 4C — Bala y colisión como cita

```
Agregá la bala. LA BALA ES UNA TASK y la COLISIÓN bala-nave DEBE SER UNA CITA (rendezvous),
tal como pide la letra. Requisitos:
- W dispara: nace una bala en la punta del cañón, sube vertical paso a paso.
- Se puede disparar otra bala mientras las anteriores siguen viajando.
- Cuando la bala alcanza una nave, eso se resuelve como una cita entre la task bala y la
  task nave (la nave se destruye, entera o carácter a carácter, vos elegí lo más simple
  de explicar).
- Habrá iteraciones sin citas (mientras la bala viaja sin chocar) — eso está bien y la
  letra lo menciona explícitamente.
- El juego termina cuando no quedan naves.

Mantenelo lo más parecido posible a los ejemplos de citas de clase. Compilá, jugá una
partida de prueba y mostrame que funciona el ciclo completo (disparar, destruir, ganar).
```

### 4D — Notas de defensa ADA

```
Generá informe/defensa-parte3.md. Como ADA vale 16 pts y la mitad es por conocer cada
sentencia, este documento tiene que ser exhaustivo:
- Explicá qué es una task, un entry, un accept, un rendezvous, un select, una guarda,
  un delay y un task type — y dónde uso cada uno en MI código.
- Mapeá cada elemento del juego a su analogía de clase (nave↔Alice/Bob, colisión↔cita).
- Listá toda sentencia que NO se haya visto en clase, con su explicación, para estudiarla.
- 8-10 preguntas probables del docente con respuesta corta.
```

---

## ETAPA 5 — Docker (Parte 4, 7 pts)

> Acá está casi todo el "valor agregado" de seguridad. Hacelo en orden: primero que
> funcione, después endurecer.

### 5A — Runners básicos que funcionan

```
Trabajamos en /parte4-docker. Arquitectura: 4 contenedores con Docker Compose: un manager
y tres runners (bash-runner, c-runner, ada-runner), cada runner con UNA app de las partes
1-3. Primero la versión que FUNCIONA, sin endurecer todavía:

- Un Dockerfile por runner que: parte de una imagen base liviana adecuada al lenguaje,
  copia la app correspondiente, instala lo mínimo para correrla, y levanta un servidor SSH.
- Los runners NO exponen puertos al host; solo se ven por la red interna de Docker.
- El manager: cliente SSH para conectarse a los runners + un servidor web simple
  (localhost:8080) que muestre estado y métricas (CPU/memoria) de cada contenedor.
- docker-compose.yml que levante todo con "docker compose up", con una red interna.

Usá las instrucciones de Dockerfile vistas en clase (FROM, WORKDIR, COPY, RUN, CMD) y la
estructura de compose de clase (services, build, ports, environment, depends_on, networks).
Confirmá que las 3 apps se ejecutan vía SSH desde el manager y que el panel web muestra
datos reales antes de seguir.
```

### 5B — Endurecimiento (hardening)

```
Ahora aplicá los requisitos de seguridad de la letra, uno por uno, y documentá cada uno:

- Imagen base mínima y fundamentada (elegí y justificá: alpine, distroless, slim, según
  el lenguaje).
- Usuario no root: el proceso principal no corre como root (USER en el Dockerfile).
- Filesystem de solo lectura donde se pueda (read_only en compose + tmpfs para lo que
  necesite escritura).
- Capabilities mínimas: cap_drop ALL y agregar solo las que de verdad hagan falta.
- Sin escalada de privilegios: security_opt no-new-privileges.
- Puertos: ningún runner expone al host; el manager solo lo necesario (8080).
- SSH endurecido: deshabilitar login root y por contraseña (solo clave), buenas prácticas.
- Sin software innecesario en ninguna imagen.

Estos puntos en su mayoría NO se vieron en el intro de clase, así que: comentá cada
directiva en los archivos Y explicá cada una en el informe, porque son justo lo que el
docente va a preguntar. Después corré un análisis de vulnerabilidades de las imágenes
(docker scout o trivy) y guardá la evidencia.
```

### 5C — Informe Docker

```
Generá informe/defensa-parte4.md cubriendo, por cada contenedor: elección de imagen base
(con fundamento), análisis de seguridad (con evidencia y resumen de vulnerabilidades),
configuración de seguridad aplicada, y decisiones de diseño. Incluí instrucciones claras
de cómo levantar todo y cómo conectarse por SSH a cada runner desde el manager. Marcá qué
conceptos no se vieron en clase para estudiarlos.
```

---

## ETAPA 6 — Cierre e informe general

```
Última etapa. Hacé:
- Un informe/informe-tecnico.md que junte todo: una intro, y un capítulo por parte
  enlazando a las notas de defensa de cada una.
- Revisá que el README de la raíz tenga instrucciones correctas para correr cada parte.
- Verificá el peso total de lo que se va a entregar (límite 40 Mb en zip/rar/pdf).
- Hacé un checklist final contra la rúbrica (35 pts) marcando qué está cubierto.
- Dame un resumen de qué quedó pendiente o flojo, si algo, para que lo revise antes de
  entregar el 29/06.
```

---

## Recordatorios para todas las etapas

- Si algo no compila o no corre, **no sigas**: arreglalo o avisá antes de avanzar.
- Priorizá siempre lo simple y explicable sobre lo ingenioso (la defensa es eliminatoria).
- Todo comentado en español, pensado para alguien que no fue a clase.
- Marcá con un comentario claro cualquier cosa que no se haya visto en clase.
