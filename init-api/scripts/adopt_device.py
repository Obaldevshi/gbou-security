"""Server-console operator command; all input is public metadata/fingerprints.

No token/password/private key is accepted, created or printed. Never imports
school data. Keep the same running writer and tunnel; use only after backup.
"""
import argparse
import json
from pathlib import Path
from app.config.database import SessionLocal
from app.config.settings import settings
from app.repositories.school_device_repository import SchoolDeviceRepository
from app.schemas.device_adoption import AdoptExistingPrimary
from app.services.device_adoption_service import DeviceAdoptionService


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--plan', type=Path, required=True)
    parser.add_argument('--apply', action='store_true')
    parser.add_argument('--rollback-generation', type=int)
    args = parser.parse_args()
    if settings.deployment_mode != 'cloud':
        raise ValueError('Use the central cloud server console')
    plan = AdoptExistingPrimary.model_validate_json(args.plan.read_text())
    with SessionLocal() as db:
        service = DeviceAdoptionService(SchoolDeviceRepository(db))
        if args.rollback_generation is not None:
            if not args.apply:
                raise ValueError('Rollback requires --apply')
            result = service.rollback_adoption(plan.school_id, plan.device_id, args.rollback_generation)
        else:
            result = service.adopt(plan, apply=args.apply)
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        raise SystemExit('Adoption failed (' + type(error).__name__ + '); no credentials printed. Check protected diagnostics.')
