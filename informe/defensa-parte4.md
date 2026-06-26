# Parte 4 - Docker - Notas de Defensa

## Que hace el sistema

4 contenedores orquestados con Docker Compose:
- **manager**: panel web (puerto 8080) + cliente SSH para conectarse a los runners
- **bash-runner**: ejecuta el script Bash de la Parte 1 (Paddock Manager)
- **c-runner**: ejecuta los programas C de la Parte 2 (Restaurante + Precedencias)
- **ada-runner**: ejecuta Space Invaders de la Parte 3

Los runners NO exponen puertos al host. Solo son accesibles desde el manager via SSH
a traves de la red interna de Docker. El panel web muestra estado y metricas reales
de cada runner (CPU, memoria, uptime) obtenidas via SSH + cgroups v2.

---

## Arquitectura

```
Host (localhost:8080)
     |
     v
 [manager]  -- red publica (para exponer puerto)
     |
     +-- red interna (internal: true, sin acceso a internet)
     |       |         |         |
     |      SSH       SSH       SSH
     |    (2222)    (2222)    (2222)
     |       |         |         |
     v       v         v         v
 [manager] [bash]    [ C ]    [ADA]
```

---

## Eleccion de imagenes base

| Contenedor | Imagen | Tamano | Justificacion |
|---|---|---|---|
| bash-runner | alpine:3.21 | ~24 MB | La mas liviana. Bash disponible via apk. Sin dependencias de glibc |
| c-runner | alpine:3.21 | ~23 MB | Compilacion estatica con musl. Binario autocontenido, no necesita gcc en runtime |
| ada-runner | debian:bookworm-slim | ~149 MB | GNAT (compilador Ada) solo disponible en Debian. El binario necesita libgnat-12 (runtime Ada) que usa glibc |
| manager | python:3.13-alpine | ~75 MB | Incluye Python para el panel web. Alpine es la variante mas liviana |

Para c-runner y ada-runner se usa **multi-stage build**: la etapa 1 compila con
gcc/gnat, la etapa 2 solo tiene los binarios y lo minimo para ejecutar. El compilador
y herramientas de desarrollo NO quedan en la imagen final.

---

## Configuracion de seguridad aplicada

### 1. Usuario no root (USER en Dockerfile)

Cada contenedor corre su proceso principal como un usuario sin privilegios:
- Runners: usuario `runner`
- Manager: usuario `manager`

Si alguien compromete el contenedor, no tiene permisos de root.

### 2. Filesystem read-only (read_only: true en compose)

El filesystem del contenedor es de solo lectura. Ningun proceso puede modificar
archivos del contenedor. Los directorios que necesitan escritura (/tmp, /run) se
montan como tmpfs (memoria RAM, temporal).

### 3. Capabilities minimas (cap_drop: ALL)

Se eliminan TODAS las capabilities de Linux. Las capabilities son permisos
granulares del kernel (ej: NET_ADMIN para configurar red, SYS_ADMIN para montar
filesystems). Quitarlas reduce lo que un atacante podria hacer.

### 4. Sin escalada de privilegios (security_opt: no-new-privileges)

Impide que un proceso dentro del contenedor gane mas privilegios de los que tiene.
Bloquea mecanismos como setuid o binarios con capabilities especiales.

### 5. Red interna (internal: true)

Los runners solo estan en la red interna de Docker. No tienen acceso a internet
ni exponen puertos al host. Solo el manager puede comunicarse con ellos.

El manager esta en dos redes:
- `interna`: para SSH con los runners
- `publica`: para exponer el puerto 8080 al host

### 6. SSH endurecido (sshd_config)

| Directiva | Que hace |
|---|---|
| Port 2222 | Puerto alto, no necesita root para escuchar |
| PermitRootLogin no | No permite login como root via SSH |
| PasswordAuthentication no | Solo clave publica, no password |
| PubkeyAuthentication yes | Autenticacion por par de claves (ed25519) |
| KbdInteractiveAuthentication no | Desactiva autenticacion interactiva |
| X11Forwarding no | No permite reenvio de graficos |
| StrictModes no | Necesario para correr sshd como non-root |

