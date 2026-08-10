---
name: timeweb-domains
description: Привязать домены к Flutter Web и FastAPI Apps в Timeweb, настроить HTTPS, CORS и клиентские URL. Использовать после успешного размещения API и web либо при смене домена.
---

# Timeweb: домены и CORS

1. Прочитать `artifacts/timeweb-progress.md`; убедиться, что API и web работают на tech URL.
2. Спросить корневой домен и подтвердить схему: `<root>` и `www.<root>` для web, `api.<root>` для FastAPI.
3. Перед покупкой домена показать актуальную цену в панели и запросить подтверждение. Не подключать платный SSL и балансировщик.
4. В разделе доменов создать `www` и `api`, затем привязать корень и `www` к web App, а `api` — к API App.
5. Проверить автоматически созданные DNS-записи до добавления ручных дублей. Дождаться выпуска бесплатного HTTPS-сертификата.
6. Не удалять tech-домены, пока новые адреса не прошли smoke-проверку.
7. Обновить `CORS_ORIGINS` API App:

```text
http://localhost:3000,https://<root>,https://www.<root>
```

8. Обновить локальный `init-app/assets/env/.env`:

```dotenv
BASE_URL=https://api.<root>/api/v1
BASE_URL_WEB=https://api.<root>/api/v1
```

9. Не запускать сборку. Попросить пользователя повторно выполнить `make build-web-prod` из `init-app/`; после его подтверждения отправить готовый `build/web` в ветку Timeweb и дождаться auto-deploy.
10. Передать пользователю `https://<root>`, `https://www.<root>` и `https://api.<root>` для ручной проверки web, авторизации и запросов с телефона.
11. Записать домены, DNS/HTTPS/CORS и факт передачи smoke-проверки пользователю в `artifacts/timeweb-progress.md`.

Если DNS уже обновлён публично, но не работает только в домашней сети, проверить с мобильного интернета и дождаться обновления локального DNS-кэша; не перезапускать Apps без причины.
