# Informe Tecnico — Obligatorio de Infraestructura

**Materia:** Infraestructura
**Carrera:** Licenciatura en Sistemas — Universidad ORT Uruguay
**Puntaje maximo:** 35 puntos

---

## Introduccion

Este obligatorio abarca 4 partes independientes que cubren conceptos fundamentales de
sistemas operativos e infraestructura: scripting en Bash, concurrencia con hilos POSIX
y semaforos en C, concurrencia estructurada con tasks y rendezvous en ADA, y empaquetado
de aplicaciones en contenedores Docker con criterios de seguridad.

Cada parte tiene su informe de defensa detallado con las explicaciones de cada comando,
sentencia y decision de diseno. Este informe tecnico es un indice general que enlaza a
cada uno.

---

## Parte 1 — Bash: Gestion de Inventario "El Paddock" (5 pts)

**Archivo principal:** `parte1-bash/paddock_manager_fixed.sh`
**Informe de defensa:** [defensa-parte1.md](defensa-parte1.md)

### Resumen

Se analizo un script heredado (`paddock_manager.sh`) que gestionaba inventario de
merchandising de F1. Tenia dos bugs criticos causados por falta de quoting:

1. **Ticket #104:** `grep $PARAMETRO` sin comillas causaba word splitting. Buscar
   "Gorra Edicion Especial Monza" partia el argumento en 4 palabras y grep los
   trataba como nombres de archivo.

2. **Ticket #105:** `rm $DIR_MERCADERIA/$PARAMETRO*.txt` sin validar que PARAMETRO
   estuviera vacio. Al no pasar escuderia, el glob `*.txt` borraba TODOS los
   manifiestos.

### Solucion

- Comillas dobles en todas las expansiones de variables (`"$PARAMETRO"`)
- Validacion de variables vacias con `[ -z "$PARAMETRO" ]`
- Se mantuvo la estructura original, solo se corrigio lo necesario

### Conceptos clave

Word splitting, globbing, expansion de variables, quoting con comillas dobles.

---

## Parte 2 — Concurrencia en C (7 pts)

### Ejercicio 1: Restaurante (Productor/Consumidor)

**Archivo principal:** `parte2-c/restaurante.c`
**Informe de defensa:** [defensa-parte2-ej1.md](defensa-parte2-ej1.md)

#### Resumen

5 cocineros (productores) y 10 mozos (consumidores) comparten una barra de platos
(buffer) de capacidad 8. Se usan 5 semaforos POSIX:

| Semaforo | Funcion | INIT |
|---|---|---|
| espacios | Lugares libres en la barra | 8 |
| hay_platos | Platos disponibles | 0 |
| mutex_barra | Acceso exclusivo a la barra | 1 |
| mutex_mozo | Solo un mozo a la vez (barra estrecha) | 1 |
| mutex_cont | Protege contadores compartidos | 1 |

El programa termina cuando se preparan y entregan 50 platos. Se resuelve el deadlock
de cierre propagando signals a los mozos bloqueados.

### Ejercicio 2: Grafo de Precedencias

**Archivo principal:** `parte2-c/ej2/precedencias.c`
**Informe de defensa:** [defensa-parte2-ej2.md](defensa-parte2-ej2.md)

#### Resumen

5 tareas con dependencias: IS → (BD, SV) → PR → DF. Se usa un semaforo por arco
del grafo, todos inicializados en 0. Cada tarea hace P de sus precedentes al empezar
y V al terminar para habilitar a las siguientes.

```
     IS
    /  \
   BD   SV
    \  /
     PR
     |
     DF
```

### Conceptos clave

Semaforos (P=sem_wait, V=sem_post, INIT=sem_init), productor/consumidor con buffer
finito, grafo de precedencias, mutua exclusion, hilos POSIX (pthread).

---

## Parte 3 — ADA: Space Invaders (16 pts)

**Archivo principal:** `parte3-ada/space_invaders.adb`
**Informe de defensa:** [defensa-parte3.md](defensa-parte3.md)

### Resumen

Space Invaders simplificado implementado con concurrencia nativa de ADA:

- **10 naves** enemigas (2 filas × 5), cada una es una **task** (task type Tarea_Nave)
- **3 balas**, cada una es una **task** (task type Tarea_Bala)
- **1 cannon** controlado por el jugador (A/D/W/Q)
- Pantalla de 80×24 caracteres en consola de texto

La **colision bala-nave es una cita (rendezvous)**: la bala llama `Naves(I).Impactar`,
la nave acepta con `accept Impactar`. Cuando la nave no es impactada, usa
`select ... or delay 0.4` para moverse. Las iteraciones sin colision no tienen citas.

### Mapeo a conceptos de clase

| Clase | Juego |
|---|---|
| Task | Cada nave y cada bala |
| Task type | Tarea_Nave, Tarea_Bala |
| Entry / Accept | Iniciar, Impactar, Disparar |
| Rendezvous | Colision bala-nave |
| Select con delay | Nave: moverse si nadie impacta |
| Select con terminate | Bala: morir cuando el juego termina |

### Cosas no vistas en clase

Get_Immediate (lectura de tecla sin Enter), Character'Val para codigos ANSI,
exception handling para Tasking_Error. Todas marcadas en el codigo y en las notas
de defensa.

---

## Parte 4 — Docker: Empaquetado con Seguridad (7 pts)

**Directorio principal:** `parte4-docker/`
**Informe de defensa:** [defensa-parte4.md](defensa-parte4.md)

