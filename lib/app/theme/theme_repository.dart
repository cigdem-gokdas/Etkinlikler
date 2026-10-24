import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemeRepository {
  Future<ThemeMode> load();
  Future<void> save(ThemeMode mode);
}

class PreferencesThemeRepository implements ThemeRepository {
  PreferencesThemeRepository(this._preferences);
  static const preferenceKey = 'theme_mode_v1';
  final SharedPreferencesAsync _preferences;

  @override
  Future<ThemeMode> load() async =>
      switch (await _preferences.getString(preferenceKey)) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };

  @override
  Future<void> save(ThemeMode mode) =>
      _preferences.setString(preferenceKey, mode.name);
}
