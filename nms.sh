#!/usr/bin/env bash

if [ "$#" -lt 4 ]; then
    echo "SE REQUIEREN AL MENOS CUATRO ARGUMENTOS"
    echo "Uso: $0 comunidad version IP objeto [objeto ...]"
    exit 1
fi

comunidad=$1
version=$2
host=$3
shift 3
objetos=("$@")

if [[ "$version" != "1" && "$version" != "2c" ]]; then
    echo "La versión debe ser 1 o 2c."
    exit 1
fi

for comando in snmptranslate snmpget; do
    if ! command -v "$comando" >/dev/null 2>&1; then
        echo "Falta instalar $comando (paquete Net-SNMP)."
        exit 1
    fi
done

# Se usan las MIB instaladas para consultar la definición de cada objeto.
tabla_mibs() {
    local objeto oid detalle primera nombre modulo base padre entrada indice tipo rango definicion

    for objeto in "${objetos[@]}"; do
        echo
        echo "Objeto: $objeto"
        oid=$(snmptranslate -m ALL -IR -On "$objeto" 2>/dev/null) || {
            echo "No se encontró el objeto en las MIB instaladas."
            continue
        }
        detalle=$(snmptranslate -m ALL -IR -OS -Td "$objeto" 2>/dev/null) || {
            echo "No se pudo obtener la definición de la MIB."
            continue
        }
        if ! printf '%s\n' "$detalle" | grep -q 'OBJECT-TYPE'; then
            echo "No se encontró la definición OBJECT-TYPE en las MIB instaladas."
            echo "OID: $oid"
            continue
        fi

        primera=$(printf '%s\n' "$detalle" | head -n 1)
        nombre=${primera%%.*}
        modulo=${nombre%%::*}
        base=$(snmptranslate -m ALL -IR -On "$nombre" 2>/dev/null)
        if [[ ! "$base" =~ ^\.[0-9]+(\.[0-9]+)+$ ]]; then
            echo "No se pudo identificar el OID de la definición."
            continue
        fi
        tipo=$(printf '%s\n' "$detalle" | sed -n 's/^[[:space:]]*SYNTAX[[:space:]]\{1,\}//p' | head -n 1)
        padre=${base%.*}
        entrada=$(snmptranslate -m ALL -Td "$padre" 2>/dev/null)
        indice=$(printf '%s\n' "$entrada" | awk '
            /INDEX(ES)?[[:space:]]*\{/ {en_indice=1}
            en_indice {texto=texto " " $0}
            en_indice && /}/ {gsub(/.*INDEX(ES)?[[:space:]]*\{[[:space:]]*/, "", texto); gsub(/[[:space:]]*\}.*/, "", texto); print texto; exit}
        ')

        echo "Tipo de dato: ${tipo:-No disponible}"
        echo "OID numérico del objeto: $base"
        if [ "$oid" != "$base" ]; then
            echo "OID numérico solicitado: $oid"
        fi

        if [ -n "$indice" ]; then
            echo "Escalar: No"
            echo "Índice de la tabla: $indice"
            # Algunas tablas tienen varios índices o índices de tipo cadena.
            IFS=',' read -r -a indices <<< "$indice"
            for nombre in "${indices[@]}"; do
                nombre=$(printf '%s' "$nombre" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//; s/^IMPLIED[[:space:]]*//')
                definicion=$(snmptranslate -m ALL -Td "$modulo::$nombre" 2>/dev/null)
                if [ -z "$definicion" ]; then
                    definicion=$(snmptranslate -m ALL -IR -Td "$nombre" 2>/dev/null)
                fi
                rango=$(printf '%s\n' "$definicion" | sed -n 's/^[[:space:]]*SYNTAX[[:space:]]\{1,\}//p' | head -n 1)
                echo "Tipo o rango de $nombre: ${rango:-No disponible en las MIB instaladas}"
            done
        elif printf '%s\n' "$entrada" | grep -q 'AUGMENTS'; then
            echo "Escalar: No"
            echo "Índice: definido por la tabla indicada en AUGMENTS."
        elif [ -z "$entrada" ] || printf '%s\n' "$entrada" | grep -q 'OBJECT-TYPE'; then
            echo "Escalar: No se pudo determinar con las MIB instaladas."
            echo "Índice: No disponible."
        else
            echo "Escalar: Sí"
            echo "Índice: 0 (instancia escalar)"
        fi
    done
}

peticion_mibs() {
    echo
    echo "Se consultan las instancias ingresadas en una petición SNMP GET."
    echo "Los escalares terminan en .0; las columnas llevan el índice de la fila."
    # -Cf evita reintentos automáticos al recibir errores de una variable en SNMPv1.
    # -r 0 evita retransmisiones cuando no responde el agente.
    snmpget -m ALL -IR -Cf -r 0 -v "$version" -c "$comunidad" "$host" "${objetos[@]}"
}

# OPCIÓN EXTRA D: recorrer un nodo con SNMPWALK. Borrar hasta FIN D si no se usa.
recorrer_nodo() {
    local nodo
    if ! command -v snmpwalk >/dev/null 2>&1; then
        echo "Falta instalar snmpwalk."
        return
    fi
    read -r -p "Nodo a recorrer (ejemplo IF-MIB::ifTable): " nodo || return
    [ -n "$nodo" ] || { echo "Debe ingresar un nodo."; return; }
    snmpwalk -m ALL -IR -v "$version" -c "$comunidad" "$host" "$nodo"
}
# FIN D

# OPCIÓN EXTRA E: consultar una tabla con SNMPTABLE.
consultar_tabla() {
    local tabla
    if ! command -v snmptable >/dev/null 2>&1; then
        echo "Falta instalar snmptable."
        return
    fi
    read -r -p "Tabla (ejemplo IF-MIB::ifTable): " tabla || return
    [ -n "$tabla" ] || { echo "Debe ingresar una tabla."; return; }
    snmptable -m ALL -IR -Ci -v "$version" -c "$comunidad" "$host" "$tabla"
}
# FIN E

# OPCIÓN EXTRA F: consultar el siguiente objeto con SNMPGETNEXT.
consultar_siguiente() {
    local nodo
    if ! command -v snmpgetnext >/dev/null 2>&1; then
        echo "Falta instalar snmpgetnext."
        return
    fi
    read -r -p "OID desde el que se buscará el siguiente: " nodo || return
    [ -n "$nodo" ] || { echo "Debe ingresar un OID."; return; }
    snmpgetnext -m ALL -IR -v "$version" -c "$comunidad" "$host" "$nodo"
}
# FIN F

# OPCIÓN EXTRA G: usar GETBULK o recorrer una rama con GETBULK (solo 2c).
consulta_bulk() {
    local modo linea
    local -a nodos_bulk
    if [ "$version" != "2c" ]; then
        echo "GETBULK necesita la versión 2c."
        return
    fi
    echo "1) Una petición GETBULK"
    echo "2) Recorrer una rama con GETBULK"
    read -r -p "Seleccione 1 o 2: " modo || return
    case "$modo" in
        1)
            if ! command -v snmpbulkget >/dev/null 2>&1; then
                echo "Falta instalar snmpbulkget."
                return
            fi
            read -r -p "OID iniciales separados por espacios: " linea || return
            read -r -a nodos_bulk <<< "$linea"
            [ "${#nodos_bulk[@]}" -gt 0 ] || { echo "Debe ingresar al menos un OID."; return; }
            echo "GETBULK devuelve los objetos siguientes a los OID ingresados."
            snmpbulkget -m ALL -IR -r 0 -Cn0 -Cr10 -v 2c -c "$comunidad" "$host" "${nodos_bulk[@]}"
            ;;
        2)
            if ! command -v snmpbulkwalk >/dev/null 2>&1; then
                echo "Falta instalar snmpbulkwalk."
                return
            fi
            read -r -p "Nodo a recorrer: " linea || return
            [ -n "$linea" ] || { echo "Debe ingresar un nodo."; return; }
            snmpbulkwalk -m ALL -IR -v 2c -c "$comunidad" "$host" "$linea"
            ;;
        *) echo "Opción no válida." ;;
    esac
}
# FIN G

