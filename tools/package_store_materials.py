"""Export approved icon size, synthetic UI captures and a credential-free checklist.

No image synthesis or visual redesign: only exact resizing of the existing launcher
asset and byte-for-byte copies of test captures. Never reads signing configuration.
"""
from pathlib import Path
from PIL import Image
from html.parser import HTMLParser
import hashlib
import json
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
destination = ROOT / 'release/rustore-1.6.1-11'
destination.mkdir(exist_ok=True)
media = destination / 'media'
media.mkdir(exist_ok=True)
icon = Image.open(ROOT / 'init-app/assets/images/app_icon.png')
assert icon.mode == 'RGB' and icon.width == icon.height
icon.resize((512, 512), Image.Resampling.LANCZOS).save(media / 'icon-512.png', optimize=True)
captures = [
    ('02-teacher-request.png', '01-teacher-request.png'),
    ('stress-360-picker-large-text.png', '02-student-selection.png'),
    ('04-selected-students.png', '03-selected-students.png'),
    ('05-teacher-students.png', '04-teacher-students.png'),
    ('stress-360-guard-large-text.png', '05-guard-queue.png'),
    ('teacher-history.png', '06-teacher-history.png'),
]
for original, exported in captures:
    source = ROOT / 'artifacts/visual-audit/android' / original
    image = Image.open(source)
    assert image.size == (720, 1280) and source.stat().st_size < 3_000_000
    shutil.copy2(source, media / exported)
listing = {
    'status': 'PREPARATION_ONLY_NOT_SUBMITTED',
    'name': 'GBOU Security',
    'package': 'ru.obaldevshi.gbou_security',
    'version': '1.6.1', 'versionCode': 11,
    'shortDescription': 'Заявки на выход учеников: учитель, охрана и администратор в одной системе.',
    'website': 'https://gbousecurity.ru/about/',
    'supportContact': '[ВЛАДЕЛЕЦ ЗАПОЛНЯЕТ РЕАЛЬНЫЙ КОНТАКТ]',
    'privacyPolicy': '[НУЖНА ПОЛНАЯ УТВЕРЖДЁННАЯ ПОЛИТИКА И ССЫЛКА В ANDROID]',
    'moderationDemo': '[ИЗОЛИРОВАННЫЙ ДЕМОКОНТУР; НЕ РЕАЛЬНАЯ ШКОЛА]',
    'accountDeletion': '[СОГЛАСОВАТЬ И ПРОВЕРИТЬ ПРИМЕНИМЫЙ IN-APP СЦЕНАРИЙ]',
    'legalReview': '[РЕКВИЗИТЫ ОПЕРАТОРА И ПРАВА НА ИСХОДНЫЙ ШАБЛОН]',
    'apk_sha256': '1aa1dd44879017571e66a0354acd3c42ae550825b92eb61a5bede17e1661fa61',
    'certificate_sha256': '17029636dd48788481e6f8ac89c07b9708ab23e485edff1462cace8a5e5a2c8d',
}
class PreparedTexts(HTMLParser):
    def __init__(self):
        super().__init__()
        self.in_pre = False
        self.blocks = []
    def handle_starttag(self, tag, attrs):
        if tag == 'pre':
            self.in_pre = True
            self.blocks.append('')
    def handle_endtag(self, tag):
        if tag == 'pre':
            self.in_pre = False
    def handle_data(self, data):
        if self.in_pre:
            self.blocks[-1] += data

texts = PreparedTexts()
texts.feed((ROOT / 'docs/rustore-publication.html').read_text(encoding='utf8'))
listing['fullDescription'] = next(text for text in texts.blocks if text.startswith('GBOU Security помогает'))
listing['whatsNew'] = next(text for text in texts.blocks if text.startswith('Улучшили мобильный интерфейс:'))
assert len(listing['name']) <= 30 and len(listing['shortDescription']) <= 80
assert len(listing['fullDescription']) <= 4000
(destination / 'listing.json').write_text(json.dumps(listing, ensure_ascii=False, indent=2), encoding='utf8')
manifest = {path.relative_to(destination).as_posix(): {
    'bytes': path.stat().st_size, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()
} for path in sorted(destination.rglob('*')) if path.is_file() and path.name != 'manifest.json'}
(destination / 'manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf8')

# Explicit handoff allowlist; no recursive workspace or private configuration.
selected = [ROOT / 'release/gbou-security-1.6.1-11.apk',
            ROOT / 'release/raspberry-child-20261018/gbou-terminal-20261018.zip',
            ROOT / 'artifacts/android-release-validation.json',
            ROOT / 'artifacts/license-audit/inventory.json']
selected += [ROOT / 'docs' / name for name in [
    'raspberry-second-device.html', 'quality-report.html', 'third-party-review.html',
    'rustore-publication.html', 'rustore-owner-checklist.html']]
selected += [path for path in destination.rglob('*') if path.is_file()]
selected += list((ROOT / 'artifacts/visual-audit').rglob('*.png'))
archive_path = ROOT / 'release/gbou-security-handoff-1.6.1-11.zip'
with zipfile.ZipFile(archive_path, 'x', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in selected:
        assert not path.is_symlink() and path.suffix.lower() not in {'.keystore', '.jks', '.db', '.sqlite', '.sqlite3', '.key', '.token'}
        assert path.name != 'key.properties'
        archive.write(path, path.relative_to(ROOT).as_posix())
with zipfile.ZipFile(archive_path) as archive:
    assert archive.testzip() is None
print(json.dumps({'store_files': len(manifest), 'handoff_files': len(selected),
                  'archive_bytes': archive_path.stat().st_size,
                  'archive_sha256': hashlib.sha256(archive_path.read_bytes()).hexdigest()}))
