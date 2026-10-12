import 'dart:math';
import 'package:flutter/material.dart';
import 'tokens.dart';

// ══════════════════════════════════════════════════════════
//  1. Hero Entrance — cinematic staggered reveal
// ══════════════════════════════════════════════════════════

class HeroEntrance extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const HeroEntrance({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1400),
  });

  @override
  State<HeroEntrance> createState() => _HeroEntranceState();
}

class _HeroEntranceState extends State<HeroEntrance>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _swipeAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnim = Tween<double>(begin: 1.08, end: 1.0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.02, 0.55, curve: Curves.easeOutCubic),
      ),
    );
    _swipeAnim = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    _opacityAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0, 0.3, curve: Curves.easeOut),
      ),
    );
    _ctrl.forward();
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
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnim.value,
          child: Transform.translate(
            offset: Offset(_swipeAnim.value, 0),
            child: Transform.scale(scale: _scaleAnim.value, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════════════
//  2. Parallax Layers — multi-depth scroll/mouse parallax
// ══════════════════════════════════════════════════════════

class ParallaxLayers extends StatelessWidget {
  final double mouseX;
  final double mouseY;
  final double scrollOffset;
  final List<ParallaxLayer> layers;

  const ParallaxLayers({
    super.key,
    this.mouseX = 0,
    this.mouseY = 0,
    this.scrollOffset = 0,
    required this.layers,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final layer in layers)
          Transform.translate(
            offset: Offset(
              mouseX * layer.mouseFactor + scrollOffset * layer.scrollFactor,
              mouseY * layer.mouseFactor * 0.5 +
                  scrollOffset * layer.scrollFactor * 0.3,
            ),
            child: layer.child,
          ),
      ],
    );
  }
}

class ParallaxLayer {
  final Widget child;
  final double mouseFactor;
  final double scrollFactor;

  const ParallaxLayer({
    required this.child,
    this.mouseFactor = 0,
    this.scrollFactor = 0,
  });
}

// ══════════════════════════════════════════════════════════
//  3. Character Hover — anime-style interactive hover
// ══════════════════════════════════════════════════════════

class CharacterHover extends StatefulWidget {
  final Widget child;
  final Color? glowColor;
  final double liftAmount;
  final VoidCallback? onTap;

  const CharacterHover({
    super.key,
    required this.child,
    this.glowColor,
    this.liftAmount = -8,
    this.onTap,
  });

  @override
  State<CharacterHover> createState() => _CharacterHoverState();
}

class _CharacterHoverState extends State<CharacterHover> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: K.easeOut,
          transform: Matrix4.diagonal3Values(1, _hovered ? 1.04 : 1.0, 1)
            ..setTranslationRaw(0, _hovered ? widget.liftAmount : 0, 0),
          transformAlignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (_hovered)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(K.r12),
                        boxShadow: [
                          BoxShadow(
                            color: (widget.glowColor ?? K.accent).withValues(
                              alpha: 0.25,
                            ),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: (widget.glowColor ?? K.accent).withValues(
                              alpha: 0.1,
                            ),
                            blurRadius: 60,
                            spreadRadius: 4,
                          ),
                        ],
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
}

// ══════════════════════════════════════════════════════════
//  4. Card Zoom Reveal — image zoom + gradient + info overlay
// ══════════════════════════════════════════════════════════

class CardZoomReveal extends StatefulWidget {
  final Widget image;
  final Widget infoOverlay;
  final double width;
  final double height;
  final Color? glowColor;

  const CardZoomReveal({
    super.key,
    required this.image,
    required this.infoOverlay,
    this.width = 180,
    this.height = 260,
    this.glowColor,
  });

  @override
  State<CardZoomReveal> createState() => _CardZoomRevealState();
}

