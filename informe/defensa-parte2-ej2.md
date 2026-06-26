# Parte 2 - Ejercicio 2 - Grafo de Precedencias - Notas de Defensa

## Que hace el programa

Implementa un sistema de despliegue con 5 tareas que tienen dependencias entre si.
Cada tarea es un hilo POSIX. Los semaforos (inicializados en 0) controlan el orden
de ejecucion: una tarea no puede empezar hasta que sus tareas previas hayan terminado.

---

## Grafo de precedencias

```
         IS
        /  \
       BD   SV
        \  /
         PR
         |
         DF
```

- IS (Inicializar Sistema): sin previas, arranca de una
- BD (Config Base de Datos): requiere IS
- SV (Config Servidor): requiere IS
- PR (Ejecutar Pruebas): requiere BD y SV (ambas)
- DF (Deploy Final): requiere PR

BD y SV pueden ejecutarse en paralelo porque ambas solo dependen de IS, no entre si.

---

## Semaforos usados

Un semaforo por cada flecha (arco) del grafo. Todos INIT en 0.

| Semaforo | Arco del grafo | INIT | Quien hace V | Quien hace P |
|---|---|---|---|---|
| `sem_is_bd` | IS -> BD | 0 | IS al terminar | BD al empezar |
| `sem_is_sv` | IS -> SV | 0 | IS al terminar | SV al empezar |
| `sem_bd_pr` | BD -> PR | 0 | BD al terminar | PR al empezar |
| `sem_sv_pr` | SV -> PR | 0 | SV al terminar | PR al empezar |
| `sem_pr_df` | PR -> DF | 0 | PR al terminar | DF al empezar |

---

## Por que INIT en 0 es correcto

Inicializar un semaforo en 0 hace que cualquier tarea que haga P(semaforo) se bloquee
inmediatamente. La tarea queda esperando hasta que otra tarea haga V(semaforo).

Esto es exactamente lo que necesitamos: la tarea dependiente (por ejemplo BD) arranca,
hace P(sem_is_bd), y se bloquea. Cuando IS termina, hace V(sem_is_bd), desbloqueando a BD.

Si inicializaramos en 1, BD podria arrancar antes que IS, rompiendo el orden del grafo.

---

## Flujo de cada tarea

```
IS:  [trabajo]  ->  V(sem_is_bd), V(sem_is_sv)
BD:  P(sem_is_bd)  ->  [trabajo]  ->  V(sem_bd_pr)
SV:  P(sem_is_sv)  ->  [trabajo]  ->  V(sem_sv_pr)
PR:  P(sem_bd_pr), P(sem_sv_pr)  ->  [trabajo]  ->  V(sem_pr_df)
DF:  P(sem_pr_df)  ->  [trabajo]
```

PR hace DOS P (espera a BD y a SV). Hasta que ambas no terminen y hagan V, PR no arranca.

---

## Por que se pueden crear todos los hilos de una vez

Aunque los 5 hilos se crean al mismo tiempo con pthread_create, los semaforos controlan
el orden. BD arranca e inmediatamente se bloquea en P(sem_is_bd). Cuando IS termine y
haga V(sem_is_bd), BD se desbloquea. Lo mismo para las demas tareas.

El orden de creacion de hilos no importa. Lo que importa es el patron de P y V.

---

## Preguntas probables del docente

**P: Por que se usa un semaforo por arco y no uno por tarea?**
R: Porque cada arco representa una dependencia especifica. IS habilita a BD por un lado
y a SV por otro. Si usaramos un solo semaforo para IS, no podriamos controlar las dos
dependencias por separado. Ademas, PR necesita esperar a DOS tareas distintas.

**P: Que garantiza que PR no arranque antes que BD y SV?**
R: PR hace P(sem_bd_pr) y P(sem_sv_pr). Ambos estan en 0 al inicio. Hasta que BD haga
V(sem_bd_pr) Y SV haga V(sem_sv_pr), PR queda bloqueado en alguno de los dos P.

**P: Puede BD ejecutarse antes que SV, o al reves?**
R: Si, cualquiera de las dos puede ejecutar primero. Ambas solo dependen de IS, no entre
si. El scheduler del SO decide cual arranca primero. Eso es correcto segun el grafo.

**P: Que pasaria si IS nunca terminara?**
R: BD, SV, PR y DF quedarian bloqueados para siempre (deadlock). BD y SV esperan en P
de los semaforos de IS que nunca recibirian V.

**P: Que pasaria si inicializaras los semaforos en 1 en vez de 0?**
R: Las tareas podrian arrancar sin esperar a sus previas. BD podria ejecutar antes que IS,
rompiendo las dependencias del grafo. El orden no estaria garantizado.

---

## Que cosas del codigo NO se vieron en clase

Todo usa conceptos vistos: semaforos inicializados en 0 para precedencias, P al empezar
cada tarea y V al terminar para habilitar a las siguientes. Es el patron exacto del
grafo de precedencias del material de clase.