### 7. Sin software innecesario

Cada contenedor tiene solo lo que necesita:
- bash-runner: bash + openssh
- c-runner: openssh (los binarios son estaticos, no necesitan librerias)
- ada-runner: openssh + libgnat-12
- manager: python + openssh-client

No hay compiladores, editores, ni herramientas de debug en las imagenes finales.

---

## Construccion multi-stage (c-runner y ada-runner)

La construccion multi-stage funciona asi:

```dockerfile
# Etapa 1: COMPILACION (imagen pesada, tiene gcc/gnat)
FROM alpine:3.21 AS compilador
RUN apk add gcc musl-dev
COPY fuentes .
RUN gcc -o programa fuentes.c

# Etapa 2: EJECUCION (imagen liviana, solo lo necesario)
FROM alpine:3.21
COPY --from=compilador /build/programa .
# gcc y los fuentes NO estan aca
```

La etapa 1 existe solo durante la construccion. La imagen final solo contiene
lo de la etapa 2. Esto reduce dramaticamente el tamano y la superficie de ataque.

---

## Panel web de monitoreo

El panel web usa Python puro (sin frameworks externos):

1. Un hilo de fondo (threading) consulta cada runner cada 10 seg
2. Se conecta via SSH y lee metricas de cgroups v2:
   - `/sys/fs/cgroup/memory.current`: memoria usada en bytes
   - `/sys/fs/cgroup/memory.max`: limite de memoria
   - `/sys/fs/cgroup/cpu.stat`: tiempo de CPU usado
   - `/proc/uptime`: tiempo activo
3. Sirve una pagina HTML con auto-refresh

cgroups v2 es el mecanismo del kernel Linux que Docker usa para limitar y medir
los recursos de cada contenedor.

---

## Como levantar el sistema

```bash
# Desde la carpeta parte4-docker/
docker compose up

# O en segundo plano:
docker compose up -d

# Ver el panel web:
# Abrir http://localhost:8080 en el navegador

# Parar todo:
docker compose down
```

## Como conectarse a los runners desde el manager

```bash
# Entrar al manager
docker exec -it parte4-docker-manager-1 sh

# Desde el manager, conectarse a cada runner:
ssh bash-runner "cd app && bash paddock_manager_fixed.sh buscar Gorra"
ssh c-runner "cd app && ./restaurante"
ssh c-runner "cd app && ./precedencias"
ssh -t ada-runner "cd app && ./space_invaders"  # -t para terminal interactiva
```

---

## Instrucciones y directivas no triviales

### Dockerfile

| Instruccion | Que hace |
|---|---|
| FROM ... AS compilador | Define una etapa de build con nombre (multi-stage) |
| COPY --from=compilador | Copia archivos desde otra etapa del build |
| RUN apk add --no-cache | Instala paquetes en Alpine sin guardar cache (imagen mas chica) |
| RUN apt-get install --no-install-recommends | Instala sin paquetes opcionales (imagen mas chica) |
| USER runner | Los comandos siguientes se ejecutan como este usuario |
| EXPOSE 8080 | Documenta que el contenedor escucha en el puerto 8080 |
| WORKDIR /home/runner/app | Establece el directorio de trabajo |

### docker-compose.yml

| Directiva | Que hace |
|---|---|
| build: context / dockerfile | Define donde estan los archivos y el Dockerfile |
| ports: "8080:8080" | Mapea puerto del host al contenedor |
| networks: [interna, publica] | Conecta el contenedor a redes especificas |
| depends_on | Espera a que los otros servicios esten creados |
| read_only: true | Filesystem de solo lectura |
| tmpfs: [/tmp, /run] | Directorios temporales en RAM (escribibles) |
| cap_drop: [ALL] | Elimina todas las capabilities de Linux |
| security_opt: [no-new-privileges:true] | Impide escalada de privilegios |
| internal: true (en networks) | Red sin acceso a internet |

