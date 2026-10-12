import '../../domain/entities/anime.dart';
import '../../core/utils/cdn_proxy.dart';

/// Data model extending the [Anime] entity with serialization logic
/// for the three supported sources (Jikan / Kitsu / AniList).
class AnimeModel extends Anime {
  const AnimeModel({
    required super.malId,
    required super.title,
    required super.imageUrl,
    required super.largeImageUrl,
    super.trailerYoutubeId,
    super.titleJapanese,
    super.synopsis,
    super.episodes,
    super.score,
    super.airedFrom,
    super.year,
    super.genres,
    super.status,
    super.rank,
    super.popularity,
    super.members,
    super.streamingLinks,
  });

  factory AnimeModel.fromEntity(Anime anime) {
    return AnimeModel(
      malId: anime.malId,
      title: anime.title,
      imageUrl: anime.imageUrl,
      largeImageUrl: anime.largeImageUrl,
      trailerYoutubeId: anime.trailerYoutubeId,
      titleJapanese: anime.titleJapanese,
      synopsis: anime.synopsis,
      episodes: anime.episodes,
      score: anime.score,
      airedFrom: anime.airedFrom,
      year: anime.year,
      genres: anime.genres,
      status: anime.status,
      rank: anime.rank,
      popularity: anime.popularity,
      members: anime.members,
      streamingLinks: anime.streamingLinks,
    );
  }

