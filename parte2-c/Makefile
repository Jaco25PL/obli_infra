# Makefile - Parte 2 (Ejercicio 1: Restaurante)
# Compila con gcc y linkea pthreads

CC = gcc
CFLAGS = -Wall
LDFLAGS = -lpthread

all: restaurante

restaurante: restaurante.c
	$(CC) $(CFLAGS) -o restaurante restaurante.c $(LDFLAGS)

clean:
	rm -f restaurante

.PHONY: all clean
