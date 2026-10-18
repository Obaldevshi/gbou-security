"""Recover expired LAN TLS after a cold-boot NTP jump; never bypass TLS."""

from pathlib import Path
import socket
import ssl
import subprocess
import time


CA = "/var/lib/caddy/.local/share/caddy/pki/authorities/local/root.crt"
STAMP = Path("/run/gbou-tls-clock-guard-last-attempt")


def expired():
    context = ssl.create_default_context(cafile=CA)
    try:
        with socket.create_connection(("127.0.0.1", 443), timeout=5) as stream:
            with context.wrap_socket(stream, server_hostname="gbousecurity.local"):
                return False
    except ssl.SSLCertVerificationError as error:
        if error.verify_code == 10:  # X509_V_ERR_CERT_HAS_EXPIRED only
            return True
        raise


def main():
    synchronized = subprocess.check_output(
        ["timedatectl", "show", "-p", "NTPSynchronized", "--value"], text=True
    ).strip()
    if synchronized != "yes":
        return  # LAN/kiosk remain available even without NTP or internet.
    if not expired():
        return
    uptime = float(Path("/proc/uptime").read_text().split()[0])
    if STAMP.exists() and uptime - float(STAMP.read_text()) < 3600:
        raise SystemExit("Expired LAN TLS persists; automatic restart cooldown active")
    STAMP.write_text(str(uptime))
    STAMP.chmod(0o600)
    subprocess.run(["systemctl", "restart", "caddy"], check=True, timeout=30)
    for _ in range(5):
        time.sleep(1)
        try:
            if not expired():
                print("LAN TLS recovered after clock synchronization; certificate validation retained.")
                return
        except OSError:
            continue
    raise SystemExit("TLS still not valid after one bounded Caddy restart")


if __name__ == "__main__":
    main()
