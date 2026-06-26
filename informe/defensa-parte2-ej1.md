# Parte 2 - Ejercicio 1 - Restaurante (Productor/Consumidor) - Notas de Defensa

## Que hace el programa

Simula un restaurante con 5 cocineros y 10 mozos que trabajan en paralelo usando hilos
POSIX. Los cocineros preparan platos y los dejan en una barra (buffer) de capacidad 8.
Los mozos retiran platos de la barra y los entregan. El programa termina cuando se
prepararon y entregaron 50 platos en total. La sincronizacion se hace con semaforos POSIX.

---

## Identificacion de procesos, recursos y semaforos

**Procesos:**
- 5 cocineros = productores (crean platos y los ponen en la barra)
- 10 mozos = consumidores (retiran platos de la barra y los entregan)

**Recurso:**
- La barra de platos listos = buffer con capacidad maxima de 8

**Condiciones de sincronizacion y sus semaforos:**

| Semaforo | Que arbitra | Valor inicial | Por que ese valor |
|---|---|---|---|
| `espacios` | Lugares libres en la barra | 8 | Al inicio la barra esta vacia, hay 8 espacios |
| `hay_platos` | Platos disponibles en la barra | 0 | Al inicio no hay ningun plato |
| `mutex_barra` | Acceso exclusivo a la barra (mutua exclusion) | 1 | Un proceso a la vez modifica la barra |
| `mutex_mozo` | Restriccion extra: solo un mozo a la vez (barra estrecha) | 1 | Un mozo a la vez |
| `mutex_cont` | Protege contadores compartidos | 1 | Acceso exclusivo a los contadores |

---

## Mapeo P/V a sem_wait/sem_post

En clase se usan las operaciones P y V de Dijkstra. En C con POSIX se traducen asi:

| Clase | POSIX | Que hace |
|---|---|---|
| `INIT(s, valor)` | `sem_init(&s, 0, valor)` | Crea el semaforo con capacidad inicial |
| `P(s)` | `sem_wait(&s)` | Pide capacidad. Si es 0, se bloquea |
| `V(s)` | `sem_post(&s)` | Devuelve capacidad. Desbloquea si hay alguien esperando |

---

## Flujo del cocinero (productor)

```
1. P(mutex_cont)    - pedir acceso al contador
2. Si ya se produjeron 50 -> salir
3. platos_producidos++
4. V(mutex_cont)    - liberar contador
5. Preparar plato   (1-3 seg, asincrono, no necesita semaforos)
6. P(espacios)      - esperar si la barra esta llena
7. P(mutex_barra)   - acceso exclusivo a la barra
8. platos_en_barra++
9. V(mutex_barra)   - liberar la barra
10. V(hay_platos)   - avisar que hay un plato nuevo
```

## Flujo del mozo (consumidor)

```
1. P(hay_platos)    - esperar si la barra esta vacia
2. Si terminado -> V(hay_platos) para despertar a otro mozo, salir
3. P(mutex_mozo)    - solo un mozo a la vez (barra estrecha)
4. P(mutex_barra)   - acceso exclusivo a la barra
5. platos_en_barra--
6. V(mutex_barra)   - liberar la barra
7. V(mutex_mozo)    - liberar acceso de mozo
8. V(espacios)      - avisar que hay un lugar libre
9. Entregar plato   (1-2 seg, asincrono)
10. P(mutex_cont)   - acceso al contador
11. platos_entregados++
12. Si entregados >= 50 -> terminado = 1, despertar mozos bloqueados
13. V(mutex_cont)   - liberar contador
```

---

## Como se evita el deadlock de cierre

Cuando se entregan los 50 platos, puede haber mozos bloqueados en `P(hay_platos)` esperando
platos que nunca van a llegar. Para evitar que queden colgados para siempre:

1. El mozo que entrega el plato #50 pone `terminado = 1`
2. Hace `V(hay_platos)` varias veces (una por cada mozo) para despertarlos
3. Cada mozo al despertar ve `terminado == 1`, propaga el signal y sale

