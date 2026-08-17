// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appName => 'Система учета выхода учащихся';

  @override
  String get appTagline => 'Безопасный и понятный выход учащихся';

  @override
  String get welcomeBack => 'С возвращением';

  @override
  String get loginSubtitle => 'Войдите, чтобы продолжить';

  @override
  String get loginPortalTitle => 'Единый защищённый вход';

  @override
  String get loginPortalDescription => 'Используйте учётную запись вашей школы';

  @override
  String get loginFeatureUnified => 'Одна система для всей школы';

  @override
  String get loginFeatureRoles => 'Отдельный доступ для каждой роли';

  @override
  String get loginFeatureProtected => 'Данные школ надёжно разделены';

  @override
  String get loginSupportHint =>
      'Нет доступа? Обратитесь к администратору школы';

  @override
  String get createAccount => 'Создать аккаунт';

  @override
  String get registerSubtitle => 'Заполните данные для регистрации';

  @override
  String get login => 'Вход';

  @override
  String get loginField => 'Логин';

  @override
  String get loginHint => 'Введите логин';

  @override
  String get register => 'Регистрация';

  @override
  String get email => 'Электронная почта';

  @override
  String get emailHint => 'Введите email';

  @override
  String get password => 'Пароль';

  @override
  String get passwordHint => 'Введите пароль';

  @override
  String get createPasswordHint => 'Придумайте пароль';

  @override
  String get firstName => 'Имя';

  @override
  String get firstNameHint => 'Введите имя';

  @override
  String get lastName => 'Фамилия';

  @override
  String get lastNameHint => 'Введите фамилию';

  @override
  String get confirmPassword => 'Подтвердите пароль';

  @override
  String get dontHaveAccount => 'Нет аккаунта?';

  @override
  String get alreadyHaveAccount => 'Уже есть аккаунт?';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get signIn => 'Войти';

  @override
  String get showPassword => 'Показать пароль';

  @override
  String get hidePassword => 'Скрыть пароль';

  @override
  String get userMenu => 'Меню пользователя';

  @override
  String get user => 'Пользователь';

  @override
  String get newRequest => 'Новая заявка';

  @override
  String get activeRequests => 'Активные';

  @override
  String get requestHistory => 'История';

  @override
  String get teacherWorkspace => 'Рабочее пространство учителя';

  @override
  String get teacherRequestComingSoon =>
      'Создание заявки будет добавлено в следующей функции MVP.';

  @override
  String get teacherRequestIntro => 'Оформите разрешение на выход ученика';

  @override
  String get requestFormTitle => 'Данные заявки';

  @override
  String get requestFormDescription =>
      'Выберите ученика, причину и запланированное время выхода.';

  @override
  String get requestClass => 'Класс';

  @override
  String get requestSelectClass => 'Выберите класс';

  @override
  String get requestClassRequired => 'Выберите класс';

  @override
  String get requestNoClasses => 'Нет доступных классов';

  @override
  String get requestStudent => 'Ученик';

  @override
  String get requestSelectStudent => 'Выберите ученика';

  @override
  String get requestStudentRequired => 'Выберите ученика';

  @override
  String get requestNoStudents => 'В этом классе нет доступных учеников';

  @override
  String get requestReason => 'Причина выхода';

  @override
  String get requestSelectReason => 'Выберите причину';

  @override
  String get requestReasonRequired => 'Выберите причину';

  @override
  String get requestReasonParentNote => 'По заявлению родителя';

  @override
  String get requestReasonHealth => 'По состоянию здоровья';

  @override
  String get requestReasonOther => 'Своя причина';

  @override
  String get requestCustomReason => 'Своя причина';

  @override
  String get requestCustomReasonHint => 'Кратко опишите причину';

  @override
  String get requestCustomReasonRequired => 'Укажите свою причину';

  @override
  String get requestCustomReasonTooShort =>
      'Причина должна содержать не менее 3 символов';

  @override
  String get requestCustomReasonNotAllowed =>
      'Своя причина допустима только для варианта «Своя причина»';

  @override
  String get requestScheduledAt => 'Время выхода';

  @override
  String get requestChooseDateTime => 'Выберите дату и время';

  @override
  String get requestChooseDate => 'Выберите дату выхода';

  @override
  String get requestChooseTime => 'Выберите время выхода';

  @override
  String get requestScheduledRequired => 'Выберите время выхода';

  @override
  String get requestScheduledInPast => 'Укажите будущее время выхода';

  @override
  String get requestScheduledTimezoneRequired =>
      'Укажите время выхода с часовым поясом';

  @override
  String get requestSubmit => 'Отправить заявку';

  @override
  String get requestSent => 'Заявка отправлена';

  @override
  String get requestPendingStatus => 'Статус: ожидает выхода';

  @override
  String get requestGoToActive => 'Перейти в активные';

  @override
  String get requestClassUnavailable => 'Класс недоступен';

  @override
  String get requestStudentUnavailable => 'Ученик недоступен';

  @override
  String get requestActiveExists =>
      'Для этого ученика уже есть ожидающая заявка';

  @override
  String get requestSendFailed =>
      'Не удалось отправить заявку. Повторите позже';

  @override
  String get activeRequestsComingSoon =>
      'Список активных заявок будет добавлен после создания заявки.';

  @override
  String get historyComingSoon =>
      'История появится после обработки заявки охраной.';

  @override
  String get guardQueue => 'Ожидают выхода';

  @override
  String get guardWorkspace => 'Рабочее пространство охраны';

  @override
  String get noExitRequests => 'Заявок на выход нет';

  @override
  String get guardQueueComingSoon =>
      'Очередь заявок будет добавлена в следующей функции охраны.';

  @override
  String get guardQueueDescription =>
      'Проверьте разрешение и подтвердите выход ученика';

  @override
  String get guardQueueAutoRefresh => 'Новые заявки появятся автоматически';

  @override
  String get guardTeacher => 'Учитель';

  @override
  String get guardRelease => 'Отпустить';

  @override
  String guardReleaseStudent(String studentName) {
    return 'Подтвердить выход ученика $studentName';
  }

  @override
  String get guardReleaseSuccess => 'Выход ученика подтверждён';

  @override
  String get guardAlreadyProcessed => 'Заявка уже обработана';

  @override
  String get guardRequestUnavailable => 'Заявка недоступна';

  @override
  String get guardReleaseFailed => 'Не удалось подтвердить выход';

  @override
  String get guardQueueLoadFailed => 'Не удалось загрузить очередь';

  @override
  String get guardQueueRefreshFailed => 'Не удалось обновить очередь';

  @override
  String get requestPendingStatusShort => 'Ожидает выхода';

  @override
  String get teacherActiveDescription =>
      'Заявки, которые ожидают обработки охраной';

  @override
  String get teacherHistoryDescription =>
      'Завершённые заявки и фактическое время выхода';

  @override
  String get teacherRequestReleasedNotice => 'Заявка обработана охраной';

  @override
  String get teacherRequestsRefreshFailed => 'Не удалось обновить заявки';

  @override
  String get teacherRequestsLoadFailed => 'Не удалось загрузить заявки';

  @override
  String get noActiveRequests => 'Активных заявок нет';

  @override
  String get noRequestHistory => 'История пока пуста';

  @override
  String get createRequestAction => 'Создать заявку';

  @override
  String get openActiveRequests => 'Открыть активные заявки';

  @override
  String get teacherReleasedAt => 'Фактическое время выхода';

  @override
  String get requestReleasedStatus => 'Отпустил';

  @override
  String get unsupportedRole => 'Интерфейс этой роли пока недоступен.';

  @override
  String get or => 'или';

  @override
  String get createAccountButton => 'Создать аккаунт';

  @override
  String get accountCreatedSuccessfully => 'Аккаунт создан';

  @override
  String get home => 'Главная';

  @override
  String get homeWelcome => 'Дизайн-система';

  @override
  String get homeDescription =>
      'Цвета, типографика и компоненты. Меняйте тему и язык в реальном времени.';

  @override
  String get homeFeatureCategories =>
      'Управление категориями: создание, просмотр, редактирование и удаление';

  @override
  String get homeFeatureProfile => 'Профиль, тема и язык';

  @override
  String get homeUiKitTitle => 'Набор компонентов';

  @override
  String get homeUiKitSubtitle => 'Дизайн-система';

  @override
  String get homeUiKitDescription =>
      'Лёгкие сплошные поверхности, токены и компоненты для плавной работы.';

  @override
  String get homeSectionAppearance => 'Оформление';

  @override
  String get homeSectionColors => 'Цвета';

  @override
  String get homeSectionTypography => 'Типографика';

  @override
  String get homeSectionComponents => 'Компоненты';

  @override
  String get homeSectionTokens => 'Токены';

  @override
  String get colorPrimary => 'Основной';

  @override
  String get colorPrimaryLight => 'Светлый основной';

  @override
  String get colorPrimaryDark => 'Тёмный основной';

  @override
  String get colorSecondary => 'Дополнительный';

  @override
  String get colorSuccess => 'Успех';

  @override
  String get colorWarning => 'Предупреждение';

  @override
  String get colorError => 'Ошибка';

  @override
  String get colorSurface => 'Поверхность';

  @override
  String get colorBackground => 'Фон';

  @override
  String get homeShowDialog => 'Показать диалог';

  @override
  String get homeDialogDemoTitle => 'Демо диалога';

  @override
  String get homeDialogDemoContent =>
      'Это диалог подтверждения из набора компонентов.';

  @override
  String get homeFontFamily => 'Шрифт';

  @override
  String get homeFontRegular => 'Обычный';

  @override
  String get homeFontMedium => 'Средний';

  @override
  String get homeFontBold => 'Жирный';

  @override
  String get homeTypeDisplayLarge => 'Крупный L';

  @override
  String get homeTypeDisplayMedium => 'Крупный M';

  @override
  String get homeTypeHeadlineMedium => 'Заголовок M';

  @override
  String get homeTypeTitleLarge => 'Подзаголовок L';

  @override
  String get homeTypeTitleMedium => 'Подзаголовок M';

  @override
  String get homeTypeBodyLarge => 'Основной L';

  @override
  String get homeTypeBodyMedium => 'Основной M';

  @override
  String get homeTypeLabelMedium => 'Метка M';

  @override
  String get homeTypeLabelSmall => 'Метка S';

  @override
  String get homeSpacing => 'Отступы';

  @override
  String get homeRadius => 'Скругление';

  @override
  String get homeGlassTokens => 'Поверхности';

  @override
  String get homeSpacingExtraSmall => 'Очень малый';

  @override
  String get homeSpacingSmall => 'Малый';

  @override
  String get homeSpacingMedium => 'Средний';

  @override
  String get homeSpacingLarge => 'Большой';

  @override
  String get homeSpacingExtraLarge => 'Очень большой';

  @override
  String get homeRendering => 'Отрисовка';

  @override
  String get homeRenderingSolid => 'Сплошная';

  @override
  String get homeBorder => 'Граница';

  @override
  String get homeDemoInputLabel => 'Пример поля';

  @override
  String get homeDemoInputHint => 'Введите текст…';

  @override
  String get homeToggleLoading => 'Переключить загрузку';

  @override
  String get homeGlassOnLight => 'Обычная';

  @override
  String get homeGlassPanel => 'Панель';

  @override
  String get homeGlassOnGradient => 'Акцентная';

  @override
  String get homeTypographySample =>
      'Съешь же ещё этих мягких французских булок';

  @override
  String get categories => 'Категории';

  @override
  String get profile => 'Профиль';

  @override
  String get profileSectionAccount => 'Аккаунт';

  @override
  String get addCategory => 'Добавить категорию';

  @override
  String get editCategory => 'Редактировать категорию';

  @override
  String get deleteCategory => 'Удалить категорию';

  @override
  String get categoryName => 'Название категории';

  @override
  String get categoryNameRequired => 'Укажите название категории';

  @override
  String get categoryNameTooShort => 'Название слишком короткое';

  @override
  String get updateCategory => 'Обновить категорию';

  @override
  String get deleteCategoryConfirmation => 'Удалить эту категорию?';

  @override
  String get categoryDeletedSuccessfully => 'Категория удалена';

  @override
  String get categoryUpdatedSuccessfully => 'Категория обновлена';

  @override
  String get noCategoriesYet => 'Категорий пока нет';

  @override
  String get noCategoriesFound => 'Категории не найдены';

  @override
  String get addFirstCategory => 'Добавьте первую категорию';

  @override
  String get tryDifferentSearch => 'Попробуйте другой запрос';

  @override
  String get searchCategories => 'Поиск категорий';

  @override
  String get addNewCategoryTooltip => 'Добавить категорию';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get updatePersonalInfo => 'Обновить личные данные';

  @override
  String get personalInformation => 'Личная информация';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get changePassword => 'Сменить пароль';

  @override
  String get changePasswordTitle => 'Смена пароля';

  @override
  String get requiredPasswordTitle => 'Смените временный пароль';

  @override
  String get requiredPasswordDescription =>
      'Для продолжения задайте личный пароль. После смены потребуется войти ещё раз.';

  @override
  String get passwordStrengthHint =>
      'Не менее 12 символов: заглавная и строчная буквы, цифра и специальный символ';

  @override
  String get changePasswordButton => 'Обновить пароль';

  @override
  String get security => 'Безопасность';

  @override
  String get logout => 'Выйти';

  @override
  String get logoutConfirmation => 'Вы уверены, что хотите выйти?';

  @override
  String get delete => 'Удалить';

  @override
  String get edit => 'Изменить';

  @override
  String get cancel => 'Отмена';

  @override
  String get save => 'Сохранить';

  @override
  String get error => 'Ошибка';

  @override
  String get loading => 'Загрузка';

  @override
  String get retry => 'Повторить';

  @override
  String get version => 'Версия';

  @override
  String get currentPassword => 'Текущий пароль';

  @override
  String get newPassword => 'Новый пароль';

  @override
  String get confirmNewPassword => 'Подтвердите новый пароль';

  @override
  String get enterCurrentPassword => 'Введите текущий пароль';

  @override
  String get enterNewPassword => 'Введите новый пароль';

  @override
  String get confirmYourNewPassword => 'Подтвердите новый пароль';

  @override
  String get currentPasswordRequired => 'Укажите текущий пароль';

  @override
  String get newPasswordRequired => 'Укажите новый пароль';

  @override
  String get passwordChangedSuccessfully => 'Пароль изменён';

  @override
  String get profileUpdatedSuccessfully => 'Профиль обновлён';

  @override
  String get accountDeletedSuccessfully => 'Аккаунт удалён';

  @override
  String get deleteAccount => 'Удалить аккаунт';

  @override
  String get deleteAccountConfirmation => 'Удалить аккаунт безвозвратно?';

  @override
  String get deleteAccountDescription =>
      'Безвозвратно удалить аккаунт и все данные';

  @override
  String get deleteAccountWarning =>
      'Это действие нельзя отменить. Все данные будут удалены.';

  @override
  String get dangerZone => 'Опасная зона';

  @override
  String get manageAccount => 'Управление аккаунтом';

  @override
  String get emailRequired => 'Укажите email';

  @override
  String get emailInvalid => 'Введите корректный email';

  @override
  String get passwordRequired => 'Укажите пароль';

  @override
  String passwordTooShort(int minLength) {
    return 'Пароль должен быть не короче $minLength символов';
  }

  @override
  String newPasswordTooShort(int minLength) {
    return 'Новый пароль должен быть не короче $minLength символов';
  }

  @override
  String fieldRequired(String fieldName) {
    return 'Поле «$fieldName» обязательно';
  }

  @override
  String fieldTooShort(String fieldName, int minLength) {
    return 'Поле «$fieldName» должно быть не короче $minLength символов';
  }

  @override
  String nameLettersOnly(String fieldName) {
    return 'Поле «$fieldName» должно содержать только буквы';
  }

  @override
  String numberRequired(Object fieldName) {
    return 'Поле «$fieldName» обязательно';
  }

  @override
  String numberInvalid(Object fieldName) {
    return 'Поле «$fieldName» должно быть числом';
  }

  @override
  String numberMustBePositive(Object fieldName) {
    return 'Поле «$fieldName» должно быть больше нуля';
  }

  @override
  String get passwordsDontMatch => 'Пароли не совпадают';

  @override
  String get last7Days => 'Последние 7 дней';

  @override
  String get last30Days => 'Последние 30 дней';

  @override
  String get today => 'Сегодня';

  @override
  String get yesterday => 'Вчера';

  @override
  String get past => 'Ранее';

  @override
  String get ok => 'ОК';

  @override
  String get offlineBanner => 'Нет подключения к интернету';

  @override
  String get loadMore => 'Загрузить ещё';

  @override
  String get appearance => 'Оформление';

  @override
  String get appearanceDescription => 'Светлая, тёмная или системная тема';

  @override
  String get language => 'Язык';

  @override
  String get languageDescription => 'Язык интерфейса';

  @override
  String get languageSystem => 'Системный';

  @override
  String get languageEnglish => 'Английский';

  @override
  String get languageRussian => 'Русский';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get errorBadRequest => 'Некорректный запрос';

  @override
  String get errorUnauthorized => 'Не авторизован';

  @override
  String get errorAccessDenied => 'Доступ запрещён';

  @override
  String get errorNotFound => 'Не найдено';

  @override
  String get errorTimeout => 'Превышено время ожидания';

  @override
  String get errorValidation => 'Ошибка валидации';

  @override
  String get errorTooManyRequests => 'Слишком много запросов';

  @override
  String get errorServer => 'Ошибка сервера';

  @override
  String get errorBadGateway => 'Ошибка шлюза';

  @override
  String get errorServiceUnavailable => 'Сервис недоступен';

  @override
  String get errorGatewayTimeout => 'Таймаут шлюза';

  @override
  String get errorClient => 'Ошибка клиента';

  @override
  String get errorRequestCancelled => 'Запрос отменён';

  @override
  String get errorInvalidCredentials => 'Неверные учётные данные';

  @override
  String get errorResourceExists => 'Ресурс уже существует';
}
