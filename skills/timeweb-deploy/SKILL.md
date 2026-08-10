---
name: timeweb-deploy
description: Провести развёртывание FastAPI и Flutter Web из этого шаблона в Timeweb Cloud. Использовать после $13-check-api-timeweb, при первом размещении, продолжении прерванного развёртывания или проверке текущего статуса Timeweb.
---

# Развёртывание в Timeweb

1. Прочитать `artifacts/api-timeweb-check.md`; не начинать размещение при критических блокерах.
2. Создать при отсутствии `artifacts/timeweb-progress.md` по `assets/progress.template.md` и продолжать с первого незавершённого этапа.
3. Проверить, что нужная ветка отправлена в GitHub и видна интеграции Timeweb.
4. Перед созданием платного ресурса показать выбранный тариф и запросить явное подтверждение пользователя.
5. Не просить публиковать пароли и токены в чате, не записывать секреты в артефакты и не коммитить `.env`.
6. Выполнять этапы последовательно:
   - `../timeweb-deploy-api/SKILL.md` — PostgreSQL и FastAPI;
   - `../timeweb-deploy-web/SKILL.md` — Flutter Web;
   - `../timeweb-domains/SKILL.md` — домены, HTTPS, CORS и финальные URL.
7. После каждого этапа записывать статус, публичные URL и проверку без секретов.
8. Не добавлять landing, TMA, магазины, VPS, балансировщик или платный SSL.

Timeweb собирает API по `init-api/Dockerfile`. Flutter Web собирать локально и передавать как готовый `init-app/build/web`.
