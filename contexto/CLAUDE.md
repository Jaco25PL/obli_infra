# CLAUDE.md — Contexto del Obligatorio de Infraestructura

> Este archivo es el contexto base. Leelo entero antes de escribir cualquier código.
> Vive en la raíz del repo. No lo borres ni lo edites salvo que el dueño lo pida.

---

## 1. Qué es esto

Obligatorio de la materia **Infraestructura** (Licenciatura en Sistemas, ORT Uruguay).
Vale **35 puntos**. Tiene 4 partes independientes:

| Parte | Tema | Lenguaje / herramienta | Puntos |
|---|---|---|---|
| 1 | Bash — diagnóstico y parche de un script | Bash | 5 |
| 2 | Concurrencia — productor/consumidor + grafo de precedencias | C (hilos POSIX + semáforos) | 7 |
| 3 | Space Invaders simplificado | ADA (tasks + rendezvous) | 16 |
| 4 | Empaquetado en contenedores aislados | Docker + Docker Compose | 7 |

**Entrega:** 29/06/26 21:00. **Defensa oral obligatoria y eliminatoria** antes del 09/07/26.

---

## 2. La regla que manda sobre todo lo demás

La rúbrica NO premia código sofisticado. Premia que el alumno **pueda explicar en la
defensa, línea por línea, qué hace cada comando y cada sentencia**. Mirá el reparto:

- Bash: 4 de 5 pts son por explicar los comandos. 1 pt por que funcione.
- C/POSIX: 5 de 7 pts por explicar. 2 por que funcione.
- ADA: 10 de 16 pts por conocer cada sentencia. Y dice explícitamente que si hay
  código "no dado en clase o ajeno a los laboratorios", el alumno tiene que mostrar
  **total soltura** en su manejo.
- Docker: 4 de 7 pts por explicar.

**Consecuencias para vos, Claude Code:**

1. **Simple > elegante > inteligente.** Si hay dos formas de hacer algo, elegí la que
   sea más fácil de explicar, aunque sea más larga.
2. **Comentá todo en español.** Cada bloque debe tener un comentario que diga QUÉ hace
   y POR QUÉ. El dueño no estuvo en clase: los comentarios son su material de estudio.
3. **No uses construcciones que no estén en el material de clase** (ver sección 4).
   Si algo realmente lo necesita y no está en clase, marcalo con un comentario
   `// OJO: esto no se vio en clase, hay que estudiarlo aparte` para que el dueño sepa
   que tiene que prepararlo.
4. **Nada de librerías externas ni dependencias raras.** Todo con lo estándar.
5. Después de cada parte, generá una sección de notas de defensa (ver sección 5).

---

## 3. Quién es el dueño del repo

- Estudiante de Uruguay. Escribe en español rioplatense (uruguayo). Si le hablás en
  español, usá ese registro, no slang de otros países.
- **No fue a las clases y no conoce el material todavía.** Trata cada explicación como si
  fuera la primera vez que lo ve. No asumas conocimiento previo.
- Va a tener que defender esto oralmente. Tu trabajo no es solo que funcione: es dejarlo
  en condiciones de entender y explicar cada parte.

---

## 4. Qué se vio en clase (úsalo como caja de herramientas permitida)

### Bash (Parte 1)
Conceptos centrales que el ejercicio quiere que se demuestren:
- **Word splitting**: Bash parte las variables sin comillas en palabras por espacios.
- **Globbing**: `*` se expande a nombres de archivos; si la variable está vacía puede
  expandirse a algo catastrófico (`rm ./dir/*.txt`).
- **Expansión de variables** y la importancia del **quoting** (`"$VAR"`).
- Buenas prácticas: comillas dobles siempre, validar variables vacías con `[ -z "$x" ]`,
  manejo seguro de rutas.

### Concurrencia en C (Parte 2)
Vocabulario y patrones vistos:
- **Semáforos** como TAD con 3 operaciones: `INIT(s, valor)`, `P(s)` (wait/baja, bloquea
  si no hay capacidad), `V(s)` (signal/sube, desbloquea). Operaciones indivisibles.
- Identificar siempre **procesos** y **recursos** antes de codear.
- **Productor/consumidor con buffer finito**: el patrón canónico. Se sincroniza por
  - capacidad libre (lleno),
  - elementos disponibles (vacío),
  - mutua exclusión de acceso al buffer.
- Un semáforo por recurso. Inicializar en la capacidad del recurso.
- **Grafo de precedencias**: para dependencias entre tareas se usan semáforos
  inicializados en 0; cada tarea hace `P` de su(s) precedente(s) al empezar y `V` al
  terminar para habilitar a las siguientes. (Tarea inicial sin previas no espera nada.)

