import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/errors/exceptions.dart';
import '../../core/utils/cdn_proxy.dart';
import '../models/anime_model.dart';

/// Jikan API character/episode models
class AnimeCharacter {
  final int malId;
  final String name;
  final String imageUrl;
  final String role;
  final String? voiceActorName;
  final String? voiceActorImageUrl;

  const AnimeCharacter({
    required this.malId,
    required this.name,
    this.imageUrl = '',
    this.role = '',
    this.voiceActorName,
    this.voiceActorImageUrl,
  });
}

class AnimeEpisode {
  final int number;
  final String title;
  final String? titleJp;
  final String? synopsis;
  final String aired;
  final double? score;

  const AnimeEpisode({
    required this.number,
    required this.title,
    this.titleJp,
    this.synopsis,
    this.aired = '',
    this.score,
  });
}

/// A review of an anime — either fetched from the Jikan API or written
/// locally by the user and persisted via LocalStorage.
class AnimeReview {
  final String username;
  final String text;
  final double overall;
  final List<String> tags;
  final bool isUser;
  final int animeId;

  const AnimeReview({
    required this.username,
    required this.text,
    this.overall = 0,
    this.tags = const [],
    this.isUser = false,
    this.animeId = 0,
  });

  AnimeReview copyWith({
    String? username,
    String? text,
    double? overall,
    List<String>? tags,
    bool? isUser,
  }) {
    return AnimeReview(
      username: username ?? this.username,
      text: text ?? this.text,
      overall: overall ?? this.overall,
      tags: tags ?? this.tags,
      isUser: isUser ?? this.isUser,
      animeId: animeId,
    );
  }

