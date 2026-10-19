# L16 — независимый основной узел каждого корпуса

## Выпуск1.8.0+14 — начат19.10.2026

По отдельному разрешению владельца собраны постоянной подписью APK, central
и school web. APK SHA2568ee6306a76e2d16c3e1b5bc105e581ceeb448b732804d1535521152818a0e65d.
Повторно255backend +14kiosk/8subtests прошли. Дополнительные regression gates:
scope_version2 при выключенном building mode возвращает409 без изменения
legacy topology; WireGuard renderer idempotent, без накопления пустых строк.
Gateway code-only updated19.10: protected network directives/credentials
unchanged, legacy host floors сохранены, все прежние службы active.
Перед migration016 сохранён свежий зашифрованный repeatable-read logical
snapshot всех17центральных таблиц015; decrypted SHA/counts verified, без
plaintext disk. PostgreSQL restore отдельно не тестировался. Private snapshot
и его receiver не включаются ни в исходники, ни в web/APK.
Ниже «локально/не выполнен» — исходный план этой итерации; текущий rollout
ещё НЕ завершён. Flag на центре остаётся OFF, рабочая Pi ещё не обновлялась.
Pi вернулась домой192.168.1.85; TCP22 отвечает, но SSH remote закрывает
соединение до key exchange/auth. Не обходить host verification, не включать
building mode и не заявлять hardware cutover до восстановления SSH/preflight.

Запрос владельца 19.10.2026 заменяет прежнее правило «один primary на школу».
Рабочий корпус 1 / school_id=2 сохраняет SQLite и school-2036.gbousecurity.ru.
Эта итерация локальная: миграции, установка и публикация отдельно, без изменения
рабочих данных, USB, Wi-Fi, SSH и старых адресов.

## Контракт

- Школа — административная группа. Единица writer/поколения/резервирования URL —
  (school_id, building_id). Один active primary на корпус, не на школу.
- QR всегда выбирает школу, активный корпус и primary/terminal. Terminal не
  принимает базу и обращается только к primary своего корпуса.
- URL привязан к корпусу, не к SD/UUID устройства. Замена primary сохраняет URL,
  увеличивает только его generation и отзывает только primary того же корпуса.
- Облачный control plane хранит школы, корпуса, администраторов и сетевой реестр.
  Между корпусами не копируются ученики, учителя, заявки, журналы или пароли
  учителей. Зеркалирование разрешено только центральным администраторам и
  настройкам своего корпуса.
- Новые адреса: <школьный-slug>-<порядковый-номер-корпуса>.gbousecurity.ru;
  номер закрепляется при выделении. Существующий адрес сохраняется без редиректа.
- Существующий школьный endpoint остаётся как legacy metadata. Новая таблица
  building_endpoints с UNIQUE(school_id, building_id), slug/legacy hostname и
  primary UUID unique. Миграция копирует только однозначно установленный current
  primary с известным корпусом, не перемещает и не удаляет школьные данные.
- Указатель логина публикуется и заменяется независимо каждым корпусом. Если
  администратор есть в нескольких корпусах, нельзя угадывать сервер или
  отправлять пароль по нескольким адресам: нужен явный выбор корпуса.
- Перепривязка с сохранением базы разрешена только в тот же school+building.
  Перенос в другой корпус — отдельная миграция, не QR-перепривязка.

## Приёмка

Два primary разных корпусов живут одновременно; смена/отзыв одного не меняет
второй. Terminal другого корпуса запрещён. Sync отдаёт только свой корпус и
разрешённых администраторов. Старые single-building устройства и адрес не
ломаются. Старые клиенты не должны молча использовать школьный общий primary
для другого корпуса. Миграция/обратная миграция проверяются на временной SQLite;
небезопасный downgrade при нескольких узлах блокируется.

## Реализовано локально

- Миграция016: building_endpoints + HMAC-указатели по endpoint, прежние таблицы
  и персональные записи не удаляются. Current legacy primary копируется только
  с доказанным корпусом и совпадающим поколением. Если legacy-реестр поменялся
  между миграцией и включением флага, startup preflight блокирует переход.
- QR context: networking_scope/building_overviews, Flutter использует generation
  нужного устройства, показывает отдельные адреса, terminal разрешён только
  после primary того же корпуса. Старый клиент без scope_version=2 отклоняется.
  Chief «Адрес и устройства» открывает единый QR/control-plane экран.
