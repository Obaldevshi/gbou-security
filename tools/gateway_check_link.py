"""Read-only gateway-side checks; no passwords, tokens or personal data."""

import socket
import ssl
import subprocess


def main():
    subprocess.run(["ping", "-c", "3", "-W", "3", "10.77.203.2"], check=True)
    for port in (80, 443, 22, 8081, 8765, 2019):
        opened = False
        try:
            with socket.create_connection(("10.77.203.2", port), timeout=1):
                opened = True
        except OSError:
            pass
        expected = port in (80, 443)
        print(f"Pi TCP {port}: {'open' if opened else 'blocked'}")
        if opened != expected:
            raise SystemExit("Unexpected tunnel firewall result")
    context = ssl.create_default_context(cafile="/root/gbou-school-root-ca.crt")
    with socket.create_connection(("10.77.203.2", 443), timeout=5) as raw:
        with context.wrap_socket(raw, server_hostname="gbousecurity.local") as tls:
            tls.sendall(b"GET /api/v1/users/ HTTP/1.1\r\nHost: gbousecurity.local\r\n"
                        b"Connection: close\r\n\r\n")
            status = tls.recv(1024).split(b"\r\n", 1)[0]
            if b" 404 " not in status:
                raise SystemExit("Gateway must not reach the LAN virtual host")
            print("Pi TLS hostname/CA verification passed; LAN vhost blocked from gateway = 404")


if __name__ == "__main__":
    main()
