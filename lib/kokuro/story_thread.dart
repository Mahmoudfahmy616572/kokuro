import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'tokens.dart';

// ══════════════════════════════════════════════════════════
//  Story Thread — the signature visual element of KOKURO
// ══════════════════════════════════════════════════════════

class StoryThread extends StatefulWidget {
  final List<Offset> points;
  final Color? color;
  final double strokeWidth;
  final bool animate;

  const StoryThread({
    super.key,
    required this.points,
    this.color,
    this.strokeWidth = 1.5,
    this.animate = true,
  });

  @override
  State<StoryThread> createState() => _StoryThreadState();
}

class _StoryThreadState extends State<StoryThread>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.animate) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return CustomPaint(
          painter: _ThreadPainter(
            points: widget.points,
            color: widget.color ?? K.threadPrimary,
            strokeWidth: widget.strokeWidth,
            progress: _ctrl.value,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ThreadPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final double progress;

  _ThreadPainter({
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final path = _buildSmoothPath(points);

    // Outer glow
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = color.withValues(alpha: 0.12);
    canvas.drawPath(path, glowPaint);

    // Mid glow
    final midGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 3
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
      ..color = color.withValues(alpha: 0.2);
    canvas.drawPath(path, midGlow);

    // Core line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.5);
    canvas.drawPath(path, linePaint);

    // Travelling light
    if (progress > 0) {
      final metric = path.computeMetrics().first;
      final len = metric.length;
      final lightPos = progress * len;
      final lightPaint = Paint()
        ..shader = ui.Gradient.radial(Offset.zero, 20, [
          color.withValues(alpha: 0.8),
          color.withValues(alpha: 0.0),
        ]);
      final tangent = metric.getTangentForOffset(lightPos);
      if (tangent != null) {
        canvas.drawCircle(tangent.position, 4, lightPaint);
      }
    }
  }

  Path _buildSmoothPath(List<Offset> pts) {
    final path = Path();
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final prev = pts[i - 1];
      final curr = pts[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(covariant _ThreadPainter old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════
//  Thread Node — circular node on a thread
// ══════════════════════════════════════════════════════════

class ThreadNode extends StatelessWidget {
  final Widget child;
  final double size;
  final Color? glowColor;
  final bool isActive;
  final VoidCallback? onTap;

  const ThreadNode({
    super.key,
    required this.child,
    this.size = 64,
    this.glowColor,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color glow = glowColor ?? K.threadPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: K.normal,
        curve: K.easeOut,
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive
                ? glow.withValues(alpha: 0.6)
                : K.border.withValues(alpha: 0.4),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isActive ? K.glow(color: glow, blur: 20) : null,
        ),
        child: ClipOval(child: child),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  Section Thread Decorator
// ══════════════════════════════════════════════════════════

class SectionThreadDecorator extends StatelessWidget {
  final Widget child;
  final Color? threadColor;
  final double width;
  final double height;

  const SectionThreadDecorator({
    super.key,
    required this.child,
    this.threadColor,
    this.width = 200,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: height * 0.4,
          left: -20,
          child: StoryThread(
            points: [
              const Offset(0, 30),
              Offset(width * 0.3, 10),
              Offset(width * 0.6, 35),
              Offset(width, 20),
            ],
            color: threadColor ?? K.threadPrimary,
            strokeWidth: 1,
          ),
        ),
        child,
      ],
    );
  }
}
