from datetime import datetime, timedelta, timezone
import os
from pathlib import Path
from shutil import disk_usage

from app.config.settings import settings
from app.core.exceptions import ForbiddenError
from app.repositories.local_node_status_repository import LocalNodeStatusRepository


class LocalNodeStatusService:
    def __init__(self, repository: LocalNodeStatusRepository):
        self.repository = repository

    def status(self) -> dict:
        if settings.deployment_mode != 'local':
            raise ForbiddenError('Состояние локального узла доступно только в школе', code='local_school_only')
        values = self.repository.timestamps()
        sd_free = disk_usage('/var/lib/gbou-local').free // (1024 * 1024)
        usb = Path('/mnt/gbou-backup')
        connected = usb.is_mount() and (
            os.name != 'posix' or usb.stat().st_dev != Path('/var/lib/gbou-local').stat().st_dev
        )
        usb_free = disk_usage(usb).free // (1024 * 1024) if connected else None
        warnings = []
        if not connected:
            warnings.append('USB-флешка не подключена: резервные копии не создаются.')
        if sd_free < 1024:
            warnings.append('На SD-карте осталось меньше 1 ГБ. Нужна проверка администратора.')
        if usb_free is not None and usb_free < 1024:
            warnings.append('На USB-флешке осталось меньше 1 ГБ.')
        backup = self._date(values.get('last_backup_verified'))
        sync = self._date(values.get('last_config_sync'))
        now = datetime.now(timezone.utc)
        if backup is None or now - backup > timedelta(hours=36):
            warnings.append('Нет проверенной резервной копии за последние 36 часов.')
        if sync is None or now - sync > timedelta(minutes=30):
            warnings.append('Настройки из центрального сервиса давно не обновлялись. Локальная работа продолжается.')
        return {
            'sd_free_mb': sd_free, 'usb_connected': connected, 'usb_free_mb': usb_free,
            'last_backup_at': backup, 'last_config_sync_at': sync, 'warnings': warnings,
        }

    @staticmethod
    def _date(value: str | None) -> datetime | None:
        try:
            parsed = datetime.fromisoformat(value) if value else None
            return parsed.replace(tzinfo=timezone.utc) if parsed and parsed.tzinfo is None else parsed
        except ValueError:
            return None
