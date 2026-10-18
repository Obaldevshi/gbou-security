"""Recipient-encrypted one-school transfer; never exposes plaintext or passwords.

Generate the private RSA key on the receiving Pi. Only its public PEM is sent
to the source. The export is read-only; import must target a separate empty DB
until the final write-freeze/cutover. No public download endpoint is created.
"""

import argparse
import base64
import gzip
import hashlib
import io
import json
import os
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

from scripts import local_node

FORMAT = "GBOU-TRANSFER-1"
MAX_BYTES = 32 * 1024 * 1024


def _oaep():
    return padding.OAEP(mgf=padding.MGF1(hashes.SHA256()), algorithm=hashes.SHA256(), label=FORMAT.encode())


def _header(document):
    return json.dumps(document, sort_keys=True, separators=(",", ":")).encode()


def prepare(private_key: Path, public_key: Path) -> None:
    if private_key.exists() or public_key.exists():
        raise FileExistsError("Ключ уже существует; перезапись запрещена")
    key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    local_node._write_private(private_key, key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption(),
    ))
    local_node._write_private(public_key, key.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo,
    ))
    print("Ключ приёмника создан. Передавать только public PEM.")


def seal(document: dict, public_pem: bytes) -> bytes:
    key = serialization.load_pem_public_key(public_pem)
    if not isinstance(key, rsa.RSAPublicKey) or key.key_size < 3072:
        raise ValueError("Нужен публичный RSA-ключ не короче 3072 бит")
    header = {
        "format": FORMAT, "school_id": document["school_id"],
        "created_at": datetime.now(timezone.utc).isoformat(),
        "counts": {name: len(rows) for name, rows in document["rows"].items()},
    }
    secret, nonce = os.urandom(32), os.urandom(12)
    raw = json.dumps(document, ensure_ascii=False, separators=(",", ":")).encode()
    if len(raw) > MAX_BYTES:
        raise ValueError("Снимок превышает безопасный размер")
    blob = AESGCM(secret).encrypt(nonce, gzip.compress(raw, mtime=0), _header(header))
    return _header({"header": header, "wrapped_key": base64.b64encode(key.encrypt(secret, _oaep())).decode(),
                    "nonce": base64.b64encode(nonce).decode(), "ciphertext": base64.b64encode(blob).decode()})


def open_envelope(blob: bytes, private_pem: bytes, school_id: int) -> dict:
    if len(blob) > MAX_BYTES:
        raise ValueError("Архив слишком большой")
    envelope = json.loads(blob)
    header = envelope["header"]
    if header.get("format") != FORMAT or header.get("school_id") != school_id:
        raise ValueError("Неверный формат или другая школа")
    private = serialization.load_pem_private_key(private_pem, password=None)
    secret = private.decrypt(base64.b64decode(envelope["wrapped_key"], validate=True), _oaep())
    packed = AESGCM(secret).decrypt(base64.b64decode(envelope["nonce"], validate=True),
                                   base64.b64decode(envelope["ciphertext"], validate=True), _header(header))
    with gzip.GzipFile(fileobj=io.BytesIO(packed)) as stream:
        raw = stream.read(MAX_BYTES + 1)
    if len(raw) > MAX_BYTES:
        raise ValueError("Распакованный снимок слишком большой")
    document = json.loads(raw)
    local_node._validate_school_archive(document)
    counts = {name: len(rows) for name, rows in document["rows"].items()}
    if document["school_id"] != school_id or counts != header["counts"]:
        raise ValueError("Содержимое не совпадает с заголовком")
    return document


def main():
    parser = argparse.ArgumentParser(description="Защищённый перенос одной школы на Raspberry")
    sub = parser.add_subparsers(dest="command", required=True)
    prepare_parser = sub.add_parser("prepare")
    prepare_parser.add_argument("--private", type=Path, required=True)
    prepare_parser.add_argument("--public", type=Path, required=True)
    export_parser = sub.add_parser("export")
    export_parser.add_argument("--school-id", type=int, required=True)
    export_parser.add_argument("--public", type=Path, required=True)
    export_parser.add_argument("--out", type=Path, required=True)
    import_parser = sub.add_parser("import")
    import_parser.add_argument("--school-id", type=int, required=True)
    import_parser.add_argument("--private", type=Path, required=True)
    import_parser.add_argument("--in", dest="source", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "prepare":
        prepare(args.private, args.public)
    elif args.command == "export":
        if args.out.exists():
            raise FileExistsError("Архив уже существует")
        document = local_node.collect_school(args.school_id)
        blob = seal(document, args.public.read_bytes())
        local_node._write_private(args.out, blob)
        print(json.dumps({"counts": {n: len(r) for n, r in document["rows"].items()},
                          "bytes": len(blob), "sha256": hashlib.sha256(blob).hexdigest()}))
    else:
        if os.name == "posix" and args.private.stat().st_mode & 0o077:
            raise PermissionError("Закрытый ключ должен иметь права 0600")
        local_node.import_document(open_envelope(args.source.read_bytes(), args.private.read_bytes(), args.school_id))


if __name__ == "__main__":
    main()
