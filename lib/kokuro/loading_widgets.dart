import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'tokens.dart';

/// Anime-flavored loading indicator — a spinning "star shuriken" core wrapped
/// in expanding nebula rings. Reads like a scene transition inside an anime,
/// not a generic OS spinner. Skeleton feeds use [FeedSkeleton] (shimmer).
class KokuroLoader extends StatefulWidget {
  final String? label;
  final double size;
  final bool compact;

  const KokuroLoader({
    super.key,
    this.label,
    this.size = 56,
    this.compact = false,
  });

  @override
  State<KokuroLoader> createState() => _KokuroLoaderState();
}

class _KokuroLoaderState extends State<KokuroLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final label = widget.label;

    if (widget.compact) {
      return SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => Transform.rotate(
            angle: _controller.value * 2 * math.pi,
            child: _StarCore(size: size * 0.8),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size * 2.4,
          height: size * 2.4,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final t = _controller.value;
              return Stack(
                alignment: Alignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    _ExpandingRing(
                      phase: (t + i / 3) % 1.0,
                      ringSize: size * 1.7,
                      accent: i == 0
                          ? K.accent
                          : i == 1
                          ? K.cyan
                          : K.threadPink,
                    ),
                  Transform.rotate(
                    angle: t * 2 * math.pi,
                    child: _StarCore(size: size * 0.62),
                  ),
                  Transform.rotate(
                    angle: -t * 4 * math.pi,
                    child: SizedBox(
                      width: size * 2.4,
                      height: size * 2.4,
                      child: CustomPaint(
                        painter: _OrbitSparkPainter(progress: t),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: K.s16),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final glow =
                  0.55 + 0.45 * math.sin(_controller.value * 2 * math.pi);
              return Text(
                label,
                style: K.bodyMedium.copyWith(
                  color: K.textSecondary.withValues(alpha: glow),
                  letterSpacing: 2,
                ),
              );
            },
          ),
          const SizedBox(height: K.s4),
          Text('✦', style: K.bodySmall.copyWith(color: K.accentSoft)),
        ],
      ],
    );
  }
}

/// A four-pointed star (shuriken) drawn with a gradient.
class _StarCore extends StatelessWidget {
  final double size;

  const _StarCore({required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _StarPainter());
  }
}

class _StarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.width / 2;
    final inner = outer * 0.38;
    final path = Path();

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final radius = i.isEven ? outer : inner;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();

    final rect = Rect.fromCenter(
      center: center,
      width: size.width,
      height: size.height,
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [K.accent, K.cyan],
      ).createShader(rect);
    canvas.drawPath(path, paint);

    final glowPaint = Paint()
      ..color = K.accent.withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant _StarPainter oldDelegate) => false;
}

/// One expanding, fading ring (like a power-up aura).
class _ExpandingRing extends StatelessWidget {
  final double phase;
  final double ringSize;
  final Color accent;

  const _ExpandingRing({
    required this.phase,
    required this.ringSize,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final scale = 0.18 + phase * 0.85;
    final opacity = (1 - phase).clamp(0.0, 1.0);
    return Opacity(
      opacity: opacity * 0.55,
      child: Container(
        width: ringSize,
        height: ringSize,
        transform: Matrix4.diagonal3Values(scale, scale, 1),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.5),
          boxShadow: K.glow(color: accent, blur: 10),
        ),
      ),
    );
  }
}

/// Two small sparks orbiting the core, like stars being drawn in.
class _OrbitSparkPainter extends CustomPainter {
  final double progress;

  _OrbitSparkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide * 0.44;
    for (var i = 0; i < 2; i++) {
      final angle = progress * 2 * math.pi + i * math.pi;
      final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      final paint = Paint()
        ..color = i == 0 ? K.cyan : K.threadPink
        ..style = PaintingStyle.fill;
      canvas.drawCircle(pos, 2.4, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitSparkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ══════════════════════════════════════════════════════════
//  Shimmer — the loading placeholder now uses a moving highlight
//  sweep instead of the static spinner.
// ══════════════════════════════════════════════════════════

class KShimmer extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  final Color? base;
  final Color? highlight;

  const KShimmer({
    super.key,
    required this.width,
    required this.height,
    this.radius = 8,
    this.base,
    this.highlight,
  });

  @override
  State<KShimmer> createState() => _KShimmerState();
}

class _KShimmerState extends State<KShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + 3 * t, 0),
            end: Alignment(-0.5 + 3 * t, 0),
            colors: [
              widget.base ?? K.bgCard,
              widget.highlight ?? K.border.withValues(alpha: 0.35),
              widget.base ?? K.bgCard,
            ],
          ).createShader(bounds),
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: K.bgCard,
              borderRadius: BorderRadius.circular(widget.radius),
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton grid shown while the explore/home feed is loading — shimmering
/// poster placeholders arranged in the same grid metrics as the real feed.
class FeedSkeleton extends StatelessWidget {
  final bool isNarrow;
  final int itemCount;

  const FeedSkeleton({super.key, this.isNarrow = false, this.itemCount = 12});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: isNarrow ? 175 : 210,
        mainAxisSpacing: K.s24,
        crossAxisSpacing: K.s16,
        childAspectRatio: 200 / 280,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: KShimmer(width: double.infinity, height: double.infinity),
          ),
          SizedBox(height: K.s8),
          KShimmer(width: 110, height: 10, radius: 4),
          SizedBox(height: K.s6),
          KShimmer(width: 70, height: 8, radius: 4),
        ],
      ),
    );
  }
}
