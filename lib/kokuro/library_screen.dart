import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../domain/entities/library_entry.dart';
import '../domain/entities/watch_status.dart';
import 'tokens.dart';
import 'components.dart';
import 'kokuro_bloc.dart';
import 'loading_widgets.dart';
import 'active_branch_scope.dart';
import 'app_strings.dart';
import 'user_profile.dart';

class LibraryScreen extends StatefulWidget {
  final int branchIndex;

  const LibraryScreen({super.key, this.branchIndex = 2});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  int _selectedTab = 0;
  LibraryLoaded? _cached;
  UserProfile _profile = const UserProfile();
  final _searchController = TextEditingController();
  String _query = '';

  /// (status filter, label). `null` status == "All".
  static final List<(WatchStatus?, String)> _tabs = [
    (null, AppStrings.all),
    (WatchStatus.watching, AppStrings.watching),
    (WatchStatus.completed, AppStrings.completed),
    (WatchStatus.planToWatch, AppStrings.planToWatch),
    (WatchStatus.onHold, AppStrings.onHold),
    (WatchStatus.dropped, AppStrings.dropped),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<KokuroBloc>().add(const LoadLibrary());
    });
  }

  Future<void> _loadProfile() async {
    final profile = await UserProfile.load();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;

    final isActive =
        ActiveBranchScope.maybeOf(context)?.isActive(widget.branchIndex) ??
        true;
    return TickerMode(
      enabled: isActive,
      child: Scaffold(
        backgroundColor: K.bg,
        body: SafeArea(
          child: BlocBuilder<KokuroBloc, KokuroState>(
            builder: (context, state) {
              if (state is LibraryLoaded) {
                _cached = state;
                return _scroll(isDesktop, state);
              }
              if (_cached != null) {
                return _scroll(isDesktop, _cached!);
              }
              if (state is KokuroError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: K.coral, size: 48),
                      const SizedBox(height: K.s16),
                      Text(state.message, style: K.bodyLarge),
                      const SizedBox(height: K.s16),
                      KokuroButton(
                        label: AppStrings.retry,
                        icon: Icons.refresh,
                        onPressed: () {
                          context.read<KokuroBloc>().add(const LoadLibrary());
                        },
                      ),
                    ],
                  ),
                );
              }
              return const Center(
                child: KokuroLoader(label: AppStrings.unfoldingLibrary),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _scroll(bool isDesktop, LibraryLoaded state) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: K.accent,
      backgroundColor: K.bgCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: K.s24),
        child: isDesktop
            ? _buildDesktopLayout(state)
            : _buildMobileLayout(state),
      ),
    );
  }

  /// Pull-to-refresh: reloads the library from local storage.
  Future<void> _refresh() {
    context.read<KokuroBloc>().add(const LoadLibrary());
    return Future<void>.delayed(const Duration(seconds: 1));
  }

  /// Opens a title and reloads the library when the detail route pops so a
  /// status/progress change made inside is reflected on the list behind it.
  Future<void> _openDetail(LibraryEntry entry) async {
    await context.push('/anime/${entry.anime.malId}', extra: entry.anime);
    if (mounted) context.read<KokuroBloc>().add(const LoadLibrary());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Layouts ──────────────────────────────────────────

  Widget _buildDesktopLayout(LibraryLoaded state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: K.s32),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: _buildLibrarySection(state)),
          const SizedBox(width: K.s32),
          SizedBox(width: 340, child: _buildProfilePanel(state)),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(LibraryLoaded state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: K.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLibrarySection(state),
          const SizedBox(height: K.s32),
          _buildProfilePanel(state),
        ],
      ),
    );
  }

  // ── Library Section ──────────────────────────────────

  Widget _buildLibrarySection(LibraryLoaded state) {
    final entries = _sorted(state.entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.myUniverse, style: K.headlineLarge),
        const SizedBox(height: K.s4),
        Text(
          entries.isEmpty
              ? AppStrings.yourStories
              : '${entries.length} ${entries.length == 1 ? AppStrings.title : AppStrings.titles} ${AppStrings.titlesInLibrary}',
          style: K.bodyLarge,
        ),
        const SizedBox(height: K.s24),
        _buildStatusTabs(entries),
        const SizedBox(height: K.s16),
        _buildUpcomingBanner(state),
        _buildWatchList(entries),
      ],
    );
  }

  List<LibraryEntry> _sorted(List<LibraryEntry> entries) {
    final list = [...entries];
    list.sort((a, b) {
      final at = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final bt = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bt.compareTo(at);
    });
    return list;
  }

  // ── Status Tabs ──────────────────────────────────────

  Widget _buildStatusTabs(List<LibraryEntry> entries) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final (status, label) = _tabs[i];
          final isActive = _selectedTab == i;
          final count = status == null
              ? entries.length
              : entries.where((e) => e.status == status).length;

          return GestureDetector(
            onTap: () => setState(() => _selectedTab = i),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: K.s16,
                vertical: K.s12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isActive ? K.accent : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: K.titleMedium.copyWith(
                      fontSize: 14,
                      color: isActive ? K.textPrimary : K.textTertiary,
                    ),
                  ),
                  const SizedBox(width: K.s6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: K.s6,
                      vertical: K.s2,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? K.accent.withValues(alpha: 0.15)
                          : K.bgSurface,
                      borderRadius: BorderRadius.circular(K.rFull),
                    ),
                    child: Text(
                      '$count',
                      style: K.bodySmall.copyWith(
                        fontSize: 11,
                        color: isActive ? K.accent : K.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Upcoming Airing Banner ────────────────────────────

  /// Real "next episode airs soon" rows for the shows the user follows —
  /// filled from AniList's `nextAiringEpisode` (no fake dates).
  Widget _buildUpcomingBanner(LibraryLoaded state) {
    if (state.upcoming.isEmpty) return const SizedBox.shrink();
    final now = DateTime.now();

    final items = <({LibraryEntry entry, DateTime at, int episode})>[];
    for (final entry in state.entries) {
      final next = state.upcoming[entry.anime.malId];
      if (next == null) continue;
      final at = next.at;
      if (at.isBefore(now)) continue;
      items.add((entry: entry, at: at, episode: next.episode));
    }
    items.sort((a, b) => a.at.compareTo(b.at));
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: K.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.upcomingAirs.toUpperCase(), style: K.labelUppercase),
          const SizedBox(height: K.s12),
          Container(
            padding: const EdgeInsets.all(K.s16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  K.accent.withValues(alpha: 0.12),
                  K.cyan.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(K.r16),
              border: Border.all(color: K.accent.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                for (final item in items.take(3))
                  InkWell(
                    onTap: () => _openDetail(item.entry),
                    borderRadius: BorderRadius.circular(K.r8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: K.s8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(K.r8),
                            child: KuroImg(
                              item.entry.anime.imageUrl,
                              width: 40,
                              height: 56,
                            ),
                          ),
                          const SizedBox(width: K.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.entry.anime.title,
                                  style: K.titleMedium.copyWith(
                                    fontSize: 14,
                                    color: K.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: K.s2),
                                Text(
                                  _airingLabel(item.at, item.episode),
                                  style: K.bodySmall.copyWith(
                                    color: K.textSecondary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_left_rounded,
                            color: K.textTertiary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _airingLabel(DateTime at, int episode) {
    final diff = at.difference(DateTime.now());
    String prefix;
    if (diff.inMinutes < 90) {
      prefix = AppStrings.airsTodayIn;
    } else if (diff.inHours < 48) {
      prefix = AppStrings.airsSoon;
    } else {
      prefix = AppStrings.nextEpisodeAirs;
    }
    return '$prefix $episode ${AppStrings.episode}';
  }

  // ── Library Search ─────────────────────────────────────

  Widget _buildLibrarySearch() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r8),
        border: Border.all(color: K.border.withValues(alpha: 0.4)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _query = v),
        style: K.bodyMedium.copyWith(color: K.textPrimary),
        decoration: InputDecoration(
          hintText: AppStrings.searchMyLibrary,
          hintStyle: K.bodyMedium.copyWith(color: K.textTertiary),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: K.textTertiary,
            size: 20,
          ),
          suffixIcon: _query.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: K.textTertiary,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: K.s12,
            vertical: K.s8,
          ),
        ),
      ),
    );
  }

  // ── Watch List ───────────────────────────────────────

  Widget _buildWatchList(List<LibraryEntry> entries) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(K.s32),
          child: Column(
            children: [
              Icon(
                Icons.library_books_outlined,
                color: K.textTertiary,
                size: 48,
              ),
              const SizedBox(height: K.s16),
              Text(AppStrings.libraryEmpty, style: K.headlineMedium),
              const SizedBox(height: K.s8),
              Text(
                AppStrings.addAnimeToWatchlist,
                style: K.bodyLarge,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final filtered =
        (_selectedTab == 0
                ? entries
                : entries
                      .where((e) => e.status == _tabs[_selectedTab].$1)
                      .toList())
            .where((e) {
              final q = _query.trim().toLowerCase();
              if (q.isEmpty) return true;
              return e.anime.title.toLowerCase().contains(q) ||
                  e.anime.titleJapanese.toLowerCase().contains(q) ||
                  e.anime.genres
                      .where((g) => g.toLowerCase().contains(q))
                      .isNotEmpty;
            })
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLibrarySearch(),
        const SizedBox(height: K.s16),
        if (filtered.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(K.s32),
              child: Column(
                children: [
                  Icon(
                    Icons.filter_alt_off_outlined,
                    color: K.textTertiary,
                    size: 40,
                  ),
                  const SizedBox(height: K.s12),
                  Text(
                    'لا شيء في "${_tabs[_selectedTab].$2}"',
                    style: K.titleMedium,
                  ),
                  const SizedBox(height: K.s4),
                  Text(
                    AppStrings.moveToStatus,
                    style: K.bodyMedium.copyWith(color: K.textTertiary),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final entry = filtered[index];
              final canTrack = entry.anime.episodes > 0;
              return _buildWatchItem(entry, canTrack: canTrack);
            },
          ),
      ],
    );
  }

  Widget _buildWatchItem(LibraryEntry entry, {bool canTrack = true}) {
    final anime = entry.anime;
    final total = anime.episodes;
    final color = _statusColor(entry.status);

    return Dismissible(
      key: ValueKey(anime.malId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: K.s24),
        margin: const EdgeInsets.only(bottom: K.s8),
        decoration: BoxDecoration(
          color: K.coral,
          borderRadius: BorderRadius.circular(K.r12),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: K.textPrimary,
          size: 24,
        ),
      ),
      confirmDismiss: (_) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${anime.title} ${AppStrings.removed}'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            width: 320,
            backgroundColor: K.bgCard,
          ),
        );
        context.read<KokuroBloc>().add(RemoveFromLibraryEvent(anime.malId));
        return true;
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: K.s8),
        padding: const EdgeInsets.all(K.s12),
        decoration: BoxDecoration(
          color: K.bgCard,
          borderRadius: BorderRadius.circular(K.r12),
          border: Border.all(color: K.borderSubtle, width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'poster-${anime.malId}',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(K.r8),
                child: KuroImg(anime.imageUrl, width: 80, height: 108),
              ),
            ),
            const SizedBox(width: K.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          anime.title,
                          style: K.titleMedium.copyWith(fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: K.s8),
                      _StatusChip(status: entry.status, color: color),
                    ],
                  ),
                  const SizedBox(height: K.s4),
                  Text(
                    canTrack
                        ? '${entry.watchedEpisodes} / $total ${AppStrings.eps}'
                        : '${entry.watchedEpisodes} ${AppStrings.epsWatched}',
                    style: K.bodySmall,
                  ),
                  if (canTrack) ...[
                    const SizedBox(height: K.s8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(K.rFull),
                      child: LinearProgressIndicator(
                        value: entry.progress,
                        minHeight: 5,
                        backgroundColor: K.bgSurface,
                        valueColor: AlwaysStoppedAnimation(color),
                      ),
                    ),
                  ],
                  const SizedBox(height: K.s8),
                  if (anime.genres.isNotEmpty)
                    Wrap(
                      spacing: K.s4,
                      runSpacing: K.s2,
                      children: anime.genres.take(2).map((g) {
                        return PersonalityTag(label: g, color: K.accentSoft);
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(width: K.s12),
            _buildItemControls(entry, canTrack),
          ],
        ),
      ),
    );
  }

  Widget _buildItemControls(LibraryEntry entry, bool canTrack) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        PopupMenuButton<WatchStatus>(
          tooltip: AppStrings.changeStatus,
          color: K.bgCard,
          onSelected: (status) {
            context.read<KokuroBloc>().add(SetWatchStatus(entry.anime, status));
          },
          itemBuilder: (context) => WatchStatus.values.map((s) {
            return PopupMenuItem(
              value: s,
              child: Row(
                children: [
                  Icon(
                    s == entry.status
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 16,
                    color: s == entry.status ? K.accent : K.textTertiary,
                  ),
                  const SizedBox(width: K.s8),
                  Text(s.label, style: K.bodyMedium),
                ],
              ),
            );
          }).toList(),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: K.s8,
              vertical: K.s6,
            ),
            decoration: BoxDecoration(
              color: K.bgSurface,
              borderRadius: BorderRadius.circular(K.r8),
              border: Border.all(color: K.borderSubtle),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tune_rounded, size: 14, color: K.textSecondary),
                const SizedBox(width: K.s4),
                Text(
                  AppStrings.status,
                  style: K.bodySmall.copyWith(color: K.textSecondary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: K.s8),
        if (canTrack)
          _EpisodeStepper(
            value: entry.watchedEpisodes,
            total: entry.anime.episodes,
            onChanged: (v) {
              context.read<KokuroBloc>().add(SetWatchProgress(entry.anime, v));
            },
          ),
        const SizedBox(height: K.s8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconAction(
              icon: Icons.play_arrow_rounded,
              tooltip: entry.isCompleted
                  ? AppStrings.rewatch
                  : AppStrings.continueWatching,
              color: K.accent,
              onTap: () => _openDetail(entry),
            ),
            const SizedBox(width: K.s6),
            _IconAction(
              icon: Icons.delete_outline_rounded,
              tooltip: AppStrings.removeFromLibrary,
              color: K.textTertiary,
              onTap: () {
                context.read<KokuroBloc>().add(
                  RemoveFromLibraryEvent(entry.anime.malId),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  // ── Profile Panel ────────────────────────────────────

  Widget _buildProfilePanel(LibraryLoaded state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(state.entries),
        const SizedBox(height: K.s24),
        _buildStatsRow(state.entries),
        const SizedBox(height: K.s24),
        _buildAnimePersonality(state.entries),
        const SizedBox(height: K.s24),
        _buildRecentActivity(state.entries),
      ],
    );
  }

  Widget _buildAvatar(List<LibraryEntry> entries) {
    final xp = _totalXp(entries);
    final level = (xp ~/ 100) + 1;
    final intoLevel = xp % 100;

    return Center(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _profile.avatarColor.withValues(alpha: 0.4),
                width: 2,
              ),
              boxShadow: K.glow(color: _profile.avatarColor, blur: 24),
            ),
            child: ClipOval(
              child: Container(
                color: K.bgCard,
                child: Icon(
                  _profile.avatarIcon,
                  size: 48,
                  color: _profile.avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: K.s12),
          Text(_profile.displayName, style: K.titleLarge),
          if (_profile.bio.isNotEmpty) ...[
            const SizedBox(height: K.s4),
            Text(
              _profile.bio,
              textAlign: TextAlign.center,
              style: K.bodySmall.copyWith(color: K.textTertiary),
            ),
          ],
          const SizedBox(height: K.s8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: K.s8,
                  vertical: K.s4,
                ),
                decoration: BoxDecoration(
                  color: K.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(K.rFull),
                ),
                child: Text(
                  '${AppStrings.level} $level',
                  style: K.bodySmall.copyWith(
                    color: K.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: K.s12),
              Text('$intoLevel / 100 ${AppStrings.xp}', style: K.bodySmall),
            ],
          ),
          const SizedBox(height: K.s8),
          SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: intoLevel / 100,
                backgroundColor: K.bgSurface,
                valueColor: AlwaysStoppedAnimation(K.accent),
                minHeight: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _totalXp(List<LibraryEntry> entries) {
    return entries.fold(0, (sum, e) {
      return sum + e.watchedEpisodes * 10 + (e.isCompleted ? 50 : 0);
    });
  }

  Widget _buildStatsRow(List<LibraryEntry> entries) {
    final watchedEpisodes = entries.fold<int>(
      0,
      (sum, e) => sum + e.watchedEpisodes,
    );
    final totalHours = (watchedEpisodes * 24 / 60).round();
    final completed = entries.where((e) => e.isCompleted).length;
    final favGenre = _computeFavoriteGenre(entries);

    return Row(
      children: [
        _buildStatCard('${totalHours}h', AppStrings.watchTime),
        const SizedBox(width: K.s8),
        _buildStatCard('$completed', AppStrings.completed),
        const SizedBox(width: K.s8),
        _buildStatCard(favGenre, AppStrings.favGenre),
      ],
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(K.s12),
        decoration: BoxDecoration(
          color: K.bgCard,
          borderRadius: BorderRadius.circular(K.r12),
          border: Border.all(color: K.borderSubtle, width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: K.statNumber.copyWith(fontSize: 24),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: K.s4),
            Text(label.toUpperCase(), style: K.labelUppercase),
          ],
        ),
      ),
    );
  }

  String _computeFavoriteGenre(List<LibraryEntry> entries) {
    final genreCounts = <String, int>{};
    for (final entry in entries) {
      for (final genre in entry.anime.genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }
    if (genreCounts.isEmpty) return AppStrings.none;
    final sorted = genreCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.key;
  }

  Widget _buildAnimePersonality(List<LibraryEntry> entries) {
    final favGenre = _computeFavoriteGenre(entries);
    final personality = _derivePersonalityFromGenre(favGenre);

    return Container(
      padding: const EdgeInsets.all(K.s16),
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r12),
        border: Border.all(color: K.borderSubtle, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.yourAnimePersonality.toUpperCase(),
            style: K.labelUppercase,
          ),
          const SizedBox(height: K.s8),
          Text(personality.title, style: K.headlineMedium),
          const SizedBox(height: K.s8),
          Text(personality.description, style: K.bodyMedium),
        ],
      ),
    );
  }

  ({String title, String description}) _derivePersonalityFromGenre(
    String genre,
  ) {
    switch (genre.toLowerCase()) {
      case 'action':
        return (
          title: AppStrings.personalityWarrior,
          description: AppStrings.personalityWarriorDesc,
        );
      case 'fantasy':
        return (
          title: AppStrings.personalityDreamer,
          description: AppStrings.personalityDreamerDesc,
        );
      case 'romance':
        return (
          title: AppStrings.personalityRomantic,
          description: AppStrings.personalityRomanticDesc,
        );
      case 'sci-fi':
        return (
          title: AppStrings.personalityVisionary,
          description: AppStrings.personalityVisionaryDesc,
        );
      case 'mystery':
        return (
          title: AppStrings.personalityDetective,
          description: AppStrings.personalityDetectiveDesc,
        );
      case 'drama':
        return (
          title: AppStrings.personalityStoryteller,
          description: AppStrings.personalityStorytellerDesc,
        );
      default:
        return (
          title: AppStrings.personalityExplorer,
          description: AppStrings.personalityExplorerDesc,
        );
    }
  }

  Widget _buildRecentActivity(List<LibraryEntry> entries) {
    final recent = entries.where((e) => e.updatedAt != null).take(5).toList();

    if (recent.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.recentActivity.toUpperCase(),
            style: K.labelUppercase,
          ),
          const SizedBox(height: K.s12),
          Center(child: Text(AppStrings.noRecentActivity, style: K.bodyLarge)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppStrings.recentActivity.toUpperCase(), style: K.labelUppercase),
        const SizedBox(height: K.s12),
        ...recent.map((entry) {
          final color = _statusColor(entry.status);
          return Padding(
            padding: const EdgeInsets.only(bottom: K.s8),
            child: Container(
              padding: const EdgeInsets.all(K.s12),
              decoration: BoxDecoration(
                color: K.bgCard,
                borderRadius: BorderRadius.circular(K.r8),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: KuroImg(
                        entry.anime.imageUrl,
                        width: 36,
                        height: 36,
                      ),
                    ),
                  ),
                  const SizedBox(width: K.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.status.label,
                          style: K.bodyMedium.copyWith(
                            color: K.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          entry.anime.title,
                          style: K.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: K.s8),
                  Text(_relativeTime(entry.updatedAt!), style: K.bodySmall),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return AppStrings.justNow;
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} ${AppStrings.minutesAgo}';
    }
    if (diff.inHours < 24) return '${diff.inHours} ${AppStrings.hoursAgo}';
    if (diff.inDays < 7) return '${diff.inDays} ${AppStrings.daysAgo}';
    return '${(diff.inDays / 7).floor()} ${AppStrings.weeksAgo}';
  }

  Color _statusColor(WatchStatus status) {
    switch (status) {
      case WatchStatus.watching:
        return K.cyan;
      case WatchStatus.completed:
        return const Color(0xFF4CD97B);
      case WatchStatus.planToWatch:
        return K.orange;
      case WatchStatus.onHold:
        return K.gold;
      case WatchStatus.dropped:
        return K.textTertiary;
    }
  }
}

// ══════════════════════════════════════════════════════════
//  Small building blocks
// ══════════════════════════════════════════════════════════

class _StatusChip extends StatelessWidget {
  final WatchStatus status;
  final Color color;
  const _StatusChip({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: K.s8, vertical: K.s2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(K.rFull),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        status.label,
        style: K.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EpisodeStepper extends StatelessWidget {
  final int value;
  final int total;
  final ValueChanged<int> onChanged;
  const _EpisodeStepper({
    required this.value,
    required this.total,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: K.bgSurface,
        borderRadius: BorderRadius.circular(K.r8),
        border: Border.all(color: K.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _step(
            Icons.remove_rounded,
            value > 0 ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 46,
            child: Text(
              '$value/$total',
              textAlign: TextAlign.center,
              style: K.bodySmall.copyWith(color: K.textPrimary, fontSize: 11),
            ),
          ),
          _step(
            Icons.add_rounded,
            value < total ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _step(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(K.r8),
      child: Padding(
        padding: const EdgeInsets.all(K.s6),
        child: Icon(
          icon,
          size: 16,
          color: onTap == null
              ? K.textTertiary.withValues(alpha: 0.4)
              : K.textPrimary,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(K.r8),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: K.bgSurface,
            borderRadius: BorderRadius.circular(K.r8),
            border: Border.all(color: K.borderSubtle),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