# OPCIÓN EXTRA H: modificar un objeto mediante SNMPSET.
modificar_objeto() {
    local objeto tipo valor
    if ! command -v snmpset >/dev/null 2>&1; then
        echo "Falta instalar snmpset."
        return
    fi
    echo "El objeto debe permitir escritura y la comunidad debe tener ese permiso."
    read -r -p "OID completo (ejemplo SNMPv2-MIB::sysLocation.0): " objeto || return
    read -r -p "Tipo (s: texto, i: entero, u: entero sin signo, o: OID): " tipo || return
    read -r -p "Nuevo valor: " valor || return
    if [ -z "$objeto" ] || [ -z "$valor" ]; then
        echo "Debe ingresar un OID y un valor."
        return
    fi
    case "$tipo" in
        s|i|u|o) ;;
        *) echo "Tipo no válido."; return ;;
    esac
    snmpset -m ALL -IR -v "$version" -c "$comunidad" "$host" "$objeto" "$tipo" "$valor"
}
# FIN H

# OPCIÓN EXTRA I: guardar en un archivo la consulta de los argumentos iniciales.
guardar_resultados() {
    local archivo estado
    read -r -p "Nombre del archivo de texto: " archivo || return
    [ -n "$archivo" ] || { echo "Debe ingresar un nombre de archivo."; return; }
    # noclobber evita sobrescribir un archivo que ya exista.
    (set -o noclobber; snmpget -m ALL -IR -Cf -r 0 -v "$version" -c "$comunidad" "$host" "${objetos[@]}" > "$archivo")
    estado=$?
    if [ "$estado" -eq 0 ]; then
        echo "Resultados guardados en $archivo."
    else
        echo "No se guardaron resultados completos. Revise el error y el archivo."
    fi
}
# FIN I

