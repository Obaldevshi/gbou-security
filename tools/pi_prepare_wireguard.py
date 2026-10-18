"""Install a narrowly scoped Pi-to-gateway link, leaving API/DB/Caddy intact."""

import base64
import ipaddress
import json
import os
from pathlib import Path
import shutil
import subprocess

GATEWAY_PUBLIC_KEY = "6vDXe0tM3QviLmMfdQ2sepFt6KKQL3kv4JJUUGIHOk0="


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def output(*args):
    return run(*args, capture_output=True).stdout.strip()


def create(path, text, mode=0o600):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
        stream.write(text)


def main():
    if os.geteuid() != 0 or output("hostname") != "gbousecurity":
        raise SystemExit("Expected root on the approved school Raspberry")
    if output("uname", "-m") != "armv7l":
        raise SystemExit("Expected the approved Raspberry Pi 3")
    for name in ("wg", "wg-quick", "nft"):
        if not shutil.which(name):
            raise SystemExit(f"Missing distro tool: {name}")
    if len(base64.b64decode(GATEWAY_PUBLIC_KEY, validate=True)) != 32:
        raise SystemExit("Invalid gateway public key")
    if not Path("/etc/systemd/system/gbou-local-api.service").exists():
        raise SystemExit("Expected existing local node installation")
    directory = Path("/etc/gbou-pi-link")
    config = Path("/etc/wireguard/gbou-wg.conf")
    if directory.exists() or config.exists():
        raise SystemExit("Link preparation already exists; not overwriting")
    devices = json.loads(output("ip", "-j", "address", "show"))
    for device in devices:
        for address in device.get("addr_info", []):
            if address["family"] == "inet":
                network = ipaddress.ip_interface(
                    f"{address['local']}/{address['prefixlen']}"
                ).network
                if network.overlaps(ipaddress.ip_network("10.77.203.0/30")):
                    raise SystemExit("Tunnel subnet conflict")
    directory.mkdir(mode=0o700)
    Path("/etc/wireguard").mkdir(mode=0o700, exist_ok=True)
    os.chmod("/etc/wireguard", 0o700)
    private = output("wg", "genkey")
    public = run("wg", "pubkey", input=private + "\n", capture_output=True).stdout.strip()
    create("/etc/wireguard/gbou-pi.key", private + "\n")
    create("/etc/wireguard/gbou-pi.pub", public + "\n", 0o644)
    create(str(config), "[Interface]\nAddress = 10.77.203.2/32\nPrivateKey = " + private
           + "\n\n[Peer]\nPublicKey = " + GATEWAY_PUBLIC_KEY
           + "\nEndpoint = 91.198.220.13:51820\nAllowedIPs = 10.77.203.1/32\n"
             "PersistentKeepalive = 25\n")
    del private
    # Scope ONLY the new interface. Existing LAN and kiosk traffic is unchanged.
    firewall = """table inet gbou_pi_link {
    chain input {
        type filter hook input priority -10; policy accept;
        iifname "gbou-wg" ct state invalid drop
        iifname "gbou-wg" ip saddr != 10.77.203.1 drop
        iifname "gbou-wg" ct state established,related accept
        iifname "gbou-wg" meta l4proto icmp accept
        iifname "gbou-wg" tcp dport { 80, 443 } accept
        iifname "gbou-wg" drop
    }
    chain forward {
        type filter hook forward priority -10; policy accept;
        iifname "gbou-wg" drop
        oifname "gbou-wg" drop
    }
}
"""
    create(str(directory / "firewall.nft"), firewall)
    apply_script = """#!/usr/bin/python3
from pathlib import Path
import subprocess
rules = Path('/etc/gbou-pi-link/firewall.nft').read_text()
exists = subprocess.run(['nft','list','table','inet','gbou_pi_link'],
                        stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode == 0
payload = ('delete table inet gbou_pi_link\\n' if exists else '') + rules
subprocess.run(['nft','--check','-f','-'],input=payload,text=True,check=True)
subprocess.run(['nft','-f','-'],input=payload,text=True,check=True)
"""
    create(str(directory / "apply-firewall.py"), apply_script, 0o700)
    unit = """[Unit]
Description=GBOU Raspberry scoped WireGuard firewall
DefaultDependencies=no
Wants=network-pre.target
Before=network-pre.target wg-quick@gbou-wg.service
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/etc/gbou-pi-link/apply-firewall.py
ExecReload=/etc/gbou-pi-link/apply-firewall.py

[Install]
WantedBy=multi-user.target
"""
    create("/etc/systemd/system/gbou-pi-link-firewall.service", unit, 0o644)
    dropin = Path("/etc/systemd/system/wg-quick@gbou-wg.service.d")
    dropin.mkdir(mode=0o755, exist_ok=True)
    create(str(dropin / "10-gbou-firewall.conf"), "[Unit]\n"
           "Requires=gbou-pi-link-firewall.service\nAfter=gbou-pi-link-firewall.service\n", 0o644)
    run("nft", "--check", "-f", str(directory / "firewall.nft"))
    run("systemctl", "daemon-reload")
    run("systemctl", "enable", "--now", "gbou-pi-link-firewall.service")
    run("systemctl", "enable", "--now", "wg-quick@gbou-wg.service")
    print("PI_WIREGUARD_PUBLIC_KEY=" + public)
    print("Link configured; gateway enrollment still required. API/DB/Caddy unchanged.")


if __name__ == "__main__":
    main()