En la implementación real en C se usan hilos **POSIX** (`pthread`) y semáforos POSIX
(`semaphore.h`: `sem_init`, `sem_wait` = P, `sem_post` = V, `sem_destroy`). Mantené el
mapeo P↔sem_wait y V↔sem_post explícito en comentarios, porque en clase se habló de P y V.

### ADA (Parte 3)
Vocabulario y patrones vistos:
- Una **task** = un proceso/hilo que corre concurrentemente con el `main` (que también es
  una task). El main espera a que terminen sus subtareas antes de finalizar.
- Una task tiene **especificación** (declara `entry`s) y **body** (los implementa con
  `accept`).
- **Rendezvous / cita**: sincronización entre dos tasks. La que llama a `Tarea.entry`
  se bloquea hasta que la otra ejecuta `accept entry`. El entry se ejecuta bajo mutua
  exclusión entre las dos tasks involucradas.
- **`select`**: permite aceptar una cita entre varias (la que llegue primero). Sintaxis:
  ```ada
  select
     accept cita1; ...
  or
     accept cita2; ...
  or
     delay 0.025;   -- rama temporal: si nadie llama en ese tiempo, sigue
  end select;
  ```
- **Guardas** (`when condición =>` antes de un `accept`): habilitan o deshabilitan una
  cita según una condición. Patrón usado para el "patio con capacidad N".
- **`delay X.X`**: pausa la task X segundos.
- **Citas nulas / de sincronización**: entries sin parámetros, usados solo para
  coordinar (ej. protocolo pedir/devolver).
- **`task type`**: define un molde de task que luego se instancia varias veces
  (`A, B, C : Semaforo;` o incluso arrays de tasks). Útil cuando hay muchas naves.
- Tipos básicos: `Integer`, `Float`, `Character`, `String(1..N)`.
- E/S: `with Ada.Text_IO; use Ada.Text_IO;` → `Put_Line`, `Put`, `Get`.

Mapeo del ejercicio a lo de clase (la rúbrica premia usar estas analogías):
- Cada **nave** es una task (como Alice/Bob).
- La **bala** es una task.
- La **colisión** bala-nave es una **cita** (rendezvous).
- Habrá iteraciones **sin** citas (cuando la bala todavía viaja y no choca).

### Docker (Parte 4)
Conceptos vistos en el teórico de virtualización + intro a Compose:
- **Contenedor**: proceso aislado vía **namespaces** (aislamiento: pid, net, user, etc.)
  y **cgroups** (límites de CPU/memoria/IO). Comparte kernel con el host (a diferencia de
  una VM). Más liviano y rápido que una VM.
- **Dockerfile**: receta para construir una imagen. Instrucciones vistas: `FROM`,
  `WORKDIR`, `COPY`, `RUN`, `CMD`. Se valoró `--no-cache-dir` y las imágenes `-slim` por
  ser livianas.
- **docker-compose.yml**: define y levanta varios contenedores juntos. Estructura vista:
  `version`, `services`, por servicio `build` / `image`, `ports`, `environment`,
  `depends_on`. Se levanta con `docker compose up`.

Conceptos que el obligatorio pide pero NO están en el material de intro (marcarlos como
"a estudiar aparte" en comentarios, y explicarlos en el informe):
- Usuario no root (`USER`), filesystem read-only (`read_only: true`), `cap_drop` /
  `cap_add`, `security_opt: no-new-privileges`, redes internas sin exponer puertos,
  hardening de SSH (`PermitRootLogin no`, `PasswordAuthentication no`).
- Análisis de vulnerabilidades de imágenes (ej. `docker scout` o `trivy`).
Estos hay que documentarlos bien porque son justo lo que diferencia el ejercicio.

---

## 5. Convenciones del repo

### Estructura de carpetas
```
/parte1-bash/
/parte2-c/
/parte3-ada/
/parte4-docker/
/informe/              <- informe técnico y notas de defensa
CLAUDE.md
GUIA_EJECUCION.md
```

### Notas de defensa
Por cada parte, además del código, generá `informe/defensa-parteN.md` con:
- Qué hace el programa en 3-4 líneas.
- Lista de cada comando/sentencia/función no trivial con una explicación de una línea.
- Las preguntas más probables del docente y su respuesta corta.
- Qué cosas del código NO se vieron en clase (si hay), para estudiar aparte.

### Estilo de código
- Comentarios en español, claros, orientados a alguien que recién aprende.
- Nombres de variables descriptivos y en español donde tenga sentido.
- Sin optimizaciones prematuras ni one-liners crípticos.

---

## 6. Flujo de trabajo

Se trabaja **por etapas**, una parte a la vez, en el orden de `GUIA_EJECUCION.md`.
No arranques una etapa nueva sin que el dueño confirme que la anterior está cerrada.
Al terminar cada etapa: compilá/probá, generá las notas de defensa, y resumí en 3 líneas
qué quedó hecho y qué tiene que revisar el dueño.
