// Gavin - A quiet offline backdrop; animation never rebuilds the camera or controls.
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

class GalaxyBackground extends StatefulWidget {
  const GalaxyBackground({super.key});
  @override
  State<GalaxyBackground> createState() => _GalaxyBackgroundState();
}

class _GalaxyBackgroundState extends State<GalaxyBackground>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(minutes: 4),
  );
  bool _reduceMotion = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    _updateMotion();
  }

  void _updateMotion() {
    if (_reduceMotion || !_active || !TickerMode.valuesOf(context).enabled) {
      _motion.stop();
    } else if (!_motion.isAnimating) {
      _motion.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _updateMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(painter: _GalaxyPainter(_motion), isComplex: true),
      ),
    ),
  );
}

class _GalaxyPainter extends CustomPainter {
  _GalaxyPainter(this.motion) : super(repaint: motion);
  final Animation<double> motion;
  static final _random = math.Random(41);
  static final _stars = List.generate(
    220,
    (_) => Offset(_random.nextDouble(), _random.nextDouble()),
  );
  // Record the nebula once; moving it never regenerates its geometry or shaders.
  static final Picture _galaxy = _recordGalaxy();

  static Picture _recordGalaxy() {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final random = math.Random(17);
    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(Offset.zero, 1.25, const Color(0x252E1F75));
    for (var arm = 0; arm < 3; arm++) {
      for (var i = 0; i < 48; i++) {
        final radius = .1 + i / 45;
        final angle = radius * 5.2 + arm * math.pi * 2 / 3;
        final point = Offset(math.cos(angle), math.sin(angle)) * radius;
        final clump =
            point +
            Offset(
              (random.nextDouble() - .5) * .13,
              (random.nextDouble() - .5) * .13,
            );
        glow(clump, .08 + random.nextDouble() * .12, const Color(0x307B4EC0));
        glow(clump, .035 + radius * .05, const Color(0x385394C4));
        if (i % 4 == 0) {
          glow(clump, .04, const Color(0x40B86EAD));
        }
      }
    }
    final clusters = [<Offset>[], <Offset>[], <Offset>[]];
    for (var i = 0; i < 2600; i++) {
      final radius = math.pow(random.nextDouble(), .65).toDouble() * 1.15;
      final angle = radius * 5.2 + (i % 3) * math.pi * 2 / 3;
      final scatter = (random.nextDouble() - .5) * .3;
      clusters[i % 3].add(
        Offset(math.cos(angle + scatter), math.sin(angle + scatter)) * radius,
      );
    }
    for (var i = 0; i < clusters.length; i++) {
      canvas.drawPoints(
        PointMode.points,
        clusters[i],
        Paint()
          ..color = [
            const Color(0x806DA8E0),
            const Color(0x70C2A7EF),
            const Color(0xA0EAE2FF),
          ][i]
          ..strokeWidth = i == 2 ? .003 : .005
          ..strokeCap = StrokeCap.round,
      );
    }
    glow(Offset.zero, .4, const Color(0xC0A38ACB));
    glow(Offset.zero, .18, const Color(0xE0F3D9BB));
    glow(Offset.zero, .055, const Color(0xFFFFF1DB));
    return recorder.endRecording();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF060816), BlendMode.src);
    final haze = Paint()
      ..shader =
          const RadialGradient(
            colors: [Color(0xFF20224B), Color(0x00060816)],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width, size.height * .8),
              radius: size.longestSide * .8,
            ),
          );
    canvas.drawRect(Offset.zero & size, haze);
    final stars = Paint();
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      stars.color = i % 7 == 0
          ? const Color(0xD0ECEAFF)
          : const Color(0x707DA3D1);
      final center = Offset(star.dx * size.width, star.dy * size.height);
      canvas.drawCircle(center, i % 11 == 0 ? 1.2 : .55, stars);
    }
    canvas.save();
    canvas.translate(size.width * .15, size.height * .87);
    canvas.rotate(-.65);
    canvas.scale(size.longestSide * .65, size.longestSide * .32);
    canvas.rotate(motion.value * math.pi * 2);
    canvas.drawPicture(_galaxy);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GalaxyPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
