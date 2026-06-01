import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleController extends ChangeNotifier {
  static const _storageKey = 'locale_language_code';

  Locale _locale = const Locale('en');

  LocaleController() {
    _load();
  }

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) {
      return;
    }
    _locale = locale;
    _save(locale);
    notifyListeners();
  }

  void setLocaleCode(String languageCode) {
    setLocale(Locale(languageCode));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_storageKey);
    if (languageCode == null || languageCode.isEmpty) {
      return;
    }
    final locale = Locale(languageCode);
    if (locale == _locale) {
      return;
    }
    _locale = locale;
    notifyListeners();
  }

  Future<void> _save(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, locale.languageCode);
  }
}
