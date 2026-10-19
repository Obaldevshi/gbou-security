"""Inventory local locked runtime dependencies; never uploads source or secrets."""
from pathlib import Path
from urllib.parse import urlparse, unquote
from urllib.request import urlopen
from concurrent.futures import ThreadPoolExecutor
import hashlib
from datetime import date
import html
import importlib.metadata as metadata
import json
import re
import struct
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def native_pom(entry):
    """Read exact public Maven coordinates; never disable HTTPS verification."""
    cache = Path.home() / '.gradle/caches/modules-2/files-2.1'
    current = dict(entry)
    entry['licenses'] = []
    try:
        for _ in range(4):
            folder = cache / current['group'] / current['name'] / current['version']
            local = list(folder.glob('*/*.pom'))
            base = ('https://dl.google.com/dl/android/maven2/' if current['group'].startswith(('androidx.', 'com.google.android.', 'com.google.mlkit'))
                    else 'https://repo.maven.apache.org/maven2/')
            url = base + current['group'].replace('.', '/') + '/' + current['name'] + '/' + current['version'] + '/' + current['name'] + '-' + current['version'] + '.pom'
            if local:
                raw = local[0].read_bytes()
            else:
                with urlopen(url, timeout=12) as response:
                    raw = response.read(262144)
            tree = ET.fromstring(raw)
            entry['licenses'] = [{tag: license.findtext('{*}' + tag, '') for tag in ('name', 'url')}
                                 for license in tree.findall('.//{*}licenses/{*}license')]
            entry['license_source'] = url
            if entry['licenses']:
                break
            parent = tree.find('{*}parent')
            if parent is None:
                break
            current = {name: parent.findtext('{*}' + tag, '') for name, tag in
                       [('group', 'groupId'), ('name', 'artifactId'), ('version', 'version')]}
    except Exception as error:
        entry['metadata_error'] = type(error).__name__
    return entry


def font_names(path):
    data = path.read_bytes()
    count = struct.unpack_from('>H', data, 4)[0]
    for index in range(count):
        tag, _, offset, _ = struct.unpack_from('>4sIII', data, 12 + 16 * index)
        if tag != b'name':
            continue
        _, records, strings = struct.unpack_from('>HHH', data, offset)
        result = {}
        for record in range(records):
            platform, _, _, name, length, start = struct.unpack_from('>HHHHHH', data, offset + 6 + record * 12)
            if name not in {0, 1, 13, 14}:
                continue
            raw = data[offset + strings + start:offset + strings + start + length]
            text = raw.decode('utf-16-be' if platform in {0, 3} else 'latin1', errors='replace')
            result.setdefault(str(name), text)
        return result
    return {}


