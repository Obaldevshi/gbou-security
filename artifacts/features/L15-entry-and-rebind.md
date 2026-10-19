# L15 — чистый вход и локальная перепривязка Raspberry

Дополнение L16: сохранённая БД возвращается ТОЛЬКО в прежние школу И корпус.
Root worker/SQLite guards отклоняют другой building_id, включая неактивные
чужие записи. Новый реестр может содержать несколько главных устройств школы;
authorize выбирает building_overview, а не общий legacy overview.

19.10.2026, прямой запрос владельца. Реализация в исходниках, без изменения
рабочей привязки/данных, публикации или сборки. Тесты и анализатор отдельно разрешены.

## Интерфейс

Android/web: название, логин, пароль, Войти. Без публичных кнопок demo,
school-discovery/settings и QR scanner. Discovery остаётся автоматическим;
явный центральный вход сохраняется на отдельном /system-login, не добавляя
основную кнопку. Privacy/licenses — нижние небольшие текстовые ссылки с
нормальным контрастом и touch48px. Полные разделы остаются в профиле.
Scanner доступен из профиля только school_admin/super_admin, с route guard.
Внешний /connect/<UUID> сохраняет отдельную центральную admin-аутентификацию:
это нужно при остановленном школьном сервере. Demo fixtures не удаляются,
публичного входа в demo нет; инструкция модерации потребует отдельного доступа.

Киоск: «Устройство» сверху слева и на входе, и в очереди. Диалог статуса,
предупреждение об остановке школы, повторный центральный admin login/password,
явный ввод ОТВЯЗАТЬ. Guard/teacher не могут запустить операцию. Пароль только
в памяти запроса к фиксированному central HTTPS, токен не в storage/job/log.

## Границы и контракт

Новых таблиц и cloud API нет. Центральные device-admin/login и own-school
overview уже проверяют роль/активность/scope/password version. Работающий
writer подтверждается scoped heartbeat. У локального kiоск bridge только
GET /local/device и POST /local/device/rebind, Unix socket root0600, фиксированные
команды worker. POST: JSON<=8KiB, custom action header, loopback Host/Origin,
confirmation; 401 wrong credentials,403foreign/temporary,409busy,503not installed.
Никаких произвольных команд/путей/URL от клиента. Повторная проверка scope в worker.

Root service устанавливается отдельно, не через JavaScript updater. Пока не
установлен, кнопка объясняет недоступность, не предлагает удалять файлы.
Школьные данные не удаляются. Primary: USB encrypted DB/config restore и полная
сверка перед fencing/quarantine, новый QR, восстановление только той же школы и корпуса
и primary-роли, ожидание РУЧНОЙ verified activation, затем запуск и CURRENT backup.
Перенос старой БД в другую школу/корпус и автоматическое понижение primary запрещены.
Terminal: нет SQLite/API/WG; отзыв собственной старой terminal-регистрации после
admin auth, private quarantine, fresh QR, штатная terminal configuration.
Primary на бывшем terminal требует отдельной установки, не пустого writer.
Wi-Fi/SSH/DNS/адреса/услуги не меняются. Interrupted preflight/moves fail closed,
без небезопасного автоматического rollback. Resume только известных стабильных фаз.

## Проверки

Добавить изолированные auth/ownership/size/origin/job tests, guard routes,
clean login/footer, existing PIN/discovery/QR tests; analyzer. Не проводить
отвязку production ради теста. Проверка экрана800x480/телефона и фактической
перепривязки отдельного устройства остаётся ручной приёмкой. Демо-функцию
модерации не считать доступной после удаления публичной кнопки.
