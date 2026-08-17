# Проверка API перед Timeweb

Статус: готово к размещению без критических несоответствий
Дата: 2026-08-10

## Контракты Flutter ↔ FastAPI

| Метод | Путь | Назначение | Flutter | FastAPI |
|---|---|---|---|---|
| POST | `/api/v1/auth/login` | Вход | `AuthApiDataSource.login` | `auth.login` |
| GET | `/api/v1/users/` | Текущий пользователь | `AuthApiDataSource.getCurrentUser` | `user.get_current_user` |
| GET | `/api/v1/teacher/classes` | Классы учителя | `getTeacherClasses` | `get_teacher_classes` |
| GET | `/api/v1/teacher/classes/{class_id}/students` | Ученики класса | `getClassStudents` | `get_class_students` |
| POST | `/api/v1/teacher/exit-requests` | Создание заявки | `createExitRequest` | `create_exit_request` |
| GET | `/api/v1/teacher/exit-requests` | Active/history snapshot | `getTeacherExitRequests` | `get_teacher_exit_requests` |
| GET | `/api/v1/guard/exit-requests` | Очередь охраны | `getPendingGuardRequests` | `get_guard_queue` |
| POST | `/api/v1/guard/exit-requests/{request_id}/release` | Выпуск ученика | `releaseExitRequest` | `release_exit_request` |

## Сверено

- общий клиентский base URL оканчивается `/api/v1`, относительные Retrofit-пути совпадают с router prefixes;
- bearer token, 401/403 и стабильные error codes согласованы;
- JSON-поля используют snake_case на обеих сторонах;
- enum: `teacher`, `guard`, `pending`, `released`, `parent_note`, `health`, `other`;
- даты передаются ISO 8601, nullable `released_at` и `released_by_id` согласованы;
- пагинация осознанно отсутствует в локальном MVP;
- миграции образуют цепочку `001 → 002 → 003`;
- Dockerfile запускает `entrypoint.sh`, который проверяет БД, выполняет `alembic upgrade head` и поднимает Uvicorn на `0.0.0.0:8080`;
- `/health`, `/ready`, `/docs` доступны вне `/api/v1`;
- обязательные backend env: `DATABASE_URL`, `SECRET_KEY`; дополнительные: `ALGORITHM`, `ACCESS_TOKEN_EXPIRE_MINUTES`, `APP_NAME`, `APP_VERSION`, `DEBUG`, `CORS_ORIGINS`;
- production Flutter env создаётся после получения технического URL API.

## Выполненные проверки

- build_runner и `flutter gen-l10n` — успешно;
- Flutter unit tests — 5/5 успешно до указания прекратить тестовые запуски;
- Python `compileall`, ARB JSON, Dart formatter parse и `git diff --check` — успешно;
- Flutter analyzer выявил один дублированный import и устаревший синтаксис полей; исправлено. Повторный analyzer не запускался по указанию пользователя;
- backend pytest не запускался: в локальном Python отсутствует пакет `pytest`, дальнейшие тестовые запуски отменены пользователем.

## Критические несоответствия

Не обнаружены.

## Параметры Timeweb

- backend project directory: `/init-api`;
- Docker port: `8080`;
- PostgreSQL и API должны использовать одну приватную сеть;
- первый CORS origin: `http://localhost:3000`, после публикации web заменить на его HTTPS origin;
- секреты вводятся только в переменные Timeweb и не сохраняются в Git/artifacts.

## Повторная проверка расширенной версии — 2026-08-17

- OpenAPI успешно формируется: 46 маршрутов.
- Добавлены и сверены Flutter ↔ FastAPI контракты смены временного пароля, dry-run импорта, SSE-событий, журнала аудита и отчётов XLSX/PDF.
- Цепочка миграций: `001 → 002 → 003 → 004 → 005_password_security → 006_audit_logs (head)`.
- Сервер слушает `0.0.0.0:8080`; entrypoint проверяет PostgreSQL, выполняет миграции и seed через `python -m scripts.seed`.
- Production CORS разрешает HTTPS-домены `*.twc1.net`; логин защищён ограничителем частоты.
- Backend: 45 тестов пройдено. Flutter: 19 тестов пройдено, analyzer — без замечаний.
- Web release собран без service worker; Android App Bundle `1.1.0+2` собран.
- Критические несоответствия контрактов не обнаружены.

## Проверка ролевой web-сборки — 2026-08-17

- API-контракты, префикс `/api/v1`, Bearer-авторизация и backend не изменялись.
- Flutter analyzer завершён без замечаний.
- Production web-сборка завершена успешно.
- Созданы 10 отложенных `*.part.js`; для каждого подготовлена gzip-версия.
- Основной `main.dart.js` после gzip: 989642 байта.
- CanvasKit загружается с домена приложения и совместим с настроенным CDN-кешированием.
- Критические несоответствия для Timeweb не обнаружены.

## Проверка брендированной web-сборки — 2026-08-17

- Backend и Flutter API-контракты не изменялись.
- Генерация локализаций и Flutter analyzer завершены успешно.
- Production web build завершён успешно.
- HTML, PWA manifest и mobile metadata содержат новое название.
- Версия кеша `1.1.0-8` исключает показ старой темы после деплоя.
- Критические несоответствия для Timeweb не обнаружены.