- Node/config: свой корпус и относящиеся к нему/общешкольные admins. Учителей,
  учеников, заявки он не выдаёт. Current node получает и is_active=false своего
  корпуса, но внешний маршрут/discovery отключённого корпуса исключаются.
- Sync сравнивает GBOU_BUILDING_ID и snapshot.building_id до первой записи.
  Local startup/import проверяют единственные школу+корпус, всех пользователей,
  классы/учеников/заявки и FK. Смешанная база отвергается без обрезания данных.
  School-wide credential в новом режиме node/config не получает.
- Discovery /destinations получает digest, возвращает адреса только одной школы.
  Для общего admin Flutter предлагает корпус ДО password request. Выбор живёт
  5минут в RAM, проверяется заново против fresh lookup. После успешного login
  дополнительно сравниваются school_id и node_building_id. Cache обновляется
  только после успешного пароля. Отмена/чужой адрес не отправляют пароль.
  Старый single-result /resolve wire сохранён; fallback туда только при
  route-level404 старого API, не при отрицательном lookup/TLS/rate-limit.
- Gateway manifest v2: старый worker отвергает его, сохраняя прошлый конфиг.
  Новый renderer проверяет unique building writer, антиоткат generation идёт
  по корпусу/постоянному hostname. Legacy floor переносится только по известному
  hostname/explicit pin. Неоднозначная миграция блокируется; TLS не ослаблен.
- L15 rebind возвращает БД только в прежние school+building+primary+hostname,
  проверяет и неактивные чужие строки, для building enrollment фиксирует
  GBOU_BUILDING_ID перед запуском. Рабочую Pi эта итерация не отвязывала.

## Проверки19.10.2026

Полный isolated backend+kiosk набор:267passed,8subtests, один существующий
Starlette/httpx deprecation warning. Flutter targeted login/discovery/QR/PIN:
31passed; analyzer no issues. Реальные016 upgrade/downgrade на временной SQLite,
independent writers/keys/terminal/sync/directory и gateway rollback floors,
mock/real transport mapping проверены. Login widget320×640/800×480,
130%text/light/dark; node--check JS, bash -n install-rebind, git diff --check.

Не выполнены: реальные несколько Pi/optical QR, новая browser/emulator
визуальная приёмка chooser, сборка, публикация и production cutover.

## Выпуск: ещё не выполнен

1. Сначала обновить gateway worker при BUILDING_NODES_ENABLED=false. Успешный
   legacy poll должен записать host floors; иначе нужен проверенный existing
   legacy pin. Не сбрасывать generation state ради прохождения проверки.
2. Encrypted backup + короткая пауза изменений ТОПОЛОГИИ. Применить016 и
   сравнить UUID/generation/hostname/building с фактическим current primary.
   Не повторять cloud→Pi import и не включать cloud writer.
3. Проверить read-only snapshot текущей SQLite на single-building scope,
   code-only обновить Pi. GBOU_BUILDING_ID взять из проверенной регистрации
   (нынешний корпус1:1). Scope двух сторон config включается в одном окне;
   промежуточный sync mismatch должен отказать, а не менять dataset.
4. Выпустить совместимые API/central+school web/APK, включить
   BUILDING_NODES_ENABLED=true, проверить startup preflight, scoped sync,
   directory, v2 gateway, прежний URL и настоящие teacher/guard заявки.
5. Новый корпус: новая SD/уникальные UUID/WG/token/API-secret, отдельные SQLite
   и USB. Подготовка своего API/HTTPS/базы и verified USB restore обязательны
   ДО ручной activation. Pending primary не получает node/config с admin hashes;
   нельзя обходить это ограничение автоматической активацией пустого узла.
   Полный school-wide export для другого корпуса неприменим.
6. QR задаёт реестр и роль; автоматическая установка всего fresh primary stack
   одним QR в эту итерацию не входит. Подготовку данных подтверждает оператор.
   Terminal — только дополнительный пост того же корпуса, без своей БД.
   Аппаратную приёмку пяти корпусов не считать выполненной на одном writer.

Новый режим по умолчанию выключен. В этой итерации не было сборок, push,
деплоя, DNS/ключей/платных услуг, runtime Pi, удаления/переноса рабочих данных.
