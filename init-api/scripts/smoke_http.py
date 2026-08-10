#!/usr/bin/env python3
"""
Small HTTP smoke checker for local API endpoints.

Usage:
  python scripts/smoke_http.py --base-url http://localhost:8000
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import json
import sys
import urllib.error
import urllib.request


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run lightweight API smoke checks.")
    parser.add_argument("--base-url", required=True, help="API base URL, e.g. https://srv.example.com")
    parser.add_argument("--timeout", type=float, default=8.0, help="Request timeout in seconds")
    parser.add_argument("--login", default="teacher.demo", help="Seeded MVP login")
    parser.add_argument("--password", default="DemoPass123!", help="Seeded MVP password")
    return parser.parse_args()


def check_get(url: str, timeout: float) -> tuple[bool, str]:
    req = urllib.request.Request(url=url, method="GET")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:  # noqa: S310
            status = resp.status
            body = resp.read().decode("utf-8", errors="replace")
            if status >= 400:
                return False, f"HTTP {status}"
            # Validate JSON when possible to catch obvious gateway/html errors.
            try:
                json.loads(body)
            except json.JSONDecodeError:
                return False, "Non-JSON response"
            return True, f"HTTP {status}"
    except urllib.error.HTTPError as exc:
        return False, f"HTTPError {exc.code}"
    except urllib.error.URLError as exc:
        return False, f"URLError {exc.reason}"
    except Exception as exc:  # defensive
        return False, f"{type(exc).__name__}: {exc}"


def check_auth(base: str, login: str, password: str, timeout: float) -> tuple[bool, str]:
    payload = json.dumps({"login": login, "password": password}).encode("utf-8")
    request = urllib.request.Request(
        url=f"{base}/api/v1/auth/login",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
            body = json.loads(response.read().decode("utf-8"))
            token = body.get("data", {}).get("access_token")
            if not token:
                return False, "Login response has no access token"

        profile_request = urllib.request.Request(
            url=f"{base}/api/v1/users/",
            headers={"Authorization": f"bearer {token}"},
            method="GET",
        )
        with urllib.request.urlopen(profile_request, timeout=timeout) as response:  # noqa: S310
            body = json.loads(response.read().decode("utf-8"))
            role = body.get("data", {}).get("role")
            return (role in {"teacher", "guard"}, f"HTTP {response.status}, role={role}")
    except urllib.error.HTTPError as exc:
        return False, f"HTTPError {exc.code}"
    except urllib.error.URLError as exc:
        return False, f"URLError {exc.reason}"
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        return False, f"Invalid response: {exc}"


def check_teacher_request(
    base: str,
    login: str,
    password: str,
    timeout: float,
) -> tuple[bool, str]:
    login_payload = json.dumps({"login": login, "password": password}).encode("utf-8")
    login_request = urllib.request.Request(
        url=f"{base}/api/v1/auth/login",
        data=login_payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(login_request, timeout=timeout) as response:  # noqa: S310
            token = json.loads(response.read().decode("utf-8"))["data"]["access_token"]

        headers = {"Authorization": f"bearer {token}"}
        classes_request = urllib.request.Request(
            url=f"{base}/api/v1/teacher/classes",
            headers=headers,
            method="GET",
        )
        with urllib.request.urlopen(classes_request, timeout=timeout) as response:  # noqa: S310
            classes = json.loads(response.read().decode("utf-8")).get("data", [])
        if not classes:
            return False, "Teacher has no seeded classes"
        class_id = classes[0]["id"]

        students_request = urllib.request.Request(
            url=f"{base}/api/v1/teacher/classes/{class_id}/students",
            headers=headers,
            method="GET",
        )
        with urllib.request.urlopen(students_request, timeout=timeout) as response:  # noqa: S310
            students = json.loads(response.read().decode("utf-8")).get("data", [])
        if not students:
            return False, "Seeded class has no students"

        payload = json.dumps(
            {
                "class_id": class_id,
                "student_id": students[0]["id"],
                "reason_type": "parent_note",
                "custom_reason": None,
                "scheduled_at": (
                    datetime.now(timezone.utc) + timedelta(minutes=30)
                ).isoformat(),
            }
        ).encode("utf-8")
        create_request = urllib.request.Request(
            url=f"{base}/api/v1/teacher/exit-requests",
            data=payload,
            headers={**headers, "Content-Type": "application/json"},
            method="POST",
        )
        try:
            with urllib.request.urlopen(create_request, timeout=timeout) as response:  # noqa: S310
                body = json.loads(response.read().decode("utf-8"))
                status = body.get("data", {}).get("status")
                return status == "pending", f"HTTP {response.status}, status={status}"
        except urllib.error.HTTPError as exc:
            if exc.code == 409:
                return True, "HTTP 409, seeded student already has a pending request"
            raise
    except urllib.error.HTTPError as exc:
        return False, f"HTTPError {exc.code}"
    except urllib.error.URLError as exc:
        return False, f"URLError {exc.reason}"
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        return False, f"Invalid response: {exc}"


def check_guard_release(base: str, password: str, timeout: float) -> tuple[bool, str]:
    login_payload = json.dumps(
        {"login": "guard.demo", "password": password}
    ).encode("utf-8")
    login_request = urllib.request.Request(
        url=f"{base}/api/v1/auth/login",
        data=login_payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(login_request, timeout=timeout) as response:  # noqa: S310
            token = json.loads(response.read().decode("utf-8"))["data"]["access_token"]

        headers = {"Authorization": f"bearer {token}"}
        queue_request = urllib.request.Request(
            url=f"{base}/api/v1/guard/exit-requests",
            headers=headers,
            method="GET",
        )
        with urllib.request.urlopen(queue_request, timeout=timeout) as response:  # noqa: S310
            queue = json.loads(response.read().decode("utf-8")).get("data", [])
        if not queue:
            return False, "Guard queue is empty after teacher request check"

        request_id = queue[0]["id"]
        release_request = urllib.request.Request(
            url=f"{base}/api/v1/guard/exit-requests/{request_id}/release",
            data=b"",
            headers=headers,
            method="POST",
        )
        with urllib.request.urlopen(release_request, timeout=timeout) as response:  # noqa: S310
            released = json.loads(response.read().decode("utf-8")).get("data", {})
        ok = released.get("status") == "released"
        return ok, f"HTTP {response.status}, status={released.get('status')}"
    except urllib.error.HTTPError as exc:
        return False, f"HTTPError {exc.code}"
    except urllib.error.URLError as exc:
        return False, f"URLError {exc.reason}"
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        return False, f"Invalid response: {exc}"


def check_teacher_snapshot(
    base: str,
    login: str,
    password: str,
    timeout: float,
) -> tuple[bool, str]:
    payload = json.dumps({"login": login, "password": password}).encode("utf-8")
    login_request = urllib.request.Request(
        url=f"{base}/api/v1/auth/login",
        data=payload,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(login_request, timeout=timeout) as response:  # noqa: S310
            token = json.loads(response.read().decode("utf-8"))["data"]["access_token"]
        request = urllib.request.Request(
            url=f"{base}/api/v1/teacher/exit-requests",
            headers={"Authorization": f"bearer {token}"},
            method="GET",
        )
        with urllib.request.urlopen(request, timeout=timeout) as response:  # noqa: S310
            snapshot = json.loads(response.read().decode("utf-8")).get("data", {})
        active = snapshot.get("active", [])
        history = snapshot.get("history", [])
        released = any(item.get("status") == "released" for item in history)
        return released, f"HTTP {response.status}, active={len(active)}, history={len(history)}"
    except urllib.error.HTTPError as exc:
        return False, f"HTTPError {exc.code}"
    except urllib.error.URLError as exc:
        return False, f"URLError {exc.reason}"
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        return False, f"Invalid response: {exc}"


def main() -> int:
    args = parse_args()
    base = args.base_url.rstrip("/")

    checks = [
        ("/health", "liveness"),
        ("/ready", "readiness"),
    ]

    failed = False
    print(f"Smoke check base URL: {base}")
    for path, label in checks:
        ok, msg = check_get(f"{base}{path}", timeout=args.timeout)
        mark = "PASS" if ok else "FAIL"
        print(f"[{mark}] {path:<16} ({label}) -> {msg}")
        failed = failed or not ok

    ok, msg = check_auth(base, args.login, args.password, args.timeout)
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {'/api/v1/auth':<16} (role auth) -> {msg}")
    failed = failed or not ok

    ok, msg = check_teacher_request(base, args.login, args.password, args.timeout)
    mark = "PASS" if ok else "FAIL"
    print(f"[{mark}] {'/api/v1/teacher':<16} (create request) -> {msg}")
    failed = failed or not ok

    if ok:
        ok, msg = check_guard_release(base, args.password, args.timeout)
        mark = "PASS" if ok else "FAIL"
        print(f"[{mark}] {'/api/v1/guard':<16} (release request) -> {msg}")
        failed = failed or not ok

    if ok:
        ok, msg = check_teacher_snapshot(
            base,
            args.login,
            args.password,
            args.timeout,
        )
        mark = "PASS" if ok else "FAIL"
        print(f"[{mark}] {'/api/v1/teacher':<16} (history snapshot) -> {msg}")
        failed = failed or not ok

    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