class _CardZoomRevealState extends State<CardZoomReveal> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: K.easeOut,
        width: widget.width,
        height: widget.height,
        transform: Matrix4.diagonal3Values(
          _hovered ? 1.06 : 1.0,
          _hovered ? 1.06 : 1.0,
          1.0,
        ),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(K.r12),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: (widget.glowColor ?? K.accent).withValues(
                      alpha: 0.2,
                    ),
                    blurRadius: 24,
                    spreadRadius: 1,
                  ),
                  BoxShadow(
                    color: (widget.glowColor ?? K.accent).withValues(
                      alpha: 0.08,
                    ),
                    blurRadius: 48,
                  ),
                ]
              : K.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(K.r12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              AnimatedScale(
                scale: _hovered ? 1.08 : 1.0,
                duration: const Duration(milliseconds: 350),
                curve: K.easeOut,
                child: widget.image,
              ),
              AnimatedOpacity(
                opacity: _hovered ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        K.bg.withValues(alpha: 0.7),
                        K.bg.withValues(alpha: 0.95),
                      ],
                      stops: const [0.3, 0.6, 1.0],
                    ),
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: K.easeOut,
                bottom: _hovered ? 0 : -80,
                left: 0,
                right: 0,
                child: widget.infoOverlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  5. Slash Transition — diagonal anime-style page transition
// ══════════════════════════════════════════════════════════

class SlashTransition extends PageRouteBuilder {
  final Widget page;
  final Color? slashColor;
  final Duration slashDuration;

