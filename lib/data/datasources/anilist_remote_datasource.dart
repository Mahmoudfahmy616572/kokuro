import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/anime_model.dart';
import 'jikan_remote_datasource.dart' show AnimeCharacter;
import '../../core/utils/cdn_proxy.dart';

/// Talks only to the AniList GraphQL API.
class AniListRemoteDataSource {
  static const String _endpoint = 'https://graphql.anilist.co';
  final http.Client _client;

  AniListRemoteDataSource({http.Client? client})
    : _client = client ?? http.Client();

  static const _mediaFields = '''
    id
    idMal
    title { romaji english native }
    coverImage { large extraLarge }
    description
    episodes
    averageScore
    seasonYear
    genres
    status
    popularity
    trailer { site id }
    externalLinks { site url }
  ''';

  Future<List<AnimeModel>> getTopAnime({int page = 1, int limit = 24}) {
    const query =
        '''
      query (\$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, sort: POPULARITY_DESC) {
            $_mediaFields
          }
        }
      }
    ''';
    return _runListQuery(query, {'page': page, 'perPage': limit});
  }

  Future<List<AnimeModel>> getAnimeByGenre(
    String genre, {
    int page = 1,
    int limit = 24,
  }) {
    const gql =
        '''
      query (\$genre: String, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(type: ANIME, genre_in: [\$genre], sort: POPULARITY_DESC) {
            $_mediaFields
          }
        }
      }
    ''';
    return _runListQuery(gql, {'genre': genre, 'page': page, 'perPage': limit});
  }

  Future<List<AnimeModel>> searchAnime(
    String query, {
    int page = 1,
    int limit = 24,
  }) {
    const gql =
        '''
      query (\$search: String, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(search: \$search, type: ANIME, sort: POPULARITY_DESC) {
            $_mediaFields
          }
        }
      }
    ''';
    return _runListQuery(gql, {
      'search': query,
      'page': page,
      'perPage': limit,
    });
  }

  Future<List<AnimeModel>> getSeasonAnime({int page = 1, int limit = 24}) {
    final now = DateTime.now();
    const gql =
        '''
      query (\$season: MediaSeason, \$seasonYear: Int, \$page: Int, \$perPage: Int) {
        Page(page: \$page, perPage: \$perPage) {
          media(
            type: ANIME,
            season: \$season,
            seasonYear: \$seasonYear,
            sort: POPULARITY_DESC
          ) {
            $_mediaFields
          }
        }
      }
    ''';
    return _runListQuery(gql, {
      'season': _seasonFromMonth(now.month),
      'seasonYear': now.year,
      'page': page,
      'perPage': limit,
    });
  }

  /// AniList has no simple "upcoming season" query — Jikan is primary and
  /// Kitsu already covers the fallback, so this deliberately returns empty.
  Future<List<AnimeModel>> getUpcomingAnime({
    int page = 1,
    int limit = 24,
  }) async => <AnimeModel>[];

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
    final isGenre = genre != null && genre != 'All' && genre.isNotEmpty;
    final isSeason = season != null && season != 'All' && season.isNotEmpty;
    final resolvedYear = (year != null && year != 'All' && year.isNotEmpty)
        ? int.tryParse(year)
        : null;

