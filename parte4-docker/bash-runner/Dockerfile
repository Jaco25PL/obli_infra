# =========================================================
# DOCKERFILE - BASH RUNNER
#
# Contenedor que ejecuta el script de Bash (Parte 1).
# Imagen base: Alpine (la mas liviana posible, ~5 MB).
# Se eligio Alpine porque el script solo necesita bash
# y no tiene dependencias de glibc.
#
# Instrucciones usadas (vistas en clase):
#   FROM     - imagen base
#   RUN      - ejecutar comandos durante la construccion
#   COPY     - copiar archivos al contenedor
#   WORKDIR  - directorio de trabajo
#   USER     - usuario que ejecuta el proceso (no root)
#   CMD      - comando que se ejecuta al iniciar
#
# OJO: USER, las opciones de seguridad de SSH y las
# directivas de hardening en compose NO se vieron en clase.
# =========================================================

FROM alpine:3.21

# Instalar lo minimo necesario:
#   bash     - interprete de Bash para ejecutar el script
#   openssh  - servidor SSH para acceso remoto desde el manager
# --no-cache evita guardar el indice de paquetes (imagen mas chica)
RUN apk add --no-cache bash openssh

# Crear usuario "runner" sin privilegios.
# El proceso principal (sshd) corre como este usuario, NO como root.
# adduser -D = no pedir password interactivamente
RUN adduser -D runner

# Crear directorio para las claves del host SSH
# y generar una clave ed25519 para identificar al servidor.
# Esta clave se genera en build time porque el filesystem
# es read-only en runtime (no se puede generar despues).
RUN mkdir -p /home/runner/ssh-host \
    && ssh-keygen -t ed25519 -f /home/runner/ssh-host/ssh_host_ed25519_key -N "" \
    && chown -R runner:runner /home/runner/ssh-host

# Copiar la clave publica del manager como clave autorizada.
# Solo quien tenga la clave privada correspondiente puede entrar.
RUN mkdir -p /home/runner/.ssh
COPY parte4-docker/ssh-keys/id_ed25519.pub /home/runner/.ssh/authorized_keys
RUN chown -R runner:runner /home/runner/.ssh \
    && chmod 700 /home/runner/.ssh \
    && chmod 600 /home/runner/.ssh/authorized_keys

# Copiar la configuracion de SSH endurecida
COPY parte4-docker/shared/sshd_config /home/runner/sshd_config
RUN chown runner:runner /home/runner/sshd_config

# Copiar el entrypoint (script de inicio)
COPY parte4-docker/shared/entrypoint.sh /home/runner/entrypoint.sh
RUN chmod +x /home/runner/entrypoint.sh

# Copiar la aplicacion: el script de Bash y sus datos de prueba
WORKDIR /home/runner/app
COPY parte1-bash/paddock_manager_fixed.sh .
COPY parte1-bash/inventario_f1.csv .
COPY parte1-bash/mercaderia/ ./mercaderia/
RUN chown -R runner:runner /home/runner/app

# Ejecutar como usuario no root
USER runner

# Iniciar sshd con el entrypoint
CMD ["/home/runner/entrypoint.sh"]
