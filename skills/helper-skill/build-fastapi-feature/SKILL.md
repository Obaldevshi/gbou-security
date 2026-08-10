---
name: build-fastapi-feature
description: Спроектировать или реализовать FastAPI-фичу со слоями model, schema, repository, service и route по SOLID и частичной Clean Architecture. Использовать при добавлении endpoint, CRUD-функции, бизнес-правил, таблицы, миграции или исправлении смешанных обязанностей backend.
---

# Архитектура FastAPI-фичи

1. Прочитать карточку функции, Flutter-контракт и существующую фичу `categories` как ориентир структуры, а не как код для слепого копирования.
2. Зафиксировать до реализации: методы и пути, авторизацию, request/response schemas, статусы, ошибки, владение данными и транзакционные правила.
3. Разнести ответственность:

```text
app/models/        # SQLAlchemy persistence
app/schemas/       # Pydantic transport contracts
app/repositories/  # запросы и сохранение
app/services/      # бизнес-правила и сценарии
app/api/v1/        # HTTP, Depends, status codes
app/core/          # общие зависимости, ошибки, responses
alembic/versions/  # изменения схемы БД
```

4. Соблюдать направление вызовов: `route → service → repository → model`. Route не выполняет SQL, repository не содержит HTTP и бизнес-решения, service не зависит от FastAPI request/response objects.
5. Передавать repository в constructor service. В `core/dependencies.py` собирать `Repository(db) → Service(repository)`, чтобы service можно было тестировать mock-repository без базы.
6. Сохранять единый sync SQLAlchemy-подход шаблона; не вводить частично async ORM. Не выполнять блокирующие внешние HTTP-вызовы в sync repository.
7. Ограничивать выборки текущим пользователем на уровне repository (`id + user_id`), не раскрывать существование чужих объектов и не доверять `user_id` из request body.
8. Валидировать форму данных в Pydantic, бизнес-ограничения — в service, допустимые сортировки/фильтры — whitelist в repository.
9. Использовать типизированные response schemas вместо неструктурированного `Any`, согласованные сообщения и общие исключения `NotFoundError`, `ConflictError`, `ValidationError`, `UnauthorizedError`.
10. Определить одного владельца транзакции. Для многошагового сценария commit/rollback должен охватывать весь service-case; не оставлять частично сохранённые данные.
11. При изменении model создать новую Alembic migration. Не переписывать уже применённую миграцию; проверить upgrade и downgrade на логическую полноту.
12. Подключить router в `app/api/v1/router.py`, dependency в `app/core/dependencies.py`, exports и сообщения. Не менять `/api/v1` без синхронного изменения Flutter.
13. Проверить безопасность: Bearer auth, ownership, отсутствие секретов в логах, ограничение pagination, корректные 401/403/404/409 и отсутствие лишних полей ответа.
14. Добавить unit-тесты service с mock-repository и проверки repository/route для критических запросов. Тесты не должны требовать Timeweb.
15. Сверить контракт с Flutter request/response models и `$13-check-api-timeweb`, затем выполнить форматирование, доступные тесты и `python -m compileall app`.

Не добавлять слои ради количества файлов: небольшая фича может иметь по одному модулю на слой, но границы ответственности и направление зависимостей должны сохраняться.
