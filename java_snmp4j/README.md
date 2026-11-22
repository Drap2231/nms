# NMS en Java

Programa de consola basado en las clases `MainSnmpWalk`, `SnmpWalk` y `SnmpUtil`. Realiza un recorrido SNMP WALK con peticiones GETNEXT usando SNMP4J. Solicita la dirección, el puerto UDP, la comunidad, la versión (`1` o `2c`) y el OID numérico.

## Requisitos

- JDK instalado (`java` y `javac`).
- Archivo `snmp4j-1.11.2.jar` en esta carpeta. Puedes usar el archivo entregado para la práctica o descargarlo desde [SNMP4J](https://snmp.app/dist/release/org/snmp4j/snmp4j/1.11.2/snmp4j-1.11.2.jar).
- Agente SNMP configurado y accesible. Debe permitir la comunidad y la versión ingresadas.

El código utiliza SNMP4J directamente y no requiere `log4j` para compilar. El Javadoc es opcional.

## Compilar y ejecutar en Linux

Desde esta carpeta:

```bash
javac -encoding UTF-8 -cp snmp4j-1.11.2.jar MainSnmpWalk.java SnmpWalk.java SnmpUtil.java
java -cp .:snmp4j-1.11.2.jar MainSnmpWalk
```

En Windows el separador del classpath es `;`:

```powershell
javac -encoding UTF-8 -cp snmp4j-1.11.2.jar MainSnmpWalk.java SnmpWalk.java SnmpUtil.java
java -cp ".;snmp4j-1.11.2.jar" MainSnmpWalk
```

## Prueba con un agente

Inicia el agente en el equipo que se va a consultar y verifica su IP, puerto y comunidad. Después ejecuta el programa e ingresa, por ejemplo:

```text
IP o nombre del agente: 192.168.1.10
Puerto UDP [161]:
Comunidad: public
Versión (1 o 2c): 2c
OID numérico inicial: 1.3.6.1.2.1.1
```

El puerto queda en 161 si presionas Enter. Cambia la IP y la comunidad por las de tu agente. El programa muestra los objetos encontrados debajo del OID, el número de consultas y el total de variables. Un WALK busca los objetos siguientes del árbol; para consultar una instancia exacta se necesita una petición GET.

Para comparar, si tienes Net-SNMP instalado en el equipo que consulta, puedes ejecutar el siguiente comando con los mismos datos:

```bash
snmpwalk -v 2c -c public 192.168.1.10 1.3.6.1.2.1.1
```

Comprueba que ambos muestran valores del mismo agente. Para la evidencia de la práctica, registra la configuración del agente y captura la consola con los parámetros y resultados de la prueba.

Si aparece `Sin respuesta del agente (timeout)`, revisa la dirección, la comunidad, la versión, el servicio del agente y el acceso al puerto UDP indicado. No significa necesariamente que la IP sea incorrecta. En SNMPv1 el agente puede responder `noSuchName` al llegar al final de los objetos accesibles.
