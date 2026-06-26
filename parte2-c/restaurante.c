/* ============================================================
 * EJERCICIO 1 - RESTAURANTE (Productor/Consumidor)
 *
 * PROCESOS:  5 cocineros (productores), 10 mozos (consumidores)
 * RECURSO:   barra de platos listos (buffer de capacidad 8)
 *
 * La sincronizacion usa el patron clasico productor/consumidor
 * con semaforos POSIX, mas un semaforo extra para la restriccion
 * de que solo un mozo puede estar en la barra a la vez.
 *
 * Compilar: gcc -o restaurante restaurante.c -lpthread
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
#include <time.h>

/* Constantes del problema (sacadas de la letra) */
#define NUM_COCINEROS    5
#define NUM_MOZOS        10
#define CAPACIDAD_BARRA  8
#define TOTAL_PLATOS     50

/* ---------------------------------------------------------------
 * SEMAFOROS - Cada uno arbitra un recurso o condicion distinta.
 *
 * En clase se usan las operaciones P y V:
 *   P(s) = sem_wait(s) = "pido capacidad, si no hay me bloqueo"
 *   V(s) = sem_post(s) = "devuelvo capacidad, desbloqueo si hay alguien esperando"
 *
 * espacios     -> lugares LIBRES en la barra.
 *                 INIT(espacios, 8) porque al inicio hay 8 lugares.
 *                 El cocinero hace P(espacios) antes de poner un plato.
 *                 El mozo hace V(espacios) despues de retirar un plato.
 *                 Si no hay espacios, el cocinero se bloquea (barra llena).
 *
 * hay_platos   -> platos DISPONIBLES en la barra.
 *                 INIT(hay_platos, 0) porque al inicio no hay platos.
 *                 El mozo hace P(hay_platos) antes de retirar un plato.
 *                 El cocinero hace V(hay_platos) despues de poner un plato.
 *                 Si no hay platos, el mozo se bloquea (barra vacia).
 *
 * mutex_barra  -> mutua exclusion para modificar platos_en_barra.
 *                 INIT(mutex_barra, 1) = un proceso a la vez toca la barra.
 *
 * mutex_mozo   -> restriccion extra de la letra: "la barra es estrecha,
 *                 entra un solo mozo a la vez".
 *                 INIT(mutex_mozo, 1) = un mozo a la vez se acerca.
 *                 Solo lo usan los mozos, los cocineros no lo necesitan.
 *
 * mutex_cont   -> protege los contadores compartidos
 *                 (platos_producidos, platos_entregados, terminado).
 *                 INIT(mutex_cont, 1)
 * --------------------------------------------------------------- */
sem_t espacios;
sem_t hay_platos;
sem_t mutex_barra;
sem_t mutex_mozo;
sem_t mutex_cont;

/* Estado compartido */
int platos_en_barra = 0;    /* cuantos platos hay ahora en la barra */
int platos_producidos = 0;   /* total de platos que ya se "reclamaron" para preparar */
int platos_entregados = 0;   /* total de platos ya entregados a las mesas */
int terminado = 0;           /* flag: 1 cuando se entregaron los 50 platos */


/* ---------------------------------------------------------------
 * HILO COCINERO (productor)
 *
 * Ciclo:
 *   1. Verificar si ya se produjeron 50 platos (si si, salir)
 *   2. Preparar un plato (parte asincrona, no necesita sync)
 *   3. P(espacios)    - esperar si la barra esta llena
 *   4. P(mutex_barra) - pedir acceso exclusivo a la barra
 *   5. Poner plato en la barra
 *   6. V(mutex_barra) - liberar la barra
 *   7. V(hay_platos)  - avisar que hay un plato nuevo
 * --------------------------------------------------------------- */
