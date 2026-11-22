public class SnmpWalk {
    private final SnmpUtil util;

    public SnmpWalk(String host, int puerto, String comunidad, String version, String oid) {
        util = new SnmpUtil(host, puerto, comunidad, version, oid);
    }

    public void doWalk() {
        util.recorrer();
    }
}
