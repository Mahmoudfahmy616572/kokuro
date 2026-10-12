import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/errors/exceptions.dart';
import '../../core/utils/cdn_proxy.dart';
import '../models/anime_model.dart';
import 'jikan_remote_datasource.dart' show AnimeCharacter, AnimeEpisode;

/// Talks only to the Kitsu API.
class KitsuRemoteDataSource {
  static const String _baseUrl = 'https://kitsu.io/api/edge';
  static const _headers = {
    'Accept': 'application/vnd.api+json',
    'Content-Type': 'application/vnd.api+json',
    'User-Agent': 'Animiat/1.0 (a legal anime metadata app)',
  };

  final http.Client _client;

  KitsuRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<AnimeModel>> getTopAnime({int page = 1, int limit = 20}) {
    return _fetchList(
      '$_baseUrl/anime?sort=-userCount&page[limit]=$limit'
      '&page[offset]=${(page - 1) * limit}&include=categories',
    );
  }

  static const Map<String, String> _categorySlugs = {
    'Action': 'action',
    'Adventure': 'adventure',
    'Comedy': 'comedy',
    'Drama': 'drama',
    'Fantasy': 'fantasy',
    'Horror': 'horror',
    'Mystery': 'mystery',
    'Romance': 'romance',
    'Sci-Fi': 'sci-fi',
    'Slice of Life': 'slice-of-life',
    'Sports': 'sports',
    'Supernatural': 'supernatural',
    'Thriller': 'thriller',
  };

  Future<List<AnimeModel>> getAnimeByGenre(
    String genre, {
    int page = 1,
    int limit = 20,
  }) {
    final slug = _categorySlugs[genre];
    if (slug == null) return Future.value(<AnimeModel>[]);
    return _fetchList(
      '$_baseUrl/anime?filter[categories]=$slug&sort=-userCount'
      '&page[limit]=$limit&page[offset]=${(page - 1) * limit}'
      '&include=categories',
    );
  }

  Future<List<AnimeModel>> searchAnime(
    String query, {
    int page = 1,
    int limit = 20,
  }) {
    return _fetchList(
      '$_baseUrl/anime?filter[text]=${Uri.encodeQueryComponent(query)}'
      '&page[limit]=$limit&page[offset]=${(page - 1) * limit}'
      '&include=categories',
    );
  }

  Future<List<AnimeModel>> getSeasonAnime({int page = 1, int limit = 20}) {
    final year = DateTime.now().year;
    return _fetchList(
      '$_baseUrl/anime?filter[seasonYear]=$year&sort=-userCount'
      '&page[limit]=$limit&page[offset]=${(page - 1) * limit}'
      '&include=categories',
    );
  }

  Future<List<AnimeModel>> getUpcomingAnime({int page = 1, int limit = 20}) {
    return _fetchList(
      '$_baseUrl/anime?filter[status]=upcoming&sort=-startDate'
      '&page[limit]=$limit&page[offset]=${(page - 1) * limit}'
      '&include=categories',
    );
  }

  Future<List<AnimeModel>> getExploreList({
    String? genre,
    String? season,
    String? year,
    String? studio,
    String? type,
    String? rating,
    String? sort,
    int page = 1,
    int limit = 20,
  }) {
    final isGenre = genre != null && genre != 'All' && genre.isNotEmpty;
    final isSeason = season != null && season != 'All' && season.isNotEmpty;
    final resolvedYear = (year != null && year != 'All' && year.isNotEmpty)
        ? int.tryParse(year)
        : null;

    if (isGenre) return getAnimeByGenre(genre, page: page, limit: limit);
    if (isSeason) {
      final y = resolvedYear ?? DateTime.now().year;
      final seasonParam = season.toLowerCase();
      return _fetchList(
        '$_baseUrl/anime?filter[season]=$seasonParam&filter[seasonYear]=$y'
        '&sort=-userCount&page[limit]=$limit'
        '&page[offset]=${(page - 1) * limit}&include=categories',
      );
    }
    if (resolvedYear != null) {
      return _fetchList(
        '$_baseUrl/anime?filter[seasonYear]=$resolvedYear&sort=-userCount'
        '&page[limit]=$limit&page[offset]=${(page - 1) * limit}'
        '&include=categories',
      );
    }
    return getTopAnime(page: page, limit: limit);
  }