  factory AnimeReview.fromCacheMap(Map<String, dynamic> map) {
    return AnimeReview(
      username: map['username'] as String? ?? '',
      text: map['text'] as String? ?? '',
      overall: (map['overall'] as num?)?.toDouble() ?? 0,
      tags: (map['tags'] as List?)?.cast<String>() ?? const [],
      isUser: map['isUser'] as bool? ?? false,
      animeId: (map['anime_id'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'username': username,
      'text': text,
      'overall': overall,
      'tags': tags,
      'isUser': isUser,
      'anime_id': animeId,
    };
  }
}

/// Talks only to the Jikan (MyAnimeList) API.
class JikanRemoteDataSource {
  static const String _baseUrl = 'https://api.jikan.moe/v4';
  final http.Client _client;

  JikanRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<AnimeModel>> getTopAnime({int page = 1, int limit = 24}) {
    return _fetchList(
      '$_baseUrl/top/anime?page=$page&limit=$limit&filter=bypopularity',
    );
  }

  static const Map<String, int> _genreIds = {
    'Action': 1,
    'Adventure': 2,
    'Comedy': 4,
    'Drama': 8,
    'Fantasy': 10,
    'Horror': 14,
    'Mystery': 7,
    'Romance': 22,
    'Sci-Fi': 24,
    'Slice of Life': 36,
    'Sports': 30,
    'Supernatural': 37,
    'Thriller': 41,
  };

  Future<List<AnimeModel>> getAnimeByGenre(
    String genre, {
    int page = 1,
    int limit = 24,
  }) {
    final ids = _genresToIds(genre);
    if (ids.isEmpty) return Future.value(<AnimeModel>[]);
    return _fetchList(
      '$_baseUrl/anime?genres=$ids&order_by=members&sort=desc'
      '&page=$page&limit=$limit',
    );
  }

  /// Maps a single or comma-separated genre string to Jikan genre ids.
  /// Returns an empty list if every name is unmapped.
  String _genresToIds(String genre) {
    final parts = genre.split(',').map((g) => g.trim()).toList();
    final ids = parts
        .map((g) => _genreIds[g])
        .whereType<int>()
        .toSet()
        .toList();
    return ids.map((id) => id.toString()).join(',');
  }

  /// Total titles currently tagged with [genre] (from Jikan's
  /// `pagination.items.total`), used to show real per-genre counts
  /// instead of hardcoded mock numbers.
  Future<int> getGenreTotalCount(String genre) async {
    final id = _genreIds[genre];
    if (id == null) return 0;
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/anime?genres=$id&limit=1'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return 0;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final items = json['pagination']?['items'] as Map<String, dynamic>?;
      return (items?['total'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<List<AnimeModel>> searchAnime(
    String query, {
    int page = 1,
    int limit = 24,
  }) {
    return _fetchList(
      '$_baseUrl/anime?q=${Uri.encodeQueryComponent(query)}&page=$page&limit=$limit',
    );
  }

  /// Searches characters by name (Jikan has no first-party character search,
  /// so this leans on the public `/characters` endpoint). Returns the
  /// character's id + name + portrait; `role` stays empty and is filled in
  /// later on the profile screen when the character is resolved in context.
  Future<List<AnimeCharacter>> searchCharacters(
    String query, {
    int limit = 12,
  }) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$_baseUrl/characters?q=${Uri.encodeQueryComponent(query)}'
              '&limit=$limit&order_by=favorites&sort=desc',
            ),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? [];
      return data.map<AnimeCharacter>((entry) {
        final char = entry as Map<String, dynamic>;
        return AnimeCharacter(
          malId: char['mal_id'] as int? ?? 0,
          name: char['name'] as String? ?? '',
          imageUrl: proxyCdnImage(
            (char['images']?['jpg']?['image_url'] ?? '') as String,
            width: 300,
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AnimeModel>> getSeasonAnime({int page = 1, int limit = 24}) {
    final now = DateTime.now();
    final season = _seasonFromMonth(now.month);
    return _fetchList(
      '$_baseUrl/seasons/${now.year}/$season?page=$page&limit=$limit',
    );
  }

  Future<List<AnimeModel>> getUpcomingAnime({int page = 1, int limit = 24}) {
    return _fetchList('$_baseUrl/seasons/upcoming?page=$page&limit=$limit');
  }

  static const Map<String, int> _studioIds = {
    'Pierrot': 1,
    'Kyoto Animation': 2,
    'Bones': 4,
    'Gainax': 8,
    'Production I.G': 10,
    'Madhouse': 11,
    'Sunrise': 14,
    'Toei Animation': 18,
    'Studio Ghibli': 21,
    'J.C.Staff': 48,
    'Ufotable': 43,
    'Studio Pierrot': 1,
    'Trigger': 803,
    'Wit Studio': 858,
    'David Production': 1081,
    'MAPPA': 569,
    'A-1 Pictures': 1865,
    'Shaft': 84,
  };

  static const Map<String, String> _jikanRatings = {
    'G': 'g',
    'PG': 'pg',
    'PG-13': 'pg13',
    'R-17': 'r17',
    'R+': 'r',
    'Rx': 'rx',
  };

  static const Map<String, String> _typeOrderBy = {
    'Popular': 'members',
    'Score': 'score',
    'Favorites': 'favorites',
    'Newest': 'start_date',
    'Oldest': 'start_date',
  };

  /// Explore feed builder — combines every active filter into one Jikan
  /// query so chips like Season / Year / Studio / Type / Rating / Sort
  /// actually filter the served list instead of being decorative.
  Future<List<AnimeModel>> getExploreList({
    String? genre,
    String? season,
    String? year,
    String? studio,
    String? type,
    String? rating,
    String? sort,
    int page = 1,
    int limit = 24,
  }) {
    final isSeasonBased =
        season != null && season.isNotEmpty && season != 'All';

    if (isSeasonBased) {
      final resolvedYear = (year != null && year != 'All' && year.isNotEmpty)
          ? year
          : DateTime.now().year.toString();
      final params = <String>['page=$page', 'limit=$limit'];
      final seasonalFilter = _seasonalTypeFilter(type);
      if (seasonalFilter != null) params.add('filter=$seasonalFilter');
      return _fetchList(
        '$_baseUrl/seasons/$resolvedYear/${season.toLowerCase()}?'
        '${params.join('&')}',
      );
    }

    final params = <String>[];
    if (genre != null && genre != 'All' && genre.isNotEmpty) {
      final ids = _genresToIds(genre);
      if (ids.isEmpty) return Future.value(<AnimeModel>[]);
      params.add('genres=$ids');
    }
    if (studio != null && studio != 'All' && studio.isNotEmpty) {
      final sid = _studioIds[studio];
      if (sid != null) params.add('producers=$sid');
    }
    if (type != null && type != 'All' && type.isNotEmpty) {
      params.add('type=${_canonicalType(type)}');
    }
    if (rating != null && rating != 'All' && rating.isNotEmpty) {
      final r = _jikanRatings[rating];
      if (r != null) params.add('rating=$r');
    }
    if (year != null && year != 'All' && year.isNotEmpty) {
      params.add('start_date=$year-01-01');
      params.add('end_date=$year-12-31');
    }
    final orderBy = _typeOrderBy[sort ?? 'Popular'] ?? 'members';
    params.add('order_by=$orderBy');
    params.add('sort=${sort == 'Oldest' ? 'asc' : 'desc'}');
    params.add('page=$page');
    params.add('limit=$limit');

    return _fetchList('$_baseUrl/anime?${params.join('&')}');
  }

  static const _validTypes = {'TV', 'Movie', 'OVA', 'ONA', 'Special', 'Music'};

  String _canonicalType(String type) {
    if (_validTypes.contains(type)) return type;
    return switch (type.toUpperCase()) {
      'TV_SHORT' => 'TV_SHORT',
      'MOVIE' => 'Movie',
      'OVA' => 'OVA',
      'ONA' => 'ONA',
      'SPECIAL' => 'Special',
      'MUSIC' => 'Music',
      _ => 'TV',
    };
  }

  String? _seasonalTypeFilter(String? type) {
    if (type == null || type == 'All' || type.isEmpty) return null;
    return switch (type.toUpperCase()) {
      'TV' => 'tv',
      'MOVIE' => 'movie',
      'OVA' => 'ova',
      'SPECIAL' => 'special',
      _ => null,
    };
  }

  Future<AnimeModel?> getAnimeDetails(int id) async {
    try {
      final response = await _client.get(Uri.parse('$_baseUrl/anime/$id/full'));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AnimeModel.fromJikanJson(json['data'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Lightweight trailer probe — only needs the plain `/anime/{id}`
  /// endpoint, so it can still succeed when `/full` is rate-limited.
  Future<String?> getTrailerId(int id) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/anime/$id'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as Map<String, dynamic>?;
      final trailer = data?['trailer'] as Map<String, dynamic>?;
      var id2 = trailer?['youtube_id'] as String?;
      if (id2 == null || id2.isEmpty) {
        final embedUrl = trailer?['embed_url'] as String? ?? '';
        final watchUrl = trailer?['url'] as String? ?? '';
        final url = embedUrl.isNotEmpty ? embedUrl : watchUrl;
        final match = RegExp(
          r'(?:embed/|v=)([A-Za-z0-9_-]{6,15})',
        ).firstMatch(url);
        if (match != null) id2 = match.group(1);
      }
      return (id2 == null || id2.isEmpty) ? null : id2;
    } catch (_) {
      return null;
    }
  }

  Future<List<AnimeModel>> getRecommendations(int animeId) async {
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/anime/$animeId/recommendations'),
      );
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? [];
      return data.take(12).map<AnimeModel>((entry) {
        final rec = entry['entry'] as Map<String, dynamic>;
        return AnimeModel(
          malId: rec['mal_id'] as int? ?? 0,
          title: rec['title'] as String? ?? '',
          imageUrl: proxyCdnImage(
            (rec['images']?['jpg']?['image_url'] ?? '') as String,
            width: 400,
          ),
          largeImageUrl: proxyCdnImage(
            (rec['images']?['jpg']?['large_image_url'] ?? '') as String,
            width: 1200,
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AnimeCharacter>> getCharacters(int animeId) async {
    try {
      // The characters payload is Jikan's heaviest endpoint (hundreds of
      // entries for popular titles) — 8s is too tight and a single
      // 429/slow response made us fall back to an always-empty Kitsu path.
      // Lie larger timeout in plus one 900ms backoff retry.
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final response = await _client
              .get(Uri.parse('$_baseUrl/anime/$animeId/characters'))
              .timeout(const Duration(seconds: 20));
          if (response.statusCode != 200) {
            if (response.statusCode == 429 || response.statusCode >= 500) {
              await Future<void>.delayed(const Duration(milliseconds: 900));
              continue;
            }
            return [];
          }
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final data = json['data'] as List<dynamic>? ?? [];
          return data.map<AnimeCharacter>((entry) {
            final char = entry['character'] as Map<String, dynamic>;
            final voiceActors = entry['voice_actors'] as List<dynamic>? ?? [];
            final jaVa = voiceActors.isNotEmpty
                ? voiceActors.first as Map<String, dynamic>
                : null;
            final person = jaVa?['person'] as Map<String, dynamic>?;
            return AnimeCharacter(
              malId: char['mal_id'] as int? ?? 0,
              name: char['name'] as String? ?? '',
              imageUrl: proxyCdnImage(
                (char['images']?['jpg']?['image_url'] ?? '') as String,
                width: 300,
              ),
              role: entry['role'] as String? ?? '',
              voiceActorName: person?['name'] as String?,
              voiceActorImageUrl: person == null
                  ? null
                  : proxyCdnImage(
                      (person['images']?['jpg']?['image_url'] ?? '') as String,
                      width: 200,
                    ),
            );
          }).toList();
        } on TimeoutException {
          await Future<void>.delayed(const Duration(milliseconds: 900));
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<AnimeReview>> getReviews(int animeId, {int page = 1}) async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/anime/$animeId/reviews?page=$page'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>? ?? [];
      return data.map<AnimeReview>((entry) {
        final e = entry as Map<String, dynamic>;
        final user = e['user'] as Map<String, dynamic>? ?? {};
        final rawText = (e['review'] as String?) ?? '';
        final text = _stripHtml(rawText);
        return AnimeReview(
          username: user['username'] as String? ?? 'Anonymous',
          text: text.isEmpty ? 'No review text provided.' : text,
          overall: ((e['score'] as num?)?.toDouble() ?? 0) / 1.0,
          tags: _parseJikanTags(e['tags']),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AnimeEpisode>> getEpisodes(int animeId, {int page = 1}) async {
    try {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          final response = await _client
              .get(Uri.parse('$_baseUrl/anime/$animeId/episodes?page=$page'))
              .timeout(const Duration(seconds: 20));
          if (response.statusCode != 200) {
            if (response.statusCode == 429 || response.statusCode >= 500) {
              await Future<void>.delayed(const Duration(milliseconds: 900));
              continue;
            }
            return [];
          }
          final json = jsonDecode(response.body) as Map<String, dynamic>;
          final data = json['data'] as List<dynamic>? ?? [];
          return data.map<AnimeEpisode>((ep) {
            return AnimeEpisode(
              number: ep['mal_id'] as int? ?? 0,
              title: ep['title'] as String? ?? '',
              titleJp: ep['title_japanese'] as String?,
              synopsis: ep['synopsis'] as String?,
              aired: ep['aired'] as String? ?? '',
              score: (ep['score'] as num?)?.toDouble(),
            );
          }).toList();
        } on TimeoutException {
          await Future<void>.delayed(const Duration(milliseconds: 900));
        }
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<List<AnimeModel>> _fetchList(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw ServerException(
        'Jikan responded with ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final data = json['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => AnimeModel.fromJikanJson(e as Map<String, dynamic>))
        .toList();
  }

  String _seasonFromMonth(int month) {
    if (month >= 1 && month <= 3) return 'winter';
    if (month >= 4 && month <= 6) return 'spring';
    if (month >= 7 && month <= 9) return 'summer';
    return 'fall';
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<String> _parseJikanTags(dynamic raw) {
    if (raw is List) return raw.map((t) => t.toString()).toList();
    final s = raw?.toString().trim();
    if (s == null || s.isEmpty) return const [];
    return s
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
  }

  void dispose() {
    _client.close();
  }
}
