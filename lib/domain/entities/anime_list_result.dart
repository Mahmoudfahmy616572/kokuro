import 'package:equatable/equatable.dart';
import 'anime.dart';

/// Result of a list fetch: the anime plus metadata about which
/// data source served it (used to inform the user of fallbacks).
class AnimeListResult extends Equatable {
  final List<Anime> anime;
  final String source;
  final bool fellBackFromPrimary;

  const AnimeListResult({
    required this.anime,
    required this.source,
    this.fellBackFromPrimary = false,
  });

  @override
  List<Object?> get props => [anime, source, fellBackFromPrimary];
}
