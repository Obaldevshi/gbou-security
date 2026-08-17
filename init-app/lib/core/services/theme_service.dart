import 'package:flutter/material.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';

@lazySingleton
class ThemeService extends ChangeNotifier {
  ThemeService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  @PostConstruct()
  void init() {
    final stored = _prefs.getString(_key);
    _themeMode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_key, mode.name);
    notifyListeners();
  }
}
