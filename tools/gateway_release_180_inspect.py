"""Read-only inspect of release guard results; never emits configuration/key bytes."""
import hashlib
import json
from pathlib import Path
import subprocess

root = Path('/var/lib/gbou-gateway')
backups = sorted(root.glob('rollback-*'))
programs = sorted(root.glob('program-before-1.8.0-14-*'))
def same(a,b):
    return a.is_file() and b.is_file() and hashlib.sha256(a.read_bytes()).digest() == hashlib.sha256(b.read_bytes()).digest()
result = {'services': {name: subprocess.run(['systemctl','is-active',name],capture_output=True,text=True).stdout.strip()
    for name in ('haproxy','wg-quick@gbou-wg','gbou-gateway-reconcile.timer')},
    'paths': {p: Path(p).resolve()==Path(p) for p in ('/root/gbou-release-1.8.0-14','/opt/gbou-gateway')},
    'program_backups': [p.name for p in programs], 'network_backups': [p.name for p in backups[-3:]]}
if backups:
    b=backups[-1]
    result['latest_network_backup_comparison'] = {
        'haproxy_equal':same(b/'haproxy.cfg',Path('/etc/haproxy/haproxy.cfg')),
        'wireguard_equal':same(b/'wireguard.conf',Path('/etc/wireguard/gbou-wg.conf'))}
if programs:
    b=programs[-1]
    result['old_code_restored'] = all(same(b/name,Path('/opt/gbou-gateway')/name) for name in ('managed_routes.py','reconcile.py'))
state=json.loads((root/'managed-state.json').read_text())
result['host_floors_present']=bool(state.get('host_generations'))
print(json.dumps(result))
