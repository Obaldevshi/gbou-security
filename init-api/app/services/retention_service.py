"""Retention policy without implicit activation or cloud deletion."""
from datetime import timezone


def one_year_before(now):
    if now.tzinfo is None or now.utcoffset() is None:
        raise ValueError('Для срока хранения необходимо время UTC с часовым поясом')
    now = now.astimezone(timezone.utc)
    try:
        return now.replace(year=now.year - 1)
    except ValueError:  # Leap day, not a fixed 365/366-day approximation.
        return now.replace(year=now.year - 1, day=28)


class RetentionService:
    def __init__(self, repository, deployment_mode):
        self.repository = repository
        self.mode = deployment_mode

    def run(self, school_id, now, *, apply=False):
        if self.mode != 'local':
            raise ValueError('Очистка облачной или legacy-базы запрещена')
        cutoff = one_year_before(now)
        # Legacy base timestamps are naive UTC on the school node.
        sql_cutoff = cutoff.replace(tzinfo=None)
        try:
            self.repository.require_single_school(school_id)
            counts = (self.repository.delete_expired(school_id, sql_cutoff) if apply
                      else self.repository.counts(school_id, sql_cutoff))
            if apply:
                self.repository.commit()
            return {'dry_run': not apply, 'cutoff_utc': cutoff.isoformat(), **counts}
        except Exception:
            self.repository.rollback()
            raise
