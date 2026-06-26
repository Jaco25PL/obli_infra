# Makefile - Parte 2 (Ejercicio 2: Grafo de Precedencias)
# Compila con gcc y linkea pthreads

CC = gcc
CFLAGS = -Wall
LDFLAGS = -lpthread

all: precedencias

precedencias: precedencias.c
	$(CC) $(CFLAGS) -o precedencias precedencias.c $(LDFLAGS)

clean:
	rm -f precedencias

.PHONY: all clean
