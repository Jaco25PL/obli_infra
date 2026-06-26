#!/bin/sh
# =========================================================
# ENTRYPOINT COMPARTIDO PARA LOS RUNNERS
#
# Se ejecuta cuando el contenedor arranca.
# Crea el directorio necesario para sshd en tmpfs
# y arranca el servidor SSH en primer plano.
# =========================================================

# Crear directorio /run/sshd si no existe.
# /run esta montado como tmpfs (escribible) porque el
# filesystem del contenedor es read-only.
mkdir -p /run/sshd 2>/dev/null || true

# Iniciar sshd:
#   -D = modo foreground (no se va a background).
#        Docker necesita que el proceso principal no termine.
#   -e = log a stderr en vez de /var/log/auth.log
#        (el filesystem es read-only, no puede escribir logs)
#   -f = ruta al archivo de configuracion
exec /usr/sbin/sshd -D -e -f /home/runner/sshd_config
