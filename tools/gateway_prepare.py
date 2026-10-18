"""Prepare ONLY the approved Timeweb VPS, without publishing a school API.

Root on 91.198.220.13. Requires distro wireguard-tools, nftables and haproxy.
Does not copy DBs, change default routes or start the public proxy.
"""

import ipaddress
import json
import os
from pathlib import Path
import shutil
import subprocess


def run(*args, **kwargs):
    return subprocess.run(args, check=True, text=True, **kwargs)


def output(*args):
    return run(*args, capture_output=True).stdout.strip()


def create(path, content, mode=0o600):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, mode)
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as stream:
        stream.write(content)


def main():
    if os.geteuid() != 0:
        raise SystemExit("Run as root on the approved gateway only")
    if 'VERSION_ID="12"' not in Path("/etc/os-release").read_text():
        raise SystemExit("Expected Debian 12")
    for command in ("wg", "wg-quick", "nft", "haproxy", "systemctl"):
        if not shutil.which(command):
            raise SystemExit(f"Missing distro package command: {command}")
    addresses = json.loads(output("ip", "-j", "address", "show"))
    assigned = [
        ipaddress.ip_interface(f"{a['local']}/{a['prefixlen']}")
        for device in addresses for a in device.get("addr_info", [])
    ]
    if not any(str(a.ip) == "91.198.220.13" for a in assigned):
        raise SystemExit("Not the approved gateway")
    if any(a.network.overlaps(ipaddress.ip_network("10.77.203.0/30"))
           for a in assigned if a.version == 4):
        raise SystemExit("Tunnel subnet conflicts with an existing interface")
    config_dir = Path("/etc/gbou-gateway")
    if config_dir.exists():
        raise SystemExit("Preparation already exists; inspect before changing it")
    if Path("/etc/wireguard/gbou-wg.conf").exists():
        raise SystemExit("Existing WireGuard configuration; not overwriting")
    # Do not layer a default-drop firewall onto unknown existing filtering.
    rules = output("nft", "list", "ruleset")
    if rules.strip():
        raise SystemExit("Existing nftables rules require a manual merge")
    for table in ("filter", "nat", "mangle", "raw", "security"):
        for line in output("iptables-save", "-t", table).splitlines():
            if line.startswith("-A ") or (line.startswith(":") and " DROP " in line):
                raise SystemExit("Existing iptables filtering requires a manual merge")

    monitor_ips = []
    for line in Path("/etc/zabbix/zabbix_agentd.conf").read_text().splitlines():
        if line.startswith("Server="):
            monitor_ips.extend(str(ipaddress.IPv4Address(v.strip()))
                               for v in line.split("=", 1)[1].split(","))
    if not monitor_ips:
        raise SystemExit("Cannot preserve the provider monitoring allowlist")
    config_dir.mkdir(mode=0o700)
    Path("/etc/wireguard").mkdir(mode=0o700, exist_ok=True)
    os.chmod("/etc/wireguard", 0o700)
    private = output("wg", "genkey")
    public = run("wg", "pubkey", input=private + "\n", capture_output=True).stdout.strip()
    create("/etc/wireguard/gbou-gateway.key", private + "\n")
    create("/etc/wireguard/gbou-gateway.pub", public + "\n", 0o644)
    create("/etc/wireguard/gbou-wg.conf", "[Interface]\nAddress = 10.77.203.1/32\n"
           "ListenPort = 51820\nPrivateKey = " + private + "\n")
    del private
    monitor_set = ", ".join(sorted(set(monitor_ips)))
    firewall = """table inet gbou_gateway {
    chain input {
        type filter hook input priority 0; policy drop;
        iifname "lo" accept
        ct state invalid drop
        ct state established,related accept
        meta l4proto { icmp, ipv6-icmp } accept
        # The Pi cannot initiate arbitrary connections to VPS services.
        iifname "gbou-wg" drop
        tcp dport { 22, 80, 443 } accept
        udp dport 51820 accept
        udp sport 67 udp dport 68 accept
        udp sport 547 udp dport 546 accept
        ip saddr { __MONITORS__ } tcp dport 10050 accept
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
""".replace("__MONITORS__", monitor_set)
    create(str(config_dir / "firewall.nft"), firewall)
    # At boot the table is absent. Reload is an atomic replace of OUR table only.
    apply_script = """#!/usr/bin/python3
from pathlib import Path
import subprocess
rules = Path('/etc/gbou-gateway/firewall.nft').read_text()
exists = subprocess.run(['nft','list','table','inet','gbou_gateway'],
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
payload = ('delete table inet gbou_gateway\\n' if exists else '') + rules
subprocess.run(['nft','--check','-f','-'],input=payload,text=True,check=True)
subprocess.run(['nft','-f','-'],input=payload,text=True,check=True)
"""
    create(str(config_dir / "apply-firewall.py"), apply_script, 0o700)
    unit = """[Unit]
Description=GBOU gateway scoped firewall
DefaultDependencies=no
Wants=network-pre.target
Before=network-pre.target wg-quick@gbou-wg.service haproxy.service
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/etc/gbou-gateway/apply-firewall.py
ExecReload=/etc/gbou-gateway/apply-firewall.py

[Install]
WantedBy=multi-user.target
"""
    create("/etc/systemd/system/gbou-gateway-firewall.service", unit, 0o644)
    run("nft", "--check", "-f", str(config_dir / "firewall.nft"))
    run("systemctl", "daemon-reload")
    # Roll back only our new table if the independent SSH check cannot succeed.
    run("systemd-run", "--unit=gbou-gateway-fw-rollback", "--on-active=120s",
        "/usr/sbin/nft", "delete", "table", "inet", "gbou_gateway")
    run("systemctl", "start", "gbou-gateway-firewall.service")
    run("systemctl", "enable", "gbou-gateway-firewall.service")
    run("systemctl", "enable", "--now", "wg-quick@gbou-wg.service")
    print("Prepared gateway; peer not enrolled; public proxy not started.")
    print("WIREGUARD_PUBLIC_KEY=" + public)
    print("Verify a NEW SSH connection, then cancel gbou-gateway-fw-rollback.timer.")


if __name__ == "__main__":
    main()
