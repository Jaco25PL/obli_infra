# =========================================================
# DOCKERFILE - C RUNNER (multi-stage build)
#
# Contenedor que ejecuta los programas de C (Parte 2).
# Usa construccion multi-etapa:
#   Etapa 1 (compilador): compila los programas con gcc
#   Etapa 2 (runtime):    imagen minima solo con los binarios
#
# Imagen base de compilacion: Alpine con gcc
# Imagen base de ejecucion:   Alpine (sin gcc, solo lo minimo)
#
# Se eligio Alpine porque musl (la libc de Alpine) soporta
# bien pthreads y el binario compilado no necesita glibc.
# =========================================================

# --- ETAPA 1: COMPILACION ---
# Esta etapa solo existe durante la construccion.
# El resultado (los binarios) se copia a la etapa final.
# gcc, musl-dev, etc. NO quedan en la imagen final.
FROM alpine:3.21 AS compilador

# Instalar gcc y las cabeceras de musl para compilar C
RUN apk add --no-cache gcc musl-dev

WORKDIR /build

# Copiar los fuentes de C
COPY parte2-c/restaurante.c .
COPY parte2-c/ej2/precedencias.c .

# Compilar los dos programas
# -Wall  = mostrar todas las advertencias
# -O2    = optimizacion nivel 2
# -static = linkeo estatico (el binario incluye todo, no necesita .so)
# -lpthread = linkear la libreria de hilos POSIX
RUN gcc -Wall -O2 -static -o restaurante restaurante.c -lpthread
RUN gcc -Wall -O2 -static -o precedencias precedencias.c -lpthread

# --- ETAPA 2: IMAGEN DE EJECUCION ---
# Imagen limpia, sin compilador ni herramientas de desarrollo.
# Solo tiene lo minimo para ejecutar los binarios y SSH.
FROM alpine:3.21

# Instalar solo openssh (para acceso remoto)
# No necesitamos gcc ni librerias de desarrollo
RUN apk add --no-cache openssh

# Crear usuario no root
RUN adduser -D runner

# Generar claves del host SSH (en build time, filesystem es read-only)
RUN mkdir -p /home/runner/ssh-host \
    && ssh-keygen -t ed25519 -f /home/runner/ssh-host/ssh_host_ed25519_key -N "" \
    && chown -R runner:runner /home/runner/ssh-host

# Clave publica del manager como autorizada
RUN mkdir -p /home/runner/.ssh
COPY parte4-docker/ssh-keys/id_ed25519.pub /home/runner/.ssh/authorized_keys
RUN chown -R runner:runner /home/runner/.ssh \
    && chmod 700 /home/runner/.ssh \
    && chmod 600 /home/runner/.ssh/authorized_keys

# Config SSH endurecida y entrypoint
COPY parte4-docker/shared/sshd_config /home/runner/sshd_config
COPY parte4-docker/shared/entrypoint.sh /home/runner/entrypoint.sh
RUN chown runner:runner /home/runner/sshd_config \
    && chmod +x /home/runner/entrypoint.sh

# Copiar SOLO los binarios compilados desde la etapa 1
# (sin gcc, sin codigo fuente, sin herramientas de compilacion)
WORKDIR /home/runner/app
COPY --from=compilador /build/restaurante .
COPY --from=compilador /build/precedencias .
RUN chown -R runner:runner /home/runner/app

# Ejecutar como usuario no root
USER runner

CMD ["/home/runner/entrypoint.sh"]
