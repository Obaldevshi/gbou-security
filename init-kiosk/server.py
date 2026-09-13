#!/usr/bin/env python3
"""Local-only lightweight guard kiosk and NetworkManager bridge."""

from __future__ import annotations

import hashlib
import json
import mimetypes
import os
import re
import subprocess
import tempfile
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
DATA_ROOT = Path(os.getenv("GBOU_KIOSK_DATA_ROOT", str(ROOT))).resolve()
WEB_ROOT = DATA_ROOT / "web"
API_BASE = os.getenv(
    "GBOU_API_BASE",
    "https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1",
).rstrip("/")
UPDATE_BASE = os.getenv(
    "GBOU_KIOSK_UPDATE_BASE",
    "https://gbousecurity.ru/kiosk",
).rstrip("/")
UPDATE_INTERVAL_SECONDS = max(
    60,
    int(os.getenv("GBOU_KIOSK_UPDATE_INTERVAL_SECONDS", "300")),
)
HOST = os.getenv("GBOU_KIOSK_HOST", "127.0.0.1")
PORT = int(os.getenv("GBOU_KIOSK_PORT", "8765"))
MAX_BODY = 16_384
MAX_MANIFEST_SIZE = 65_536
MAX_ASSET_SIZE = 524_288
UPDATE_ASSETS = ("index.html", "app.css", "app.js", "version.js")
VERSION_PATTERN = re.compile(r'GBOU_KIOSK_UI_VERSION\s*=\s*"([a-f0-9]{16})"')