void* cocinero(void* arg) {
    int id = *(int*)arg;

    while (1) {
        /* Verificar si ya se produjeron todos los platos.
         * Se protege el contador con mutex_cont para que dos cocineros
         * no reclamen el mismo plato. */
        sem_wait(&mutex_cont);           /* P(mutex_cont) */
        if (platos_producidos >= TOTAL_PLATOS) {
            sem_post(&mutex_cont);       /* V(mutex_cont) */
            break;                       /* ya no hay mas platos que preparar */
        }
        platos_producidos++;
        int mi_plato = platos_producidos;
        sem_post(&mutex_cont);           /* V(mutex_cont) */

        /* Preparar plato (asincrono, no necesita ningun semaforo) */
        printf("Cocinero %d preparando plato #%d...\n", id, mi_plato);
        sleep(rand() % 3 + 1);          /* random de 1 a 3 segundos */

        /* Dejar plato en la barra (sincrono, necesita semaforos) */
        sem_wait(&espacios);             /* P(espacios) - si barra llena, me bloqueo */
        sem_wait(&mutex_barra);          /* P(mutex_barra) - acceso exclusivo */
        platos_en_barra++;
        printf("Cocinero %d dejo plato #%d en la barra (platos en barra: %d)\n",
               id, mi_plato, platos_en_barra);
        sem_post(&mutex_barra);          /* V(mutex_barra) - libero la barra */
        sem_post(&hay_platos);           /* V(hay_platos) - aviso que hay un plato */
    }

    printf("Cocinero %d termino su turno.\n", id);
    return NULL;
}


/* ---------------------------------------------------------------
 * HILO MOZO (consumidor)
 *
 * Ciclo:
 *   1. P(hay_platos)  - esperar si la barra esta vacia
 *   2. Verificar si ya se termino (flag terminado)
 *   3. P(mutex_mozo)  - solo un mozo a la vez (barra estrecha)
 *   4. P(mutex_barra) - acceso exclusivo a la barra
 *   5. Retirar plato
 *   6. V(mutex_barra) - liberar la barra
 *   7. V(mutex_mozo)  - liberar acceso de mozo
 *   8. V(espacios)    - avisar que hay un espacio libre
 *   9. Entregar plato (parte asincrona)
 *  10. Actualizar contador de entregas
 * --------------------------------------------------------------- */
void* mozo(void* arg) {
    int id = *(int*)arg;

    while (1) {
        /* Esperar a que haya un plato en la barra */
        sem_wait(&hay_platos);           /* P(hay_platos) - si no hay platos, me bloqueo */

        /* Verificar si el servicio ya termino.
         * Cuando se entregan los 50 platos, se pone terminado = 1
         * y se mandan signals extra a hay_platos para despertar
         * a los mozos que esten bloqueados. Si un mozo se despierta
         * y ve terminado = 1, propaga el signal y sale. */
        if (terminado) {
            sem_post(&hay_platos);       /* V(hay_platos) - despertar al siguiente mozo */
            break;
        }

        /* Retirar plato de la barra */
        sem_wait(&mutex_mozo);           /* P(mutex_mozo) - solo un mozo a la vez */
        sem_wait(&mutex_barra);          /* P(mutex_barra) - acceso exclusivo */
        platos_en_barra--;
        printf("Mozo %d retiro un plato de la barra (platos en barra: %d)\n",
               id, platos_en_barra);
        sem_post(&mutex_barra);          /* V(mutex_barra) - libero la barra */
        sem_post(&mutex_mozo);           /* V(mutex_mozo) - libero para otro mozo */
        sem_post(&espacios);             /* V(espacios) - aviso que hay un lugar libre */

        /* Entregar plato a la mesa (asincrono) */
        printf("Mozo %d esta entregando el plato...\n", id);
        sleep(rand() % 2 + 1);          /* random de 1 a 2 segundos */

        /* Actualizar contador de entregas */
        sem_wait(&mutex_cont);           /* P(mutex_cont) */
        platos_entregados++;
        printf("Mozo %d entrego el plato (total entregados: %d/%d)\n",
               id, platos_entregados, TOTAL_PLATOS);

        if (platos_entregados >= TOTAL_PLATOS) {
            terminado = 1;
            /* Despertar a todos los mozos que puedan estar bloqueados
             * en P(hay_platos). Como ya no van a venir mas platos,
             * sin esto quedarian bloqueados para siempre (deadlock de cierre).
             * Cada mozo al despertar ve terminado = 1 y sale. */
            int i;
            for (i = 0; i < NUM_MOZOS; i++) {
                sem_post(&hay_platos);   /* V(hay_platos) - signal de finalizacion */
            }
        }
        sem_post(&mutex_cont);           /* V(mutex_cont) */

        if (terminado) break;
    }

    printf("Mozo %d termino su turno.\n", id);
    return NULL;
}


