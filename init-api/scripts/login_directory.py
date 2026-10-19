"""Opt-in current-primary snapshot. No plaintext login or password leaves the Pi."""
import hashlib
import os
from pathlib import Path
from urllib.parse import urlsplit

import httpx
from sqlalchemy import or_
from app.config.database import SessionLocal
from app.config.settings import settings
from app.models.school import School
from app.models.school_building import SchoolBuilding
from app.models.user import User, UserRole


def login_digest(login: str) -> str:
    return hashlib.sha256(('gbou-login-directory-v1:' + login.strip().lower()).encode('utf-8')).hexdigest()


def local_digests(db, school_id, building_id=None):
    # Select only login; no password/hash, names or student rows enter this path.
    query = db.query(User.login).join(School, School.id == User.school_id).outerjoin(
        SchoolBuilding, SchoolBuilding.id == User.building_id,
    ).filter(User.school_id == school_id, User.is_active.is_(True), User.deleted_at.is_(None),
             User.role.in_([UserRole.TEACHER, UserRole.GUARD, UserRole.SCHOOL_ADMIN]),
             School.is_active.is_(True), or_(User.building_id.is_(None),
                 (SchoolBuilding.is_active.is_(True) & (SchoolBuilding.school_id == school_id))))
    if building_id is not None:
        query = query.filter((User.building_id == building_id) |
                             (User.building_id.is_(None) & (User.role == UserRole.SCHOOL_ADMIN)))
    rows = query.all()
    digests = sorted({login_digest(row[0]) for row in rows})
    if len(digests) > 10000:
        raise ValueError('Directory snapshot exceeds supported school size')
    return digests


def publish():
    if settings.deployment_mode != 'local' or not settings.login_directory_enabled:
        return
    from scripts.node_config import _read_token
    base = os.environ.get('GBOU_CLOUD_API_BASE', '').rstrip('/')
    uri = urlsplit(base)
    if (uri.scheme != 'https' or not uri.hostname or uri.username or uri.password
            or uri.query or uri.fragment or uri.path != '/api/v1'):
        raise ValueError('Invalid central HTTPS API')
    school_id = int(os.environ.get('GBOU_SCHOOL_ID', '0'))
    if school_id <= 0:
        raise ValueError('Missing school scope')
    token = _read_token(Path(os.environ.get('GBOU_NODE_TOKEN_FILE', '/etc/gbou-local/node.token')))
    with httpx.Client(timeout=20, follow_redirects=False, trust_env=False,
                      headers={'X-School-Device-Token': token}) as client:
        response = client.post(base + '/devices/heartbeat')
        response.raise_for_status()
        status = response.json()
        if status.get('role') != 'primary' or status.get('state') != 'active' or status.get('is_primary') is not True:
            raise ValueError('Only current primary can publish the directory')
        if settings.gbou_building_id is not None and (status.get('school_id') != school_id
                or status.get('building_id') != settings.gbou_building_id):
            raise ValueError('Device and local building scopes do not match')
        with SessionLocal() as db:
            digests = local_digests(db, school_id, settings.gbou_building_id)
        response = client.put(base + '/login-directory/snapshot', json={
            'generation': status['generation'], 'login_digests': digests,
        })
        response.raise_for_status()
    print('Login directory snapshot synchronized; no source identifiers or credentials exported')


if __name__ == '__main__':
    try:
        publish()
    except Exception as error:
        # HTTP exception strings can contain response bodies/URLs. Never print them.
        raise SystemExit('Login directory sync failed (' + type(error).__name__ + ')') from None
