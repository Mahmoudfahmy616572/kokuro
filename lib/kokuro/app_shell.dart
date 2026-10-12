// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
// This app is a Flutter-web PWA; dart:html powers the SW install/update
// bridge (app-install prompt + reload-on-new-version) which has no
// package:web fallback that works from the same codebase.
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'active_branch_scope.dart';
import 'app_strings.dart';
import 'kokuro_bloc.dart';
import 'tokens.dart';
import 'user_profile.dart';

class AppShell extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const AppShell({super.key, required this.navigationShell});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late final GoRouter _router;
  final _searchController = TextEditingController();

  /// Last known library/watchlist size so the bookmark badge doesn't
  /// flicker to 0 while the bloc is on detail/search/loading states.
  int _listCount = 0;

  UserProfile _profile = const UserProfile();

  /// Active branch passed to [ActiveBranchScope]. Set to -1 while a pushed
  /// sub-route (anime detail, character profile) covers the shell so every
  /// background branch — hero rotation, constellation, shimmer — stops
  /// burning frames behind it.
  int _activeIndex = 0;

  /// True when the service worker installed a new build while the app was
  /// running — surfaced as a "new version available" banner with a reload.
  bool _updateAvailable = false;

  /// True while the browser offers a deferred PWA install prompt — surfaced
  /// as a "install the app" banner with an install action.
  bool _installReady = false;

  @override
  void initState() {
    super.initState();
    _activeIndex = widget.navigationShell.currentIndex;
    _loadProfile();
    _listenForUpdates();
    _listenForInstall();
  }

  void _listenForUpdates() {
    if (html.window.isSecureContext != true) return;
    html.window.addEventListener('kokuro:update-available', (_) {
      if (!mounted) return;
      setState(() => _updateAvailable = true);
    });
  }

  void _listenForInstall() {
    if (html.window.isSecureContext != true) return;
    html.window.addEventListener('kokuro:install-ready', (_) {
      if (!mounted) return;
      setState(() => _installReady = true);
    });
    html.window.addEventListener('kokuro:installed', (_) {
      if (!mounted) return;
      setState(() => _installReady = false);
    });
  }

  void _promptInstall() {
    html.window.dispatchEvent(html.Event('kokuro:install-request'));
  }

  void _reloadForUpdate() => html.window.location.reload();

  Future<void> _loadProfile() async {
    final profile = await UserProfile.load();
    if (!mounted) return;
    setState(() => _profile = profile);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _router = GoRouter.of(context);
    _router.routerDelegate.removeListener(_onRouteChanged);
    _router.routerDelegate.addListener(_onRouteChanged);
    _sync();
  }

  @override
  void dispose() {
    _router.routerDelegate.removeListener(_onRouteChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onRouteChanged() => _sync();

  void _sync() {
    final path = _router.routerDelegate.currentConfiguration.uri.path;
    final isShell = const ['/home', '/explore', '/library'].contains(path);
    final next = isShell ? widget.navigationShell.currentIndex : -1;
    if (next != _activeIndex) setState(() => _activeIndex = next);
  }

  int get _selectedIndex => widget.navigationShell.currentIndex;

  void _onNavTap(int index) {
    if (index == _selectedIndex) return;
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: Column(
        children: [
          if (_updateAvailable) _buildUpdateBanner(),
          if (_installReady) _buildInstallBanner(),
          _buildTopNav(),
          Expanded(
            child: ActiveBranchScope(
              index: _activeIndex,
              child: widget.navigationShell,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  //  Top Navigation Bar — matches reference exactly
  // ══════════════════════════════════════════════════════════

  Widget _buildUpdateBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: K.s16, vertical: K.s8),
      color: K.accent.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.system_update_alt_rounded, size: 18),
          const SizedBox(width: K.s8),
          Expanded(
            child: Text(
              AppStrings.updateAvailable,
              style: K.bodySmall.copyWith(color: K.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _reloadForUpdate,
            style: TextButton.styleFrom(
              foregroundColor: K.accent,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(AppStrings.updateNow),
          ),
        ],
      ),
    );
  }

  Widget _buildInstallBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: K.s16, vertical: K.s8),
      color: K.cyan.withValues(alpha: 0.10),
      child: Row(
        children: [
          const Icon(Icons.download_rounded, size: 18),
          const SizedBox(width: K.s8),
          Expanded(
            child: Text(
              AppStrings.installPrompt,
              style: K.bodySmall.copyWith(color: K.textPrimary),
            ),
          ),
          TextButton(
            onPressed: _promptInstall,
            style: TextButton.styleFrom(
              foregroundColor: K.cyan,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(AppStrings.installNow),
          ),
        ],
      ),
    );
  }

  Widget _buildTopNav() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final showSearchBar = width >= 900;
        final showAppName = showSearchBar;
        final showNavLabels = width >= 560;
        final padH = width < 480 ? K.s12 : K.s24;

        return Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: padH),
          decoration: BoxDecoration(
            color: K.bgAlt.withValues(alpha: 0.6),
            border: Border(
              bottom: BorderSide(
                color: K.border.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // Logo
              _buildLogo(),
              if (showAppName) ...[
                const SizedBox(width: K.s8),
                Text(
                  AppStrings.appName,
                  style: K.titleMedium.copyWith(letterSpacing: 2),
                ),
                const SizedBox(width: K.s32),
              ] else
                const SizedBox(width: K.s16),

              // Nav Items
              if (showNavLabels) ...[
                _buildNavItem(0, AppStrings.navHome),
                _buildNavItem(1, AppStrings.navExplore),
                _buildNavItem(2, AppStrings.navLibrary),
              ] else ...[
                _buildNavIcon(0, Icons.home_rounded),
                _buildNavIcon(1, Icons.explore_rounded),
                _buildNavIcon(2, Icons.menu_book_rounded),
              ],
              const SizedBox(width: K.s16),

              // Search Bar (wide) — or a compact magnifier icon
              if (showSearchBar) ...[
                Expanded(child: _buildSearchBar()),
                const SizedBox(width: K.s16),
              ] else ...[
                _buildIconBtn(
                  Icons.search_rounded,
                  onTap: () => context.goNamed('explore'),
                ),
                const SizedBox(width: K.s8),
              ],

              // Icons
              _buildNotificationsBtn(),
              const SizedBox(width: K.s8),
              BlocBuilder<KokuroBloc, KokuroState>(
                buildWhen: (prev, next) =>
                    _resolveListCount(prev) != _resolveListCount(next),
                builder: (context, state) {
                  final count = _resolveListCount(state);
                  return _buildIconBtn(
                    Icons.bookmark_border_rounded,
                    badge: count,
                    onTap: () => context.goNamed('library'),
                  );
                },
              ),
              const SizedBox(width: K.s8),
              _buildProfileAvatar(onTap: () => context.goNamed('profile')),
            ],
          ),
        );
      },
    );
  }

  /// Real library size from the bloc (LibraryLoaded after the library
  /// screen loads, HomeLoaded.watchlistIds on home) — sticky otherwise.
  int _resolveListCount(KokuroState state) {
    if (state is LibraryLoaded) {
      _listCount = state.entries.length;
    } else if (state is HomeLoaded) {
      _listCount = state.watchlistIds.length;
    }
    return _listCount;
  }

  /// Top-bar search: submit jumps to Explore with `?q=…`, and the Explore
  /// screen dispatches the real SearchAnime bloc event from that param.
  void _onSearchSubmitted(String value) {
    final query = value.trim();
    if (query.isEmpty) return;
    context.goNamed('explore', queryParameters: {'q': query});
  }

  void _showNotifications() {
    final size = MediaQuery.sizeOf(context);
    final state = context.read<KokuroBloc>().state;
    final upcoming = state is LibraryLoaded
        ? _sortedUpcoming(state)
        : const <({int id, String title, DateTime at, int episode})>[];

    showMenu<String>(
      context: context,
      color: K.bgCard,
      elevation: 12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(K.r8),
        side: BorderSide(color: K.border.withValues(alpha: 0.3)),
      ),
      position: RelativeRect.fromLTRB(
        size.width - K.s24 - (upcoming.isEmpty ? 200 : 270),
        56,
        K.s24,
        0,
      ),
      items: [
        PopupMenuItem<String>(
          enabled: false,
          height: 36,
          child: Text(AppStrings.notifications, style: K.labelUppercase),
        ),
        if (upcoming.isEmpty)
          PopupMenuItem<String>(
            enabled: false,
            height: 40,
            child: Text(
              AppStrings.noNotifications,
              style: K.bodyMedium.copyWith(color: K.textTertiary),
            ),
          )
        else
          for (final item in upcoming.take(5))
            PopupMenuItem<String>(
              height: 56,
              onTap: () => context.push('/anime/${item.id}'),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: K.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(K.r8),
                    ),
                    child: const Icon(Icons.event_available_rounded, size: 18),
                  ),
                  const SizedBox(width: K.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          item.title,
                          style: K.bodyMedium.copyWith(
                            color: K.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: K.s2),
                        Text(
                          _airingLabel(item),
                          style: K.bodySmall.copyWith(color: K.textTertiary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        if (upcoming.isEmpty)
          PopupMenuItem<String>(
            height: 44,
            onTap: () => context.goNamed('library'),
            child: Text(
              AppStrings.openMyList,
              style: K.bodyMedium.copyWith(color: K.accent),
            ),
          ),
      ],
    );
  }

  /// Upcoming entries filtered to the future and sorted soonest-first.
  List<({int id, String title, DateTime at, int episode})> _sortedUpcoming(
    LibraryLoaded state,
  ) {
    final now = DateTime.now();
    final result = <({int id, String title, DateTime at, int episode})>[];
    for (final entry in state.entries) {
      final next = state.upcoming[entry.anime.malId];
      if (next == null) continue;
      final at = next.at;
      if (at.isBefore(now)) continue;
      result.add((
        id: entry.anime.malId,
        title: entry.anime.title,
        at: at,
        episode: next.episode,
      ));
    }
    result.sort((a, b) => a.at.compareTo(b.at));
    return result;
  }

  static String _airingLabel(
    ({int id, String title, DateTime at, int episode}) item,
  ) {
    final now = DateTime.now();
    final diff = item.at.difference(now);
    final prefix = diff.inMinutes >= 0 && diff.inMinutes < 90
        ? AppStrings.airsTodayIn
        : diff.inHours < 48
        ? AppStrings.airsSoon
        : AppStrings.nextEpisodeAirs;
    return '$prefix ${AppStrings.episode} ${item.episode}'
        ' ${AppStrings.on} ${_formatAiringDate(item.at)}';
  }

  static String _formatAiringDate(DateTime at) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${at.day} ${months[at.month - 1]}';
  }

  Widget _buildNotificationsBtn() {
    return _buildIconBtn(
      Icons.notifications_none_rounded,
      onTap: _showNotifications,
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [K.accent, K.threadSecondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(K.r8),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: Colors.white,
        size: 18,
      ),
    );
  }

  Widget _buildNavItem(int index, String label) {
    final isActive = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: K.s16, vertical: K.s8),
        child: Text(
          label,
          style: K.titleMedium.copyWith(
            fontSize: 14,
            color: isActive ? K.textPrimary : K.textSecondary,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(int index, IconData icon) {
    final isActive = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: K.s4),
      child: GestureDetector(
        onTap: () => _onNavTap(index),
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: isActive
                ? K.accent.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(K.r8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? K.accent : K.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: K.s12),
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r8),
        border: Border.all(color: K.borderSubtle, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: K.textTertiary, size: 16),
          const SizedBox(width: K.s8),
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              onTap: () {
                if (_searchController.text.trim().isEmpty) {
                  context.goNamed('explore');
                }
              },
              style: K.bodySmall.copyWith(color: K.textPrimary),
              decoration: InputDecoration(
                hintText: AppStrings.searchHint,
                hintStyle: K.bodySmall.copyWith(color: K.textTertiary),
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: K.s6,
              vertical: K.s2,
            ),
            decoration: BoxDecoration(
              color: K.bgSurface,
              borderRadius: BorderRadius.circular(K.r4),
            ),
            child: Text(
              '/',
              style: K.bodySmall.copyWith(color: K.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, {VoidCallback? onTap, int badge = 0}) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: K.bgCard,
            borderRadius: BorderRadius.circular(K.r8),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: AlignmentDirectional.topEnd,
            children: [
              Center(child: Icon(icon, color: K.textSecondary, size: 18)),
              if (badge > 0)
                Positioned(
                  top: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: K.accent,
                      borderRadius: BorderRadius.circular(K.rFull),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: K.bodySmall.copyWith(
                        fontSize: 9,
                        height: 1.2,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar({VoidCallback? onTap}) {
    final color = _profile.avatarColor;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Tooltip(
          message: AppStrings.myProfile,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: 0.45),
                width: 1.5,
              ),
            ),
            child: ClipOval(
              child: Container(
                color: K.bgSurface,
                child: Icon(_profile.avatarIcon, color: color, size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
