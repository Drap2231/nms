import java.io.IOException;
import org.snmp4j.CommunityTarget;
import org.snmp4j.PDU;
import org.snmp4j.Snmp;
import org.snmp4j.event.ResponseEvent;
import org.snmp4j.mp.SnmpConstants;
import org.snmp4j.smi.Null;
import org.snmp4j.smi.OID;
import org.snmp4j.smi.OctetString;
import org.snmp4j.smi.UdpAddress;
import org.snmp4j.smi.VariableBinding;
import org.snmp4j.transport.DefaultUdpTransportMapping;

public class SnmpUtil {
    private final String host;
    private final int puerto;
    private final String comunidad;
    private final String version;
    private final String oidInicial;

    public SnmpUtil(String host, int puerto, String comunidad, String version, String oidInicial) {
        this.host = host;
        this.puerto = puerto;
        this.comunidad = comunidad;
        this.version = version;
        this.oidInicial = oidInicial;
    }

    public void recorrer() {
        Snmp snmp = null;
        int consultas = 0;
        int variables = 0;
        try {
            OID raiz = new OID(oidInicial);
            OID actual = raiz;
            UdpAddress direccion = new UdpAddress(host + "/" + puerto);
            if (!direccion.isValid()) {
                System.out.println("Dirección del agente no válida.");
                return;
            }

            CommunityTarget destino = new CommunityTarget();
            destino.setCommunity(new OctetString(comunidad));
            destino.setAddress(direccion);
            destino.setVersion(version.equals("1") ? SnmpConstants.version1 : SnmpConstants.version2c);
            destino.setRetries(1);
            destino.setTimeout(1500);

            snmp = new Snmp(new DefaultUdpTransportMapping());
            snmp.listen();
            System.out.println("Iniciando consulta SNMP " + version + "...");

            while (true) {
                PDU peticion = new PDU();
                peticion.setType(PDU.GETNEXT);
                peticion.add(new VariableBinding(actual));
                consultas++;
                ResponseEvent evento = snmp.send(peticion, destino);
                PDU respuesta = evento == null ? null : evento.getResponse();

                if (respuesta == null) {
                    System.out.println("ERROR: Sin respuesta del agente (timeout).");
                    break;
                }
                if (respuesta.getErrorStatus() != PDU.noError) {
                    if (version.equals("1") && respuesta.getErrorStatus() == PDU.noSuchName) {
                        System.out.println("Fin del recorrido.");
                    } else {
                        System.out.println("Error del agente: " + respuesta.getErrorStatusText());
                    }
                    break;
                }
                if (respuesta.size() == 0) {
                    System.out.println("El agente devolvió una respuesta vacía.");
                    break;
                }

                VariableBinding variable = respuesta.get(0);
                OID siguiente = variable.getOid();
                if (siguiente == null || Null.isExceptionSyntax(variable.getVariable().getSyntax())
                        || siguiente.size() < raiz.size()
                        || raiz.leftMostCompare(raiz.size(), siguiente) != 0) {
                    System.out.println("Fin del recorrido.");
                    break;
                }
                if (siguiente.compareTo(actual) <= 0) {
                    System.out.println("El agente devolvió un OID que no avanza. Se detuvo el recorrido.");
                    break;
                }
                System.out.println(variable);
                variables++;
                actual = siguiente;
            }
        } catch (IOException e) {
            System.out.println("Error de comunicación: " + e.getMessage());
        } catch (IllegalArgumentException e) {
            System.out.println("Dirección u OID no válido: " + e.getMessage());
        } finally {
            if (snmp != null) {
                try {
                    snmp.close();
                } catch (IOException e) {
                    System.out.println("No se pudo cerrar la conexión: " + e.getMessage());
                }
            }
            System.out.println("Consultas realizadas: " + consultas);
            System.out.println("Variables obtenidas: " + variables);
        }
    }
}