  Future<AnimeModel?> getAnimeDetails(int id) async {
    final response = await _client
        .get(
          Uri.parse('$_baseUrl/anime/$id?include=categories,mappings'),
          headers: _headers,
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as Map<String, dynamic>?;
    final included = body['included'] as List<dynamic>? ?? [];
    if (data == null) return null;
    return AnimeModel.fromKitsu(data, included);
  }

  /// Resolves a Kitsu anime id to its real MyAnimeList id via the mappings
  /// relationship (`externalSite: "myanimelist/anime"`). Returns null when
  /// the id is unknown or has no MAL mapping.
  Future<int?> resolveMalId(int kitsuId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('$_baseUrl/anime/$kitsuId/mappings?page[limit]=20'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final data = body['data'] as List<dynamic>? ?? [];
      for (final item in data) {
        final map = item as Map<String, dynamic>;
        final attrs = map['attributes'] as Map<String, dynamic>? ?? {};
        final site = attrs['externalSite'] as String? ?? '';
        if (site == 'myanimelist/anime' || site == 'myanimelist') {
          final id = int.tryParse(attrs['externalId']?.toString() ?? '');
          if (id != null && id > 0) return id;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<AnimeModel>> _fetchList(String url) async {
    final response = await _client
        .get(Uri.parse(url), headers: _headers)
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw ServerException(
        'Kitsu responded with ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final data = body['data'] as List<dynamic>? ?? [];
    final included = body['included'] as List<dynamic>? ?? [];
    return data
        .map((e) => AnimeModel.fromKitsu(e as Map<String, dynamic>, included))
        .toList();
  }

  // ── Characters ────────────────────────────────────────────

  Future<List<AnimeCharacter>> getCharacters(int animeId) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$_baseUrl/anime/$animeId/characters'
              '?include=character&page[limit]=24',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rawData = body['data'] as List<dynamic>? ?? [];
      final included = body['included'] as List<dynamic>? ?? [];

      // Build a lookup of character id -> attributes from `included`.
      final byId = <String, Map<String, dynamic>>{};
      for (final item in included) {
        final map = item as Map<String, dynamic>;
        if (map['type'] == 'characters') {
          byId[map['id'].toString()] =
              map['attributes'] as Map<String, dynamic>? ?? {};
        }
      }

      final characters = <AnimeCharacter>[];
      for (final item in rawData) {
        final map = item as Map<String, dynamic>;
        final attributes = map['attributes'] as Map<String, dynamic>? ?? {};
        final charRel = map['relationships']?['character']?['data'] as Map?;
        final charId = charRel?['id']?.toString();
        final charAttrs = charId != null ? byId[charId] : null;

        final rawImage = charAttrs?['image'] as Map<String, dynamic>?;
        final imageUrl = rawImage?['original'] as String? ?? '';

        characters.add(
          AnimeCharacter(
            malId: int.tryParse(charId ?? '') ?? 0,
            name:
                (charAttrs?['canonicalName'] as String?) ??
                (charAttrs?['name'] as String?) ??
                'Unknown',
            imageUrl: imageUrl.isEmpty
                ? ''
                : proxyCdnImage(imageUrl, width: 300),
            role: (attributes['role'] as String?) ?? '',
          ),
        );
      }

      return characters;
    } catch (_) {
      return [];
    }
  }

  // ── Episodes ──────────────────────────────────────────────

  Future<List<AnimeEpisode>> getEpisodes(int animeId, {int page = 1}) async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '$_baseUrl/anime/$animeId/episodes?page[offset]=${(page - 1) * 30}'
              '&page[limit]=30',
            ),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return [];

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final rawData = body['data'] as List<dynamic>? ?? [];

      return rawData.map<AnimeEpisode>((item) {
        final map = item as Map<String, dynamic>;
        final attributes = map['attributes'] as Map<String, dynamic>? ?? {};
        final titles = attributes['titles'] as Map<String, dynamic>? ?? {};
        final canonical = attributes['canonicalTitle'] as String? ?? '';
        return AnimeEpisode(
          number: (attributes['number'] as num?)?.toInt() ?? 0,
          title:
              (titles['en_us'] as String?) ??
              (titles['en_jp'] as String?) ??
              canonical,
          titleJp: titles['ja_jp'] as String?,
          synopsis: attributes['synopsis'] as String?,
          aired: attributes['airdate'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Related (genre-based fallback) ────────────────────────

  static const Map<String, String> _genreSlugs = {
    'Action': 'action',
    'Adventure': 'adventure',
    'Comedy': 'comedy',
    'Drama': 'drama',
    'Fantasy': 'fantasy',
    'Horror': 'horror',
    'Mystery': 'mystery',
    'Romance': 'romance',
    'Sci-Fi': 'sci-fi',
    'Science Fiction': 'sci-fi',
    'Slice of Life': 'slice-of-life',
    'Sports': 'sports',
    'Supernatural': 'supernatural',
    'Thriller': 'thriller',
    'Psychological': 'psychological',
    'Music': 'music',
    'Historical': 'historical',
    'Mecha': 'mecha',
    'Military': 'military',
    'School': 'school',
    'Seinen': 'seinen',
    'Shonen': 'shounen',
    'Magical Girls': 'magical-girls',
    'Harem': 'harem',
  };

  /// Returns a real list of anime sharing one of [genres] (best effort).
  /// Falls back to the top list when no slug match is found.
  Future<List<AnimeModel>> getRelatedAnime(
    int animeId, {
    List<String> genres = const [],
  }) async {
    for (final genre in genres) {
      final slug = _genreSlugs[genre];
      if (slug == null) continue;
      try {
        final url =
            '$_baseUrl/anime?filter[categories]=$slug&sort=-userCount'
            '&page[limit]=24&include=categories';
        final list = await _fetchList(url);
        final filtered = list
            .where((a) => a.malId != animeId)
            .take(12)
            .toList();
        if (filtered.isNotEmpty) return filtered;
      } catch (_) {
        continue;
      }
    }

    // No genre matched — pull a different slice of the top list.
    try {
      final offset = (animeId * 7) % 400;
      final url =
          '$_baseUrl/anime?sort=-userCount&page[limit]=24&page[offset]=$offset'
          '&include=categories';
      final list = await _fetchList(url);
      return list.where((a) => a.malId != animeId).take(12).toList();
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
