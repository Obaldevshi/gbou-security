from collections import OrderedDict
from threading import Lock
from time import monotonic
from typing import Annotated

from fastapi import APIRouter, Depends, Header, Request, Response
from app.core.dependencies import DatabaseDep
from app.core.exceptions import BaseError
from app.repositories.login_directory_repository import LoginDirectoryRepository
from app.repositories.school_device_repository import SchoolDeviceRepository
from app.services.login_directory_service import LoginDirectoryService
from app.services.school_device_service import SchoolDeviceService
from app.schemas.login_directory import DirectorySnapshot, ResolveSchool, SchoolDestination, SchoolDestinations, SnapshotResult

router = APIRouter()


def service(db: DatabaseDep):
    return LoginDirectoryService(LoginDirectoryRepository(db), SchoolDeviceService(SchoolDeviceRepository(db)))


class DirectoryRateLimit:
    """Bounded, process-local lookup quota, unrelated to password/login limits."""
    def __init__(self, clock=monotonic, attempts=120, capacity=4096):
        self.clock, self.attempts, self.capacity = clock, attempts, capacity
        self.buckets = OrderedDict()
        self.lock = Lock()

    def check(self, key):
        with self.lock:
            now = self.clock()
            bucket = self.buckets.setdefault(key, [now, 0])
            if bucket[0] <= now - 60:
                bucket[:] = [now, 0]
            self.buckets.move_to_end(key)
            while len(self.buckets) > self.capacity:
                self.buckets.popitem(last=False)
            if bucket[1] >= self.attempts:
                error = BaseError('Повторите определение школы позже или укажите её адрес.', 429, 'directory_retry_later')
                error.headers = {'Retry-After': '60', 'Cache-Control': 'no-store'}
                raise error
            bucket[1] += 1


lookup_limit = DirectoryRateLimit(attempts=1200)
identifier_limit = DirectoryRateLimit(attempts=12)


@router.post('/resolve', response_model=SchoolDestination, response_model_exclude_none=True)
def resolve(payload: ResolveSchool, request: Request, response: Response,
            manager: Annotated[LoginDirectoryService, Depends(service)]):
    response.headers['Cache-Control'] = 'no-store'
    # One repeatedly retried identifier cannot exhaust other teachers' quota.
    identifier_limit.check((request.client.host if request.client else 'unknown', payload.login_digest))
    lookup_limit.check(request.client.host if request.client else 'unknown')
    return manager.resolve(payload.login_digest)


@router.put('/snapshot', response_model=SnapshotResult)
def snapshot(payload: DirectorySnapshot, response: Response,
             manager: Annotated[LoginDirectoryService, Depends(service)],
             token: Annotated[str | None, Header(alias='X-School-Device-Token')] = None):
    response.headers['Cache-Control'] = 'no-store'
    return manager.replace(token or '', payload)


@router.post('/destinations', response_model=SchoolDestinations)
def destinations(payload: ResolveSchool, request: Request, response: Response,
                 manager: Annotated[LoginDirectoryService, Depends(service)]):
    response.headers['Cache-Control'] = 'no-store'
    identifier_limit.check((request.client.host if request.client else 'unknown', payload.login_digest))
    lookup_limit.check(request.client.host if request.client else 'unknown')
    return SchoolDestinations(choices=manager.choices(payload.login_digest))
