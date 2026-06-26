# Parte 3 - Space Invaders en ADA - Notas de Defensa

## Que hace el programa

Implementa un Space Invaders simplificado en ADA usando concurrencia nativa del lenguaje.
10 naves enemigas (en 2 filas de 5) se mueven de lado a lado. El jugador controla un
cannon en la parte inferior y dispara balas hacia arriba. Cuando una bala alcanza una
nave, se produce una CITA (rendezvous) que destruye la nave. El juego termina cuando
se destruyen todas las naves o el jugador aprieta Q.

---

## Mapeo a los conceptos de clase

| Concepto de clase | En el juego |
|---|---|
| Task | Cada nave es una task, cada bala es una task, el main es una task |
| Task type | Tarea_Nave y Tarea_Bala son task types (moldes que se instancian varias veces) |
| Entry | Iniciar, Impactar (en nave), Iniciar_Bala, Disparar (en bala) |
| Accept | Dentro del body de cada task, acepta sus entries |
| Rendezvous / cita | La colision bala-nave: la bala llama Naves(I).Impactar, la nave acepta con accept Impactar |
| Select con delay | La nave usa select/accept Impactar/or delay 0.4 para moverse si nadie la impacta |
| Select con terminate | La bala espera con select/accept Disparar/or terminate para morir cuando no hay mas trabajo |
| Iteraciones sin citas | Cuando la bala sube pero no choca con ninguna nave, no hay citas en esa iteracion |

---

## Arquitectura de tasks

```
Main (task principal)
  |
  |-- Naves(1..10) : Tarea_Nave    -- 10 instancias
  |-- Balas(1..3)  : Tarea_Bala    -- 3 instancias
```

Todas las tasks arrancan automaticamente antes del begin del main. El main las inicializa
con citas (Iniciar, Iniciar_Bala) y despues entra al loop del juego.

---

## Flujo de cada task

### Nave (Tarea_Nave)
```
1. accept Iniciar(id, fila, col)  -- cita con el main, recibe posicion
2. Guardar posicion en Nav(Id)
3. Loop mientras este viva:
   select
     accept Impactar          -- si una bala llama, aceptar la cita
     -> marcar como Destruida
   or
     delay 0.4                -- si nadie llama en 0.4 seg, moverse
     -> Col := Col + Direccion
   end select
```

### Bala (Tarea_Bala)
```
1. accept Iniciar_Bala(id)        -- cita con el main, recibe ID
2. Loop externo (esperar y disparar):
   select
     accept Disparar(col)         -- cita con el main, recibe columna
   or
     terminate                    -- si el programa termina, morir
   end select
3. Loop interno (subir desde fila ALTO-1 hasta fila 1):
   - Por cada nave viva en la misma fila y rango de columna:
     -> Naves(I).Impactar         -- CITA de colision (rendezvous)
   - Si no hay colision, subir un paso (Fila - 1)
4. Desactivarse y volver al loop externo
```

### Main
```
1. Inicializar naves (cita Iniciar con cada una)
2. Inicializar balas (cita Iniciar_Bala con cada una)
3. Loop del juego:
   - Leer teclado (Get_Immediate, no bloqueante)
   - A/D: mover cannon
   - W: buscar bala libre, llamar Disparar
   - Q: Juego_Activo := False
   - Actualizar direccion de movimiento
   - Verificar si gano
   - Dibujar pantalla
   - delay 0.05
```

---

## La cita de la colision (concepto central)

La colision entre bala y nave es el ejemplo mas importante del programa. Es un
rendezvous (cita) tal como se vio en clase:

1. La bala (caller) llama a `Naves(I).Impactar`
2. La nave (called) tiene `accept Impactar` dentro de un `select`
3. Ambas tasks se sincronizan: la bala espera a que la nave acepte, la nave espera
   a que alguien llame
4. El cuerpo del accept se ejecuta bajo mutua exclusion entre las dos tasks
5. Al terminar el accept, ambas continuan por su lado

Si la nave ya termino, la llamada a Impactar lanza Tasking_Error. Por eso la bala
usa begin/exception para atrapar ese error y seguir sin bloquearse.

---

## Entries y su proposito

| Entry | Task que lo tiene | Quien lo llama | Para que |
|---|---|---|---|
| Iniciar(id, fila, col) | Tarea_Nave | Main | Darle a la nave su ID y posicion |
| Impactar | Tarea_Nave | Tarea_Bala | Colision: destruir la nave |
| Iniciar_Bala(id) | Tarea_Bala | Main | Darle a la bala su ID |
| Disparar(col) | Tarea_Bala | Main | Decirle a la bala que salga desde esa columna |

---

## Sentencias y funciones no triviales

