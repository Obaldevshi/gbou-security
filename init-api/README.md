# Backend Template API

Локальный FastAPI backend: JWT auth, профиль, Category CRUD, SQLAlchemy, Alembic и PostgreSQL.

## Запуск

```bash
cp .env.example .env
docker compose up --build
```

- API: `http://localhost:8000`
- Swagger: `http://localhost:8000/docs`
- health: `http://localhost:8000/health`
- readiness: `http://localhost:8000/ready`

## Команды

```bash
make dev
make migrate
make seed
make smoke
```

Для доступа с физического телефона используйте LAN IP компьютера в `init-app/assets/env/.env` и разрешите порт `8000` в firewall.

## Production

- TimeWeb health check: `GET /ready` на порту `8080`.
- Вход ограничен переменными `LOGIN_RATE_LIMIT` и `LOGIN_RATE_WINDOW_SECONDS`.
- Метрики процесса доступны главному администратору через `GET /api/v1/system/monitoring`.
- Резервная копия: `./scripts/backup_database.sh`. `BACKUP_DIR` обязательно
  подключается к постоянному хранилищу; локальная файловая система контейнера
  не считается резервной копией.
- После первого входа каждая административно созданная учётная запись обязана
  заменить временный пароль.
