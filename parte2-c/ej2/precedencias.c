/* ============================================================
 * EJERCICIO 2 - GRAFO DE PRECEDENCIAS
 *
 * Tareas y dependencias:
 *   IS (inicializar sistema): sin previas
 *   BD (config base de datos): requiere IS
 *   SV (config servidor):     requiere IS
 *   PR (ejecutar pruebas):    requiere BD y SV
 *   DF (deploy final):        requiere PR
 *
 * Grafo:
 *
 *         IS
 *        /  \
 *       BD   SV
 *        \  /
 *         PR
 *         |
 *         DF
 *
 * Cada dependencia se modela con un semaforo inicializado en 0.
 * La tarea que depende hace P (sem_wait) al empezar.
 * La tarea que habilita hace V (sem_post) al terminar.
 * Asi, la dependiente se bloquea hasta que la previa termine.
 *
 * Compilar: gcc -o precedencias precedencias.c -lpthread
 * ============================================================ */

#include <stdio.h>
#include <stdlib.h>
#include <pthread.h>
#include <semaphore.h>
#include <unistd.h>
#include <time.h>

/* ---------------------------------------------------------------
 * SEMAFOROS DE PRECEDENCIA
 *
 * Un semaforo por cada arco del grafo, todos INIT en 0.
 * INIT en 0 significa que la tarea dependiente se bloquea de
 * entrada, hasta que la previa haga V (sem_post).
 *
 * sem_is_bd: IS -> BD   (IS habilita a BD)
 * sem_is_sv: IS -> SV   (IS habilita a SV)
 * sem_bd_pr: BD -> PR   (BD habilita a PR)
 * sem_sv_pr: SV -> PR   (SV habilita a PR)
 * sem_pr_df: PR -> DF   (PR habilita a DF)
 * --------------------------------------------------------------- */
sem_t sem_is_bd;
sem_t sem_is_sv;
sem_t sem_bd_pr;
sem_t sem_sv_pr;
sem_t sem_pr_df;


/* --- Tarea IS: Inicializar Sistema ---
 * Sin previas, no hace P de nada.
 * Al terminar hace V de sem_is_bd y sem_is_sv
 * para habilitar a BD y SV. */
void* tarea_is(void* arg) {
    printf("[IS] Iniciando: Inicializar sistema...\n");
    sleep(1);  /* simular trabajo */
    printf("[IS] Terminada: Sistema inicializado.\n");

    sem_post(&sem_is_bd);   /* V(sem_is_bd) - habilitar BD */
    sem_post(&sem_is_sv);   /* V(sem_is_sv) - habilitar SV */
    return NULL;
}

/* --- Tarea BD: Configurar Base de Datos ---
 * Requiere IS. Hace P(sem_is_bd) para esperar.
 * Al terminar hace V(sem_bd_pr) para habilitar PR. */
void* tarea_bd(void* arg) {
    sem_wait(&sem_is_bd);   /* P(sem_is_bd) - esperar a que IS termine */
    printf("[BD] Iniciando: Configurar base de datos...\n");
    sleep(2);  /* simular trabajo */
    printf("[BD] Terminada: Base de datos configurada.\n");

    sem_post(&sem_bd_pr);   /* V(sem_bd_pr) - habilitar PR */
    return NULL;
}

/* --- Tarea SV: Configurar Servidor ---
 * Requiere IS. Hace P(sem_is_sv) para esperar.
 * Al terminar hace V(sem_sv_pr) para habilitar PR. */
void* tarea_sv(void* arg) {
    sem_wait(&sem_is_sv);   /* P(sem_is_sv) - esperar a que IS termine */
    printf("[SV] Iniciando: Configurar servidor...\n");
    sleep(1);  /* simular trabajo */
    printf("[SV] Terminada: Servidor configurado.\n");

    sem_post(&sem_sv_pr);   /* V(sem_sv_pr) - habilitar PR */
    return NULL;
}

/* --- Tarea PR: Ejecutar Pruebas ---
 * Requiere BD y SV. Hace P de los dos semaforos.
 * Ambos P deben completarse antes de arrancar.
 * Al terminar hace V(sem_pr_df) para habilitar DF. */
void* tarea_pr(void* arg) {
    sem_wait(&sem_bd_pr);   /* P(sem_bd_pr) - esperar a que BD termine */
    sem_wait(&sem_sv_pr);   /* P(sem_sv_pr) - esperar a que SV termine */
    printf("[PR] Iniciando: Ejecutar pruebas...\n");
    sleep(2);  /* simular trabajo */
    printf("[PR] Terminada: Pruebas ejecutadas.\n");

    sem_post(&sem_pr_df);   /* V(sem_pr_df) - habilitar DF */
    return NULL;
}

/* --- Tarea DF: Deploy Final ---
 * Requiere PR. Hace P(sem_pr_df) para esperar.
 * Es la ultima tarea, no hace V de nada. */
void* tarea_df(void* arg) {
    sem_wait(&sem_pr_df);   /* P(sem_pr_df) - esperar a que PR termine */
    printf("[DF] Iniciando: Deploy final...\n");
    sleep(1);  /* simular trabajo */
    printf("[DF] Terminada: Deploy completado!\n");

    return NULL;
}


int main() {
    /* Inicializar todos los semaforos en 0.
     * INIT en 0 = la tarea dependiente se bloquea al hacer P
     * hasta que la previa haga V. */
    sem_init(&sem_is_bd, 0, 0);   /* INIT(sem_is_bd, 0) */
    sem_init(&sem_is_sv, 0, 0);   /* INIT(sem_is_sv, 0) */
    sem_init(&sem_bd_pr, 0, 0);   /* INIT(sem_bd_pr, 0) */
    sem_init(&sem_sv_pr, 0, 0);   /* INIT(sem_sv_pr, 0) */
    sem_init(&sem_pr_df, 0, 0);   /* INIT(sem_pr_df, 0) */

    printf("=== GRAFO DE PRECEDENCIAS ===\n");
    printf("Orden esperado: IS -> (BD, SV en paralelo) -> PR -> DF\n\n");

    /* Crear TODOS los hilos de una vez.
     * Aunque se crean todos juntos, los semaforos controlan
     * el orden: BD y SV esperan a IS, PR espera a BD y SV, etc.
     * El orden de creacion no importa porque la sincronizacion
     * la manejan los semaforos. */
    pthread_t hilo_is, hilo_bd, hilo_sv, hilo_pr, hilo_df;

    pthread_create(&hilo_is, NULL, tarea_is, NULL);
    pthread_create(&hilo_bd, NULL, tarea_bd, NULL);
    pthread_create(&hilo_sv, NULL, tarea_sv, NULL);
    pthread_create(&hilo_pr, NULL, tarea_pr, NULL);
    pthread_create(&hilo_df, NULL, tarea_df, NULL);

    /* Esperar a que todos terminen */
    pthread_join(hilo_is, NULL);
    pthread_join(hilo_bd, NULL);
    pthread_join(hilo_sv, NULL);
    pthread_join(hilo_pr, NULL);
    pthread_join(hilo_df, NULL);

    /* Destruir semaforos */
    sem_destroy(&sem_is_bd);
    sem_destroy(&sem_is_sv);
    sem_destroy(&sem_bd_pr);
    sem_destroy(&sem_sv_pr);
    sem_destroy(&sem_pr_df);

    printf("\n=== Despliegue completo ===\n");
    return 0;
}
