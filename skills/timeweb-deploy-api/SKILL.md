---
name: timeweb-deploy-api
description: Развернуть managed PostgreSQL и FastAPI App через Dockerfile в Timeweb Cloud. Использовать после проверки API-контрактов или для продолжения незавершённого этапа API без локального Docker Compose.
---

# Timeweb: PostgreSQL и FastAPI

1. Прочитать `artifacts/timeweb-progress.md` и `artifacts/api-timeweb-check.md`.
2. Проверить доступ Timeweb к GitHub-репозиторию и выбранной ветке.
3. Показать пользователю стоимость выбранных PostgreSQL и App-тарифов; создавать ресурсы только после подтверждения.
4. Создать managed PostgreSQL без публичного IP в новой приватной сети и дождаться рабочего статуса.
5. Получить из панели имя БД, пользователя, приватный host и порт. URL-кодировать пароль при формировании `DATABASE_URL`; не сохранять полную строку в git или артефактах.
6. Создать App Platform из Dockerfile со значениями:

| Поле | Значение |
|---|---|
| Репозиторий и ветка | текущая ветка развёртывания |
| Директория проекта | `/init-api` |
| Имя App | латиницей, например `my-app-api` |
| Порт | `8080` |
| Build/start команды | оставить пустыми |
| Приватная сеть | та же, что у PostgreSQL |
| Healthcheck path | оставить пустым на первом деплое |

7. Добавить в Timeweb переменные `DATABASE_URL`, `SECRET_KEY`, `ALGORITHM=HS256`, `ACCESS_TOKEN_EXPIRE_MINUTES=30`, `APP_NAME`, `APP_VERSION`, `DEBUG=false` и `CORS_ORIGINS=http://localhost:3000`. Значения вводить без префикса `KEY=`.
8. Дождаться деплоя и проверить логи: миграции завершились, Uvicorn слушает `0.0.0.0:8080`, секреты не напечатаны.
9. Проверить `https://<tech-domain>/health`, `/ready` и `/docs`.
10. Записать в `artifacts/timeweb-progress.md` только публичный tech URL и статусы проверок.
11. Обновить локальный `init-app/assets/env/.env`:

```dotenv
BASE_URL=https://<tech-domain>/api/v1
BASE_URL_WEB=https://<tech-domain>/api/v1
```

Не переходить к web, пока `/health` и `/ready` не работают, кроме явного решения пользователя.
