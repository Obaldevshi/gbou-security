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
  Locale? _locale = const Locale('ru');

  Locale? get locale => _locale;

  @PostConstruct()
  void init() {
    _locale = const Locale('ru');
    _prefs.setString(_key, 'ru');
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = const Locale('ru');
    await _prefs.setString(_key, 'ru');
    notifyListeners();
  }
}
