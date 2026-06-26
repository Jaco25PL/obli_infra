#!/usr/bin/env python3
# =========================================================
# PANEL WEB DE MONITOREO
#
# Servidor web simple que muestra el estado y metricas
# de los contenedores runners (bash, C, ADA).
#
# Funciona asi:
#   1. Un hilo de fondo consulta cada runner via SSH cada 10 seg
#   2. Lee metricas del sistema de cgroups (CPU, memoria)
#   3. Sirve una pagina HTML con los resultados
#
# OJO: lo siguiente NO se vio en clase, hay que estudiarlo:
#   - http.server: modulo de Python para crear un servidor web
#   - subprocess: para ejecutar comandos SSH desde Python
#   - threading: para ejecutar tareas en segundo plano
#   - /sys/fs/cgroup/: archivos virtuales de Linux que exponen
#     metricas de uso de recursos del contenedor (cgroups v2)
#
# Compilar/ejecutar: python3 panel.py
# Acceder desde el navegador: http://localhost:8080
# =========================================================

import http.server
import subprocess
import threading
import time

# =========================================================
# CONFIGURACION
# Lista de runners a monitorear.
# El nombre coincide con el nombre del servicio en docker-compose
# (Docker Compose crea DNS automatico para cada servicio).
# =========================================================
RUNNERS = [
    {"nombre": "bash-runner", "app": "Script Bash (Paddock Manager)"},
    {"nombre": "c-runner", "app": "Programas C (Restaurante + Precedencias)"},
    {"nombre": "ada-runner", "app": "Space Invaders (ADA)"},
]

# Diccionario compartido: guarda las metricas de cada runner.
# El hilo de monitoreo lo actualiza, el servidor HTTP lo lee.
estado_runners = {}


