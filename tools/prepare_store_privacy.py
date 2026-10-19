"""Render the same bundled policy for web. --check is a submission gate, not approval."""
from pathlib import Path
import html
import json
import re
import sys

root = Path(__file__).resolve().parents[1]
policy = json.loads((root/'init-app/assets/privacy/policy.json').read_text(encoding='utf8'))
missing = []
if policy.get('approved') is not True:
    missing.append('owner_approval')
if not policy.get('operator_name','').strip():
    missing.append('operator_name')
if not re.fullmatch(r'[^\s@]+@[^\s@]+\.[^\s@]+', policy.get('contact_email','')):
    missing.append('contact_email')
if not policy.get('retention_policy','').strip():
    missing.append('retention_policy')
if '--check' in sys.argv:
    print(json.dumps({'ready_for_submission':not missing, 'missing':missing}))
    raise SystemExit(1 if missing else 0)
esc = html.escape
page = '<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>'+esc(policy['title'])+'</title><style>body{font:17px/1.65 system-ui,sans-serif;color:#172b3a;max-width:800px;margin:24px auto;padding:0 20px}h1{line-height:1.2}a,p{overflow-wrap:anywhere}.draft{background:#fff4dc;padding:16px}h2{margin-top:2em}</style><main><a href="/">В приложение</a><h1>'+esc(policy['title'])+'</h1><p>'+esc(policy['version'])+'</p>'
if missing:
    page += '<p class="draft">Редакция для согласования. Окончательный текст и порядок хранения и удаления всех категорий данных ещё не утверждены. Не использовать как готовую политику для отправки в RuStore.</p>'
for key in ('operator_name','contact_email','retention_policy'):
    if policy.get(key):
        page += '<p>'+esc(policy[key])+'</p>'
for section in policy['sections']:
    page += '<h2>'+esc(section['title'])+'</h2><p>'+esc(section['text'])+'</p>'
page += '<p><a href="/delete-account.html">Запрос удаления аккаунта без установки приложения</a></p></main></html>'
(root/'init-app/web/privacy.html').write_text(page,encoding='utf8',newline='\n')
print(json.dumps({'web_policy_rendered':True,'approved':not missing,'source':'assets/privacy/policy.json'}))
