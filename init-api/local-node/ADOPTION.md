# Действующая Raspberry → управляемый реестр

Это операторская процедура для существующей2036/ID2, а не новый публичный
способ подключения. Не запускать `install-pairing.sh` на рабочем сервере.
Ни миграции школьных записей, ни копирования SQLite обратно в cloud нет.

1. НаPi проверить API/kiosk/WG, резервирование USB и восстановление
   в отдельный файл. Записать fingerprint школьных таблиц и существующего
   credential, UUID и PUBLIC WG. Plaintext ключа не извлекать с Pi.
2. Опубликовать API с migration013 (nullablelegacy_hostname). Проверить
   cloud-only ready/deny. Web-контракт не изменён, новая Flutter-сборка не нужна.
3. Обновить gatewayrenderer/reconcile, сохранив root-only rollback файлов.
   Проверить dry-run прежнего manifest0, адрес школы по-прежнему200.
4. Pin текущего peer в `/etc/gbou-gateway/managed.json`:
   preserved_routes запись с hostname,school_id2,public_key,tunnel_ip10.77.203.2.
   При остановленном **только reconcile timer** установить managed_only=true.
   HAProxy/WG/школьный API не останавливать; это не смена writer.
5. В доверенной центральной серверной консоли подготовить JSONплан по схеме
   AdoptExistingPrimary, выполнить `python -m scripts.adopt_device --plan FILE`
   (dry-run), затем ту же команду с `--apply`. В плане только publicmetadata
   и SHA256 от уже хешированного ключа (диагностический fingerprint), НЕ token.
   Подтверждение same-writer/USB-restore должно быть фактически проверено.
6. Центральная атомарная операция сохраняет короткий slug, добавляет
   legacy_hostname=school-2036.gbousecurity.ru, активный primary/generation1
   с **тем же хешем** sync-key, отключает legacy credential row. Ключ не
   создаётся/не меняется/не передаётся. Чужая школа/корпус, неверный
   fingerprint, конкурирующий primary/generation — отказ без частичного commit.
7. Gatewaydry-run получает1managedschool с прежнимIP/key/URL. Применить
   через штатную службу с rollback, без wgdown/up. Ownership/state записывается
   даже если сетевые файлы идентичны. Включить reconcile timer обратно.
8. После проверки manifest и центрального deviceheartbeat сохранить на Pi
   `/etc/gbou-device/device.json`0600: publicметаданные, cloud_origin,
   token_file=/etc/gbou-local/node.token. Ключ не копируется, APIenv не меняется.
   Установить device_heartbeat.py и gbou-device-heartbeat service/timer60сек.
9. Проверить sync, heartbeat/is_primary, publicready/TLS/Hostdeny, USBrestore,
   отсутствие изменений школьных записей, непрерывность API/kiosk/WG.
   После этого QRдети доступны в своей школе (только регистрируются, не
   получают SQLite; вход обычного охранника остаётся обязательным).

## Безопасность отката

Если центральный commit ещё не выполнен: вернуть прежний gatewaypin и
timer; текущий маршрут/данные никуда не переносились. После commit, но
до появления дочерних устройств: rootCLI
`python -m scripts.adopt_device --plan FILE --apply --rollback-generation 1`
снова делает прежнюю legacyзапись активной, отзывает только этотprimary и
повышает generation. Gatewaypin managed_only=false разрешается вернуть
**только после такого явного отката**. Не восстанавливать cloudшкольную БД.

При нормальной работе managed_only=true означает: исчезнувшая из manifest
школа НЕ возвращается к прежнему peer. Это предотвращает обход отзыва и
случайный доступ к устаревшему writer. При настоящей будущей замене Pi
канонический URL остаётся на SchoolEndpoint, новый10.78.xpeer заменяет
старый; обязательны fencing/проверенная база/CAS, как и до adoption.

CLIповтор того же успешного плана идемпотентен. После смены generation или
добавления устройств автоматический откат запрещён. Не удалять записи
для обхода этой проверки. Диагностика выводит только статусы/счётчики,
не ФИО детей, пароли или сырой WireGuardконфиг.
