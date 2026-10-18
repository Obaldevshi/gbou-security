"""Bounded, process-local login protection for the single-worker school node.

There is deliberately NO school-wide/IP bucket: failed attempts for one login
must not prevent other teachers behind the same NAT from signing in.
"""
from collections import OrderedDict, deque
from contextlib import contextmanager
import hashlib
import math
from threading import Lock
from time import monotonic

from app.core.exceptions import BaseError


class LoginAttemptGuard:
    def __init__(self, *, attempts=8, window_seconds=60, capacity=4096,
                 concurrent=2, clock=monotonic):
        self.attempts = attempts
        self.window = window_seconds
        self.capacity = capacity
        self.concurrent = concurrent
        self.clock = clock
        self._buckets = OrderedDict()
        self._active = 0
        self._lock = Lock()

    @contextmanager
    def attempt(self, login):
        key = hashlib.sha256(login.strip().lower().encode()).digest()
        with self._lock:
            now = self.clock()
            bucket = self._buckets.setdefault(key, deque())
            while bucket and bucket[0] <= now - self.window:
                bucket.popleft()
            self._buckets.move_to_end(key)
            while len(self._buckets) > self.capacity:
                self._buckets.popitem(last=False)
            if len(bucket) >= self.attempts:
                retry = max(1, math.ceil(bucket[0] + self.window - now))
                error = BaseError(
                    f'Слишком много попыток для этого логина. Повторите через {retry} сек.',
                    429, 'login_retry_later',
                )
                error.headers = {'Retry-After': str(retry)}
                raise error
            if self._active >= self.concurrent:
                error = BaseError('Сервис занят. Повторите вход через пару секунд.',
                                  503, 'login_busy')
                error.headers = {'Retry-After': '2'}
                raise error
            bucket.append(now)
            self._active += 1
        succeeded = False
        try:
            yield
            succeeded = True
        finally:
            with self._lock:
                self._active -= 1
                if succeeded:
                    self._buckets.pop(key, None)


school_login_guard = LoginAttemptGuard()