def consultar_runner(nombre):
    """
    Consulta un runner via SSH y devuelve sus metricas.

    Se conecta por SSH al runner y lee archivos del sistema
    de cgroups v2 para obtener uso de CPU y memoria.
    Si la conexion falla, el runner se marca como inactivo.
    """
    resultado = {
        "activo": False,
        "memoria_usada": "N/A",
        "memoria_limite": "N/A",
        "cpu_total": "N/A",
        "uptime": "N/A",
    }

    try:
        # Comando SSH que lee 4 metricas separadas por "---"
        # Se usa la config de ~/.ssh/config que ya tiene
        # el puerto, usuario y clave para cada runner.
        comando = [
            "ssh",
            "-o", "ConnectTimeout=3",
            nombre,
            # Leer metricas de cgroups v2:
            # memory.current = bytes de memoria en uso
            # memory.max = limite de memoria del contenedor
            # cpu.stat = estadisticas de CPU (usage_usec, etc)
            # /proc/uptime = tiempo que lleva corriendo
            "cat /sys/fs/cgroup/memory.current 2>/dev/null; "
            "echo '---'; "
            "cat /sys/fs/cgroup/memory.max 2>/dev/null; "
            "echo '---'; "
            "cat /sys/fs/cgroup/cpu.stat 2>/dev/null; "
            "echo '---'; "
            "cat /proc/uptime 2>/dev/null"
        ]

        # Ejecutar el comando SSH con timeout de 5 segundos
        proc = subprocess.run(
            comando,
            capture_output=True,
            text=True,
            timeout=5
        )

        if proc.returncode == 0:
            resultado["activo"] = True

            # Separar las 4 secciones de la salida
            partes = proc.stdout.split("---\n")

            # Memoria actual (bytes -> MB)
            if len(partes) >= 1 and partes[0].strip():
                try:
                    bytes_mem = int(partes[0].strip())
                    resultado["memoria_usada"] = str(bytes_mem // (1024 * 1024)) + " MB"
                except ValueError:
                    pass

            # Memoria limite (bytes -> MB, o "sin limite")
            if len(partes) >= 2 and partes[1].strip():
                max_mem = partes[1].strip()
                if max_mem == "max":
                    resultado["memoria_limite"] = "sin limite"
                else:
                    try:
                        resultado["memoria_limite"] = str(int(max_mem) // (1024 * 1024)) + " MB"
                    except ValueError:
                        pass

            # CPU total (usage_usec -> segundos)
            if len(partes) >= 3:
                for linea in partes[2].strip().split("\n"):
                    if linea.startswith("usage_usec"):
                        try:
                            usec = int(linea.split()[1])
                            seg = usec / 1000000.0
                            resultado["cpu_total"] = "{:.2f} seg".format(seg)
                        except (ValueError, IndexError):
                            pass

            # Uptime (segundos)
            if len(partes) >= 4 and partes[3].strip():
                try:
                    uptime_seg = float(partes[3].strip().split()[0])
                    resultado["uptime"] = str(int(uptime_seg)) + " seg"
                except (ValueError, IndexError):
                    pass

    except Exception:
        # Si falla la conexion SSH, el runner queda como inactivo
        pass

    return resultado


def hilo_monitoreo():
    """
    Hilo de fondo que consulta los runners periodicamente.

    Cada 10 segundos, se conecta a cada runner via SSH y
    actualiza el diccionario estado_runners con las metricas.
    Es un hilo daemon: se cierra automaticamente cuando el
    programa principal termina.
    """
    while True:
        for runner in RUNNERS:
            nombre = runner["nombre"]
            estado_runners[nombre] = consultar_runner(nombre)
        # Esperar 10 segundos antes de la siguiente consulta
        time.sleep(10)


def generar_html():
    """
    Genera la pagina HTML con el estado de los runners.

    Crea una tabla con una fila por runner mostrando:
    estado, memoria usada, limite de memoria, CPU y uptime.
    La pagina se auto-refresca cada 10 segundos.
    """
    filas = ""
    for runner in RUNNERS:
        nombre = runner["nombre"]
        info = estado_runners.get(nombre, {})

        # Determinar si esta activo o inactivo
        activo = info.get("activo", False)
        texto_estado = "ACTIVO" if activo else "INACTIVO"
        clase_css = "activo" if activo else "inactivo"

        # Construir la fila de la tabla
        filas += (
            "<tr>"
            "<td>" + nombre + "</td>"
            "<td>" + runner["app"] + "</td>"
            '<td class="' + clase_css + '">' + texto_estado + "</td>"
            "<td>" + str(info.get("memoria_usada", "N/A")) + "</td>"
            "<td>" + str(info.get("memoria_limite", "N/A")) + "</td>"
            "<td>" + str(info.get("cpu_total", "N/A")) + "</td>"
            "<td>" + str(info.get("uptime", "N/A")) + "</td>"
            "</tr>\n"
        )

    # Pagina HTML completa con CSS inline
    html = """<!DOCTYPE html>
<html>
<head>
    <title>Panel de Monitoreo - Obligatorio Infraestructura</title>
    <meta http-equiv="refresh" content="10">
    <style>
        body {
            font-family: monospace;
            background: #1a1a2e;
            color: #e0e0e0;
            padding: 20px;
        }
        h1 { color: #00d4ff; }
        table {
            border-collapse: collapse;
            width: 100%;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid #444;
            padding: 10px;
            text-align: center;
        }
        th { background: #16213e; color: #00d4ff; }
        .activo { color: #00ff88; font-weight: bold; }
        .inactivo { color: #ff4444; font-weight: bold; }
        .info { margin-top: 20px; color: #888; font-size: 0.9em; }
        .ssh-info {
            margin-top: 30px;
            background: #16213e;
            padding: 15px;
            border-radius: 5px;
        }
        .ssh-info h2 { color: #00d4ff; margin-top: 0; }
        code { color: #00ff88; }
    </style>
</head>
<body>
    <h1>Panel de Monitoreo</h1>
    <p>Obligatorio Infraestructura - ORT Uruguay</p>

    <table>
        <tr>
            <th>Runner</th>
            <th>Aplicacion</th>
            <th>Estado</th>
            <th>Memoria Usada</th>
            <th>Memoria Limite</th>
            <th>CPU Total</th>
            <th>Uptime</th>
        </tr>
""" + filas + """
    </table>

    <p class="info">Auto-refresh cada 10 segundos.
       Metricas obtenidas via SSH + cgroups v2.</p>

    <div class="ssh-info">
        <h2>Como ejecutar las aplicaciones</h2>
        <p>Desde el contenedor manager, conectarse via SSH:</p>
        <p><code>ssh bash-runner "cd app && bash paddock_manager_fixed.sh buscar Gorra"</code></p>
        <p><code>ssh c-runner "cd app && ./restaurante"</code></p>
        <p><code>ssh c-runner "cd app && ./precedencias"</code></p>
        <p><code>ssh -t ada-runner "cd app && ./space_invaders"</code></p>
        <p style="color: #888; font-size: 0.85em;">
            Nota: el juego de ADA necesita <code>ssh -t</code> para terminal interactiva.
        </p>
    </div>
</body>
</html>"""
    return html


class ManejadorHTTP(http.server.BaseHTTPRequestHandler):
    """
    Handler HTTP que responde a las peticiones del navegador.

    Cuando alguien accede a http://localhost:8080, este handler
    genera la pagina HTML con el estado actual de los runners.
    """

    def do_GET(self):
        """Responder a peticiones GET con la pagina del panel."""
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.end_headers()
        self.wfile.write(generar_html().encode())

    def log_message(self, format, *args):
        """Silenciar logs de acceso para no llenar la terminal."""
        pass


# =========================================================
# PUNTO DE ENTRADA
# =========================================================
if __name__ == "__main__":
    # Arrancar el hilo de monitoreo en segundo plano.
    # daemon=True hace que el hilo muera cuando el programa termine.
    monitor = threading.Thread(target=hilo_monitoreo, daemon=True)
    monitor.start()

    # Dar tiempo para la primera consulta a los runners
    print("Consultando runners...")
    time.sleep(3)

    # Arrancar el servidor web en el puerto 8080.
    # "0.0.0.0" significa que acepta conexiones desde cualquier IP
    # (necesario para que el host acceda al contenedor).
    servidor = http.server.HTTPServer(("0.0.0.0", 8080), ManejadorHTTP)
    print("Panel web activo en http://0.0.0.0:8080")
    servidor.serve_forever()
