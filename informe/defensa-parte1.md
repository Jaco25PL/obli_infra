# Parte 1 - Bash - Notas de Defensa

## Que hace el programa

`paddock_manager.sh` es un script de Bash que gestiona el inventario de mercaderia de un
equipo de Formula 1. Permite buscar productos en un archivo CSV, ingresar nuevos productos,
descatalogar una escuderia (borrando sus manifiestos y lineas del CSV) y vender unidades.
Los datos se almacenan en `inventario_f1.csv` y los manifiestos de envio en `./mercaderia/`.

---

## Informe de Autopsia - Diagnostico tecnico de los incidentes

### Ticket #104: Fallo en Consultas

**Linea exacta del fallo:** linea 21 del script original:
```bash
grep $PARAMETRO $ARCHIVO_CSV
```

**Que hizo el usuario:**
```bash
./paddock_manager.sh buscar "Gorra Edicion Especial Monza"
```

**Que paso por dentro - Word Splitting:**

Cuando Bash encuentra una variable **sin comillas dobles**, aplica un mecanismo llamado
**word splitting** (separacion por palabras). Esto significa que Bash toma el contenido de
la variable y lo parte en palabras separadas usando los espacios como separador.

El usuario paso `"Gorra Edicion Especial Monza"` como segundo argumento. Las comillas del
usuario hacen que el shell lo reciba como UN solo argumento en `$2`, asi que `PARAMETRO`
contiene la cadena completa `Gorra Edicion Especial Monza`.

Pero en la linea 21, `$PARAMETRO` aparece **sin comillas**:
```bash
grep $PARAMETRO $ARCHIVO_CSV
```

Al no tener comillas, Bash aplica word splitting y parte la cadena en 4 palabras separadas.
El comando que realmente se ejecuta es:
```bash
grep Gorra Edicion Especial Monza inventario_f1.csv
```

Para `grep`, el primer argumento es el patron a buscar (`Gorra`) y **todos los demas
argumentos son nombres de archivos** donde buscar. Asi que grep intenta abrir los archivos
`Edicion`, `Especial`, `Monza` e `inventario_f1.csv`. Como los archivos `Edicion`,
`Especial` y `Monza` no existen, da el error:
```
grep: Edicion: No such file or directory
grep: Especial: No such file or directory
grep: Monza: No such file or directory
```

**Solucion aplicada:**
```bash
grep "$PARAMETRO" "$ARCHIVO_CSV"
```
Con comillas dobles, Bash trata `"$PARAMETRO"` como una sola cadena, sin importar cuantos
espacios tenga adentro. `grep` recibe un solo patron: `Gorra Edicion Especial Monza`.

---

### Ticket #105: Perdida de Datos Catastrofica

**Linea exacta del fallo:** linea 26 del script original:
```bash
rm $DIR_MERCADERIA/$PARAMETRO*.txt
```

**Que hizo el usuario:**
```bash
./paddock_manager.sh descatalogar
```
(sin poner el nombre de la escuderia)

**Que paso por dentro - Variable vacia + Globbing:**

Al no pasar segundo argumento, `$PARAMETRO` queda **vacio** (cadena de largo cero). Veamos
como se expande la linea paso a paso:

1. **Expansion de variables:** Bash reemplaza `$DIR_MERCADERIA` por `./mercaderia` y
   `$PARAMETRO` por nada (vacio). La linea queda:
   ```bash
   rm ./mercaderia/*.txt
   ```

2. **Globbing (expansion de comodines):** Bash ve el patron `*.txt` y lo expande a
   **todos los archivos que terminen en .txt** en ese directorio. Si hay 3 manifiestos,
   el comando que realmente se ejecuta es:
   ```bash
   rm ./mercaderia/Ferrari_manifiesto.txt ./mercaderia/McLaren_manifiesto.txt ./mercaderia/RedBull_manifiesto.txt
   ```

3. **Resultado:** se borran TODOS los manifiestos de TODAS las escuderias. El pasante
   no queria esto, solo olvido poner el nombre.

**Por que falta de validacion + globbing = catastrofe?**

El script original **no valida** que `$PARAMETRO` tenga un valor antes de ejecutar `rm`.
Si la variable esta vacia, el `*` queda "suelto" y matchea contra todo. Es el equivalente
a pedirle a alguien "borrame los archivos de [nadie en particular]" y que borre todo.

**Solucion aplicada (dos capas de proteccion):**

1. **Validacion de variable vacia** antes de ejecutar cualquier cosa:
   ```bash
   if [ -z "$PARAMETRO" ]; then
       echo "Error: Debes especificar el nombre de la escuderia a descatalogar."
       exit 1
   fi
   ```
   `[ -z "$PARAMETRO" ]` devuelve verdadero si la cadena tiene largo cero (esta vacia).
   Asi el script frena antes de llegar al `rm`.

2. **Comillas dobles en la ruta** (proteccion contra word splitting):
   ```bash
   rm "${DIR_MERCADERIA}/${PARAMETRO}"*.txt
   ```
   Las llaves `{}` delimitan donde empieza y termina cada variable. Las comillas protegen
   la parte de variables contra word splitting. El `*` queda fuera de las comillas para
   que el shell pueda expandirlo, pero solo despues de que `$PARAMETRO` ya tiene un valor
   seguro (por ejemplo, `Ferrari`), asi que expande solo a `Ferrari*.txt`.

