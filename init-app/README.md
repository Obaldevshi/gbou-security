# Mobile + Web Template

Адаптивный Flutter starter для локальной разработки Android/iOS и web с BLoC, GetIt/Injectable, Dio/Retrofit, go_router и ARB localization.

## Адаптивная компоновка

Используйте `AppLayoutItemBuilder` из `lib/app/layout/app_layout_item_builder.dart`: до `550` логических пикселей включительно выбирается `narrow`, выше — `wide`. Mobile и web должны переиспользовать функции, маршруты и UI-компоненты без копирования целых экранов.

## Подключение размещённого API

```bash
cp assets/env/.env.example assets/env/.env
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter devices
flutter run -d <device-id>
```

До размещения API запускайте mock-режим. После ручной загрузки backend в Timeweb задайте его HTTPS-адрес:

```dotenv
BASE_URL=https://api.example.ru/api/v1
BASE_URL_WEB=https://api.example.ru/api/v1
```

Телефон использует `BASE_URL`, браузер — `BASE_URL_WEB`. Для локального Chrome разрешите origin `http://localhost:3000` в CORS размещённого API. Не храните секреты Timeweb в клиентском `.env`.

## Mock mode

```bash
flutter run -t lib/main_mock.dart -d <device-id>
flutter run -t lib/main_mock.dart -d chrome --web-port 3000
```

Подходит для UI-разработки без backend. Любой email, пароль минимум 6 символов.

## Генерация и проверки

```bash
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
flutter build web --debug -t lib/main_mock.dart
```

После добавления assets выполните генерацию повторно.

## Production-сборки

Перед сборкой скопируйте `.env.example` в `assets/env/.env` и задайте HTTPS API. Без этого файла Makefile остановится до запуска Flutter. Production target — `lib/main.dart`; при необходимости его можно переопределить через `PROD_TARGET`.

```bash
# APK для установки и тестирования на телефоне
make build-apk-prod

# папка build/web для загрузки в Timeweb
make build-web-prod

# обе сборки последовательно
make build-prod
```

APK создаётся в `build/app/outputs/flutter-apk/app-release.apk`, web-артефакт — в `build/web/`.
