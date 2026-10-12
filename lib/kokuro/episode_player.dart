// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../domain/entities/anime.dart';
import 'app_strings.dart';
import 'tokens.dart';
import 'components.dart';

/// Plays a single episode from YouTube (official channels) by searching
/// `"<title> episode <n>"` and reports **real** playback progress so the
/// user's library can be updated automatically when they actually watch.
///
/// The actual YouTube embed + IFrame API live in the JS bridge in
/// `web/index.html`; this widget only mounts a container and reacts to the
/// `infoDelivery` messages the bridge pushes ~4x/second.
class EpisodePlayer extends StatefulWidget {
  final Anime anime;
  final int episodeNumber;
  final int totalEpisodes;
  final VoidCallback? onStarted;
  final ValueChanged<double>? onProgress;
  final VoidCallback? onCompleted;
  final VoidCallback? onClose;

  const EpisodePlayer({
    super.key,
    required this.anime,
    required this.episodeNumber,
    required this.totalEpisodes,
    this.onStarted,
    this.onProgress,
    this.onCompleted,
    this.onClose,
  });

  @override
  State<EpisodePlayer> createState() => _EpisodePlayerState();
}

class _EpisodePlayerState extends State<EpisodePlayer> {
  static final Set<String> _registered = {};

  late final html.EventListener _listener;

  bool _started = false;
  bool _completed = false;
  bool _ready = false;
  bool _muted = true;
  bool _failed = false;
  int? _errorCode;
  int _kicks = 0;
  Timer? _kick;

  double _current = 0;
  double _duration = 0;

  String get _viewType =>
      'kuro-ep-${widget.anime.malId}-${widget.episodeNumber}';
  String get _containerId =>
      'kuro-epbox-${widget.anime.malId}-${widget.episodeNumber}';

  String get _title {
    final t = widget.anime.title.trim();
    return t.isEmpty ? 'anime' : t;
  }

  String get _query => '$_title episode ${widget.episodeNumber}';