| Sentencia | Que hace |
|---|---|
| `task type Tarea_Nave is` | Define un molde de task reutilizable, como task type Semaforo de clase |
| `entry Impactar` | Declara un punto de cita en la especificacion de la task |
| `accept Impactar` | Acepta la cita en el body. Se bloquea hasta que alguien llame |
| `select ... or delay 0.4` | Si nadie llama en 0.4 segundos, toma la rama del delay |
| `select ... or terminate` | La task termina automaticamente cuando el programa va a finalizar |
| `Naves(I).Impactar` | Entry call: la bala llama a la cita de colision con la nave I |
| `Naves : array (1..10) of Tarea_Nave` | Crea 10 instancias del task type (10 naves como tasks) |
| `Nav(I).Estado := Destruida` | Cambia el estado compartido de la nave (accedido por Dibujar) |
| `and then` | AND con corto-circuito: si la primera es falsa, no evalua el resto |
| `in 1 .. ALTO` | Operador de rango: True si el valor esta entre 1 y ALTO inclusive |
| `declare ... begin ... end` | Bloque declarativo inline, como un scope local |

---

## Cosas que NO se vieron en clase (hay que estudiar aparte)

| Concepto | Donde se usa | Explicacion |
|---|---|---|
| `Get_Immediate(Tecla, Hay_Tecla)` | Loop principal del main | Lee una tecla sin esperar Enter. La version con dos parametros es no bloqueante: si no hay tecla, Hay_Tecla queda False |
| `Character'Val(27)` | Procedimiento Dibujar | Obtiene el caracter ASCII 27 (ESC). Se usa para enviar codigos ANSI a la terminal |
| `ESC[2J` y `ESC[H` | Procedimiento Dibujar | Codigos ANSI: [2J limpia la pantalla, [H mueve el cursor al inicio. Son estandar en terminales modernas |
| `exception when Tasking_Error` | Bala al llamar Impactar | Atrapa el error que ocurre si la task de la nave ya termino |
| `exception when others` | Lectura de teclado | Atrapa cualquier error al leer el teclado (algunas terminales pueden dar error) |

---

## Preguntas probables del docente

**P: Por que cada nave es una task?**
R: Porque cada nave es una entidad concurrente que se mueve independientemente de las
demas. Cada nave corre en paralelo, como Alice y Bob en los ejemplos de clase.

**P: Donde esta el rendezvous (cita) en tu programa?**
R: En la colision bala-nave. La bala (caller) llama a `Naves(I).Impactar` y la nave
(called) acepta con `accept Impactar`. Se sincronizan en ese punto, la nave se marca
como destruida, y cada una sigue por su lado.

**P: Que pasa en las iteraciones donde la bala no choca con nadie?**
R: No hay ninguna cita. La bala simplemente sube un paso (Fila - 1) y espera 0.07
segundos. Solo cuando coincide en posicion con una nave hace la llamada a Impactar.

**P: Para que sirve el select con delay en la nave?**
R: Es una espera selectiva con timeout. Si una bala llama a Impactar, la nave acepta
la cita y se destruye. Si nadie llama en 0.4 segundos, toma la rama del delay y se
mueve. Asi la nave no se queda bloqueada esperando eternamente.

**P: Para que sirve el select con terminate en la bala?**
R: Permite que la task de la bala termine automaticamente cuando el programa va a
finalizar. Si el main pone Juego_Activo en False y no hay mas trabajo, las balas
que estan en select/or terminate terminan solas, sin necesidad de signal.

**P: Por que usas begin/exception al llamar Impactar?**
R: Porque entre el momento en que la bala comprueba que la nave esta viva y el momento
en que llama a Impactar, la nave podria haber terminado. Si la task de la nave ya
termino, la llamada a Impactar lanza Tasking_Error. El exception lo atrapa para que
la bala no se caiga.

**P: Como se comunican las tasks con el main para dibujar?**
R: A traves de variables globales compartidas (Nav y Bal). Cada task actualiza su
posicion en el array correspondiente. El main lee esas posiciones en Dibujar para
pintar la pantalla. No hace falta mutex porque cada task escribe solo su propia
posicion y el main solo lee.

**P: Que es un task type y para que lo usas?**
R: Es un molde de task que se puede instanciar varias veces, como task type Semaforo
del material de clase. Yo defino Tarea_Nave como task type y despues creo un array
de 10 instancias. Cada instancia es una task independiente.

**P: El main espera a que terminen las tasks?**
R: Si. En ADA, el main (que es una task) espera automaticamente a que todas sus
subtasks terminen antes de finalizar. Es como pthread_join en C pero automatico.

**P: Que pasaria si no pusieras el delay 0.05 en el loop principal?**
R: El loop correria a maxima velocidad, consumiendo todo el CPU y redibujando la
pantalla cientos de veces por segundo. El delay 0.05 mantiene el juego a ~20 FPS.

---

## Compilar y ejecutar

```bash
# Compilar
gnatmake space_invaders.adb

# Ejecutar
./space_invaders

# Controles
# A = mover cannon a la izquierda
# D = mover cannon a la derecha
# W = disparar
# Q = salir
```