/* ---------------------------------------------------------------
 * MAIN
 * - Inicializa semaforos
 * - Crea hilos de cocineros y mozos
 * - Espera a que todos terminen (pthread_join)
 * - Destruye semaforos y muestra resumen
 * --------------------------------------------------------------- */
int main() {
    srand(time(NULL));

    /* Inicializar semaforos.
     * sem_init(semaforo, 0, valor_inicial)
     *   - el 0 significa que el semaforo se comparte entre hilos (no procesos)
     *   - el tercer parametro es la capacidad inicial */
    sem_init(&espacios, 0, CAPACIDAD_BARRA);  /* INIT(espacios, 8) */
    sem_init(&hay_platos, 0, 0);              /* INIT(hay_platos, 0) */
    sem_init(&mutex_barra, 0, 1);             /* INIT(mutex_barra, 1) */
    sem_init(&mutex_mozo, 0, 1);              /* INIT(mutex_mozo, 1) */
    sem_init(&mutex_cont, 0, 1);              /* INIT(mutex_cont, 1) */

    pthread_t hilos_cocineros[NUM_COCINEROS];
    pthread_t hilos_mozos[NUM_MOZOS];
    int ids_cocineros[NUM_COCINEROS];
    int ids_mozos[NUM_MOZOS];
    int i;

    printf("=== RESTAURANTE - Productor/Consumidor ===\n");
    printf("Cocineros: %d, Mozos: %d, Capacidad barra: %d, Total platos: %d\n\n",
           NUM_COCINEROS, NUM_MOZOS, CAPACIDAD_BARRA, TOTAL_PLATOS);

    /* Crear hilos de cocineros (productores).
     * pthread_create(hilo, atributos, funcion, argumento)
     * - Cada hilo arranca ejecutando la funcion cocinero()
     * - Le pasamos su ID como argumento */
    for (i = 0; i < NUM_COCINEROS; i++) {
        ids_cocineros[i] = i + 1;
        pthread_create(&hilos_cocineros[i], NULL, cocinero, &ids_cocineros[i]);
    }

    /* Crear hilos de mozos (consumidores) */
    for (i = 0; i < NUM_MOZOS; i++) {
        ids_mozos[i] = i + 1;
        pthread_create(&hilos_mozos[i], NULL, mozo, &ids_mozos[i]);
    }

    /* Esperar a que terminen todos los hilos.
     * pthread_join(hilo, NULL) bloquea al main hasta que ese hilo termine.
     * Es como un "wait" del proceso padre hacia sus hijos. */
    for (i = 0; i < NUM_COCINEROS; i++) {
        pthread_join(hilos_cocineros[i], NULL);
    }
    for (i = 0; i < NUM_MOZOS; i++) {
        pthread_join(hilos_mozos[i], NULL);
    }

    /* Destruir semaforos (liberar recursos del SO) */
    sem_destroy(&espacios);
    sem_destroy(&hay_platos);
    sem_destroy(&mutex_barra);
    sem_destroy(&mutex_mozo);
    sem_destroy(&mutex_cont);

    printf("\n=== Servicio terminado ===\n");
    printf("Platos producidos: %d\n", platos_producidos);
    printf("Platos entregados: %d\n", platos_entregados);

    return 0;
}
