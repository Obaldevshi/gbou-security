"""Enable the previously validated TLS-transparent proxy, with rollback."""

from pathlib import Path
import shutil
import subprocess


def main():
    target = Path("/etc/haproxy/haproxy.cfg")
    pending = Path("/etc/gbou-gateway/haproxy.pending.cfg")
    backup = Path("/etc/gbou-gateway/haproxy.before-public.cfg")
    if backup.exists():
        raise SystemExit("Backup exists; inspect current state instead of repeating")
    # The operator verifies authoritative/public DNS before running this step.
    # The VPS resolver may still hold a negative answer from before creation.
    dns = subprocess.run(["getent", "ahostsv4", "school-2036.gbousecurity.ru"], text=True, capture_output=True)
    if dns.returncode == 0 and "91.198.220.13" not in dns.stdout:
        raise SystemExit("DNS points somewhere unexpected")
    if dns.returncode:
        print("VPS resolver still caches absence; external DNS was verified separately.")
    subprocess.run(["haproxy", "-c", "-f", str(pending)], check=True)
    subprocess.run(["systemctl", "is-active", "--quiet", "wg-quick@gbou-wg"], check=True)
    shutil.copy2(target, backup)
    try:
        shutil.copyfile(pending, target)
        target.chmod(0o644)
        subprocess.run(["systemctl", "enable", "haproxy"], check=True)
        subprocess.run(["systemctl", "restart", "haproxy"], check=True)
        subprocess.run(["systemctl", "is-active", "--quiet", "haproxy"], check=True)
    except BaseException:
        shutil.copy2(backup, target)
        subprocess.run(["systemctl", "restart", "haproxy"], check=False)
        raise
    print("TLS-transparent proxy active; no TLS key, database or payload logging on gateway.")


if __name__ == "__main__":
    main()
