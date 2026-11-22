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

while true; do
    echo
    echo "NMS EPN"
    echo "a) Tabla de MIB's"
    echo "b) Petición de MIB's"
    echo "c) Salida"
    if ! read -r -p "Opción: " opcion; then
        echo
        break
    fi
    case "$opcion" in
        a|A) tabla_mibs ;;
        b|B) peticion_mibs ;;
        c|C) echo "Saliendo."; break ;;
        *) echo "Opción no válida." ;;
    esac
done
