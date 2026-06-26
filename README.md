# Obligatorio de Infraestructura — ORT Uruguay

Obligatorio de la materia Infraestructura (Licenciatura en Sistemas).
4 partes: Bash, C (concurrencia), ADA (Space Invaders), Docker.

---

## Como correr cada parte

### Parte 1 — Bash

```bash
cd parte1-bash/

# Buscar un producto
./paddock_manager_fixed.sh buscar "Gorra"

# Ingresar un producto nuevo
./paddock_manager_fixed.sh ingresar "006,Campera,Ferrari,15,89.99"

# Descatalogar una escuderia
./paddock_manager_fixed.sh descatalogar Ferrari
```

### Parte 2 — C (Concurrencia)

```bash
# Ejercicio 1: Restaurante (productor/consumidor)
cd parte2-c/
make
./restaurante

# Ejercicio 2: Grafo de precedencias
cd parte2-c/ej2/
make
./precedencias
```

### Parte 3 — ADA (Space Invaders)

```bash
cd parte3-ada/
gnatmake space_invaders.adb
./space_invaders

# Controles: A=izquierda, D=derecha, W=disparar, Q=salir
```

### Parte 4 — Docker

```bash
cd parte4-docker/

# Levantar todo
docker compose up

# Panel web: abrir http://localhost:8080 en el navegador

# Ejecutar apps desde el manager (en otra terminal):
docker exec -it parte4-docker-manager-1 sh
ssh bash-runner "cd app && bash paddock_manager_fixed.sh buscar Gorra"
ssh c-runner "cd app && ./restaurante"
ssh c-runner "cd app && ./precedencias"
ssh -t ada-runner "cd app && ./space_invaders"

# Parar todo
docker compose down
```

---

## Informes y notas de defensa

Todos los informes estan en la carpeta `informe/`:

- [Informe tecnico general](informe/informe-tecnico.md)
- [Defensa Parte 1 — Bash](informe/defensa-parte1.md)
- [Defensa Parte 2 Ej.1 — Restaurante](informe/defensa-parte2-ej1.md)
- [Defensa Parte 2 Ej.2 — Precedencias](informe/defensa-parte2-ej2.md)
- [Defensa Parte 3 — ADA Space Invaders](informe/defensa-parte3.md)
- [Defensa Parte 4 — Docker](informe/defensa-parte4.md)