  SlashTransition({
    required this.page,
    this.slashColor,
    this.slashDuration = const Duration(milliseconds: 350),
  }) : super(
         pageBuilder: (context, animation, secondaryAnimation) => page,
         transitionDuration: slashDuration + const Duration(milliseconds: 300),
         reverseTransitionDuration:
             slashDuration + const Duration(milliseconds: 200),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           final slashCtrl = CurvedAnimation(
             parent: animation,
             curve: const Interval(0, 0.5, curve: Curves.easeOutCubic),
           );
           final pageCtrl = CurvedAnimation(
             parent: animation,
             curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
           );
           return Stack(
             children: [
               AnimatedBuilder(
                 animation: slashCtrl,
                 builder: (_, c) => ClipPath(
                   clipper: _SlashClipper(progress: slashCtrl.value),
                   child: Container(
                     color: slashColor ?? K.accent,
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
}

class _SlashClipper extends CustomClipper<Path> {
  final double progress;

  _SlashClipper({required this.progress});

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final sweep = progress * 1.5;

    return Path()
      ..moveTo(-w * 0.3, 0)
      ..lineTo(w * sweep - w * 0.3, 0)
      ..lineTo(w * sweep + w * 0.2, h)
      ..lineTo(-w * 0.3 - w * 0.2, h)
      ..close();
  }

  @override
  bool shouldReclip(covariant _SlashClipper old) => old.progress != progress;
}

// ══════════════════════════════════════════════════════════
//  6. Speed Lines — anime-style motion lines
// ══════════════════════════════════════════════════════════

class SpeedLines extends StatefulWidget {
  final Duration duration;
  final int lineCount;
  final Color color;
  final double maxWidth;

  const SpeedLines({
    super.key,
    this.duration = const Duration(milliseconds: 400),
    this.lineCount = 12,
    this.color = K.textPrimary,
    this.maxWidth = 2,
  });

  @override
  State<SpeedLines> createState() => _SpeedLinesState();
}

class _SpeedLinesState extends State<SpeedLines>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration)
      ..forward()
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          _ctrl.reverse();
        }
      });
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
          painter: _SpeedLinesPainter(
            progress: _ctrl.value,
            lineCount: widget.lineCount,
            color: widget.color,
            maxWidth: widget.maxWidth,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _SpeedLinesPainter extends CustomPainter {
  final double progress;
  final int lineCount;
  final Color color;
  final double maxWidth;

  _SpeedLinesPainter({
    required this.progress,
    required this.lineCount,
    required this.color,
    required this.maxWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = progress < 0.5 ? progress * 2 : (1 - progress) * 2;
    if (opacity <= 0) return;
    final paint = Paint()..strokeCap = StrokeCap.round;
    final rng = Random(42);

    for (var i = 0; i < lineCount; i++) {
      final y = rng.nextDouble() * size.height;
      final startX = -size.width * 0.2 + rng.nextDouble() * size.width * 0.3;
      final len = size.width * (0.3 + rng.nextDouble() * 0.5);
      final swipe = progress * len * 1.5;

      paint
        ..color = color.withValues(
          alpha: opacity * (0.15 + rng.nextDouble() * 0.25),
        )
        ..strokeWidth = 0.5 + rng.nextDouble() * maxWidth;

      canvas.drawLine(
        Offset(startX + swipe, y),
        Offset(startX + swipe + len * 0.4, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter old) =>
      old.progress != progress;
}

// ══════════════════════════════════════════════════════════
//  7. Energy Aura — animated glow behind content
// ══════════════════════════════════════════════════════════

class EnergyAura extends StatefulWidget {
  final Widget child;
  final Color? color;
  final double minOpacity;
  final double maxOpacity;
  final double blurRadius;

  const EnergyAura({
    super.key,
    required this.child,
    this.color,
    this.minOpacity = 0.15,
    this.maxOpacity = 0.35,
    this.blurRadius = 40,
  });

  @override
  State<EnergyAura> createState() => _EnergyAuraState();
}

class _EnergyAuraState extends State<EnergyAura>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary keeps the pulsing aura in its own layer so the glow
    // never forces sibling content to repaint every animation frame.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final opacity =
              widget.minOpacity + (widget.maxOpacity - widget.minOpacity) * t;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (widget.color ?? K.accent).withValues(
                            alpha: opacity,
                          ),
                          blurRadius: widget.blurRadius,
                          spreadRadius: widget.blurRadius * 0.3,
                        ),
                        BoxShadow(
                          color: (widget.color ?? K.accent).withValues(
                            alpha: opacity * 0.4,
                          ),
                          blurRadius: widget.blurRadius * 1.5,
                          spreadRadius: widget.blurRadius * 0.1,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              widget.child,
            ],
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════
//  8. Floating Particles — themed anime particle field
// ══════════════════════════════════════════════════════════

class FloatingParticles extends StatefulWidget {
  final int count;
  final List<Color>? colors;
  final double maxSize;
  final double speed;
  final ParticleShape shape;

  const FloatingParticles({
    super.key,
    this.count = 20,
    this.colors,
    this.maxSize = 4,
    this.speed = 0.3,
    this.shape = ParticleShape.dot,
  });

  @override
  State<FloatingParticles> createState() => _FloatingParticlesState();
}

enum ParticleShape { dot, star, diamond }

class _FloatingParticlesState extends State<FloatingParticles>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    final colors = widget.colors ?? <Color>[K.accent, K.cyan, K.pink];
    _particles = List.generate(widget.count, (_) {
      return _Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1 + rng.nextDouble() * (widget.maxSize - 1),
        speed: 0.2 + rng.nextDouble() * widget.speed,
        color: colors[rng.nextInt(colors.length)],
        phase: rng.nextDouble() * pi * 2,
        drift: (rng.nextDouble() - 0.5) * 0.4,
      );
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..repeat();
    _ctrl.addListener(_tick);
  }

  void _tick() {
    for (final p in _particles) {
      p.y -= p.speed * 0.004;
      p.x += sin(p.phase + _ctrl.value * 6) * p.drift * 0.002;
      if (p.y < -0.05) {
        p.y = 1.05;
        p.x = Random().nextDouble();
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary isolates the particle canvas so its constant ticking
    // only re-rasters this small layer — never the full-screen hero stack.
    return RepaintBoundary(
      child: IgnorePointer(
        child: CustomPaint(
          painter: _ParticlePainter(particles: _particles, shape: widget.shape),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _Particle {
  double x, y, size, speed, phase, drift;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
    required this.phase,
    required this.drift,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final ParticleShape shape;

  _ParticlePainter({required this.particles, required this.shape});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color.withValues(alpha: 0.3 + 0.4 * (p.size / 4));
      final cx = p.x * size.width;
      final cy = p.y * size.height;

      switch (shape) {
        case ParticleShape.star:
          _drawStar(canvas, cx, cy, p.size, paint);
          break;
        case ParticleShape.diamond:
          final path = Path()
            ..moveTo(cx, cy - p.size)
            ..lineTo(cx + p.size * 0.6, cy)
            ..lineTo(cx, cy + p.size)
            ..lineTo(cx - p.size * 0.6, cy)
            ..close();
          canvas.drawPath(path, paint);
          break;
        case ParticleShape.dot:
          canvas.drawCircle(Offset(cx, cy), p.size, paint);
          break;
      }
    }
  }

  void _drawStar(Canvas canvas, double cx, double cy, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 4; i++) {
      final angle = i * pi / 2;
      final outerX = cx + cos(angle) * r;
      final outerY = cy + sin(angle) * r;
      final innerAngle = angle + pi / 4;
      final innerX = cx + cos(innerAngle) * r * 0.4;
      final innerY = cy + sin(innerAngle) * r * 0.4;
      if (i == 0) {
        path.moveTo(outerX, outerY);
      } else {
        path.lineTo(outerX, outerY);
      }
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ══════════════════════════════════════════════════════════
//  9. Kinetic Typography — staggered word/letter animation
// ══════════════════════════════════════════════════════════

class KineticText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final KineticMode mode;
  final Duration duration;
  final Duration stagger;

  const KineticText({
    super.key,
    required this.text,
    required this.style,
    this.mode = KineticMode.word,
    this.duration = const Duration(milliseconds: 800),
    this.stagger = const Duration(milliseconds: 80),
  });

  @override
  State<KineticText> createState() => _KineticTextState();
}

enum KineticMode { word, letter }

class _KineticTextState extends State<KineticText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _animations;

  List<String> _tokenize(String text) => widget.mode == KineticMode.letter
      ? text.split('')
      : text.split(RegExp(r'(?<=\s)'));

  void _buildAnimations() {
    final tokens = _tokenize(widget.text);
    _animations = List.generate(tokens.length, (i) {
      final start =
          (i * widget.stagger.inMilliseconds) / widget.duration.inMilliseconds;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _ctrl,
          curve: Interval(start, end, curve: Curves.easeOutCubic),
        ),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _buildAnimations();
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant KineticText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.mode != widget.mode ||
        oldWidget.stagger != widget.stagger) {
      _ctrl.reset();
      _buildAnimations();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = _tokenize(widget.text);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Wrap(
          children: List.generate(tokens.length, (i) {
            final anim = i < _animations.length
                ? _animations[i]
                : _animations.last;
            return Opacity(
              opacity: anim.value,
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - anim.value)),
                child: Text(tokens[i], style: widget.style),
              ),
            );
          }),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════
//  10. Scroll-Scrubbed Hero — transforms with scroll position
// ══════════════════════════════════════════════════════════

class ScrollScrubbedHero extends StatelessWidget {
  final double scrollOffset;
  final double maxHeight;
  final Widget child;

  const ScrollScrubbedHero({
    super.key,
    required this.scrollOffset,
    required this.maxHeight,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (scrollOffset / maxHeight).clamp(0.0, 1.0);
    final scale = 1.0 - progress * 0.15;
    final opacity = (1.0 - progress * 0.6).clamp(0.0, 1.0);

    return Opacity(
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, -progress * 40),
        child: Transform.scale(scale: scale, child: child),
      ),
    );
  }
}
