# NMS

Script en Bash para consultar objetos MIB mediante SNMP en Linux.

## Requisitos

- Bash y las herramientas de Net-SNMP (`snmpget` y `snmptranslate`).
- Los archivos MIB que describen los objetos que se van a analizar. Deben estar instalados y ser reconocidos por Net-SNMP, junto con sus dependencias.
- Un agente SNMP accesible y configurado con la comunidad y la versión indicadas.

En AlmaLinux o Rocky Linux:

```bash
sudo dnf install net-snmp-utils
```

En Ubuntu o Debian:

```bash
sudo apt install snmp
```

La instalación de las definiciones MIB depende de la distribución. Si `snmptranslate` no reconoce un objeto, hay que instalar o agregar su archivo MIB y sus dependencias. Los OID numéricos permiten consultar el agente, pero para mostrar el tipo y los índices se necesita también la definición MIB.

## Ejecución

```bash
chmod +x nms.sh
./nms.sh comunidad version IP objeto [objeto ...]
```

La versión puede ser `1` o `2c`. Al menos se deben ingresar la comunidad, la versión, la dirección del agente y un objeto.

Para la consulta se deben ingresar **instancias completas**: los objetos escalares terminan en `.0`; las columnas de una tabla deben llevar el índice de la fila. Se pueden combinar ambas en una sola ejecución. Ejemplo para un agente en `192.168.1.10`, usando los nombres de las MIB estándar y la fila 1 de interfaces:

```bash
./nms.sh public 2c 192.168.1.10 SNMPv2-MIB::sysDescr.0 IF-MIB::ifDescr.1
```

También se pueden ingresar OID numéricos completos:

```bash
./nms.sh public 2c 192.168.1.10 .1.3.6.1.2.1.1.1.0 .1.3.6.1.2.1.2.2.1.2.1
```

La opción **a** muestra la definición, tipo, OID e índice de los objetos encontrados en las MIB locales. Para columnas de tabla se muestra la sintaxis del índice cuando está disponible; una restricción heredada de una convención textual puede requerir revisar su definición. La opción **b** envía las instancias indicadas juntas en una petición GET; no obtiene todas las filas de una tabla automáticamente. La opción **c** termina el programa.

El agente debe permitir el acceso a los objetos y la fila indicada debe existir. Si no responde, comprueba la IP, la conectividad, el puerto UDP 161, la versión y la comunidad. En SNMPv1, un objeto inexistente puede hacer fallar toda la petición.

## Opciones adicionales

El archivo `nms.sh` incluye estas opciones después de las tres de la práctica:

| Opción | Función |
| --- | --- |
| d | Recorrer un nodo con `snmpwalk`. |
| e | Consultar una tabla completa con `snmptable`. |
| f | Consultar el objeto siguiente con `snmpgetnext`. |
| g | Usar `snmpbulkget` o `snmpbulkwalk` con la versión 2c. |
| h | Cambiar un objeto con `snmpset`. |
| i | Guardar en un archivo de texto el resultado de consultar los objetos iniciales. |
| j | Consultar nombre, descripción, ubicación y tiempo de funcionamiento. |
| k | Consultar la tabla de interfaces, con su estado y contadores. |
| l | Comprobar si el equipo responde a `ping`. |
| m | Cambiar la comunidad, la versión y el host durante la ejecución. |

Las opciones adicionales comprueban cuando necesitan un comando distinto. `snmptable` y las consultas por nombre necesitan las MIB correspondientes instaladas. GETBULK busca los objetos siguientes a los OID indicados; recorrer una rama puede necesitar varias peticiones.

La opción h **modifica datos del equipo**. El OID debe ser escribible y la comunidad debe tener permiso de escritura. Para un texto se usa el tipo `s`, por ejemplo `SNMPv2-MIB::sysLocation.0`. La opción i no sobrescribe un archivo existente. Si falla la consulta puede quedar un archivo vacío o incompleto. La opción l usa ICMP: que un equipo no responda al ping no demuestra que SNMP esté deshabilitado. Al cambiar los parámetros con m se mantienen los objetos originales.

## Quitar opciones

Cada opción adicional tiene una letra. Para quitar, por ejemplo, la opción d:

1. Borra el bloque de código desde `# OPCIÓN EXTRA D` hasta `# FIN D`.
2. Borra la línea que muestra la opción en el menú, marcada con `# EXTRA D`.
3. Borra la línea correspondiente del `case`, también marcada con `# EXTRA D`.

Para quedarte únicamente con lo solicitado en la práctica, usa `nms_basico.sh`, que conserva el menú con las opciones a, b y c:

```bash
chmod +x nms_basico.sh
./nms_basico.sh public 2c 192.168.1.10 SNMPv2-MIB::sysDescr.0
```