# OPCIÓN EXTRA J: consultar información general con una sola petición GET.
informacion_general() {
    echo "Nombre, descripción, ubicación y tiempo de funcionamiento:"
    snmpget -m ALL -Cf -r 0 -v "$version" -c "$comunidad" "$host" \
        .1.3.6.1.2.1.1.5.0 .1.3.6.1.2.1.1.1.0 \
        .1.3.6.1.2.1.1.6.0 .1.3.6.1.2.1.1.3.0
}
# FIN J

# OPCIÓN EXTRA K: mostrar la tabla de interfaces, incluido su estado y contadores.
estado_interfaces() {
    if ! command -v snmptable >/dev/null 2>&1; then
        echo "Falta instalar snmptable."
        return
    fi
    snmptable -m ALL -IR -Ci -v "$version" -c "$comunidad" "$host" IF-MIB::ifTable
}
# FIN K

# OPCIÓN EXTRA L: comprobar conectividad ICMP con PING.
comprobar_conectividad() {
    if ! command -v ping >/dev/null 2>&1; then
        echo "Falta instalar ping."
        return
    fi
    if ping -c 1 -W 2 "$host"; then
        echo "El equipo respondió al ping."
    else
        echo "El equipo no respondió al ping; esto no confirma si SNMP funciona."
    fi
}
# FIN L

# OPCIÓN EXTRA M: cambiar los parámetros sin salir del script.
cambiar_parametros() {
    local nueva_comunidad nueva_version nuevo_host
    read -r -p "Nueva comunidad: " nueva_comunidad || return
    read -r -p "Nueva versión (1 o 2c): " nueva_version || return
    read -r -p "Nueva IP o nombre del host: " nuevo_host || return
    if [ -z "$nueva_comunidad" ] || [ -z "$nuevo_host" ]; then
        echo "La comunidad y el host no pueden estar vacíos. No se hicieron cambios."
        return
    fi
    if [[ "$nueva_version" != "1" && "$nueva_version" != "2c" ]]; then
        echo "Versión no válida. No se hicieron cambios."
        return
    fi
    comunidad=$nueva_comunidad
    version=$nueva_version
    host=$nuevo_host
    echo "Parámetros actualizados. Los objetos iniciales se mantienen."
}
# FIN M

while true; do
    echo
    echo "NMS EPN"
    echo "a) Tabla de MIB's"
    echo "b) Petición de MIB's"
    echo "c) Salida"
    # OPCIONES EXTRA: borra la línea de cada opción que no necesites.
    echo "d) Recorrer un nodo"                # EXTRA D
    echo "e) Consultar una tabla completa"      # EXTRA E
    echo "f) Consultar el siguiente objeto"     # EXTRA F
    echo "g) Consulta GETBULK"                  # EXTRA G
    echo "h) Modificar un objeto"               # EXTRA H
    echo "i) Guardar resultados en un archivo"  # EXTRA I
    echo "j) Información general del equipo"    # EXTRA J
    echo "k) Estado de las interfaces"          # EXTRA K
    echo "l) Comprobar conectividad"            # EXTRA L
    echo "m) Cambiar parámetros"                # EXTRA M
    if ! read -r -p "Opción: " opcion; then
        echo
        break
    fi
    case "$opcion" in
        a|A) tabla_mibs ;;
        b|B) peticion_mibs ;;
        c|C) echo "Saliendo."; break ;;
        d|D) recorrer_nodo ;;           # EXTRA D
        e|E) consultar_tabla ;;          # EXTRA E
        f|F) consultar_siguiente ;;      # EXTRA F
        g|G) consulta_bulk ;;            # EXTRA G
        h|H) modificar_objeto ;;         # EXTRA H
        i|I) guardar_resultados ;;       # EXTRA I
        j|J) informacion_general ;;      # EXTRA J
        k|K) estado_interfaces ;;        # EXTRA K
        l|L) comprobar_conectividad ;;   # EXTRA L
        m|M) cambiar_parametros ;;       # EXTRA M
        *) echo "Opción no válida." ;;
    esac
done
