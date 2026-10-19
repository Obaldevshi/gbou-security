"""Read-only public HTTPS checks; never prints response records or credentials."""
from pathlib import Path
import hashlib
import argparse
import json
import sys
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('mode', choices=['school', 'central'])
parser.add_argument('--version', default='1.6.1+11')
args = parser.parse_args()
mode = args.mode
expected_version, expected_build = args.version.split('+')
origin = 'https://school-2036.gbousecurity.ru' if mode == 'school' else 'https://gbousecurity.ru'
api = origin if mode == 'school' else 'https://obaldevshi-gbou-security-ac8a.twc1.net'
build = ROOT / ('release/' + ('school' if mode == 'school' else 'central') + '-web-' + args.version.replace('+', '-'))


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
assert version['version'] == expected_version and version['build_number'] == expected_build
result['version'] = args.version
paths = ['main.dart.js', 'licenses/index.html', 'assets/fonts/MaterialIcons-Regular.otf']
if expected_version != '1.6.1':
    paths += ['privacy.html', 'delete-account.html']
for path in paths:
    status, blob = read(origin + '/' + path)
    assert status == 200
    digest = hashlib.sha256(blob).hexdigest()
    expected = (build / path).read_bytes()
    exact = blob == expected
    # Only these exact static HTML files may traverse Git CRLF -> LF normalization.
    # Keep raw hashes, never normalize executable JS, fonts or any other bytes.
    normalized = (mode == 'central' and path in {'licenses/index.html', 'privacy.html', 'delete-account.html'}
                  and blob.replace(b'\r\n', b'\n') == expected.replace(b'\r\n', b'\n'))
    assert exact or normalized, 'Mismatch: ' + path
    result['checks'][path] = {'status': status, 'sha256': digest, 'exact_match': exact,
                              'git_crlf_lf_only': not exact and normalized}
(ROOT / ('artifacts/public-release-' + mode + '.json')).write_text(json.dumps(result, indent=2), encoding='utf8')
print(json.dumps(result))
