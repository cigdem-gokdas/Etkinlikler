import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Lives above navigation: only a new process/root state replays the intro.
class LaunchIntro extends StatefulWidget {
  const LaunchIntro({super.key, required this.child});
  final Widget child;

  @override
  State<LaunchIntro> createState() => _LaunchIntroState();
}

class _LaunchIntroState extends State<LaunchIntro>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _finished = true);
        }
      });
  bool _started = false;
  bool _finished = false;
  bool _reduced = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.accessibleNavigationOf(context);
    if (!_started) {
      _started = true;
      _reduced = reduced;
      if (reduced) _controller.duration = const Duration(milliseconds: 360);
      _controller.forward();
    } else if (reduced && !_reduced) {
      _reduced = true;
      _controller.forward(from: .9);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          excluding: !_finished,
          child: IgnorePointer(ignoring: !_finished, child: widget.child),
        ),
        if (!_finished)
          AnimatedBuilder(
            animation: _controller,
            child: RepaintBoundary(
              child: ShaderMask(
                shaderCallback: (bounds) => const RadialGradient(
                  colors: [Colors.white, Colors.white, Colors.transparent],
                  stops: [0, .64, 1],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: Image.asset(
                  'assets/branding/mobilab_logo.png',
                  width: 330,
                  height: 330,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            builder: (context, logo) {
              final t = _controller.value;
              final approach = Curves.easeInCubic.transform(
                (t / .54).clamp(0, 1),
              );
              final settle = ((t - .54) / .18).clamp(0.0, 1.0);
              final reveal = Curves.easeInOut.transform(
                ((t - .74) / .26).clamp(0, 1),
              );
              final scale = _reduced
                  ? .85
                  : t < .54
                  ? .22 + approach * .91
                  : 1.13 - .13 * Curves.easeOutCubic.transform(settle);
              final shake = _reduced
                  ? 0.0
                  : math.sin(settle * math.pi * 6) * (1 - settle) * 2;
              return Opacity(
                opacity: _reduced ? 1 - t : 1 - reveal,
                child: AnnotatedRegion<SystemUiOverlayStyle>(
                  value: SystemUiOverlayStyle.dark,
                  child: ColoredBox(
                    key: const ValueKey('launch-intro'),
                    color: const Color(0xFFFAFAF8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.identity()
                              ..setEntry(3, 2, .001)
                              ..translateByDouble(shake, -shake * .4, 0, 1)
                              ..rotateY(_reduced ? 0 : (1 - approach) * -.28)
                              ..rotateX(_reduced ? 0 : (1 - approach) * .12)
                              ..scaleByDouble(scale, scale, 1, 1),
                            child: logo,
                          ),
                        ),
                        if (!_reduced && t >= .54)
                          RepaintBoundary(
                            child: CustomPaint(
                              key: const ValueKey('impact-fracture'),
                              painter: ImpactCrackPainter(
                                progress: ((t - .54) / .16).clamp(0, 1),
                                opacity:
                                    (1 - ((t - .66) / .17).clamp(0, 1)) * .48,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    ),
  );
}

class ImpactCrackPainter extends CustomPainter {
  const ImpactCrackPainter({required this.progress, required this.opacity});
  final double progress;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity == 0) return;
    final origin = Offset(size.width * .5, size.height * .47);
    final radius = size.shortestSide * .67;
    final paint = Paint()
      ..color = const Color(0xFF315C50).withValues(alpha: opacity)
      ..strokeWidth = .7
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 7; i++) {
      final angle = i * math.pi * 2 / 7 + .19;
      Offset point(double r, double a) =>
          origin + Offset(math.cos(a), math.sin(a)) * radius * r * progress;
      final p1 = point(.28, angle);
      final p2 = point(.56, angle + (i.isEven ? .10 : -.08));
      final p3 = point(.86 + i % 3 * .07, angle);
      final path = Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy);
      canvas.drawPath(
        path.shift(const Offset(.8, .8)),
        Paint()
          ..color = Colors.white.withValues(alpha: opacity)
          ..strokeWidth = 1.3
          ..style = PaintingStyle.stroke,
      );
      canvas.drawPath(path, paint);
      final branch = point(.77, angle + (i.isEven ? .22 : -.23));
      canvas.drawLine(p2, branch, paint);
    }
  }

  @override
  bool shouldRepaint(ImpactCrackPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.opacity != opacity;
}