Los cocineros no tienen este problema porque verifican el contador ANTES de producir. Si
ya se reclamaron 50 platos, simplemente salen del loop sin bloquearse en ningun semaforo.

---

## Comandos y funciones no triviales

| Funcion/Comando | Que hace |
|---|---|
| `pthread_create(hilo, NULL, funcion, arg)` | Crea un nuevo hilo que ejecuta `funcion` con argumento `arg` |
| `pthread_join(hilo, NULL)` | Bloquea al hilo que llama hasta que `hilo` termine. Como un "wait" |
| `sem_init(&s, 0, valor)` | Inicializa semaforo `s` con capacidad `valor`. El 0 = compartido entre hilos |
| `sem_wait(&s)` | P(s): decrementa. Si llega a 0, bloquea al hilo hasta que alguien haga sem_post |
| `sem_post(&s)` | V(s): incrementa. Si hay hilos bloqueados, desbloquea uno |
| `sem_destroy(&s)` | Libera los recursos del semaforo (limpieza al final) |
| `srand(time(NULL))` | Inicializa la semilla del generador de numeros random |
| `rand() % 3 + 1` | Genera un numero random entre 1 y 3 |
| `sleep(n)` | Pausa el hilo actual `n` segundos |
| `-lpthread` | Flag de gcc para linkear la libreria de hilos POSIX |

---

## Preguntas probables del docente

**P: Por que hay 5 semaforos y no 3 como en el patron clasico?**
R: El patron clasico tiene 3 (espacios, hay_platos, mutex). Aca agregamos `mutex_mozo`
porque la letra dice que la barra es estrecha y entra un solo mozo a la vez (restriccion
extra). Y `mutex_cont` para proteger los contadores de produccion/entrega.

**P: Que pasa si un cocinero quiere poner un plato y la barra esta llena?**
R: Se bloquea en `sem_wait(&espacios)` (P(espacios)). Queda bloqueado hasta que un mozo
retire un plato y haga `sem_post(&espacios)` (V(espacios)), liberando un espacio.

**P: Que pasa si un mozo quiere retirar un plato y la barra esta vacia?**
R: Se bloquea en `sem_wait(&hay_platos)` (P(hay_platos)). Queda bloqueado hasta que un
cocinero deje un plato y haga `sem_post(&hay_platos)` (V(hay_platos)).

**P: Por que los semaforos de espacios y hay_platos se inicializan en 8 y 0?**
R: `espacios` en 8 porque al inicio la barra esta vacia (8 lugares libres). `hay_platos`
en 0 porque al inicio no hay ningun plato. La suma espacios + hay_platos siempre da 8
(la capacidad de la barra).

**P: Que pasaria si no protegieras los contadores con mutex_cont?**
R: Tendriamos una condicion de carrera. Dos hilos podrian leer el mismo valor del
contador, ambos incrementar a lo mismo, y perder un incremento. Podriamos contar
49 platos en vez de 50 y el programa no terminaria.

**P: Cual es la diferencia entre un hilo y un proceso?**
R: Un proceso tiene su propio espacio de memoria. Los hilos comparten el espacio de
memoria del proceso que los creo. Por eso los hilos pueden acceder a las mismas variables
globales (como platos_en_barra), pero necesitan sincronizacion para no pisar datos.

**P: Por que pthread_join y no simplemente dejar que main termine?**
R: Si main termina, el proceso entero muere y mata a todos los hilos. Con pthread_join,
main espera a que cada hilo termine su trabajo antes de seguir.

---

## Que cosas del codigo NO se vieron en clase

Todo el codigo usa conceptos vistos en clase: semaforos (P, V, INIT), productor/consumidor
con buffer finito, hilos POSIX (pthread_create, pthread_join), y funciones estandar de C.
No hay nada fuera del material de clase.
