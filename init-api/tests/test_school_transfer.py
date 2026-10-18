import json

import pytest
from cryptography.exceptions import InvalidTag
from scripts import local_node, school_transfer


def test_recipient_transfer_private_key_tamper_and_school_scope(tmp_path):
    private, public = tmp_path / 'private.pem', tmp_path / 'public.pem'
    school_transfer.prepare(private, public)
    rows = {name: [] for name in local_node.ORDER}
    rows['schools'] = [{'id': 2, 'short_name': 'Проверочная школа'}]
    document = {'schema': 1, 'school_id': 2, 'rows': rows}
    blob = school_transfer.seal(document, public.read_bytes())
    assert 'Проверочная школа'.encode() not in blob
    assert school_transfer.open_envelope(blob, private.read_bytes(), 2) == document
    with pytest.raises(ValueError, match='другая школа'):
        school_transfer.open_envelope(blob, private.read_bytes(), 7)
    modified = json.loads(blob)
    modified['header']['counts']['students'] = 10
    with pytest.raises(InvalidTag):
        school_transfer.open_envelope(json.dumps(modified).encode(), private.read_bytes(), 2)
    before = private.read_bytes()
    with pytest.raises(FileExistsError):
        school_transfer.prepare(private, public)
    assert private.read_bytes() == before


def test_recipient_transfer_wrong_private_key(tmp_path):
    first, second = tmp_path / 'first.pem', tmp_path / 'second.pem'
    first_pub, second_pub = tmp_path / 'first.pub', tmp_path / 'second.pub'
    school_transfer.prepare(first, first_pub)
    school_transfer.prepare(second, second_pub)
    rows = {name: [] for name in local_node.ORDER}
    rows['schools'] = [{'id': 2}]
    blob = school_transfer.seal({'schema': 1, 'school_id': 2, 'rows': rows}, first_pub.read_bytes())
    with pytest.raises(ValueError):
        school_transfer.open_envelope(blob, second.read_bytes(), 2)
