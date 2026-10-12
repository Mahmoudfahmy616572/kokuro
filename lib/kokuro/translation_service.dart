import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:translator/translator.dart';

/// Lightweight wrapper around Google Translate (free tier).
/// Translates English text to Arabic for display in the UI.
///
/// Translations are cached in memory first, then persisted to
/// [SharedPreferences] so an already-translated string is never
/// sent to Google twice (saves quota + latency on return visits).
class TranslationService {
  TranslationService._();

  static final _translator = GoogleTranslator();

  static const _prefsKey = 'translation_cache_v1';
  static const _maxPersistEntries = 300;
  static const _maxPersistTextLen = 6000;

  static final _cache = <String, String>{};

  /// Entries that still need to be flushed to disk.
  static final _dirty = <String, String>{};
  static bool _loaded = false;
  static bool _loadFailed = false;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// Loads the persisted cache once (lazily, on first use).
  static Future<void> _ensureLoaded() async {
    if (_loaded || _loadFailed) return;
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            final v = entry.value;
            if (v is String) _cache[entry.key] = v;
          }
        }
      }
      _loaded = true;
    } catch (_) {
      // Corrupt/oversized payload — fall back to memory-only caching.
      _loadFailed = true;
    }
  }

  static Future<void> _flush() async {
    if (_dirty.isEmpty || _loadFailed) return;
    final batch = Map<String, String>.from(_dirty);
    _dirty.clear();
    try {
      final prefs = await _prefs();
      final raw = prefs.getString(_prefsKey);
      var stored = <String, dynamic>{};
      if (raw != null && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) stored = decoded;
        } catch (_) {
          stored = {};
        }
      }
      stored.addAll(batch);
      if (stored.length > _maxPersistEntries) {
        // Drop oldest keys once the map grows past the cap.
        final keys = stored.keys.toList();
        for (var i = 0; i < keys.length - _maxPersistEntries; i++) {
          stored.remove(keys[i]);
        }
      }
      await prefs.setString(_prefsKey, jsonEncode(stored));
    } catch (_) {
      // Persistence is best-effort — keep the in-memory result anyway.
      _dirty.addAll(batch);
    }
  }

  /// Translates [text] from English to Arabic.
  /// Returns the original text if it's already Arabic or on failure.
  static Future<String> toArabic(String text) async {
    if (text.isEmpty) return text;
    await _ensureLoaded();
    if (_cache.containsKey(text)) return _cache[text]!;

    var translated = text;
    try {
      // If text is mostly Arabic already, skip translation
      final arabicCount = text.runes
          .where((r) => r >= 0x0600 && r <= 0x06FF)
          .length;
      if (arabicCount / text.length > 0.3) {
        translated = text;
      } else {
        final result = await _translator.translate(text, from: 'en', to: 'ar');
        translated = result.text;
      }
    } catch (_) {
      // On failure, return original text
      translated = text;
    }

    _cache[text] = translated;
    if (text.length <= _maxPersistTextLen) {
      _dirty[text] = translated;
      _flush();
    }
    return translated;
  }
}