### Resumen

4 contenedores orquestados con Docker Compose:

- **manager** (python:3.13-alpine): panel web en puerto 8080 + cliente SSH
- **bash-runner** (alpine:3.21): ejecuta el script Bash
- **c-runner** (alpine:3.21, multi-stage): ejecuta los programas C
- **ada-runner** (debian:bookworm-slim, multi-stage): ejecuta Space Invaders

Los runners estan en una red interna sin acceso a internet. Solo el manager expone
puerto al host (8080).

### Seguridad aplicada

| Medida | Implementacion |
|---|---|
| Usuario no root | USER runner / USER manager en Dockerfile |
| Filesystem read-only | read_only: true en compose |
| Capabilities minimas | cap_drop: ALL |
| Sin escalada de privilegios | security_opt: no-new-privileges:true |
| Red aislada | networks internal: true |
| SSH endurecido | PermitRootLogin no, PasswordAuthentication no, solo ed25519 |
| Sin software innecesario | Multi-stage build, sin compiladores en imagen final |

### Como levantar

```bash
cd parte4-docker/
docker compose up
# Panel web: http://localhost:8080
```

### Cosas no vistas en clase

read_only, tmpfs, cap_drop, security_opt, internal networks, USER, multi-stage build,
hardening SSH, cgroups v2. Todas explicadas en detalle en las notas de defensa.

---

## Checklist contra la rubrica (35 pts)

### Bash (5 pts)

- [x] Describir el funcionamiento de todos los comandos y parametros (4 pts)
  - Informe de autopsia con word splitting, globbing, expansion de variables
  - Tabla con cada comando/sentencia y su explicacion
  - 8 preguntas probables con respuesta
- [x] El programa hace lo pedido en su totalidad (1 pt)
  - Script arreglado con quoting y validacion
  - Datos de prueba incluidos

### POSIX (7 pts)

- [x] Describir el funcionamiento de todos los comandos y parametros (5 pts)
  - Identificacion de procesos, recursos y semaforos
  - Mapeo P/V a sem_wait/sem_post
  - Flujo de cocinero y mozo paso a paso
  - Explicacion del deadlock de cierre
  - Grafo de precedencias con justificacion de INIT=0
  - 12 preguntas probables con respuesta
- [x] El programa hace lo pedido en su totalidad (2 pts)
  - Restaurante: 5 cocineros, 10 mozos, buffer 8, 50 platos, barra estrecha
  - Precedencias: grafo IS→BD/SV→PR→DF con semaforos

### ADA (16 pts)

- [x] Conocer cada sentencia y seccion de codigo (10 pts)
  - Explicacion de task, entry, accept, rendezvous, select, delay, task type
  - Mapeo de cada elemento del juego a analogias de clase
  - 5 cosas no vistas en clase identificadas y explicadas
  - 10 preguntas probables con respuesta
- [x] Resuelto con analogias a problemas de clase, solucion simple (2 pts)
  - Nave = task (como Alice/Bob), colision = cita, select con delay para movimiento
- [x] El programa hace lo pedido en su totalidad (4 pts)
  - Pantalla 80x24, naves de 4 pixeles en 2 filas, movimiento lateral
  - Cannon controlado por teclado, balas concurrentes
  - Colision como rendezvous, juego termina al destruir todas las naves

### Docker (7 pts)

- [x] Describir el funcionamiento de todos los comandos y parametros (4 pts)
  - Eleccion de imagen base fundamentada por contenedor
  - Cada directiva de seguridad explicada
  - Instrucciones de como levantar y conectarse
  - 10 preguntas probables con respuesta
- [x] El programa hace lo pedido en su totalidad (1 pt)
  - 4 contenedores, docker compose up, panel web funcional
  - SSH entre manager y runners, apps ejecutables
- [x] Seguridad y eficiencia (2 pts restantes)
  - Imagen base minima y fundamentada
  - Usuario no root, FS read-only, cap_drop ALL, no-new-privileges
  - Red interna sin puertos expuestos, SSH endurecido
  - Sin software innecesario (multi-stage)

**Total cubierto: 35/35 pts**

---

## Estructura del repositorio

```
obli/
├── parte1-bash/
│   ├── paddock_manager.sh          # Script original (con bugs)
│   ├── paddock_manager_fixed.sh    # Script corregido
│   ├── inventario_f1.csv           # Datos de prueba
│   └── mercaderia/                 # Manifiestos de envio
├── parte2-c/
│   ├── restaurante.c               # Productor/consumidor
│   ├── Makefile
│   └── ej2/
│       ├── precedencias.c          # Grafo de precedencias
│       └── Makefile
├── parte3-ada/
│   └── space_invaders.adb          # Space Invaders en ADA
├── parte4-docker/
│   ├── docker-compose.yml
│   ├── manager/
│   │   ├── Dockerfile
│   │   ├── panel.py
│   │   └── ssh_config
│   ├── bash-runner/Dockerfile
│   ├── c-runner/Dockerfile
│   ├── ada-runner/Dockerfile
│   ├── shared/
│   │   ├── entrypoint.sh
│   │   └── sshd_config
│   └── ssh-keys/
│       ├── id_ed25519
│       └── id_ed25519.pub
├── informe/
│   ├── informe-tecnico.md          # Este archivo
│   ├── defensa-parte1.md
│   ├── defensa-parte2-ej1.md
│   ├── defensa-parte2-ej2.md
│   ├── defensa-parte3.md
│   └── defensa-parte4.md
└── README.md
```
