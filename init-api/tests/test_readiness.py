import asyncio

import pytest
from fastapi import HTTPException
from sqlalchemy.exc import OperationalError

from app.api.health import ready


def test_ready_success():
    class Database:
        def execute(self, statement):
            assert str(statement) == "SELECT 1"

    assert asyncio.run(ready(Database())) == {"status": "ready"}


def test_ready_hides_connection_details():
    class Database:
        def execute(self, statement):
            raise OperationalError("SELECT 1", {}, Exception("private connection detail"))

    with pytest.raises(HTTPException) as caught:
        asyncio.run(ready(Database()))
    assert caught.value.status_code == 503
    assert caught.value.headers == {"Retry-After": "15"}
    assert "private connection detail" not in caught.value.detail
