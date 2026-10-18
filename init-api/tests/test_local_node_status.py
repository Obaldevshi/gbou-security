from datetime import datetime, timedelta, timezone
from types import SimpleNamespace

import pytest

from app.config.settings import settings
from app.core.exceptions import ForbiddenError
from app.services import local_node_status_service as module


class Repository:
    def __init__(self, values):
        self.values = values

    def timestamps(self):
        return self.values


def test_local_status_warns_about_missing_usb_and_stale_backup(monkeypatch):
    monkeypatch.setattr(settings, 'deployment_mode', 'local')
    monkeypatch.setattr(module, 'disk_usage', lambda _: SimpleNamespace(free=512 * 1024 * 1024))
    monkeypatch.setattr(module.Path, 'is_mount', lambda _: False)
    result = module.LocalNodeStatusService(Repository({})).status()
    assert result['usb_connected'] is False
    assert result['last_backup_at'] is None
    assert len(result['warnings']) == 4
    assert 'school_id' not in result


def test_local_status_accepts_recent_verified_backup(monkeypatch):
    monkeypatch.setattr(settings, 'deployment_mode', 'local')
    monkeypatch.setattr(module, 'disk_usage', lambda _: SimpleNamespace(free=8 * 1024**3))
    monkeypatch.setattr(module.Path, 'is_mount', lambda _: False)
    now = datetime.now(timezone.utc).isoformat()
    result = module.LocalNodeStatusService(Repository({'last_backup_verified': now, 'last_config_sync': now})).status()
    assert len(result['warnings']) == 1  # USB missing, no false stale warnings.


def test_cloud_status_never_reads_local_files(monkeypatch):
    monkeypatch.setattr(settings, 'deployment_mode', 'cloud')
    with pytest.raises(ForbiddenError):
        module.LocalNodeStatusService(Repository({})).status()
