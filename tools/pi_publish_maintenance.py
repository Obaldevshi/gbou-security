"""Validate and install the maintenance-only Caddy site, preserving LAN."""

from pathlib import Path
import os
import shutil
import subprocess


def main():
    if os.geteuid() != 0:
        raise SystemExit("Run as root on the Raspberry")
    target = Path("/etc/caddy/Caddyfile")
    candidate = Path("/home/admin/Caddyfile.maintenance")
    backup = Path("/etc/caddy/Caddyfile.before-public-maintenance")
    text = candidate.read_text()
    if "respond @gateway 404" not in text or "school-2036.gbousecurity.ru" not in text:
        raise SystemExit("Expected isolated maintenance configuration")
    if backup.exists():
        raise SystemExit("Backup already exists; inspect before repeating")
    subprocess.run(["caddy", "validate", "--config", str(candidate), "--adapter", "caddyfile"], check=True)
    shutil.copy2(target, backup)
    try:
        shutil.copyfile(candidate, target)
        target.chmod(0o644)
        subprocess.run(["systemctl", "reload", "caddy"], check=True)
        subprocess.run(["systemctl", "is-active", "--quiet", "caddy"], check=True)
    except BaseException:
        shutil.copy2(backup, target)
        subprocess.run(["systemctl", "reload", "caddy"], check=False)
        raise
    print("Maintenance-only public site installed; LAN preserved; school API not published.")


if __name__ == "__main__":
    main()
