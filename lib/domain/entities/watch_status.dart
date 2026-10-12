/// How a title sits in the user's library. Mirrors the classic
/// MyAnimeList/AniList watch-status vocabulary.
enum WatchStatus {
  watching('watching', 'أشاهد'),
  completed('completed', 'مكتمل'),
  planToWatch('plan_to_watch', 'قائمة المشاهدة'),
  onHold('on_hold', 'معلّق'),
  dropped('dropped', 'متوقف');

  const WatchStatus(this.key, this.label);

  /// Stable string used for persistence (never rename these).
  final String key;

  /// Human readable label for the UI.
  final String label;

  static WatchStatus fromKey(String? key) {
    for (final status in values) {
      if (status.key == key) return status;
    }
    return WatchStatus.planToWatch;
  }
}
