"""Render/validate a pending proxy config; never start a public listener."""

import argparse
from pathlib import Path
import re
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("hostname")
    args = parser.parse_args()
    hostname = args.hostname.lower()
    if not re.fullmatch(r"[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.gbousecurity\.ru", hostname):
        raise SystemExit("Expected one subdomain of gbousecurity.ru")
    source = Path("/root/gbou-haproxy.cfg.example").read_text()
    rendered = source.replace("__SCHOOL_FQDN__", hostname)
    if "__" in rendered:
        raise SystemExit("Unresolved configuration placeholder")
    target = Path("/etc/gbou-gateway/haproxy.pending.cfg")
    if target.exists() and target.read_text() != rendered:
        raise SystemExit("Pending config differs; not overwriting")
    if not target.exists():
        with target.open("x") as stream:
            stream.write(rendered)
        target.chmod(0o600)
    subprocess.run(["haproxy", "-c", "-f", str(target)], check=True)
    print("Pending proxy config validated; public proxy NOT installed or started.")


if __name__ == "__main__":
    main()
