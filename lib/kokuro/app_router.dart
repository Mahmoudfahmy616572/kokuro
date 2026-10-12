import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../data/datasources/jikan_remote_datasource.dart';
import '../domain/entities/anime.dart';
import 'app_shell.dart';
import 'app_strings.dart';
import 'character_screen.dart';
import 'components.dart';
import 'detail_screen.dart';
import 'explore_screen.dart';
import 'home_screen.dart';
import 'kokuro_bloc.dart';
import 'library_screen.dart';
import 'profile_screen.dart';
import 'tokens.dart';

/// go_router is the single source of truth for navigation in KOKURO.
/// The three top-level tabs live inside a StatefulShellRoute (keeps each
/// tab's scroll state alive, like the old IndexedStack), while detail and
/// character pages are ordinary child routes on top.
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  observers: [HeroController()],
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          AppShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              name: 'home',
              builder: (context, state) => const HomeScreen(branchIndex: 0),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/explore',
              name: 'explore',
              builder: (context, state) => ExploreScreen(
                branchIndex: 1,
                initialParams: state.uri.queryParameters,
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/library',
              name: 'library',
              builder: (context, state) => const LibraryScreen(branchIndex: 2),
            ),
          ],
        ),
      ],
    ),
    GoRoute(
      path: '/anime/:id',
      name: 'detail',
      pageBuilder: (context, state) {
        final child = AnimeDetailScreen(
          animeId: int.tryParse(state.pathParameters['id'] ?? '') ?? 0,
          anime: state.extra is Anime ? (state.extra as Anime) : null,
        );
        return CustomTransitionPage<void>(
          key: state.pageKey,
          transitionDuration: const Duration(milliseconds: 1100),
          reverseTransitionDuration: const Duration(milliseconds: 850),
          child: child,
          transitionsBuilder: (_, animation, _, child) {
            final slashCtrl = CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.55, curve: Curves.easeOutCubic),
            );
            final pageCtrl = CurvedAnimation(
              parent: animation,
              curve: const Interval(0.3, 0.85, curve: Curves.easeOutCubic),
            );
            return Stack(
              children: [
                AnimatedBuilder(
                  animation: slashCtrl,
                  builder: (_, c) => ClipPath(
                    clipper: _DetailSlashClipper(progress: slashCtrl.value),
                    child: Container(
                      color: K.accent.withValues(alpha: 0.6),
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                FadeTransition(opacity: pageCtrl, child: child),
              ],
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/character/:id',
      name: 'character',
      pageBuilder: (context, state) {
        final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
        final extra = state.extra is AnimeCharacter
            ? state.extra as AnimeCharacter
            : null;
        return _fadePage(
          state,
          _CharacterRoute(characterId: id, initial: extra),
        );
      },
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      pageBuilder: (context, state) => _fadePage(state, const ProfileScreen()),
    ),
  ],
);

/// Soft scene-fade for pushed pages — reads like a cut between scenes.
Page<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    transitionDuration: const Duration(milliseconds: 380),
    reverseTransitionDuration: const Duration(milliseconds: 280),
    child: child,
    transitionsBuilder: (_, animation, _, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Resolves the tapped character from the currently loaded detail state so
/// the `/character/:id` URL always works — including browser refresh — even
/// though go_router only carries the character id in the path. The resolved
/// pair is cached for the lifetime of the route so the profile screen's own
/// LoadCharacter (which flips the bloc to KokuroLoading/CharacterLoaded)
/// never makes us fall back to the unavailable view.
class _CharacterRoute extends StatefulWidget {
  final int characterId;

  /// Direct character (e.g. from a search result) — passed via `extra` so
  /// the profile opens instantly instead of waiting for a detail state.
  final AnimeCharacter? initial;

  const _CharacterRoute({required this.characterId, this.initial});

  @override
  State<_CharacterRoute> createState() => _CharacterRouteState();
}

class _CharacterRouteState extends State<_CharacterRoute> {
  AnimeCharacter? _character;
  int? _animeId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<KokuroBloc, KokuroState>(
      builder: (context, state) {
        final char = _character;
        if (char == null && widget.initial != null) {
          _character = widget.initial;
        }
        if (char == null && state is DetailLoaded) {
          for (final c in state.characters) {
            if (c.malId == widget.characterId) {
              _character = c;
              _animeId = state.anime.malId;
            }
          }
        }
        final animeId = _animeId;
        if (char != null) {
          return CharacterProfileScreen(character: char, animeId: animeId ?? 0);
        }
        return const _CharacterUnavailable();
      },
    );
  }
}

class _CharacterUnavailable extends StatelessWidget {
  const _CharacterUnavailable();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: K.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_off_rounded,
              color: K.textTertiary,
              size: 48,
            ),
            const SizedBox(height: K.s16),
            Text(AppStrings.characterNotFound, style: K.bodyLarge),
            const SizedBox(height: K.s24),
            KokuroButton(
              label: AppStrings.goBack,
              icon: Icons.arrow_back_rounded,
              filled: false,
              accentColor: K.accent,
              onPressed: () => context.pop(),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSlashClipper extends CustomClipper<Path> {
  final double progress;
  _DetailSlashClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final sweep = progress * 1.6;
    return Path()
      ..moveTo(-w * 0.25, 0)
      ..lineTo(w * sweep - w * 0.25, 0)
      ..lineTo(w * sweep + w * 0.15, h)
      ..lineTo(-w * 0.25 - w * 0.15, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant _DetailSlashClipper old) =>
      old.progress != progress;
}
