import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/exceptions.dart';
import '../../domain/entities/watch_status.dart';
import '../models/anime_model.dart';
import 'jikan_remote_datasource.dart' show AnimeReview;

/// Per-title tracking data stored next to the watchlist (status + progress).
class LibraryMetaData {
  final WatchStatus status;
  final int watchedEpisodes;
  final DateTime? updatedAt;

  const LibraryMetaData({
    this.status = WatchStatus.planToWatch,
    this.watchedEpisodes = 0,
    this.updatedAt,
  });
}

/// Handles local persistence for watchlist and ratings.
class LocalStorageDataSource {
  static const String _watchlistKey = 'watchlist';
  static const String _ratingsKey = 'anime_ratings';
  static const String _libraryMetaKey = 'library_meta';

  Future<List<AnimeModel>> getWatchlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_watchlistKey) ?? [];
      return raw
          .map((s) {
            try {
              return AnimeModel.fromCacheMap(
                jsonDecode(s) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<AnimeModel>()
          .toList();
    } catch (e) {
      throw CacheException('فشل قراءة المفضلة: $e');
    }
  }

  Future<void> addToWatchlist(AnimeModel anime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (await getWatchlist())
          .map((a) => jsonEncode(a.toCacheMap()))
          .toList();
      if (!list.any((s) {
        try {
          return (jsonDecode(s) as Map<String, dynamic>)['mal_id'] ==
              anime.malId;
        } catch (_) {
          return false;
        }
      })) {
        list.insert(0, jsonEncode(anime.toCacheMap()));
      }
      await prefs.setStringList(_watchlistKey, list);
    } catch (e) {
      throw CacheException('فشل حفظ في المفضلة: $e');
    }
  }

  Future<void> removeFromWatchlist(int animeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_watchlistKey) ?? [];
      final updated = raw.where((s) {
        try {
          return (jsonDecode(s) as Map<String, dynamic>)['mal_id'] != animeId;
        } catch (_) {
          return false;
        }
      }).toList();
      await prefs.setStringList(_watchlistKey, updated);
    } catch (e) {
      throw CacheException('فشل حذف من المفضلة: $e');
    }
  }

  // ── Library meta (watch status + episode progress) ────────

  Future<Map<int, LibraryMetaData>> getLibraryMeta() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_libraryMetaKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final out = <int, LibraryMetaData>{};
      decoded.forEach((key, value) {
        final id = int.tryParse(key);
        if (id == null || value is! Map) return;
        final map = value as Map<String, dynamic>;
        final updatedMs = map['updated'] as int?;
        out[id] = LibraryMetaData(
          status: WatchStatus.fromKey(map['status'] as String?),
          watchedEpisodes: map['watched'] as int? ?? 0,
          updatedAt: updatedMs == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(updatedMs),
        );
      });
      return out;
    } catch (e) {
      throw CacheException('فشل قراءة حالة المشاهدة: $e');
    }
  }

  Future<void> setLibraryMeta(
    int animeId, {
    WatchStatus? status,
    int? watchedEpisodes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_libraryMetaKey);
      final decoded =
          (raw == null ? <String, dynamic>{} : jsonDecode(raw))
              as Map<String, dynamic>;
      final existing = decoded['$animeId'] as Map<String, dynamic>?;
      decoded['$animeId'] = {
        'status':
            status?.key ??
            existing?['status'] as String? ??
            WatchStatus.planToWatch.key,
        'watched': watchedEpisodes ?? existing?['watched'] as int? ?? 0,
        'updated': DateTime.now().millisecondsSinceEpoch,
      };
      await prefs.setString(_libraryMetaKey, jsonEncode(decoded));
    } catch (e) {
      throw CacheException('فشل حفظ حالة المشاهدة: $e');
    }
  }

  Future<void> removeLibraryMeta(int animeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_libraryMetaKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      decoded.remove('$animeId');
      await prefs.setString(_libraryMetaKey, jsonEncode(decoded));
    } catch (e) {
      throw CacheException('فشل حذف حالة المشاهدة: $e');
    }
  }

  Future<Map<int, double>> getAllRatings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_ratingsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (k, v) => MapEntry(int.parse(k), (v as num).toDouble()),
      );
    } catch (e) {
      throw CacheException('فشل قراءة التقييمات: $e');
    }
  }

  Future<void> rateAnime(int animeId, double rating) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratings = await getAllRatings();
      ratings[animeId] = rating;
      await prefs.setString(
        _ratingsKey,
        jsonEncode(ratings.map((k, v) => MapEntry('$k', v))),
      );
    } catch (e) {
      throw CacheException('فشل حفظ التقييم: $e');
    }
  }

  Future<void> removeRating(int animeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ratings = await getAllRatings();
      ratings.remove(animeId);
      await prefs.setString(
        _ratingsKey,
        jsonEncode(ratings.map((k, v) => MapEntry('$k', v))),
      );
    } catch (e) {
      throw CacheException('فشل حذف التقييم: $e');
    }
  }

  // ── Response cache (API list/details, offline fallback) ──

  static const String _cachePrefix = 'resp_cache:';

  /// Returns `(payload, savedAtEpochMs)` for `key`, or null when absent.
  Future<(String, int)?> readCache(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$key');
      if (raw == null) return null;
      final sep = raw.indexOf('\n');
      if (sep <= 0) return null;
      final savedAt = int.tryParse(raw.substring(0, sep));
      if (savedAt == null) return null;
      return (raw.substring(sep + 1), savedAt);
    } catch (_) {
      return null;
    }
  }

  Future<void> writeCache(String key, String json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_cachePrefix$key',
        '${DateTime.now().millisecondsSinceEpoch}\n$json',
      );
    } catch (_) {
      // Best-effort cache: storage failures must never break the app.
    }
  }

  // ── Reviews (user-written, persisted) ─────────────────────

  static const String _userReviewsKey = 'user_reviews';

  Future<List<AnimeReview>> getUserReviews(int animeId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userReviewsKey);
      if (raw == null) return [];
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final forAnime = decoded['$animeId'] as List<dynamic>? ?? [];
      return forAnime
          .map((e) => AnimeReview.fromCacheMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw CacheException('فشل قراءة الريفيوهات: $e');
    }
  }

  Future<void> submitUserReview(int animeId, AnimeReview review) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_userReviewsKey);
      final decoded =
          (raw == null ? <String, dynamic>{} : jsonDecode(raw))
              as Map<String, dynamic>;
      final forAnime = (decoded['$animeId'] as List<dynamic>? ?? [])
          .map((e) => AnimeReview.fromCacheMap(e as Map<String, dynamic>))
          .toList();
      final withUserRating = review.overall > 0 ? forAnime : forAnime;
      final ctx = review.isUser
          ? withUserRating.where((r) => !r.isUser).toList()
          : withUserRating;
      ctx.insert(0, review);
      decoded['$animeId'] = ctx.map((r) => r.toCacheMap()).toList();
      await prefs.setString(_userReviewsKey, jsonEncode(decoded));
    } catch (e) {
      throw CacheException('فشل حفظ الريفيو: $e');
    }
  }
}