    if (isGenre) return getAnimeByGenre(genre, page: page, limit: limit);
    if (isSeason) {
      final variables = <String, dynamic>{
        'season': _seasonFromName(season),
        'page': page,
        'perPage': limit,
      };
      if (resolvedYear != null) variables['seasonYear'] = resolvedYear;
      final gql =
          '''
        query (\$season: MediaSeason, \$seasonYear: Int, \$page: Int, \$perPage: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(season: \$season, seasonYear: \$seasonYear, type: ANIME, sort: POPULARITY_DESC) {
              $_mediaFields
            }
          }
        }
      ''';
      return _runListQuery(gql, variables);
    }
    if (resolvedYear != null) {
      final gql =
          '''
        query (\$year: Int, \$page: Int, \$perPage: Int) {
          Page(page: \$page, perPage: \$perPage) {
            media(seasonYear: \$year, type: ANIME, sort: POPULARITY_DESC) {
              $_mediaFields
            }
          }
        }
      ''';
      return _runListQuery(gql, {
        'year': resolvedYear,
        'page': page,
        'perPage': limit,
      });
    }
    return getTopAnime(page: page, limit: limit);
  }

  String _seasonFromName(String season) {
    return switch (season.toLowerCase()) {
      'winter' => 'WINTER',
      'spring' => 'SPRING',
      'summer' => 'SUMMER',
      'fall' => 'FALL',
      _ => 'FALL',
    };
  }

  Future<AnimeModel?> getAnimeDetails(int id) async {
    const gql =
        '''
      query (\$idMal: Int) {
        Media(idMal: \$idMal, type: ANIME) {
          $_mediaFields
        }
      }
    ''';
    final body = await _post({
      'query': gql,
      'variables': {'idMal': id},
    });
    final data = body?['data'] as Map<String, dynamic>?;
    final media = data?['Media'] as Map<String, dynamic>?;
    if (media == null) return null;
    return AnimeModel.fromAniList(media);
  }

  Future<List<AnimeModel>> getRecommendations(int animeId) async {
    const gql = '''
      query (\$idMal: Int) {
        Media(idMal: \$idMal, type: ANIME) {
          recommendations(perPage: 12) {
            edges {
              node {
                mediaRecommendation {
                  id
                  idMal
                  title { romaji english }
                  coverImage { large extraLarge }
                }
              }
            }
          }
        }
      }
    ''';
    try {
      final body = await _post({
        'query': gql,
        'variables': {'idMal': animeId},
      });
      final data = body?['data'] as Map<String, dynamic>?;
      final media = data?['Media'] as Map<String, dynamic>?;
      final edges = media?['recommendations']?['edges'] as List<dynamic>? ?? [];
      return edges.map<AnimeModel>((edge) {
        final node = edge['node'] as Map<String, dynamic>? ?? {};
        final rec = node['mediaRecommendation'] as Map<String, dynamic>? ?? {};
        final title = rec['title'] as Map<String, dynamic>? ?? {};
        final cover = rec['coverImage'] as Map<String, dynamic>? ?? {};
        return AnimeModel(
          malId: rec['idMal'] as int? ?? rec['id'] as int? ?? 0,
          title:
              title['romaji'] as String? ?? title['english'] as String? ?? '',
          imageUrl: proxyCdnImage(cover['large'] as String? ?? '', width: 400),
          largeImageUrl: proxyCdnImage(
            cover['extraLarge'] as String? ?? '',
            width: 1200,
          ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<AnimeModel>> _runListQuery(
    String query,
    Map<String, dynamic> variables,
  ) async {
    try {
      final body = await _post({'query': query, 'variables': variables});
      final data = body?['data'] as Map<String, dynamic>?;
      final page = data?['Page'] as Map<String, dynamic>?;
      final media = page?['media'] as List<dynamic>? ?? [];
      return media
          .map((m) => AnimeModel.fromAniList(m as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Fetches characters from AniList GraphQL as a fallback when Jikan is down.
  /// Accepts a MAL id and queries AniList's `Media(idMal:)`.
  Future<List<AnimeCharacter>> getCharacters(int malId) async {
    const query = '''
      query (\$idMal: Int) {
        Media(idMal: \$idMal, type: ANIME) {
          characters(perPage: 25, sort: FAVOURITES_DESC) {
            edges {
              node {
                id
                name { full }
                image { large }
              }
              role
              voiceActors(language: JAPANESE) {
                name { full }
                image { large }
              }
            }
          }
        }
      }
    ''';
    try {
      final body = await _post({
        'query': query,
        'variables': {'idMal': malId},
      });
      final media = body?['data']?['Media'] as Map<String, dynamic>?;
      final edges = media?['characters']?['edges'] as List<dynamic>? ?? [];
      return edges.map<AnimeCharacter>((edge) {
        final node = edge['node'] as Map<String, dynamic>;
        final vaList = edge['voiceActors'] as List<dynamic>? ?? [];
        final va = vaList.isNotEmpty ? vaList.first : null;
        final vaPerson = va as Map<String, dynamic>?;
        return AnimeCharacter(
          malId: node['id'] as int? ?? 0,
          name: node['name']?['full'] as String? ?? '',
          imageUrl: proxyCdnImage(
            node['image']?['large'] as String? ?? '',
            width: 300,
          ),
          role: edge['role'] as String? ?? '',
          voiceActorName: vaPerson?['name']?['full'] as String?,
          voiceActorImageUrl: vaPerson == null
              ? null
              : proxyCdnImage(
                  vaPerson['image']?['large'] as String? ?? '',
                  width: 200,
                ),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Batch next-episode airing lookup for a set of MAL ids. Used by the
  /// library/notifications to tell the user when a watched show airs next
  /// (AniList's `nextAiringEpisode` is the only cheap source of future dates).
  Future<Map<int, ({DateTime at, int episode})>> getNextAiringEpisodes(
    List<int> idMals,
  ) async {
    if (idMals.isEmpty) return const {};
    final unique = idMals.toSet().take(48).toList();
    const query = '''
      query (\$ids: [Int]) {
        Page(page: 1, perPage: 48) {
          media(idMal_in: \$ids, type: ANIME) {
            idMal
            nextAiringEpisode {
              airingAt
              episode
            }
          }
        }
      }
    ''';
    try {
      final body = await _post({
        'query': query,
        'variables': {'ids': unique},
      });
      final page = body?['data']?['Page'] as Map<String, dynamic>?;
      final media = page?['media'] as List<dynamic>? ?? [];
      final result = <int, ({DateTime at, int episode})>{};
      for (final m in media) {
        final node = m as Map<String, dynamic>;
        final idMal = node['idMal'] as int?;
        final airing = node['nextAiringEpisode'] as Map<String, dynamic>?;
        final at = airing?['airingAt'] as int?;
        final episode = airing?['episode'] as int?;
        if (idMal != null && at != null && episode != null) {
          result[idMal] = (
            at: DateTime.fromMillisecondsSinceEpoch(at * 1000),
            episode: episode,
          );
        }
      }
      return result;
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, dynamic>?> _post(Map<String, dynamic> payload) async {
    final response = await _client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'User-Agent':
                'Animiat/1.0 (a legal anime metadata app built with Flutter)',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  String _seasonFromMonth(int month) {
    if (month >= 1 && month <= 3) return 'WINTER';
    if (month >= 4 && month <= 6) return 'SPRING';
    if (month >= 7 && month <= 9) return 'SUMMER';
    return 'FALL';
  }

  void dispose() {
    _client.close();
  }
}
