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

## Проверка операционных сценариев E11 — 2026-08-18

| Метод | Путь | Тело / параметры | Успешный ответ |
|---|---|---|---|
| POST | `/api/v1/school/students/import` | `building_id`, `class_id`, `text`, `dry_run` | `created_count`, построчные `errors` |
| POST | `/api/v1/school/teachers/import` | `building_id`, `text`, `dry_run`; неизвестные классы создаются в корпусе | `created_count`, построчные `errors` |
| GET | `/api/v1/guard/exit-requests/history` | Bearer охранника | до 500 выпущенных текущим охранником заявок |
| GET | `/api/v1/guard/exit-requests` | Bearer охранника | актуальная очередь корпуса |
| GET | `/api/v1/school/exit-requests` | Bearer администратора школы | `active` и `history` |

- Новый `class_id` при импорте учеников проверяется в границах школы и корпуса;
  старый формат строк с названием класса остаётся совместимым.
- `ExitRequestResponse` одинаков на FastAPI и Flutter: snake_case, ISO 8601,
  nullable `released_at`/`released_by_id`, enum статусов не изменён.
- Пароль согласован во всех схемах и формах: `8..128` символов и минимум одна
  русская или латинская буква.
- SSE дополнен polling раз в 10 секунд; это не меняет API и сохраняет данные при
  кратковременном таймауте reverse proxy.
- Цепочка миграций остаётся `001 → … → 007_school_buildings (head)`; новые
  маршруты и правила не требуют изменения схемы PostgreSQL.
- `.env.example` перечисляет `DATABASE_URL`, `SECRET_KEY`, JWT, CORS, rate limit
  и backup-настройки без production-секретов.
- Docker/TimeWeb: `entrypoint.sh` проверяет PostgreSQL, выполняет `alembic
  upgrade head`, запускает seed как модуль и Uvicorn на `0.0.0.0:8080`;
  `/health` и `/ready` находятся вне `/api/v1`.
- `build_runner` успешно пересоздал Retrofit/DI; Flutter analyzer — без
  замечаний; Flutter — 19/19 тестов; FastAPI — 45/45 тестов.
- Критические несоответствия контрактов не обнаружены. API готов к TimeWeb.
- Production web-сборка завершена успешно: основной bundle и 11 deferred
  ролевых модулей присутствуют; для всех 12 JavaScript-файлов создан и
  побайтово проверен gzip. Wasm dry-run предупреждает только о текущем
  `flutter_secure_storage_web`; JavaScript-сборку это не блокирует.
- Bootstrap `1.1.0-10` запускает Flutter сразу, а регистрацию service worker,
  распаковку и наполнение кеша выполняет в фоне. Первая отрисовка больше не
  ждёт до 5 секунд смены контроллера и загрузку CanvasKit/main bundle в кеш.
- После изменения production web-сборка повторена; gzip побайтово проверен для
  основного bundle, 11 deferred-модулей и 12 локальных CanvasKit-файлов.

## Проверка брендированной web-сборки — 2026-08-17

- Backend и Flutter API-контракты не изменялись.
- Генерация локализаций и Flutter analyzer завершены успешно.
- Production web build завершён успешно.
- HTML, PWA manifest и mobile metadata содержат новое название.
- Версия кеша `1.1.0-8` исключает показ старой темы после деплоя.
- Критические несоответствия для Timeweb не обнаружены.

## Проверка корпусов школы — 2026-08-17

| Метод | Путь | Тело / параметры | Результат |
|---|---|---|---|
| GET/POST | `/api/v1/school/buildings` | `name`, `address` | список или созданный корпус |
| PATCH/DELETE | `/api/v1/school/buildings/{id}` | `name`, `address` | обновление или безопасное удаление |
| PATCH | `/api/v1/school/buildings/{id}/status` | `is_active` | изменённый статус |
| GET/POST/PATCH | `/api/v1/school/classes` | `building_id`, `name` | класс с `building_name` |
| GET/POST/PATCH | `/api/v1/school/teachers` | `building_id`, `class_ids` | учитель и классы одного корпуса |
| GET/POST/PATCH | `/api/v1/school/guards` | `building_id` | сотрудник охраны корпуса |
| GET | `/api/v1/school/students` | query `building_id`/`class_id` | ученики выбранного корпуса |
| GET | `/api/v1/school/exit-requests` | query `building_id` | заявки выбранного корпуса |

- Flutter и FastAPI используют одинаковые snake_case-поля и общий base URL
  `https://obaldevshi-gbou-security-ac8a.twc1.net/api/v1`.
- Bearer-авторизация и ролевое ограничение `school_admin` сохранены.
- Миграции образуют цепочку до `007_school_buildings (head)`; существующим
  школам, классам, учителям, охранникам и заявкам назначается основной корпус.
- Docker запускает `app.main:app` на `0.0.0.0:8080`; `/health` и `/ready`
  присутствуют.
- Flutter analyzer — без замечаний; Flutter — 19 тестов; FastAPI — 45 тестов.
- Production web-сборка и gzip-сжатие завершены успешно.
- Предупреждение wasm касается `flutter_secure_storage_web` и не влияет на
  текущую JavaScript/CanvasKit-сборку.
- Критические несоответствия для Timeweb не обнаружены.
