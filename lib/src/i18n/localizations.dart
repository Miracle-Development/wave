import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocalisationDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalisationDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.isSupported(locale);

  @override
  bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final loc = AppLocalizations(AppLocalizations.fetchLocale(locale));
    await loc.load();
    return loc;
  }
}

class AppLocalizations {
  AppLocalizations(this.locale);
  final Locale locale;

  late final Map<String, String> _keys;

  static const Locale defaultLocale = Locale('en');
  static const supportedLocales = <Locale>[Locale('ru'), defaultLocale];
  static const supportedLanguageCodes = <String>{'en', 'ru'};

  static bool isSupported(Locale locale) =>
      supportedLanguageCodes.contains(locale.languageCode);

  static Locale fetchLocale(Locale locale) =>
      isSupported(locale) ? Locale(locale.languageCode) : defaultLocale;

  Future<void> load() async {
    // 1) База en
    final base = await _loadJsonMap('assets/i18n/en.json');
    // 2) Текущий язык (может совпадать с en)
    final lang = locale.languageCode;
    final overlay = lang == 'en'
        ? const <String, dynamic>{}
        : await _tryLoadJsonMap('assets/i18n/$lang.json');

    // merge и сплющивание в плоские ключи "a.b.c"
    final merged = <String, dynamic>{}
      ..addAll(base)
      ..addAll(overlay);
    _keys = _flatten(merged);
  }

  // ---- API ----

  String t(String key, {Map<String, Object?> params = const {}}) {
    final raw = _keys[key] ?? key;
    if (params.isEmpty) return raw;
    return _fillPlaceholders(raw, params);
  }

  String translate(String key, [Map<String, String>? placeholders]) =>
      t(key, params: placeholders ?? const {});

  static AppLocalizations of(BuildContext context) =>
      Localizations.of<AppLocalizations>(context, AppLocalizations)!;

  // ---- helpers ----

  Future<Map<String, dynamic>> _loadJsonMap(String path) async {
    final raw = await rootBundle.loadString(path);
    return (json.decode(raw) as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _tryLoadJsonMap(String path) async {
    try {
      final raw = await rootBundle.loadString(path);
      return (json.decode(raw) as Map<String, dynamic>);
    } catch (_) {
      return const {};
    }
  }

  Map<String, String> _flatten(Map<String, dynamic> map, {String? prefix}) {
    final out = <String, String>{};

    map.forEach((k, v) {
      // пропускаем служебные ключи (на будущее, под ARB-стиль)
      if (k.startsWith('@')) return;

      final key = prefix == null ? k : '$prefix.$k';
      if (v is Map) {
        out.addAll(_flatten(v.cast<String, dynamic>(), prefix: key));
      } else if (v is String) {
        out[key] = v;
      } else if (v != null) {
        out[key] = v.toString();
      }
    });

    return out;
  }

  String _fillPlaceholders(String text, Map<String, Object?> params) {
    // поддерживаем как ${name}, так и {name}
    return text.replaceAllMapped(RegExp(r'\$\{(\w+)\}|\{(\w+)\}'), (m) {
      final key = m.group(1) ?? m.group(2)!;
      final val = params[key];
      return val?.toString() ?? m.group(0)!;
    });
  }
}

// syntactic sugar: context.l10n.t('key')
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
