# Скиллы проекта для Codex

В проекте используются основной набор repo-скиллов Codex и отдельный пакет развёртывания Timeweb.

```text
.agents/skills/
├── 01-start/
├── 02-import-idea/
├── 03-define-features/
├── 03b-prioritize-mvp/
├── 04-map-screens/
├── 06-branding/
├── 07-write-stories/
├── 08-data-model/
├── 09-plan-features/
├── 10-add-feature/
├── 10b-fix-feature/
├── 11-verify-mock/       # ручной чек-лист без запуска со стороны Codex
└── 13-check-api-timeweb/  # проверка API перед ручной загрузкой
```

Каждый скилл расположен в отдельной папке и содержит обязательный `SKILL.md` с полями `name` и `description`. Каталоги `.cursor` и `.claude` удалены.

## Как вызывать

В Codex укажите скилл явно через `$имя-скилла`, например:

```text
Используй $13-check-api-timeweb и проверь API перед загрузкой в Timeweb.
```

Codex также может выбрать скилл автоматически по его `description`.

## Развёртывание Timeweb

В `skills/` перенесена и адаптирована часть Timeweb-пакета из проекта `tachka-main`:

```text
skills/
├── timeweb-deploy/      # оркестратор и память прогресса
├── timeweb-deploy-api/  # managed PostgreSQL + FastAPI Dockerfile App
├── timeweb-deploy-web/  # публикация готовой пользователем build/web
└── timeweb-domains/     # DNS, HTTPS, CORS и финальные URL
```

Начинать после `$13-check-api-timeweb` с `skills/timeweb-deploy/SKILL.md`. Пакет не содержит landing, TMA и магазины. Перед созданием любого платного ресурса Codex обязан показать выбранный тариф и получить явное подтверждение.

Готовые артефакты пользователь собирает самостоятельно из `init-app/Makefile`: `make build-apk-prod` создаёт APK для телефона, `make build-web-prod` — папку `init-app/build/web` для Timeweb. Codex не запускает эти команды без отдельной явной просьбы.

## Архитектурные helpers

В `skills/helper-skill/` находятся вспомогательные инструкции для реализации:

```text
helper-skill/
├── design-flutter-ui/       # стильный, адаптивный и лёгкий UI
├── build-flutter-feature/   # Flutter feature + SOLID/Clean Architecture
└── build-fastapi-feature/   # FastAPI feature по backend-слоям
```

`$06-branding` использует UI-helper, а `$10-add-feature` — оба архитектурных helper-скилла. Их также можно указать Codex напрямую по пути к `SKILL.md`.

## Назначение pipeline

Pipeline ведёт до адаптивного MVP и пакета API для ручной проверки и загрузки в Timeweb:

- запуск Flutter на Android/iOS устройстве и в Chrome, визуальную проверку UI, анализатор, тесты и сборки выполняет пользователь;
- mobile и web переиспользуют функции, маршруты и UI, а компоновка переключается через `AppLayoutItemBuilder`;
- mock-режим позволяет разрабатывать интерфейс без backend;
- маршруты, DTO, авторизация, ошибки, миграции и настройки FastAPI статически сверяются с Flutter;
- результат проверки сохраняется в `artifacts/api-timeweb-check.md`.

`$13-check-api-timeweb` ничего не загружает и не изменяет в Timeweb. Развёртывание начинается только отдельным явным запуском `skills/timeweb-deploy/SKILL.md`; локальный backend для него не требуется.
