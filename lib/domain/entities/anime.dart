import 'package:equatable/equatable.dart';

/// A single official streaming/watch-listing URL for an anime title,
/// e.g. "Crunchyroll" → https://www.crunchyroll.com/series/…
class StreamingLink {
  final String site;
  final String url;

  const StreamingLink({required this.site, required this.url});

  Map<String, dynamic> toMap() => {'site': site, 'url': url};

  factory StreamingLink.fromMap(Map<String, dynamic> map) {
    return StreamingLink(
      site: map['site'] as String? ?? '',
      url: map['url'] as String? ?? '',
    );
  }

  String get label {
    final s = site.trim();
    if (s.isEmpty) return '';
    return s[0].toUpperCase() + s.substring(1);
  }
}

/// Pure domain entity. No framework or serialization dependencies.
class Anime extends Equatable {
  final int malId;
  final String title;
  final String titleJapanese;
  final String imageUrl;
  final String largeImageUrl;
  final String? trailerYoutubeId;
  final String synopsis;
  final int episodes;
  final double score;
  final DateTime? airedFrom;
  final int year;
  final List<String> genres;
  final String status;
  final int? rank;
  final int? popularity;
  final int? members;
  final List<StreamingLink> streamingLinks;

  const Anime({
    required this.malId,
    required this.title,
    required this.imageUrl,
    required this.largeImageUrl,
    this.trailerYoutubeId,
    this.titleJapanese = '',
    this.synopsis = '',
    this.episodes = 0,
    this.score = 0,
    this.airedFrom,
    this.year = 0,
    this.genres = const [],
    this.status = '',
    this.rank,
    this.popularity,
    this.members,
    this.streamingLinks = const [],
  });

  Anime copyWith({
    int? malId,
    String? title,
    String? titleJapanese,
    String? imageUrl,
    String? largeImageUrl,
    String? trailerYoutubeId,
    String? synopsis,
    int? episodes,
    double? score,
    DateTime? airedFrom,
    int? year,
    List<String>? genres,
    String? status,
    int? rank,
    int? popularity,
    int? members,
    List<StreamingLink>? streamingLinks,
  }) {
    return Anime(
      malId: malId ?? this.malId,
      title: title ?? this.title,
      titleJapanese: titleJapanese ?? this.titleJapanese,
      imageUrl: imageUrl ?? this.imageUrl,
      largeImageUrl: largeImageUrl ?? this.largeImageUrl,
      trailerYoutubeId: trailerYoutubeId ?? this.trailerYoutubeId,
      synopsis: synopsis ?? this.synopsis,
      episodes: episodes ?? this.episodes,
      score: score ?? this.score,
      airedFrom: airedFrom ?? this.airedFrom,
      year: year ?? this.year,
      genres: genres ?? this.genres,
      status: status ?? this.status,
      rank: rank ?? this.rank,
      popularity: popularity ?? this.popularity,
      members: members ?? this.members,
      streamingLinks: streamingLinks ?? this.streamingLinks,
    );
  }

  @override
  List<Object?> get props => [
    malId,
    title,
    titleJapanese,
    imageUrl,
    largeImageUrl,
    trailerYoutubeId,
    synopsis,
    episodes,
    score,
    airedFrom,
    year,
    genres,
    status,
    rank,
    popularity,
    members,
    streamingLinks,
  ];
}
