"""Install only a recipient-encrypted node token; never log plaintext."""
import argparse
import base64
import hashlib
import os
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--sealed', required=True)
    parser.add_argument('--sha256', required=True)
    args = parser.parse_args()
    destination = Path('/etc/gbou-local/node.token')
    private = Path('/var/lib/gbou-local/migration/receiver.pem')
    if destination.exists():
        raise FileExistsError('Existing node token will not be replaced')
    assert private.stat().st_mode & 0o077 == 0
    blob = base64.b64decode(args.sealed, validate=True)
    assert len(blob) == 384
    assert hashlib.sha256(blob).hexdigest() == args.sha256
    key = serialization.load_pem_private_key(private.read_bytes(), password=None)
    token = key.decrypt(blob, padding.OAEP(
        mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(),
        label=b'GBOU-NODE-KEY-1',
    ))
    assert len(token.strip()) >= 40
    assert token.endswith(b'\n') and b'\n' not in token[:-1]
    descriptor = os.open(destination, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(descriptor, 'wb') as stream:
        stream.write(token)
        stream.flush()
        os.fsync(stream.fileno())
    assert destination.stat().st_mode & 0o077 == 0
    print('Node token installed privately; plaintext was not displayed')


if __name__ == '__main__':
    main()
