"""Enroll exactly one Pi peer; no private key is transferred or printed."""

import argparse
import base64
import os
from pathlib import Path
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("pi_public_key")
    args = parser.parse_args()
    if os.geteuid() != 0:
        raise SystemExit("Root required")
    if len(base64.b64decode(args.pi_public_key, validate=True)) != 32:
        raise SystemExit("Invalid peer public key")
    current_public = subprocess.check_output(
        ["wg", "show", "gbou-wg", "public-key"], text=True
    ).strip()
    if current_public != "6vDXe0tM3QviLmMfdQ2sepFt6KKQL3kv4JJUUGIHOk0=":
        raise SystemExit("Not the prepared gateway")
    config = Path("/etc/wireguard/gbou-wg.conf")
    old = config.read_text()
    if "[Peer]" in old:
        raise SystemExit("A peer already exists; inspect rather than overwriting")
    backup = config.with_name("gbou-wg.conf.before-peer")
    with open(backup, "x", opener=lambda p, flags: os.open(p, flags, 0o600)) as stream:
        stream.write(old)
    candidate = config.with_name("gbou-wg.conf.next")
    with open(candidate, "x", opener=lambda p, flags: os.open(p, flags, 0o600)) as stream:
        stream.write(old + "\n[Peer]\nPublicKey = " + args.pi_public_key
                     + "\nAllowedIPs = 10.77.203.2/32\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(candidate, config)
    subprocess.run(["wg", "set", "gbou-wg", "peer", args.pi_public_key,
                    "allowed-ips", "10.77.203.2/32"], check=True)
    subprocess.run(["ip", "route", "replace", "10.77.203.2/32", "dev", "gbou-wg"], check=True)
    dropin = Path("/etc/systemd/system/wg-quick@gbou-wg.service.d")
    dropin.mkdir(mode=0o755, exist_ok=True)
    target = dropin / "10-gbou-firewall.conf"
    with target.open("x") as stream:
        stream.write("[Unit]\nRequires=gbou-gateway-firewall.service\n"
                     "After=gbou-gateway-firewall.service\n")
    target.chmod(0o644)
    subprocess.run(["systemctl", "daemon-reload"], check=True)
    print("One Pi peer enrolled. No LAN/default routes or database changes.")


if __name__ == "__main__":
    main()
