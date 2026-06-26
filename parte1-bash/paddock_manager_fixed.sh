#!/bin/bash

# paddock_manager_fixed.sh - V1.1 (Parcheado)
# Uso: ./paddock_manager_fixed.sh [accion] [parametros...]
#
# Cambios respecto a V1.0:
#   - Se agregan comillas dobles a TODAS las expansiones de variables
#     para evitar word splitting y globbing accidental.
#   - Se validan las variables vacias antes de operar, para evitar
#     borrados catastroficos o comportamientos inesperados.
#   - Se usan rutas seguras con comillas para evitar expansiones peligrosas.

# --- Lectura de argumentos ---
# Se encierran en comillas dobles para que Bash NO aplique word splitting.
# Sin comillas, un valor como "Gorra Edicion Especial" se partiria en
# 3 palabras separadas: "Gorra", "Edicion", "Especial".
ACCION="$1"
PARAMETRO="$2"

# --- Rutas de datos ---
ARCHIVO_CSV="inventario_f1.csv"
DIR_MERCADERIA="./mercaderia"

# --- Validacion de la accion ---
# [ -z "$ACCION" ] verifica si la variable esta vacia.
# Las comillas dobles alrededor de "$ACCION" son necesarias:
# sin ellas, si ACCION esta vacia, el comando quedaria como [ -z  ]
# lo cual puede dar resultados inesperados.
if [ -z "$ACCION" ]; then
    echo "Error: Debes especificar una accion (ingresar, buscar, vender, descatalogar)."
    exit 1
fi

case "$ACCION" in

    buscar)
        # --- PARCHE del Ticket #104 ---
        # BUG ORIGINAL (linea 21 del script legacy):
        #     grep $PARAMETRO $ARCHIVO_CSV
        #
        # Sin comillas, Bash aplica WORD SPLITTING a $PARAMETRO:
        # si el usuario escribio "Gorra Edicion Especial Monza",
        # Bash lo parte en 4 palabras y grep lo interpreta asi:
        #     grep Gorra Edicion Especial Monza inventario_f1.csv
        #          ^^^^^ ^^^^^^^ ^^^^^^^^ ^^^^^
        #          patron  archivo  archivo  archivo
        # Es decir, grep busca "Gorra" y trata "Edicion", "Especial" y
        # "Monza" como NOMBRES DE ARCHIVOS a leer. Como esos archivos no
        # existen, da error: "Edicion: No such file or directory".
        #
        # SOLUCION: encerrar "$PARAMETRO" entre comillas dobles.
        # Asi Bash lo trata como UNA SOLA cadena, sin importar los espacios.

        # Primero validamos que el usuario haya pasado algo para buscar
        if [ -z "$PARAMETRO" ]; then
            echo "Error: Debes especificar que producto buscar."
            echo "Uso: $0 buscar \"nombre del producto\""
            exit 1
        fi

        echo "Buscando '$PARAMETRO' en el inventario..."
        grep "$PARAMETRO" "$ARCHIVO_CSV"
        ;;

    descatalogar)
        # --- PARCHE del Ticket #105 ---
        # BUG ORIGINAL (linea 26 del script legacy):
        #     rm $DIR_MERCADERIA/$PARAMETRO*.txt
        #
        # Si el usuario NO pasa el nombre de la escuderia, $PARAMETRO
        # queda VACIO y el comando se expande a:
        #     rm ./mercaderia/*.txt
        #
        # Eso es GLOBBING: el shell expande el patron *.txt a TODOS los
        # archivos .txt que existan en ese directorio. Resultado: se borran
        # TODOS los manifiestos de TODAS las escuderias.
        #
        # Ademas, la falta de comillas en $DIR_MERCADERIA/$PARAMETRO*.txt
        # tambien es peligrosa: si el nombre tuviera espacios, se partiria
        # por word splitting, igual que en el ticket #104.
        #
        # SOLUCION:
        # 1. Validar que $PARAMETRO no este vacio ANTES de ejecutar rm.
        # 2. Encerrar la ruta completa entre comillas dobles para evitar
        #    word splitting y globbing accidental.
        #    Nota: el * debe quedar FUERA de las comillas para que el shell
        #    pueda expandirlo al nombre real del archivo, pero SOLO despues
        #    de que ya verificamos que $PARAMETRO tiene un valor seguro.

        # Validacion: si no se paso nombre de escuderia, NO hacer nada
        if [ -z "$PARAMETRO" ]; then
            echo "Error: Debes especificar el nombre de la escuderia a descatalogar."
            echo "Uso: $0 descatalogar NombreEscuderia"
            exit 1
        fi

        echo "Descatalogando productos y manifiestos de la escuderia: $PARAMETRO"

        # Usamos comillas en la parte que tiene variables, y dejamos el *
        # fuera para que el shell lo expanda solo sobre los archivos de ESA escuderia.
        # Ejemplo: si PARAMETRO=Ferrari, se expande a ./mercaderia/Ferrari*.txt
        # que matchea "Ferrari_manifiesto.txt" pero NO "McLaren_manifiesto.txt".
        rm "${DIR_MERCADERIA}/${PARAMETRO}"*.txt

        # Borrado del CSV: sed busca lineas que contengan $PARAMETRO y las borra.
        # Las comillas dobles dentro del patron de sed permiten que la variable
        # se expanda correctamente.
        sed -i "/$PARAMETRO/d" "$ARCHIVO_CSV"
        echo "Operacion finalizada."
        ;;

    ingresar)
        # Se valida que haya datos para ingresar
        if [ -z "$PARAMETRO" ]; then
            echo "Error: Debes especificar los datos del producto a ingresar."
            echo "Uso: $0 ingresar \"ID,Nombre,Escuderia,Stock,Precio\""
            exit 1
        fi

        echo "Ingresando nuevo producto..."
        # Comillas dobles en "$PARAMETRO" evitan que word splitting rompa
        # la linea CSV (por ejemplo si el nombre tiene espacios).
        echo "$PARAMETRO" >> "$ARCHIVO_CSV"
        echo "Producto ingresado."
        ;;

    vender)
        # Se valida que se pase un ID
        if [ -z "$PARAMETRO" ]; then
            echo "Error: Debes especificar el ID del producto a vender."
            echo "Uso: $0 vender ID"
            exit 1
        fi

        echo "Vendiendo 1 unidad del ID: $PARAMETRO"
        echo "Funcion en mantenimiento..."
        ;;

    *)
        echo "Accion no reconocida: '$ACCION'"
        echo "Acciones validas: ingresar, buscar, vender, descatalogar"
        exit 1
        ;;
esac