  /// Jikan / MyAnimeList JSON shape.
  factory AnimeModel.fromJikanJson(Map<String, dynamic> json) {
    final images = json['images'] as Map<String, dynamic>? ?? {};
    final jpg = images['jpg'] as Map<String, dynamic>? ?? {};
    final aired = json['aired'] as Map<String, dynamic>?;
    final from = aired?['from'] as String?;
    DateTime? airedFrom;
    if (from != null && from.isNotEmpty) {
      airedFrom = DateTime.tryParse(from);
    }
    final genres = (json['genres'] as List<dynamic>? ?? [])
        .map((g) => ((g as Map<String, dynamic>)['name'] ?? '') as String)
        .toList();
    final trailer = json['trailer'] as Map<String, dynamic>?;
    // Jikan often leaves `youtube_id` empty but still provides `embed_url`
    // (…/embed/<id>?…) — fall back to extracting the id from the URLs.
    String? trailerId = trailer?['youtube_id'] as String?;
    if (trailerId == null || trailerId.isEmpty) {
      final embedUrl = trailer?['embed_url'] as String? ?? '';
      final watchUrl = trailer?['url'] as String? ?? '';
      final trailerUrl = embedUrl.isNotEmpty ? embedUrl : watchUrl;
      final idMatch = RegExp(
        r'(?:embed/|v=)([A-Za-z0-9_-]{6,15})',
      ).firstMatch(trailerUrl);
      if (idMatch != null) trailerId = idMatch.group(1);
    }

    return AnimeModel(
      malId: json['mal_id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      titleJapanese: json['title_japanese'] as String? ?? '',
      imageUrl: proxyCdnImage(jpg['image_url'] as String? ?? '', width: 400),
      largeImageUrl: proxyCdnImage(
        jpg['large_image_url'] as String? ?? '',
        width: 1200,
      ),
      trailerYoutubeId: trailerId,
      synopsis: json['synopsis'] as String? ?? '',
      episodes: json['episodes'] as int? ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      airedFrom: airedFrom,
      year: airedFrom?.year ?? 0,
      genres: genres,
      status: json['status'] as String? ?? '',
      rank: json['rank'] as int?,
      popularity: json['popularity'] as int?,
      members: json['members'] as int?,
    );
  }

  /// Kitsu JSON:API shape (entry + included categories).
  factory AnimeModel.fromKitsu(
    Map<String, dynamic> entry,
    List<dynamic> included,
  ) {
    final attrs = entry['attributes'] as Map<String, dynamic>? ?? {};
    final titles = attrs['titles'] as Map<String, dynamic>? ?? {};
    final poster = attrs['posterImage'] as Map<String, dynamic>? ?? {};
    final rels = entry['relationships'] as Map<String, dynamic>? ?? {};
    final categoryRels = rels['categories']?['data'] as List<dynamic>? ?? [];

    final genres = categoryRels
        .map<String>((cr) {
          final id = cr['id'];
          for (final inc in included) {
            final incMap = inc as Map<String, dynamic>;
            if (incMap['id'] == id) {
              return (incMap['attributes']?['title'] as String? ?? '');
            }
          }
          return '';
        })
        .where((g) => g.isNotEmpty)
        .toList();

    if (genres.length > 8) genres.removeRange(8, genres.length);

    String synopsis = attrs['synopsis'] as String? ?? '';
    if (synopsis.length > 600) synopsis = '${synopsis.substring(0, 597)}...';

    String? ytId = attrs['youtubeVideoId'] as String?;
    if (ytId != null && ytId.isNotEmpty) {
      final strip = RegExp(
        r'(?:v=|embed/)([A-Za-z0-9_-]{6,15})',
      ).firstMatch(ytId);
      if (strip != null) ytId = strip.group(1);
    }

    final kitsuId = int.tryParse(entry['id']?.toString() ?? '') ?? 0;
    // Prefer the real MAL id from the `mappings` include when present —
    // Kitsu list/detail requests can include `mappings` so every consumer
    // (characters, episodes, recommendations) gets a working MAL key.
    int malId = kitsuId;
    for (final inc in included) {
      final incMap = inc as Map<String, dynamic>;
      if (incMap['type'] != 'mappings') continue;
      final mAttrs = incMap['attributes'] as Map<String, dynamic>? ?? {};
      final site = mAttrs['externalSite'] as String? ?? '';
      if (site == 'myanimelist/anime' || site == 'myanimelist') {
        final mapped = int.tryParse(mAttrs['externalId']?.toString() ?? '');
        if (mapped != null && mapped > 0) {
          malId = mapped;
          break;
        }
      }
    }

    return AnimeModel(
      malId: malId,
      title:
          titles['en'] as String? ??
          titles['en_jp'] as String? ??
          titles['ja_jp'] as String? ??
          '',
      titleJapanese: titles['ja_jp'] as String? ?? '',
      imageUrl: proxyCdnImage(
        poster['large'] as String? ?? poster['medium'] as String? ?? '',
        width: 400,
      ),
      largeImageUrl: proxyCdnImage(
        poster['original'] as String? ?? poster['large'] as String? ?? '',
        width: 1200,
      ),
      synopsis: synopsis,
      episodes: attrs['episodeCount'] as int? ?? 0,
      score: _parseRating(attrs['averageRating']),
      year: _parseYear(attrs['startDate']),
      genres: genres,
      status: attrs['status'] as String? ?? '',
      trailerYoutubeId: ytId,
    );
  }

  /// AniList GraphQL shape.
  factory AnimeModel.fromAniList(Map<String, dynamic> media) {
    final title = media['title'] as Map<String, dynamic>? ?? {};
    final cover = media['coverImage'] as Map<String, dynamic>? ?? {};
    final romaji = title['romaji'] as String? ?? '';
    final english = title['english'] as String? ?? '';
    final native = title['native'] as String? ?? '';

    String description = media['description'] as String? ?? '';
    description = _stripHtml(description);

    final trailer = media['trailer'] as Map<String, dynamic>?;
    String? trailerId;
    if (trailer != null && trailer['site'] == 'youtube') {
      trailerId = trailer['id']?.toString();
    }

    final externalLinks = (media['externalLinks'] as List<dynamic>? ?? [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          final site = m['site'] as String? ?? '';
          final url = m['url'] as String? ?? '';
          return StreamingLink(site: site, url: url);
        })
        .where((l) => l.site.isNotEmpty && l.url.isNotEmpty)
        .where(
          (l) => !RegExp(
            r'^(myanime|twitter|youtube|youtu|anilist\.co)',
          ).hasMatch(l.site.toLowerCase().replaceAll(' ', '')),
        )
        .toList();

    return AnimeModel(
      malId: media['idMal'] as int? ?? media['id'] as int? ?? 0,
      title: romaji.isNotEmpty
          ? romaji
          : (english.isNotEmpty ? english : native),
      titleJapanese: native,
      imageUrl: proxyCdnImage(cover['large'] as String? ?? '', width: 400),
      largeImageUrl: proxyCdnImage(
        cover['extraLarge'] as String? ?? '',
        width: 1200,
      ),
      synopsis: description,
      episodes: media['episodes'] as int? ?? 0,
      score: ((media['averageScore'] as num?)?.toDouble() ?? 0) / 10,
      year: media['seasonYear'] as int? ?? 0,
      genres: (media['genres'] as List<dynamic>? ?? [])
          .map((g) => g.toString())
          .toList(),
      status: media['status'] as String? ?? '',
      popularity: media['popularity'] as int?,
      members: media['popularity'] as int?,
      trailerYoutubeId: trailerId,
      streamingLinks: externalLinks,
    );
  }

  Map<String, dynamic> toCacheMap() {
    return {
      'mal_id': malId,
      'title': title,
      'title_japanese': titleJapanese,
      'image_url': imageUrl,
      'large_image_url': largeImageUrl,
      'score': score,
      'episodes': episodes,
      'year': year,
      'genres': genres.join(','),
      'streaming': [for (final l in streamingLinks) l.toMap()],
    };
  }

  factory AnimeModel.fromCacheMap(Map<String, dynamic> map) {
    return AnimeModel(
      malId: map['mal_id'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      titleJapanese: map['title_japanese'] as String? ?? '',
      imageUrl: map['image_url'] as String? ?? '',
      largeImageUrl: map['large_image_url'] as String? ?? '',
      score: (map['score'] as num?)?.toDouble() ?? 0,
      episodes: map['episodes'] as int? ?? 0,
      year: map['year'] as int? ?? 0,
      genres: (map['genres'] as String? ?? '')
          .split(',')
          .where((g) => g.isNotEmpty)
          .toList(),
      streamingLinks: (map['streaming'] as List<dynamic>? ?? [])
          .map((e) => StreamingLink.fromMap(e as Map<String, dynamic>))
          .where((l) => l.site.isNotEmpty && l.url.isNotEmpty)
          .toList(),
    );
  }

  static double _parseRating(Object? value) {
    final s = value?.toString() ?? '';
    if (s.isEmpty) return 0;
    final parsed = double.tryParse(s);
    if (parsed == null || parsed.isNaN) return 0;
    return parsed / 10;
  }

  static int _parseYear(Object? value) {
    final v = value?.toString() ?? '';
    if (v.isEmpty || v.length < 4) return 0;
    return int.tryParse(v.substring(0, 4)) ?? 0;
  }

  static String _stripHtml(String input) {
    if (input.isEmpty) return '';
    return input
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'");
  }
}
