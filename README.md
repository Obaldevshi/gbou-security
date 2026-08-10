# Локальный шаблон mobile + web

Минимальный монорепозиторий для локальной разработки одного адаптивного Flutter-приложения на физическом телефоне и в браузере.

```text
mobile-template/
├── .agents/    # единый набор repo-скиллов Codex
├── init-api/   # FastAPI + PostgreSQL
├── init-app/   # Flutter для Android/iOS/Web
└── skills/     # workflow, архитектурные helpers и Timeweb deploy-скиллы
```

В шаблоне намеренно нет landing, store submission, signing, production entrypoints, TMA и облачного деплоя. Web используется только как цель локальной разработки самого приложения, без отдельного лендинга и релизного контура.

## 1. Backend без локального стенда

Основной Codex pipeline не требует локального backend или базы данных. Интерфейс разрабатывается в mock-режиме, а перед ручной загрузкой API выполняется `$13-check-api-timeweb`.

## 2. Адрес размещённого API

До загрузки backend используйте mock-режим. После ручного размещения API в Timeweb создайте конфигурацию клиента:

```bash
cd init-app
cp assets/env/.env.example assets/env/.env
```

В `assets/env/.env` укажите HTTPS-адрес API, например:

```dotenv
BASE_URL=https://api.example.ru/api/v1
BASE_URL_WEB=https://api.example.ru/api/v1
```

## 3. Запуск Flutter на телефоне

```bash
cd init-app
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter devices
flutter run -d <device-id>
```

Для Android включите Developer options и USB debugging. Для проверки интерфейса без backend:

```bash
flutter run -t lib/main_mock.dart -d <device-id>
```

Перед размещением backend в Timeweb запустите `$13-check-api-timeweb`, затем по явной команде продолжите через `skills/timeweb-deploy/SKILL.md`. Timeweb-пакет разворачивает managed PostgreSQL, FastAPI, Flutter Web и домены без локального backend.

## 4. Запуск Flutter в браузере

Для локальной web-отладки используйте фиксированный порт `3000` и разрешите origin `http://localhost:3000` в CORS размещённого API:

```bash
flutter run -d chrome --web-port 3000
flutter run -t lib/main_mock.dart -d chrome --web-port 3000
```

## Полезные проверки

```bash
# Flutter mobile + web
cd init-app
flutter analyze
flutter test
flutter build web --debug -t lib/main_mock.dart
```
