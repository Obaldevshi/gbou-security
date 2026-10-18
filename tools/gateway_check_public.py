"""Public TLS/Host isolation probes; no credentials or real school requests."""

import socket
import ssl


NAME = "school-2036.gbousecurity.ru"


def request(host, path="/", extra=""):
    with socket.create_connection(("127.0.0.1", 443), timeout=8) as raw:
        with ssl.create_default_context().wrap_socket(raw, server_hostname=NAME) as tls:
            tls.sendall(f"GET {path} HTTP/1.1\r\nHost: {host}\r\n{extra}Connection: close\r\n\r\n".encode())
            result = b""
            while True:
                chunk = tls.recv(4096)
                if not chunk:
                    break
                result += chunk
                if len(result) > 16384:
                    raise SystemExit("Unexpected large maintenance response")
            return result


def main():
    for host, path, extra, expected in (
        (NAME, "/", "", 503),
        (NAME, "/api/v1/users/", "", 503),
        ("gbousecurity.local", "/api/v1/users/", "", 404),
        ("192.168.1.85", "/api/v1/users/", "X-Forwarded-For: 192.168.1.22\r\n", 404),
    ):
        response = request(host, path, extra)
        status = response.split(b"\r\n", 1)[0]
        if f" {expected} ".encode() not in status:
            raise SystemExit(f"Unexpected isolation status: {status!r}")
        if host == NAME and b"cache-control: no-store" not in response.lower():
            raise SystemExit("Maintenance response must not be cached")
        if host == NAME and b"alt-svc:" in response.lower():
            raise SystemExit("Do not advertise HTTP/3 through the TCP-only gateway")
        print(f"Public TLS validated, Host {host}, {path}: {expected}")
    try:
        with socket.create_connection(("127.0.0.1", 443), timeout=8) as raw:
            with ssl.create_default_context().wrap_socket(raw, server_hostname="gbousecurity.local"):
                raise SystemExit("Unexpected SNI accepted by public proxy")
    except (ssl.SSLError, ConnectionResetError):
        print("Non-permitted public SNI rejected")


if __name__ == "__main__":
    main()
