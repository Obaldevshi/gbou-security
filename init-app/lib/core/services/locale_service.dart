import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class LocaleService extends ChangeNotifier {
  LocaleService(this._prefs);

  final SharedPreferences _prefs;
  // A versioned key resets installations that previously persisted English
  // before Russian became the product's primary locale.
  static const _key = 'locale_v2';
  static const _systemLocale = 'system';

  Locale? _locale = const Locale('ru');

  Locale? get locale => _locale;

  @PostConstruct()
  void init() {
    final stored = _prefs.getString(_key);
    _locale = switch (stored) {
      _systemLocale => null,
      'en' => const Locale('en'),
      'ru' => const Locale('ru'),
      _ => const Locale('ru'),
    };
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    if (locale == null) {
      await _prefs.setString(_key, _systemLocale);
    } else {
      await _prefs.setString(_key, locale.languageCode);
    }
    notifyListeners();
  }
}
