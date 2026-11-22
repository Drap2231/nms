import java.util.Scanner;
import java.util.NoSuchElementException;

public class MainSnmpWalk {
    public static void main(String[] args) {
        Scanner teclado = new Scanner(System.in);

        try {
            System.out.println("Consulta SNMP WALK");

            String host;
            do {
                System.out.print("IP o nombre del agente: ");
                host = teclado.nextLine().trim();
                if (host.isEmpty()) {
                    System.out.println("Ingrese una dirección.");
                }
            } while (host.isEmpty());

            int puerto = 0;
            while (puerto == 0) {
                System.out.print("Puerto UDP [161]: ");
                String entrada = teclado.nextLine().trim();
                if (entrada.isEmpty()) {
                    puerto = 161;
                } else {
                    try {
                        int numero = Integer.parseInt(entrada);
                        if (numero >= 1 && numero <= 65535) {
                            puerto = numero;
                        } else {
                            System.out.println("El puerto debe estar entre 1 y 65535.");
                        }
                    } catch (NumberFormatException e) {
                        System.out.println("Ingrese un número de puerto válido.");
                    }
                }
            }

            String comunidad;
            do {
                System.out.print("Comunidad: ");
                comunidad = teclado.nextLine().trim();
                if (comunidad.isEmpty()) {
                    System.out.println("Ingrese una comunidad.");
                }
            } while (comunidad.isEmpty());

            String version;
            do {
                System.out.print("Versión (1 o 2c): ");
                version = teclado.nextLine().trim().toLowerCase();
                if (!version.equals("1") && !version.equals("2c")) {
                    System.out.println("La versión debe ser 1 o 2c.");
                }
            } while (!version.equals("1") && !version.equals("2c"));

            String oid;
            do {
                System.out.print("OID numérico inicial (ejemplo 1.3.6.1.2.1.1): ");
                oid = teclado.nextLine().trim();
                if (!oid.matches("\\.?[0-9]+(\\.[0-9]+)+")) {
                    System.out.println("Ingrese un OID numérico válido.");
                }
            } while (!oid.matches("\\.?[0-9]+(\\.[0-9]+)+"));
            if (oid.startsWith(".")) {
                oid = oid.substring(1);
            }

            SnmpWalk walk = new SnmpWalk(host, puerto, comunidad, version, oid);
            walk.doWalk();
        } catch (NoSuchElementException e) {
            System.out.println("Entrada finalizada.");
        } finally {
            teclado.close();
        }
    }
}
