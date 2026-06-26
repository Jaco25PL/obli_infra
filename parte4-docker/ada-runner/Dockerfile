# =========================================================
# DOCKERFILE - ADA RUNNER (multi-stage build)
#
# Contenedor que ejecuta Space Invaders en ADA (Parte 3).
# Usa construccion multi-etapa:
#   Etapa 1 (compilador): compila con gnatmake en Debian
#   Etapa 2 (runtime):    Debian slim con la libreria Ada
#
# Imagen de compilacion: Debian bookworm (tiene gnat)
# Imagen de ejecucion:   Debian bookworm-slim (liviana)
#
# No se puede usar Alpine porque GNAT (compilador Ada) no
# esta disponible en Alpine, y el binario compilado necesita
# libgnat (la libreria de runtime de Ada) que usa glibc.
# =========================================================

# --- ETAPA 1: COMPILACION ---
FROM debian:bookworm AS compilador

# Instalar gnat (compilador Ada para Debian)
RUN apt-get update \
    && apt-get install -y --no-install-recommends gnat \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copiar el fuente de ADA
COPY parte3-ada/space_invaders.adb .

# Compilar con gnatmake
RUN gnatmake space_invaders.adb

# --- ETAPA 2: IMAGEN DE EJECUCION ---
FROM debian:bookworm-slim

# Instalar lo minimo:
#   openssh-server - para acceso SSH desde el manager
#   libgnat-12     - libreria de runtime de Ada (necesaria para
#                    ejecutar programas compilados con GNAT 12)
# --no-install-recommends evita paquetes opcionales
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       openssh-server \
       libgnat-12 \
    && rm -rf /var/lib/apt/lists/*

# Crear usuario no root
RUN useradd -m runner

# Generar claves del host SSH
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

# Crear directorio /run/sshd que Debian necesita para sshd
RUN mkdir -p /run/sshd

# Copiar el binario compilado desde la etapa 1
WORKDIR /home/runner/app
COPY --from=compilador /build/space_invaders .
RUN chown -R runner:runner /home/runner/app

# Ejecutar como usuario no root
USER runner

CMD ["/home/runner/entrypoint.sh"]
