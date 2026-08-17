// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Student Exit Tracking System';

  @override
  String get appTagline => 'Safe and clear student dismissal';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get loginPortalTitle => 'Secure unified sign-in';

  @override
  String get loginPortalDescription => 'Use the account issued by your school';

  @override
  String get loginFeatureUnified => 'One system for the whole school';

  @override
  String get loginFeatureRoles => 'Dedicated access for every role';

  @override
  String get loginFeatureProtected => 'School data is securely isolated';

  @override
  String get loginSupportHint => 'No access? Contact your school administrator';

  @override
  String get createAccount => 'Create account';

  @override
  String get registerSubtitle => 'Fill in the details to get started';

  @override
  String get login => 'Login';

  @override
  String get loginField => 'Login';

  @override
  String get loginHint => 'Enter your login';

  @override
  String get register => 'Register';

  @override
  String get email => 'Email';

  @override
  String get emailHint => 'Enter your email';

  @override
  String get password => 'Password';

  @override
  String get passwordHint => 'Enter your password';

  @override
  String get createPasswordHint => 'Create a password';

  @override
  String get firstName => 'First name';

  @override
  String get firstNameHint => 'Enter your first name';

  @override
  String get lastName => 'Last name';

  @override
  String get lastNameHint => 'Enter your last name';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get dontHaveAccount => 'Don\'t have an account?';

  @override
  String get alreadyHaveAccount => 'Already have an account?';

  @override
  String get signUp => 'Sign up';

  @override
  String get signIn => 'Sign in';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get userMenu => 'User menu';

  @override
  String get user => 'User';

  @override
  String get newRequest => 'New request';

  @override
  String get activeRequests => 'Active';

  @override
  String get requestHistory => 'History';

  @override
  String get teacherWorkspace => 'Teacher workspace';

  @override
  String get teacherRequestComingSoon =>
      'Request creation will be added in the next MVP feature.';

  @override
  String get teacherRequestIntro => 'Create a student dismissal request';

  @override
  String get requestFormTitle => 'Request details';

  @override
  String get requestFormDescription =>
      'Select a student, reason, and scheduled dismissal time.';

  @override
  String get requestClass => 'Class';

  @override
  String get requestSelectClass => 'Select a class';

  @override
  String get requestClassRequired => 'Select a class';

  @override
  String get requestNoClasses => 'No classes available';

  @override
  String get requestStudent => 'Student';

  @override
  String get requestSelectStudent => 'Select a student';

  @override
  String get requestStudentRequired => 'Select a student';

  @override
  String get requestNoStudents => 'No available students in this class';

  @override
  String get requestReason => 'Dismissal reason';

  @override
  String get requestSelectReason => 'Select a reason';

  @override
  String get requestReasonRequired => 'Select a reason';

  @override
  String get requestReasonParentNote => 'Parent request';

  @override
  String get requestReasonHealth => 'Health reasons';

  @override
  String get requestReasonOther => 'Other reason';

  @override
  String get requestCustomReason => 'Other reason';

  @override
  String get requestCustomReasonHint => 'Briefly describe the reason';

  @override
  String get requestCustomReasonRequired => 'Enter the reason';

  @override
  String get requestCustomReasonTooShort =>
      'The reason must be at least 3 characters';

  @override
  String get requestCustomReasonNotAllowed =>
      'A custom reason is only allowed for Other reason';

  @override
  String get requestScheduledAt => 'Dismissal time';

  @override
  String get requestChooseDateTime => 'Select date and time';

  @override
  String get requestChooseDate => 'Select dismissal date';

  @override
  String get requestChooseTime => 'Select dismissal time';

  @override
  String get requestScheduledRequired => 'Select dismissal time';

  @override
  String get requestScheduledInPast => 'Select a future dismissal time';

  @override
  String get requestScheduledTimezoneRequired =>
      'Select a dismissal time with a time zone';

  @override
  String get requestSubmit => 'Send request';

  @override
  String get requestSent => 'Request sent';

  @override
  String get requestPendingStatus => 'Status: waiting to leave';

  @override
  String get requestGoToActive => 'Go to active requests';

  @override
  String get requestClassUnavailable => 'Class is unavailable';

  @override
  String get requestStudentUnavailable => 'Student is unavailable';

  @override
  String get requestActiveExists =>
      'This student already has a pending request';

  @override
  String get requestSendFailed => 'Could not send the request. Try again later';

  @override
  String get activeRequestsComingSoon =>
      'Active requests will be added after request creation.';

  @override
  String get historyComingSoon =>
      'History will appear after a guard processes a request.';

  @override
  String get guardQueue => 'Waiting to leave';

  @override
  String get guardWorkspace => 'Guard workspace';

  @override
  String get noExitRequests => 'No exit requests';

  @override
  String get guardQueueComingSoon =>
      'The request queue will be added in the next guard feature.';

  @override
  String get guardQueueDescription =>
      'Check the permission and confirm the student\'s dismissal';

  @override
  String get guardQueueAutoRefresh => 'New requests will appear automatically';

  @override
  String get guardTeacher => 'Teacher';

  @override
  String get guardRelease => 'Release';

  @override
  String guardReleaseStudent(String studentName) {
    return 'Confirm dismissal for $studentName';
  }

  @override
  String get guardReleaseSuccess => 'Student dismissal confirmed';

  @override
  String get guardAlreadyProcessed => 'The request has already been processed';

  @override
  String get guardRequestUnavailable => 'The request is unavailable';

  @override
  String get guardReleaseFailed => 'Could not confirm the dismissal';

  @override
  String get guardQueueLoadFailed => 'Could not load the queue';

  @override
  String get guardQueueRefreshFailed => 'Could not refresh the queue';

  @override
  String get requestPendingStatusShort => 'Waiting to leave';

  @override
  String get teacherActiveDescription =>
      'Requests waiting for guard processing';

  @override
  String get teacherHistoryDescription =>
      'Completed requests and actual dismissal time';

  @override
  String get teacherRequestReleasedNotice =>
      'The request was processed by the guard';

  @override
  String get teacherRequestsRefreshFailed => 'Could not refresh requests';

  @override
  String get teacherRequestsLoadFailed => 'Could not load requests';

  @override
  String get noActiveRequests => 'There are no active requests';

  @override
  String get noRequestHistory => 'The history is empty';

  @override
  String get createRequestAction => 'Create request';

  @override
  String get openActiveRequests => 'Open active requests';

  @override
  String get teacherReleasedAt => 'Actual dismissal time';

  @override
  String get requestReleasedStatus => 'Released';

  @override
  String get unsupportedRole => 'This role interface is not available yet.';

  @override
  String get or => 'or';

  @override
  String get createAccountButton => 'Create account';

  @override
  String get accountCreatedSuccessfully => 'Account created successfully';

  @override
  String get home => 'Home';

  @override
  String get homeWelcome => 'Design System';

  @override
  String get homeDescription =>
      'Explore colors, typography, and components. Switch theme and language live.';

  @override
  String get homeFeatureCategories =>
      'Manage categories with CRUD and pagination';

  @override
  String get homeFeatureProfile => 'View profile, theme and locale settings';

  @override
  String get homeUiKitTitle => 'UI Kit';

  @override
  String get homeUiKitSubtitle => 'Design System';

  @override
  String get homeUiKitDescription =>
      'Lightweight solid surfaces, tokens, and components for smooth performance.';

  @override
  String get homeSectionAppearance => 'Appearance';

  @override
  String get homeSectionColors => 'Colors';

  @override
  String get homeSectionTypography => 'Typography';

  @override
  String get homeSectionComponents => 'Components';

  @override
  String get homeSectionTokens => 'Design Tokens';

  @override
  String get colorPrimary => 'Primary';

  @override
  String get colorPrimaryLight => 'Primary Light';

  @override
  String get colorPrimaryDark => 'Primary Dark';

  @override
  String get colorSecondary => 'Secondary';

  @override
  String get colorSuccess => 'Success';

  @override
  String get colorWarning => 'Warning';

  @override
  String get colorError => 'Error';

  @override
  String get colorSurface => 'Surface';

  @override
  String get colorBackground => 'Background';

  @override
  String get homeShowDialog => 'Show dialog';

  @override
  String get homeDialogDemoTitle => 'Dialog demo';

  @override
  String get homeDialogDemoContent =>
      'This is a confirmation dialog from the UI kit.';

  @override
  String get homeFontFamily => 'Font family';

  @override
  String get homeFontRegular => 'Regular';

  @override
  String get homeFontMedium => 'Medium';

  @override
  String get homeFontBold => 'Bold';

  @override
  String get homeTypeDisplayLarge => 'Display L';

  @override
  String get homeTypeDisplayMedium => 'Display M';

  @override
  String get homeTypeHeadlineMedium => 'Headline M';

  @override
  String get homeTypeTitleLarge => 'Title L';

  @override
  String get homeTypeTitleMedium => 'Title M';

  @override
  String get homeTypeBodyLarge => 'Body L';

  @override
  String get homeTypeBodyMedium => 'Body M';

  @override
  String get homeTypeLabelMedium => 'Label M';

  @override
  String get homeTypeLabelSmall => 'Label S';

  @override
  String get homeSpacing => 'Spacing';

  @override
  String get homeRadius => 'Border radius';

  @override
  String get homeGlassTokens => 'Surfaces';

  @override
  String get homeSpacingExtraSmall => 'Extra small';

  @override
  String get homeSpacingSmall => 'Small';

  @override
  String get homeSpacingMedium => 'Medium';

  @override
  String get homeSpacingLarge => 'Large';

  @override
  String get homeSpacingExtraLarge => 'Extra large';

  @override
  String get homeRendering => 'Rendering';

  @override
  String get homeRenderingSolid => 'Solid';

  @override
  String get homeBorder => 'Border';

  @override
  String get homeDemoInputLabel => 'Sample input';

  @override
  String get homeDemoInputHint => 'Type something…';

  @override
  String get homeToggleLoading => 'Toggle loading';

  @override
  String get homeGlassOnLight => 'Default';

  @override
  String get homeGlassPanel => 'Panel';

  @override
  String get homeGlassOnGradient => 'Accent';

  @override
  String get homeTypographySample => 'The quick brown fox';

  @override
  String get categories => 'Categories';

  @override
  String get profile => 'Profile';

  @override
  String get profileSectionAccount => 'Account';

  @override
  String get addCategory => 'Add category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get deleteCategory => 'Delete category';

  @override
  String get categoryName => 'Category name';

  @override
  String get categoryNameRequired => 'Category name is required';

  @override
  String get categoryNameTooShort => 'Category name is too short';

  @override
  String get updateCategory => 'Update category';

  @override
  String get deleteCategoryConfirmation =>
      'Are you sure you want to delete this category?';

  @override
  String get categoryDeletedSuccessfully => 'Category deleted successfully';

  @override
  String get categoryUpdatedSuccessfully => 'Category updated successfully';

  @override
  String get noCategoriesYet => 'No categories yet';

  @override
  String get noCategoriesFound => 'No categories found';

  @override
  String get addFirstCategory => 'Add your first category';

  @override
  String get tryDifferentSearch => 'Try a different search';

  @override
  String get searchCategories => 'Search categories';

  @override
  String get addNewCategoryTooltip => 'Add category';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get updatePersonalInfo => 'Update your personal information';

  @override
  String get personalInformation => 'Personal information';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get changePassword => 'Change password';

  @override
  String get changePasswordTitle => 'Change password';

  @override
  String get requiredPasswordTitle => 'Change your temporary password';

  @override
  String get requiredPasswordDescription =>
      'Set a personal password to continue. You will sign in again after changing it.';

  @override
  String get passwordStrengthHint =>
      'Use at least 12 characters with upper and lower case letters, a number, and a special character';

  @override
  String get changePasswordButton => 'Update password';

  @override
  String get security => 'Security';

  @override
  String get logout => 'Logout';

  @override
  String get logoutConfirmation => 'Are you sure you want to logout?';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get error => 'Error';

  @override
  String get loading => 'Loading';

  @override
  String get retry => 'Retry';

  @override
  String get version => 'Version';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmNewPassword => 'Confirm new password';

  @override
  String get enterCurrentPassword => 'Enter current password';

  @override
  String get enterNewPassword => 'Enter new password';

  @override
  String get confirmYourNewPassword => 'Confirm your new password';

  @override
  String get currentPasswordRequired => 'Current password is required';

  @override
  String get newPasswordRequired => 'New password is required';

  @override
  String get passwordChangedSuccessfully => 'Password changed successfully';

  @override
  String get profileUpdatedSuccessfully => 'Profile updated successfully';

  @override
  String get accountDeletedSuccessfully => 'Account deleted successfully';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get deleteAccountConfirmation =>
      'Are you sure you want to delete your account?';

  @override
  String get deleteAccountDescription =>
      'Permanently delete your account and all data';

  @override
  String get deleteAccountWarning =>
      'This action cannot be undone. All your data will be permanently deleted.';

  @override
  String get dangerZone => 'Danger zone';

  @override
  String get manageAccount => 'Manage your account';

  @override
  String get emailRequired => 'Email is required';

  @override
  String get emailInvalid => 'Please enter a valid email';

  @override
  String get passwordRequired => 'Password is required';

  @override
  String passwordTooShort(int minLength) {
    return 'Password must be at least $minLength characters';
  }

  @override
  String newPasswordTooShort(int minLength) {
    return 'New password must be at least $minLength characters';
  }

  @override
  String fieldRequired(String fieldName) {
    return '$fieldName is required';
  }

  @override
  String fieldTooShort(String fieldName, int minLength) {
    return '$fieldName must be at least $minLength characters';
  }

  @override
  String nameLettersOnly(String fieldName) {
    return '$fieldName must contain only letters';
  }

  @override
  String numberRequired(Object fieldName) {
    return '$fieldName is required';
  }

  @override
  String numberInvalid(Object fieldName) {
    return '$fieldName must be a valid number';
  }

  @override
  String numberMustBePositive(Object fieldName) {
    return '$fieldName must be greater than zero';
  }

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get past => 'Past';

  @override
  String get ok => 'OK';

  @override
  String get offlineBanner => 'No internet connection';

  @override
  String get loadMore => 'Load more';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceDescription => 'Light, dark, or system theme';

  @override
  String get language => 'Language';

  @override
  String get languageDescription => 'App display language';

  @override
  String get languageSystem => 'System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageRussian => 'Russian';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get errorBadRequest => 'Bad request';

  @override
  String get errorUnauthorized => 'Unauthorized';

  @override
  String get errorAccessDenied => 'Access denied';

  @override
  String get errorNotFound => 'Not found';

  @override
  String get errorTimeout => 'Request timeout';

  @override
  String get errorValidation => 'Validation error';

  @override
  String get errorTooManyRequests => 'Too many requests';

  @override
  String get errorServer => 'Server error';

  @override
  String get errorBadGateway => 'Bad gateway';

  @override
  String get errorServiceUnavailable => 'Service unavailable';

  @override
  String get errorGatewayTimeout => 'Gateway timeout';

  @override
  String get errorClient => 'Client error';

  @override
  String get errorRequestCancelled => 'Request cancelled';

  @override
  String get errorInvalidCredentials => 'Invalid credentials';

  @override
  String get errorResourceExists => 'Resource already exists';
}
