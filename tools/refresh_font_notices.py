"""Incremental font-only audit; preserve the existing dependency inventory."""
from pathlib import Path
import hashlib
import html
import json
import re
from audit_licenses import font_names

root=Path(__file__).resolve().parents[1]
inventory=root/'artifacts/license-audit/inventory.json'
data=json.loads(inventory.read_text(encoding='utf8'))
data['fonts']=[{'file':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
    'names':font_names(p)} for p in sorted((root/'init-app/assets/fonts').glob('*.ttf'))]
inventory.write_text(json.dumps(data,ensure_ascii=False,indent=2),encoding='utf8')
web=root/'init-app/web/licenses/index.html'
page=web.read_text(encoding='utf8')
for name in ('Roboto-Apache-2.0','ASSET_NOTICES'):
    section='<details><summary>'+name+'</summary><pre>'+html.escape(
        (root/f'init-app/assets/licenses/{name}.txt').read_text(encoding='utf8'))+'</pre></details>'
    pattern=r'<details><summary>'+re.escape(name)+r'</summary><pre>.*?</pre></details>'
    if re.search(pattern,page,flags=re.S):page=re.sub(pattern,lambda _:section,page,flags=re.S)
    else:page=page.replace('</html>',section+'</html>')
web.write_text(page,encoding='utf8',newline='\n')
print(json.dumps({'incremental_font_audit':True,'font_count':len(data['fonts']),
    'dependency_inventory_preserved':True,'roboto_license_in_web':True}))
