import 'package:equatable/equatable.dart';

import 'anime.dart';
import 'watch_status.dart';

/// A watchlist title enriched with the user's own tracking data
/// (status + episode progress). This is what powers the Library screen.
class LibraryEntry extends Equatable {
  final Anime anime;
  final WatchStatus status;
  final int watchedEpisodes;
  final DateTime? updatedAt;

  const LibraryEntry({
    required this.anime,
    this.status = WatchStatus.planToWatch,
    this.watchedEpisodes = 0,
    this.updatedAt,
  });

  /// 0..1 completion ratio. Unknown episode counts fall back to the status.
  double get progress {
    if (anime.episodes > 0) {
      return (watchedEpisodes / anime.episodes).clamp(0.0, 1.0);
    }
    return status == WatchStatus.completed ? 1.0 : 0.0;
  }

  bool get isCompleted => status == WatchStatus.completed;

  LibraryEntry copyWith({
    Anime? anime,
    WatchStatus? status,
    int? watchedEpisodes,
    DateTime? updatedAt,
  }) {
    return LibraryEntry(
      anime: anime ?? this.anime,
      status: status ?? this.status,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [anime, status, watchedEpisodes, updatedAt];
}