---

## Resumen de conceptos clave (para la defensa)

| Concepto | Que es | Donde aparecio |
|---|---|---|
| **Word Splitting** | Bash parte las variables sin comillas en palabras separadas usando espacios como separador | Ticket #104: `grep $PARAMETRO` partio "Gorra Edicion Especial Monza" en 4 palabras |
| **Globbing** | Bash expande comodines (`*`, `?`) a nombres de archivos que coincidan con el patron | Ticket #105: `*.txt` se expandio a todos los .txt del directorio |
| **Expansion de variables** | Bash reemplaza `$VARIABLE` por su valor antes de ejecutar el comando | En ambos tickets: `$PARAMETRO` se reemplazo (por la cadena o por vacio) |
| **Quoting (comillas dobles)** | Encerrar `"$VARIABLE"` entre comillas dobles impide word splitting y globbing | Solucion en ambos tickets |
| **Validacion con `[ -z ]`** | `[ -z "$VAR" ]` verifica si una variable esta vacia (largo cero) | Solucion del #105: frenar si no se paso escuderia |

---

## Comandos y sentencias no triviales del script

| Comando/Sentencia | Que hace |
|---|---|
| `#!/bin/bash` | **Shebang**: le dice al sistema operativo que use `/bin/bash` para interpretar este script |
| `$1`, `$2` | Parametros posicionales: `$1` es el primer argumento que el usuario pasa al script, `$2` el segundo |
| `[ -z "$VAR" ]` | Test de cadena vacia: devuelve verdadero si `$VAR` tiene largo cero |
| `case ... esac` | Estructura de seleccion multiple (como un switch): compara un valor contra varios patrones |
| `grep "patron" archivo` | Busca lineas en un archivo que contengan el patron dado e imprime las que matchean |
| `rm archivo` | Borra (remove) un archivo del disco. No hay papelera, es irreversible |
| `sed -i "/patron/d" archivo` | **s**tream **ed**itor. `-i` edita el archivo en sitio. `/patron/d` borra las lineas que contengan ese patron |
| `echo "texto" >> archivo` | Agrega (`>>`) una linea al final del archivo. Con `>` sobreescribiria todo |
| `exit 1` | Termina el script con codigo de salida 1 (error). `exit 0` seria exito |
| `"${VAR}"` | Llaves para delimitar el nombre de la variable dentro de una cadena mas larga |
| `*` (en rutas) | Comodin (glob): matchea cualquier secuencia de caracteres en nombres de archivos |

---

## Preguntas probables del docente

**P: Que es word splitting?**
R: Es un mecanismo de Bash que toma el contenido de una variable sin comillas y lo separa
en palabras usando los espacios (y tabs y saltos de linea) como separadores. Cada palabra
se convierte en un argumento separado para el comando.

**P: Que es globbing?**
R: Es la expansion de comodines (`*`, `?`, `[...]`) que Bash hace automaticamente.
Reemplaza el patron por los nombres de archivos que coincidan. Si no hay ningun match,
deja el patron tal cual (en la config por defecto).

**P: Por que las comillas dobles solucionan el ticket #104?**
R: Porque las comillas dobles impiden que Bash aplique word splitting y globbing al
contenido de la variable. `"$PARAMETRO"` se pasa como un solo argumento a grep, sin
importar cuantos espacios tenga.

**P: Que pasaria si el directorio mercaderia estuviera vacio y se ejecuta `rm ./mercaderia/*.txt`?**
R: Si no hay archivos .txt, el glob `*.txt` no matchea nada. En la configuracion por
defecto de Bash, el patron queda literal y `rm` intenta borrar un archivo llamado
literalmente `*.txt`, que no existe, y da error. No se borraria nada, pero el error
es confuso.

**P: Por que `[ -z "$PARAMETRO" ]` lleva comillas?**
R: Sin comillas, si `$PARAMETRO` esta vacio, el comando quedaria como `[ -z ]` (con un
solo argumento para el test), lo cual puede dar resultados inesperados. Con comillas
queda `[ -z "" ]`, que se evalua correctamente como verdadero.

**P: Cual es la diferencia entre `>>` y `>` en la linea del `echo`?**
R: `>>` agrega al final del archivo (append). `>` sobreescribe el archivo completo,
perdiendo todo su contenido anterior.

**P: Que hace `sed -i "/patron/d"` paso a paso?**
R: `sed` es un editor de flujo (stream editor). `-i` le dice que modifique el archivo
directamente (in-place). El comando `/patron/d` busca todas las lineas que contengan
"patron" y las borra (`d` = delete). El resultado es que el archivo queda sin esas lineas.

**P: Hay algo en el script que no se viera en clase?**
R: No. Todo el script usa conceptos basicos de Bash: variables, quoting, condicionales
con `[ ]`, `case`, `grep`, `sed`, `rm`, `echo`. Son las herramientas estandar del shell.

---

## Que cosas del codigo NO se vieron en clase

Todo el contenido del script arreglado usa unicamente conceptos y comandos cubiertos en
el material de Bash: word splitting, globbing, expansion de variables, quoting con
comillas dobles, validacion con `[ -z ]`, y los comandos `grep`, `sed`, `rm`, `echo`.
No hay nada que requiera estudio adicional fuera de clase.
