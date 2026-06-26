# =========================================================
# DOCKERFILE - MANAGER
#
# Contenedor gestor con dos responsabilidades:
#   1. Cliente SSH para conectarse a los runners
#   2. Panel web de monitoreo (puerto 8080)
#
# Imagen base: python:3.13-alpine
# Se eligio esta imagen porque:
#   - Incluye Python para el panel web (http.server)
#   - Alpine es la variante mas liviana (~50 MB)
#   - No necesita compilador ni herramientas extra
# =========================================================

FROM python:3.13-alpine

# Instalar cliente SSH para conectarse a los runners
# No necesitamos el servidor SSH, solo el cliente
RUN apk add --no-cache openssh-client

# Crear usuario no root
RUN adduser -D manager

# Copiar la clave privada SSH del manager
# (con esta clave se conecta a los runners)
RUN mkdir -p /home/manager/.ssh
COPY parte4-docker/ssh-keys/id_ed25519 /home/manager/.ssh/id_ed25519
COPY parte4-docker/ssh-keys/id_ed25519.pub /home/manager/.ssh/id_ed25519.pub
RUN chmod 700 /home/manager/.ssh \
    && chmod 600 /home/manager/.ssh/id_ed25519 \
    && chown -R manager:manager /home/manager/.ssh

# Copiar la configuracion del cliente SSH
# Define como conectarse a cada runner (host, puerto, usuario, clave)
COPY parte4-docker/manager/ssh_config /home/manager/.ssh/config
RUN chmod 600 /home/manager/.ssh/config \
    && chown manager:manager /home/manager/.ssh/config

# Copiar el panel web
WORKDIR /home/manager
COPY parte4-docker/manager/panel.py .
RUN chown manager:manager panel.py

# Ejecutar como usuario no root
USER manager

# Exponer puerto 8080 para el panel web
EXPOSE 8080

# Iniciar el panel web
CMD ["python3", "panel.py"]
