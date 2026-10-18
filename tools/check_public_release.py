"""Read-only public HTTPS checks; never prints response records or credentials."""
from pathlib import Path
import hashlib
import json
import sys
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
mode = sys.argv[1]
assert mode in {'school', 'central'}
origin = 'https://school-2036.gbousecurity.ru' if mode == 'school' else 'https://gbousecurity.ru'
api = origin if mode == 'school' else 'https://obaldevshi-gbou-security-ac8a.twc1.net'
build = ROOT / ('release/' + ('school' if mode == 'school' else 'central') + '-web-1.6.1-11')


def read(url):
    try:
        with urlopen(Request(url, headers={'Cache-Control': 'no-cache'}), timeout=30) as response:
            return response.status, response.read()
    except HTTPError as error:
        return error.code, b''


result = {'target': mode, 'checks': {}}
for path, expected in [('/ready', 200), ('/api/v1/teacher/classes', 401 if mode == 'school' else 404),
                       ('/api/v1/node/config', 404 if mode == 'school' else 401)]:
    status, _ = read(api + path)
    result['checks'][path] = status
    assert status == expected, (mode, path, status, expected)
status, blob = read(origin + '/version.json')
assert status == 200
version = json.loads(blob)
assert version['version'] == '1.6.1' and version['build_number'] == '11'
result['version'] = '1.6.1+11'
for path in ['main.dart.js', 'licenses/index.html', 'assets/fonts/MaterialIcons-Regular.otf']:
    status, blob = read(origin + '/' + path)
    assert status == 200
    digest = hashlib.sha256(blob).hexdigest()
    assert digest == hashlib.sha256((build / path).read_bytes()).hexdigest(), 'Mismatch: ' + path
    result['checks'][path] = {'status': status, 'sha256': digest}
(ROOT / ('artifacts/public-release-' + mode + '.json')).write_text(json.dumps(result, indent=2), encoding='utf8')
print(json.dumps(result))
