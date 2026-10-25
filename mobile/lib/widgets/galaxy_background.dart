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
  static final _stars = _makeStars();
  static final _arms = _makeArms();
  static final _core = _arms.where((point) => point.distance < .45).toList();

  static List<Offset> _makeStars() {
    final random = math.Random(41);
    return List.generate(
      110,
      (_) => Offset(random.nextDouble(), random.nextDouble()),
    );
  }

  static List<Offset> _makeArms() {
    final random = math.Random(17);
    return List.generate(700, (index) {
      final radius = math.pow(random.nextDouble(), .7).toDouble();
      final angle =
          radius * 7 +
          (index.isEven ? 0 : math.pi) +
          (random.nextDouble() - .5) * .65;
      return Offset(math.cos(angle) * radius, math.sin(angle) * radius);
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(const Color(0xFF0A101B), BlendMode.src);
    final stars = Paint()..color = const Color(0x70D6E1ED);
    for (var i = 0; i < _stars.length; i++) {
      final star = _stars[i];
      canvas.drawCircle(
        Offset(star.dx * size.width, star.dy * size.height),
        i % 9 == 0 ? 1 : .5,
        stars,
      );
    }
    canvas.save();
    canvas.translate(size.width * .78, size.height * .25);
    canvas.rotate(-.5);
    canvas.scale(size.width * .95, size.width * .42);
    canvas.rotate(motion.value * math.pi * 2);
    canvas.drawPoints(
      PointMode.points,
      _arms,
      Paint()
        ..color = const Color(0x506F8AA6)
        ..strokeWidth = .006
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPoints(
      PointMode.points,
      _core,
      Paint()
        ..color = const Color(0x65C0C9CB)
        ..strokeWidth = .009
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset.zero,
      .025,
      Paint()..color = const Color(0x70D8D5BF),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GalaxyPainter oldDelegate) =>
      oldDelegate.motion != motion;
}