def _download(url: str, maximum_size: int) -> bytes:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json, text/plain, */*",
            "Cache-Control": "no-cache",
            "User-Agent": "GBOU-Kiosk-Updater/1.0",
        },
    )
    with urllib.request.urlopen(request, timeout=10) as response:
        data = response.read(maximum_size + 1)
    if len(data) > maximum_size:
        raise ValueError("Remote kiosk asset is too large")
    return data


def _current_ui_version() -> str:
    try:
        content = (WEB_ROOT / "version.js").read_text(encoding="utf-8")
    except OSError:
        return "unknown"
    match = VERSION_PATTERN.search(content)
    return match.group(1) if match else "unknown"


def _apply_remote_update() -> bool:
    if not UPDATE_BASE.startswith("https://"):
        raise ValueError("Kiosk update URL must use HTTPS")
    cache_buster = int(time.time())
    manifest_data = _download(
        f"{UPDATE_BASE}/manifest.json?t={cache_buster}",
        MAX_MANIFEST_SIZE,
    )
    manifest = json.loads(manifest_data.decode("utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("Invalid kiosk update manifest")
    version = manifest.get("version")
    files = manifest.get("files")
    if not isinstance(version, str) or not re.fullmatch(r"[a-f0-9]{16}", version):
        raise ValueError("Invalid kiosk update version")
    if version == _current_ui_version():
        return False
    if not isinstance(files, dict) or set(files) != set(UPDATE_ASSETS):
        raise ValueError("Invalid kiosk update file list")

    DATA_ROOT.mkdir(parents=True, exist_ok=True)
    WEB_ROOT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".web-update-", dir=DATA_ROOT) as directory:
        staging = Path(directory)
        for name in UPDATE_ASSETS:
            metadata = files.get(name)
            if not isinstance(metadata, dict):
                raise ValueError("Invalid kiosk asset metadata")
            expected_hash = metadata.get("sha256")
            expected_size = metadata.get("size")
            if not isinstance(expected_hash, str) or not re.fullmatch(r"[a-f0-9]{64}", expected_hash):
                raise ValueError("Invalid kiosk asset hash")
            if not isinstance(expected_size, int) or not 0 < expected_size <= MAX_ASSET_SIZE:
                raise ValueError("Invalid kiosk asset size")
            encoded_name = urllib.parse.quote(name, safe="")
            data = _download(
                f"{UPDATE_BASE}/{encoded_name}?v={version}",
                MAX_ASSET_SIZE,
            )
            if len(data) != expected_size:
                raise ValueError("Kiosk asset size mismatch")
            if hashlib.sha256(data).hexdigest() != expected_hash:
                raise ValueError("Kiosk asset hash mismatch")
            (staging / name).write_bytes(data)

        # version.js is replaced last. Until that point an interrupted update is
        # retried instead of being treated as complete.
        for name in (*UPDATE_ASSETS[:-1], UPDATE_ASSETS[-1]):
            os.replace(staging / name, WEB_ROOT / name)
    return True


def _update_loop() -> None:
    while True:
        try:
            if _apply_remote_update():
                print(f"Kiosk UI updated to {_current_ui_version()}")
        except (OSError, ValueError, UnicodeError, json.JSONDecodeError, urllib.error.URLError):
            print("Kiosk UI update unavailable; using the local copy")
        time.sleep(UPDATE_INTERVAL_SECONDS)


def _split_nmcli(line: str) -> list[str]:
    fields: list[str] = []
    current: list[str] = []
    escaped = False
    for character in line:
        if escaped:
            current.append(character)
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == ":":
            fields.append("".join(current))
            current = []
        else:
            current.append(character)
    fields.append("".join(current))
    return fields


def _wifi_networks() -> list[dict[str, Any]]:
    process = subprocess.run(
        [
            "nmcli",
            "--terse",
            "--escape",
            "yes",
            "--fields",
            "IN-USE,SSID,SIGNAL,SECURITY",
            "device",
            "wifi",
            "list",
            "--rescan",
            "yes",
        ],
        capture_output=True,
        text=True,
        timeout=20,
        check=False,
    )
    if process.returncode != 0:
        raise RuntimeError("Не удалось получить список Wi-Fi сетей")
    networks: dict[str, dict[str, Any]] = {}
    for raw_line in process.stdout.splitlines():
        fields = _split_nmcli(raw_line)
        if len(fields) < 4 or not fields[1].strip():
            continue
        active, ssid, signal, security = fields[:4]
        item = {
            "ssid": ssid,
            "signal": int(signal or 0),
            "secure": bool(security and security != "--"),
            "active": active.strip() in {"*", "yes", "да"},
        }
        previous = networks.get(ssid)
        if previous is None or item["signal"] > previous["signal"]:
            networks[ssid] = item
    return sorted(
        networks.values(),
        key=lambda item: (not item["active"], -item["signal"], item["ssid"].casefold()),
    )


class KioskHandler(SimpleHTTPRequestHandler):
    server_version = "GBOUKiosk/1.0"

    def log_message(self, format_string: str, *args: Any) -> None:
        # Never log request bodies, passwords or bearer tokens.
        print(f"{self.client_address[0]} {format_string % args}")

    def translate_path(self, path: str) -> str:
        clean_path = path.split("?", 1)[0]
        relative = "index.html" if clean_path in {"", "/"} else clean_path.lstrip("/")
        candidate = (WEB_ROOT / relative).resolve()
        if WEB_ROOT.resolve() not in candidate.parents and candidate != WEB_ROOT.resolve():
            return str(WEB_ROOT / "__missing__")
        return str(candidate)

    def end_headers(self) -> None:
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cache-Control", "no-store")
        self.send_header(
            "Content-Security-Policy",
            "default-src 'self'; script-src 'self'; style-src 'self'; "
            "img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'",
        )
        super().end_headers()

    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/health":
            self._json(HTTPStatus.OK, {"ok": True})
        elif self.path == "/local/version":
            self._json(HTTPStatus.OK, {"version": _current_ui_version()})
        elif self.path == "/local/wifi/networks":
            try:
                self._json(HTTPStatus.OK, {"networks": _wifi_networks()})
            except (OSError, RuntimeError, subprocess.SubprocessError):
                self._json(
                    HTTPStatus.SERVICE_UNAVAILABLE,
                    {"message": "Настройка Wi-Fi недоступна"},
                )
        elif self.path == "/api/queue":
            self._proxy("GET", "/guard/exit-requests")
        elif self.path == "/api/history":
            self._proxy("GET", "/guard/exit-requests/history")
        else:
            super().do_GET()

    def do_POST(self) -> None:  # noqa: N802
        if self.path == "/api/login":
            payload = self._read_json()
            if payload is not None:
                self._proxy("POST", "/auth/login", payload)
            return
        release_match = re.fullmatch(r"/api/requests/(\d+)/release", self.path)
        if release_match:
            self._proxy(
                "POST",
                f"/guard/exit-requests/{release_match.group(1)}/release",
                {},
            )
            return
        if self.path == "/local/wifi/connect":
            payload = self._read_json()
            if payload is not None:
                self._connect_wifi(payload)
            return
        self._json(HTTPStatus.NOT_FOUND, {"message": "Маршрут не найден"})

    def _read_json(self) -> dict[str, Any] | None:
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError:
            length = 0
        if length < 0 or length > MAX_BODY:
            self._json(HTTPStatus.REQUEST_ENTITY_TOO_LARGE, {"message": "Слишком большой запрос"})
            return None
        try:
            return json.loads(self.rfile.read(length) or b"{}")
        except (json.JSONDecodeError, UnicodeDecodeError):
            self._json(HTTPStatus.BAD_REQUEST, {"message": "Некорректные данные"})
            return None

    def _proxy(self, method: str, remote_path: str, payload: dict[str, Any] | None = None) -> None:
        body = None if payload is None else json.dumps(payload).encode("utf-8")
        headers = {"Accept": "application/json"}
        if body is not None:
            headers["Content-Type"] = "application/json"
        authorization = self.headers.get("Authorization")
        if authorization and authorization.startswith("Bearer "):
            headers["Authorization"] = authorization
        request = urllib.request.Request(
            f"{API_BASE}{remote_path}",
            data=body,
            headers=headers,
            method=method,
        )
        try:
            with urllib.request.urlopen(request, timeout=10) as response:
                data = response.read()
                self._raw(response.status, data, response.headers.get_content_type())
        except urllib.error.HTTPError as error:
            self._raw(error.code, error.read(), error.headers.get_content_type())
        except (urllib.error.URLError, TimeoutError, OSError):
            self._json(
                HTTPStatus.BAD_GATEWAY,
                {"message": "Нет связи с сервером. Проверьте интернет"},
            )

    def _connect_wifi(self, payload: dict[str, Any]) -> None:
        ssid = str(payload.get("ssid", "")).strip()
        password = str(payload.get("password", ""))
        if not ssid or len(ssid.encode("utf-8")) > 32:
            self._json(HTTPStatus.BAD_REQUEST, {"message": "Выберите сеть Wi-Fi"})
            return
        if password and not 8 <= len(password) <= 63:
            self._json(
                HTTPStatus.BAD_REQUEST,
                {"message": "Пароль Wi-Fi должен содержать от 8 до 63 символов"},
            )
            return
        command = ["nmcli", "--wait", "30", "device", "wifi", "connect", ssid]
        if password:
            command.extend(["password", password])
        try:
            process = subprocess.run(
                command,
                capture_output=True,
                text=True,
                timeout=35,
                check=False,
            )
        except (OSError, subprocess.SubprocessError):
            self._json(
                HTTPStatus.SERVICE_UNAVAILABLE,
                {"message": "Не удалось запустить настройку Wi-Fi"},
            )
            return
        if process.returncode == 0:
            self._json(HTTPStatus.OK, {"message": f"Подключено к сети «{ssid}»"})
        else:
            self._json(
                HTTPStatus.BAD_REQUEST,
                {"message": "Не удалось подключиться. Проверьте пароль и сигнал"},
            )

    def _json(self, status: int, payload: dict[str, Any]) -> None:
        self._raw(status, json.dumps(payload, ensure_ascii=False).encode("utf-8"), "application/json")

    def _raw(self, status: int, data: bytes, content_type: str) -> None:
        self.send_response(status)
        self.send_header("Content-Type", f"{content_type}; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)


def main() -> None:
    mimetypes.add_type("application/javascript", ".js")
    WEB_ROOT.mkdir(parents=True, exist_ok=True)
    server = ThreadingHTTPServer((HOST, PORT), KioskHandler)
    updater = threading.Thread(target=_update_loop, name="kiosk-updater", daemon=True)
    updater.start()
    print(
        f"GBOU kiosk: http://{HOST}:{PORT}; API: {API_BASE}; "
        f"updates: {UPDATE_BASE}"
    )
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