---

## Cosas que NO se vieron en clase (hay que estudiar aparte)

| Concepto | Donde se usa | Explicacion |
|---|---|---|
| read_only: true | docker-compose.yml | Filesystem de solo lectura, protege contra escrituras no autorizadas |
| tmpfs | docker-compose.yml | Directorio temporal en RAM, necesario cuando el FS es read-only |
| cap_drop: ALL | docker-compose.yml | Elimina todas las Linux capabilities (permisos del kernel) |
| security_opt: no-new-privileges | docker-compose.yml | Previene escalada de privilegios dentro del contenedor |
| internal: true | docker-compose.yml (networks) | Red Docker sin acceso a internet |
| USER | Dockerfile | Define el usuario que ejecuta el proceso (no root) |
| Multi-stage build | Dockerfile (c-runner, ada-runner) | Compilar en una etapa, ejecutar en otra mas liviana |
| PermitRootLogin no | sshd_config | Bloquea acceso SSH como root |
| PasswordAuthentication no | sshd_config | Solo permite acceso con clave publica |
| cgroups v2 | panel.py | Sistema del kernel para metricas de recursos de contenedores |
| http.server | panel.py | Modulo de Python para crear un servidor web basico |
| threading | panel.py | Modulo de Python para ejecutar codigo en segundo plano |

---

## Preguntas probables del docente

**P: Por que elegiste Alpine para bash-runner y c-runner pero Debian para ada-runner?**
R: Alpine es la imagen mas liviana (~5 MB). La uso donde puedo. Para Ada, GNAT solo
esta en Debian y el binario compilado necesita libgnat (que usa glibc, no musl).

**P: Que es un multi-stage build y por que lo usas?**
R: Son Dockerfiles con varias etapas FROM. La primera tiene el compilador y compila.
La segunda es la imagen final, solo tiene el binario. El compilador no queda en la
imagen final, asi es mas chica y tiene menos superficie de ataque.

**P: Por que cap_drop ALL? Que pasa si un contenedor necesita alguna capability?**
R: cap_drop ALL elimina todos los permisos especiales del kernel. Si alguno fuera
necesario, se agrega con cap_add solo ese. En nuestro caso ningun runner necesita
capabilities especiales.

**P: Que pasa si pongo read_only sin tmpfs?**
R: sshd no podria escribir su PID file, ni crear archivos temporales. El contenedor
fallaria al iniciar. tmpfs da directorios temporales en RAM que son escribibles.

**P: Por que los runners no exponen puertos al host?**
R: Porque solo necesitan ser accesibles desde el manager, no desde afuera. La red
interna (internal: true) los aisla. Si un runner se compromete, no puede salir
a internet ni ser accedido directamente desde el host.

**P: Por que sshd corre en puerto 2222 y no en 22?**
R: Porque los puertos menores a 1024 son privilegiados y necesitan root. Como
el proceso corre como usuario non-root, usa un puerto alto.

**P: Como obtiene el panel web las metricas de los contenedores?**
R: El manager se conecta via SSH a cada runner y lee archivos de cgroups v2
(/sys/fs/cgroup/memory.current, cpu.stat). cgroups es el mecanismo del kernel
que Docker usa para aislar y medir recursos.

**P: Que es no-new-privileges?**
R: Impide que un proceso gane mas privilegios de los que empezo con. Por ejemplo,
si hay un binario con setuid en el contenedor, no podria escalar a root.

**P: Como funciona la autenticacion SSH?**
R: El manager tiene una clave privada (id_ed25519). Cada runner tiene la clave
publica correspondiente en authorized_keys. Al conectarse, SSH verifica que el
manager tiene la clave privada que corresponde a la publica. No se usan passwords.

**P: Que diferencia hay entre un contenedor y una maquina virtual?**
R: Un contenedor comparte el kernel del host y se aisla con namespaces y cgroups.
Es mas liviano y rapido de arrancar. Una VM tiene su propio kernel y sistema
operativo completo, mas pesada pero mas aislada.