def main():
    native_build = subprocess.run(
        [str(ROOT / 'init-app/android/gradlew.bat'), '-I', str(ROOT / 'tools/license-runtime.init.gradle'),
         'gbouLicenseInventory', '--console=plain', '-q'], cwd=ROOT / 'init-app/android',
        capture_output=True, text=True, encoding='utf-8', errors='replace', check=True)
    native = json.loads(next(line.split('=', 1)[1] for line in native_build.stdout.splitlines()
                             if line.startswith('GBOU_LICENSE_JSON=')))
    with ThreadPoolExecutor(max_workers=8) as pool:
        native = list(pool.map(native_pom, native))
    native_text, native_missing = [], []
    cache = Path.home() / '.gradle/caches/modules-2/files-2.1'
    for entry in native:
        if entry['version'] in {'unspecified', '1.0-SNAPSHOT'}:
            continue
        folder = cache / entry['group'] / entry['name'] / entry['version']
        if not entry['licenses'] and not entry['group'].startswith('io.flutter'):
            native_missing.append(':'.join(entry[key] for key in ('group', 'name', 'version')))
        title = ':'.join(entry[key] for key in ('group', 'name', 'version'))
        native_text.append(title + '\n' + '\n'.join(value['name'] + '\n' + value['url'] for value in entry['licenses']))
        for jar in [*folder.glob('*/*.jar'), *folder.glob('*/*.aar')]:
            with zipfile.ZipFile(jar) as archive:
                for name in archive.namelist():
                    if re.match(r'^META-INF/(LICENSE|NOTICE|COPYING)([.-].*)?$', name, re.I):
                        native_text.append(title + ' / ' + name + '\n' + archive.read(name).decode('utf8', errors='replace'))
    (ROOT / 'init-app/assets/licenses/ANDROID_NOTICES.txt').write_text(
        'Android runtime dependency notices\n\n'
        'Resolved release coordinates and upstream license declarations.\n'
        'Apache 2.0 full text is in Material-Icons-Apache-2.0.txt. Flutter engine\n'
        'third-party notices are also included in Flutter release NOTICES.\n\n'
        + '\n\n'.join(native_text), encoding='utf8')
    config = json.loads((ROOT / 'init-app/.dart_tool/package_config.json').read_text())
    graph = json.loads((ROOT / 'init-app/.dart_tool/package_graph.json').read_text())
    packages = {entry['name']: entry for entry in graph['packages']}
    runtime, todo = set(), list(packages['mobile_template']['dependencies'])
    while todo:
        name = todo.pop()
        if name in runtime:
            continue
        runtime.add(name)
        todo.extend(packages.get(name, {}).get('dependencies', []))
    roots = {}
    for entry in config['packages']:
        url = urlparse(entry['rootUri'])
        roots[entry['name']] = Path(unquote(url.path).lstrip('/')) if url.scheme == 'file' else (ROOT / 'init-app/.dart_tool' / entry['rootUri']).resolve()
    result, notices, missing = [], [], []
    for name in sorted(runtime):
        folder = roots[name]
        files = [file for file in folder.iterdir() if file.is_file() and re.match(r'^(licen[cs]e|copying|notice)(\.|$)', file.name, re.I)]
        if not files and name in {'flutter_localizations', 'flutter_web_plugins'}:
            # These SDK packages use the Flutter SDK's parent license.
            files = [folder.parents[1] / 'LICENSE']
        if not files:
            missing.append(name)
        licenses = []
        for file in files:
            text = file.read_text(encoding='utf-8', errors='replace')
            notices.append((name + ' / ' + file.name, text))
            licenses.append({'name': file.name, 'sha256': hashlib.sha256(file.read_bytes()).hexdigest()})
        result.append({'package': name, 'version': packages.get(name, {}).get('version'), 'files': licenses})
    backend = []
    for distribution in sorted(metadata.distributions(), key=lambda value: value.metadata['Name'].lower()):
        item = distribution.metadata
        classifiers = [value for value in item.get_all('Classifier', []) if value.startswith('License ::')]
        backend.append({'name': item['Name'], 'version': distribution.version,
                        'expression': item.get('License-Expression'), 'classifiers': classifiers,
                        'license': item.get('License', '')[:500]})
    fonts = [{'file': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'names': font_names(path)}
             for path in sorted((ROOT / 'init-app/assets/fonts').glob('*.ttf'))]
    output = ROOT / 'artifacts/license-audit'
    output.mkdir(parents=True, exist_ok=True)
    (output / 'inventory.json').write_text(json.dumps({'flutter_runtime': result, 'missing': missing,
        'android_runtime': native, 'android_missing_pom_license': native_missing,
        'backend_environment_including_test_tools': backend, 'fonts': fonts}, ensure_ascii=False, indent=2), encoding='utf-8')
    destination = ROOT / 'init-app/web/licenses'
    destination.mkdir(parents=True, exist_ok=True)
    for path in sorted((ROOT / 'init-app/assets/licenses').glob('*.txt')):
        notices.append((path.stem, path.read_text(encoding='utf-8')))
    page = '<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Лицензии компонентов GBOU Security</title><style>body{font:16px/1.6 system-ui;max-width:960px;margin:32px auto;padding:0 20px;color:#172b3a}pre{white-space:pre-wrap;overflow-wrap:anywhere;font:13px/1.6 monospace}summary{padding:12px;background:#edf3f8;cursor:pointer}details{margin:10px 0}a{color:#195f99}</style><a href="/about/">О проекте</a><h1>Лицензии компонентов GBOU Security</h1><p>Уведомления о сторонних библиотеках и поставляемых ресурсах. Лицензии сохраняются за их правообладателями. Снимок зависимостей от 18 октября 2026 года. Дополнительные уведомления движка Flutter доступны в разделе «Лицензии компонентов» приложения.</p>'
    page = page.replace('18 октября 2026 года', date.today().isoformat())
    for name, text in notices:
        page += '<details><summary>' + html.escape(name) + '</summary><pre>' + html.escape(text) + '</pre></details>'
    page += '</html>'
    (destination / 'index.html').write_text(page, encoding='utf-8')
    print(json.dumps({'runtime_packages': len(runtime), 'missing_root_license': missing,
                      'android_components': len(native), 'android_missing_pom_license': native_missing,
                      'backend_environment_packages': len(backend), 'font_count': len(fonts)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