  @override
  void initState() {
    super.initState();
    _listener = _onMessage;
    html.window.addEventListener('message', _listener);
    _registerView();
    _kick = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => _kickstart(),
    );
  }

  @override
  void dispose() {
    _kick?.cancel();
    html.window.removeEventListener('message', _listener);
    html.window.postMessage(
      jsonEncode({
        'channel': 'kuro',
        'viewType': _viewType,
        'event': 'dispose',
      }),
      '*',
    );
    super.dispose();
  }

  void _registerView() {
    if (_registered.contains(_viewType)) return;
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final root = html.DivElement()
        ..className = 'krvp ep'
        ..style.width = '100%'
        ..style.height = '100%';
      root.setInnerHtml(
        '<div id="$_containerId" class="krv-epframe"></div>',
        treeSanitizer: html.NodeTreeSanitizer.trusted,
      );
      html.window.postMessage(
        jsonEncode({
          'channel': 'kuro',
          'viewType': _viewType,
          'event': 'attach',
          'config': {
            'query': _query,
            'controls': true,
            'containerId': _containerId,
          },
        }),
        '*',
      );
      return root;
    });
    _registered.add(_viewType);
  }

  void _send(String func, [List<Object?> args = const []]) {
    html.window.postMessage(
      jsonEncode({
        'channel': 'kuro',
        'viewType': _viewType,
        'event': 'command',
        'func': func,
        'args': args,
      }),
      '*',
    );
  }

  /// Nudges the freshly-mounted embed until it actually starts playing.
  void _kickstart() {
    if (!mounted) return;
    if (_ready) {
      _kick?.cancel();
      return;
    }
    _kicks++;
    if (_kicks > 20) {
      _kick?.cancel();
      return;
    }
    _send('playVideo');
  }

  void _onMessage(html.Event event) {
    if (!mounted) return;
    final message = event as html.MessageEvent;
    final raw = message.data;
    if (raw is! String) return;

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }
    final vt = payload['viewType'];
    if (vt is String && vt != _viewType) return;

    final ev = payload['event'];
    if (ev == 'playerError') {
      _kick?.cancel();
      final code = (payload['code'] as num?)?.toInt();
      // 150 = "video not embeddable" — YouTube search embeds load multiple
      // results as a playlist; it typically skips to the next result on this
      // error, so don't treat it as fatal.
      if (code != 150 && mounted) {
        setState(() {
          _failed = true;
          _errorCode = code;
        });
      }
      return;
    }
    if (ev != 'infoDelivery') return;

    final Map<String, dynamic> info;
    final rawInfo = payload['info'];
    if (rawInfo is String) {
      try {
        info = (jsonDecode(rawInfo) as Map?)?.cast<String, dynamic>() ?? {};
      } catch (_) {
        return;
      }
    } else if (rawInfo is Map) {
      info = rawInfo.cast<String, dynamic>();
    } else {
      return;
    }

    final time = (info['currentTime'] as num?)?.toDouble();
    final duration = (info['duration'] as num?)?.toDouble();
    final rawState = info['playerState'];
    String? state;
    if (rawState is String) {
      state = rawState;
    } else if (rawState is num) {
      const states = [
        'unstarted',
        'ended',
        'playing',
        'paused',
        'buffering',
        'cued',
      ];
      final i = rawState.toInt();
      if (i >= 0 && i < states.length) state = states[i];
    }

    if (time != null) _current = time;
    if (duration != null && duration > 0) _duration = duration;

    if (state == 'playing') {
      _ready = true;
      _failed = false;
      _kick?.cancel();
      if (_muted) {
        _send('unMute');
        _muted = false;
      }
      if (!_started) {
        _started = true;
        widget.onStarted?.call();
      }
    }

    if (_duration > 0) {
      final progress = (_current / _duration).clamp(0.0, 1.0);
      widget.onProgress?.call(progress);
      if (!_completed && (state == 'ended' || progress >= 0.9)) {
        _completed = true;
        widget.onCompleted?.call();
      }
    }

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration > 0
        ? (_current / _duration).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: K.bgCard,
        borderRadius: BorderRadius.circular(K.r12),
        border: Border.all(color: K.border),
      ),
      padding: const EdgeInsets.all(K.s12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${AppStrings.episodeNumber} ${widget.episodeNumber}',
                style: K.labelUppercase,
              ),
              const SizedBox(width: K.s8),
              Text(
                AppStrings.officialYouTube,
                style: K.bodySmall.copyWith(color: K.textTertiary),
              ),
              const Spacer(),
              if (widget.onClose != null)
                IconButton(
                  tooltip: AppStrings.closePlayer,
                  icon: const Icon(
                    Icons.close_rounded,
                    color: K.textSecondary,
                    size: 20,
                  ),
                  onPressed: widget.onClose,
                ),
            ],
          ),
          const SizedBox(height: K.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(K.r8),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  HtmlElementView(viewType: _viewType),
                  if (_failed) _errorOverlay(),
                  if (!_ready && !_failed)
                    ColoredBox(
                      color: const Color(0xCC000000),
                      child: Center(
                        child: CircularProgressIndicator(color: K.accent),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: K.s8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(K.rFull),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: K.bgSurface,
                    valueColor: AlwaysStoppedAnimation(K.accent),
                  ),
                ),
              ),
              const SizedBox(width: K.s12),
              Text(
                '${_fmt(_current)} / ${_fmt(_duration)}',
                style: K.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: K.s6),
          Text(
            _completed
                ? AppStrings.watchedSaved
                : _ready
                ? AppStrings.watchingNow
                : AppStrings.startingStream,
            style: K.bodySmall.copyWith(
              color: _completed ? K.accent : K.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorOverlay() {
    final message = _errorCode == null
        ? AppStrings.couldNotPlay
        : AppStrings.videoUnavailable;
    return ColoredBox(
      color: K.bg.withValues(alpha: 0.96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam_off_rounded, color: K.coral, size: 32),
            const SizedBox(height: K.s12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: K.s24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: K.bodyMedium,
              ),
            ),
            const SizedBox(height: K.s16),
            KokuroButton(
              label: AppStrings.searchOnYouTube,
              icon: Icons.open_in_new_rounded,
              onPressed: () => html.window.open(
                'https://www.youtube.com/results?search_query='
                    '${Uri.encodeComponent(_query)}',
                '_blank',
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double seconds) {
    if (seconds.isNaN || seconds.isInfinite || seconds <= 0) return '0:00';
    final m = (seconds ~/ 60).toString();
    final s = (seconds % 60).toStringAsFixed(0).padLeft(2, '0');
    return '$m:$s';
  }
}
